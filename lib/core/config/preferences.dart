import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences.g.dart';

/// Local key-value settings (theme mode, small UI choices). Loaded once in
/// bootstrap before `runApp` and injected with an override.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('sharedPreferencesProvider must be overridden in bootstrap');
