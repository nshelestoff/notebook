import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart' as bloc_concurrency;

part 'note_bloc.freezed.dart';

@freezed
abstract class NoteState with _$NoteState {
  const NoteState._();

  String? get text => when<String?>(
      initial: () => null,
      addingText: () => null,
      hasText: (text) => text,
      attachingFile: (text) => text,
      hasTextAndFile: (text, _) => text,
      sending: (text, _) => text,
      sent: (text, _) => text,
      error: (text, _, __) => text);

  bool get isProcessing => map<bool>(
      initial: (_) => false,
      addingText: (_) => true,
      hasText: (_) => false,
      attachingFile: (_) => true,
      hasTextAndFile: (_) => false,
      sending: (_) => true,
      sent: (_) => false,
      error: (_) => true);

  String? get path => when<String?>(
      initial: () => null,
      addingText: () => null,
      hasText: (_) => null,
      attachingFile: (_) => null,
      hasTextAndFile: (_, path) => path,
      sending: (_, path) => path,
      sent: (_, path) => path,
      error: (_, path, __) => path);

  const factory NoteState.initial() = _InitialNoteState;

  const factory NoteState.addingText() = _AddingTextNoteState;

  const factory NoteState.hasText({required String text}) = _HasTextNoteState;

  const factory NoteState.attachingFile({required String text}) =
      _AddingFileNoteState;

  const factory NoteState.hasTextAndFile(
      {required String text, required String path}) = _HasTextAndFileNoteState;

  const factory NoteState.sending(
      {required String text, required String path}) = _SendingNoteState;

  const factory NoteState.sent({required String text, required String path}) =
      _SentNoteState;

  const factory NoteState.error(
      {@Default('') String? text,
      @Default('') String? path,
      @Default('Произошла ошибка') String message}) = _ErrorNoteState;
}

@freezed
abstract class NoteEvent with _$NoteEvent {
  const NoteEvent._();

  @Implements<_TextContainer>()
  @With<_InitialStateEmitter>()
  @With<_AddingTextEmitter>()
  @With<_HasTextEmitter>()
  @With<_ErrorEmitter>()
  const factory NoteEvent.addText({required String text}) = _AddTextNoteEvent;

  @Implements<_FileContainer>()
  @With<_AttachingFileEmitter>()
  @With<_HasTextAndFileEmitter>()
  @With<_HasTextEmitter>()
  @With<_ErrorEmitter>()
  const factory NoteEvent.attachFile({required String path}) =
      _AttachFileNoteEvent;

  @With<_HasTextAndFileEmitter>()
  @With<_SendingEmitter>()
  @With<_SentEmitter>()
  @With<_InitialStateEmitter>()
  @With<_ErrorEmitter>()
  const factory NoteEvent.send() = _SendNoteEvent;
}

class NoteBLoC extends Bloc<NoteEvent, NoteState> {
  NoteBLoC() : super(const NoteState.initial()) {
    on<NoteEvent>(
        (event, emitter) => event.map<Future<void>>(
              addText: (event) => _addText(event, emitter),
              attachFile: (event) => _attachFile(event, emitter),
              send: (event) => _send(event, emitter),
            ),
        transformer: bloc_concurrency.droppable());
  }

  Future<void> _attachFile(
      _AttachFileNoteEvent event, Emitter<NoteState> emitter) async {
    try {
      emitter(event.attachingFile(state: state));

      emitter(event.hasTextAndFile(state: state));
    } on Object catch (error, stackTrace) {
      emitter(
          event.error(state: state, message: 'Ошибка при добавлении файла'));
      emitter(event.hasText());
      rethrow;
    }
  }

  Future<void> _addText(
      _AddTextNoteEvent event, Emitter<NoteState> emitter) async {
    try {
      emitter(event.addingText());
      emitter(event.hasText());
    } on Object catch (error, stackTrace) {
      emitter(
          event.error(state: state, message: 'Ошибка при добавлении текста'));
      emitter(event.initial());
      rethrow;
    }
  }

  Future<void> _send(_SendNoteEvent event, Emitter<NoteState> emitter) async {
    try {
      emitter(event.sending(state: state));
      emitter(event.sent(state: state));
    } on Object catch (error, stackTrace) {
      emitter(event.error(state: state, message: 'Ошибка при оправке'));
      emitter(event.hasTextAndFile(state: state));
      rethrow;
    }
  }
}

abstract class _TextContainer {
  String get text;
}

abstract class _FileContainer {
  String get path;
}

mixin _InitialStateEmitter on NoteEvent {
  NoteState initial() => const NoteState.initial();
}

mixin _AddingTextEmitter on NoteEvent {
  NoteState addingText() => const NoteState.addingText();
}

mixin _HasTextEmitter on NoteEvent implements _TextContainer {
  NoteState hasText() => NoteState.hasText(text: text);
}

mixin _ErrorEmitter on NoteEvent {
  NoteState error({required NoteState state, String? message}) =>
      NoteState.error(
          text: state.text,
          message: message ?? 'Произошла ошибка',
          path: state.path);
}

mixin _AttachingFileEmitter on NoteEvent {
  NoteState attachingFile({required NoteState state}) {
    assert(
        state.text != null, 'Нельзя добавлять файл, если текста не существует');
    return NoteState.attachingFile(text: state.text!);
  }
}

mixin _HasTextAndFileEmitter on NoteEvent implements _FileContainer {
  NoteState hasTextAndFile({required NoteState state}) {
    assert(state.text != null,
        'Нельзя добавлять файл, если текста еще не существует');
    return NoteState.hasTextAndFile(text: state.text!, path: path);
  }
}

mixin _SendingEmitter on NoteEvent {
  NoteState sending({required NoteState state}) {
    assert(state.text != null && state.path != null,
        'Можно отправлять только обладая текстом и файлом');
    return NoteState.hasTextAndFile(text: state.text!, path: state.path!);
  }
}

mixin _SentEmitter on NoteEvent {
  NoteState sent({required NoteState state}) {
    assert(state.text != null && state.path != null,
        'Можно отправлять только обладая текстом и файлом');
    return NoteState.sent(text: state.text!, path: state.path!);
  }
}
