import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:notebook/model/authentication_model/user_entity.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart' as bloc_concurrency;
import '../../model/authentication_model/authentication_repository.dart';

part 'authentication_bloc.freezed.dart';

@freezed
abstract class AuthenticationState with _$AuthenticationState {
  const AuthenticationState._();

  AuthenticatedUser? get authenticatedOrNull => maybeMap<AuthenticatedUser?>(
        notAuthenticated: (_) => null,
        orElse: () => user.authenticatedOrNull,
      );

  bool get inProgress => maybeMap<bool>(
        orElse: () => true,
        authenticated: (_) => false,
        notAuthenticated: (_) => false,
      );

  @override
  UserEntity get user => when<UserEntity>(
        authenticated: (user) => user,
        inProgress: (user) => user,
        notAuthenticated: (user) => user,
        successful: (user) => user,
        error: (user, _) => user,
      );

  const factory AuthenticationState.inProgress(
          {@Default(UserEntity.notAuthenticated()) final UserEntity user}) =
      _InProgressAuthenticationState;

  const factory AuthenticationState.notAuthenticated(
          {@Default(UserEntity.notAuthenticated()) final UserEntity user}) =
      _NotAuthenticatedAuthenticationState;

  const factory AuthenticationState.authenticated({
    required final AuthenticatedUser user,
  }) = _AuthenticatedAuthenticationState;

  const factory AuthenticationState.error(
      {@Default(UserEntity.notAuthenticated()) final UserEntity user,
      @Default('Произошла ошибка') String message}) = _ErrorAuthenticationState;

  const factory AuthenticationState.successful(
          {@Default(UserEntity.notAuthenticated()) final UserEntity user}) =
      _SuccessfulAuthenticationState;
}

@freezed
abstract class AuthenticationEvent with _$AuthenticationEvent {
  const AuthenticationEvent._();

  const factory AuthenticationEvent.logIn(
      {required String login,
      required String password}) = _LogInAuthenticationEvent;

  const factory AuthenticationEvent.logOut() = _LogOutAuthenticationEvent;
}

class AuthenticationBLoC
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  AuthenticationBLoC({
    required final IAuthenticationRepository repository,
    UserEntity? userEntity,
  })  : _repository = repository,
        super(userEntity?.when<AuthenticationState>(
                authenticated: (user) =>
                    AuthenticationState.authenticated(user: user),
                notAuthenticated: () =>
                    const AuthenticationState.notAuthenticated()) ??
            const AuthenticationState.notAuthenticated()) {
    on<AuthenticationEvent>(
      (event, emitter) => event.map<Future<void>>(
        logIn: (event) => _logIn(event, emitter),
        logOut: (event) => _logOut(event, emitter),
      ),
      transformer: bloc_concurrency.droppable(),
    );
  }

  final IAuthenticationRepository _repository;

  Future<void> _logIn(_LogInAuthenticationEvent event,
      Emitter<AuthenticationState> emitter) async {
    try {
      emitter(AuthenticationState.inProgress(user: state.user));
      final newUser =
          await _repository.login(login: event.login, password: event.password);
      emitter(AuthenticationState.successful(user: newUser));
    } on Object catch (error, stackTrace) {
      emitter(AuthenticationState.error(
          user: state.user, message: 'Ошибка аутентификации'));
      rethrow;
    } finally {
      emitter(state.user.when<AuthenticationState>(
          authenticated: (user) =>
              AuthenticationState.authenticated(user: user),
          notAuthenticated: () =>
              const AuthenticationState.notAuthenticated()));
    }
  }

  Future<void> _logOut(_LogOutAuthenticationEvent event,
      Emitter<AuthenticationState> emitter) async {
    try {
      emitter(AuthenticationState.inProgress(user: state.user));
      await _repository.logout();
      emitter(const AuthenticationState.successful(
          user: UserEntity.notAuthenticated()));
    } on Object catch (error, stackTrace) {
      emitter(AuthenticationState.error(
          user: state.user, message: 'Ошибка аутентификации'));
      rethrow;
    } finally {
      emitter(state.user.when<AuthenticationState>(
          authenticated: (user) =>
              AuthenticationState.authenticated(user: user),
          notAuthenticated: () =>
              const AuthenticationState.notAuthenticated()));
    }
  }
}
