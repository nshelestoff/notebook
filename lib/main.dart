import 'package:flutter/material.dart';
import 'app.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart' as bloc_concurrency;
import 'bloc/app_bloc_observer.dart';

void main() => runZonedGuarded<void>(
        () async {
          Bloc.observer = AppBlocObserver.instance();
          Bloc.transformer = bloc_concurrency.sequential<Object?>();
          runApp(const MyApp());
        },
        (error, stack) {

        }
        );
