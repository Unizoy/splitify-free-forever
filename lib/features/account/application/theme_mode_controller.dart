import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:splitify/core/config/preferences.dart';

part 'theme_mode_controller.g.dart';

/// Light / Dark / System choice (B3), stored on the phone. System by default.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  /// Preferences key.
  static const storageKey = 'theme_mode';

  @override
  ThemeMode build() => parse(ref.watch(sharedPreferencesProvider).getString(storageKey));

  /// Switches the theme now and saves the choice.
  Future<void> select(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(storageKey, mode.name);
  }

  /// Stored value → mode; unknown or missing means [ThemeMode.system].
  static ThemeMode parse(String? stored) =>
      ThemeMode.values.firstWhere((m) => m.name == stored, orElse: () => ThemeMode.system);
}
