import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/logging/logger.dart';

/// Starts logging and error handlers, validates the build settings and
/// returns the root widget. Later phases add database, Supabase and Firebase.
Future<Widget> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();
  installErrorHandlers();
  try {
    final env = Env.load();
    return ProviderScope(overrides: [envProvider.overrideWithValue(env)], child: const App());
  } on EnvException catch (e) {
    return ConfigErrorApp(message: e.message);
  }
}
