import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';

Future<ProviderContainer> containerWith(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // TC-B3-02: the saved choice is restored on start.
  test('TC-B3-02 persisted dark is restored', () async {
    final c = await containerWith({'theme_mode': 'dark'});
    expect(c.read(themeModeControllerProvider), ThemeMode.dark);
  });

  // TC-B3-02
  test('TC-B3-02 persisted light is restored', () async {
    final c = await containerWith({'theme_mode': 'light'});
    expect(c.read(themeModeControllerProvider), ThemeMode.light);
  });

  // TC-B3-02
  test('TC-B3-02 missing value means system', () async {
    final c = await containerWith({});
    expect(c.read(themeModeControllerProvider), ThemeMode.system);
  });

  // TC-B3-02
  test('TC-B3-02 garbage value means system', () async {
    final c = await containerWith({'theme_mode': 'purple'});
    expect(c.read(themeModeControllerProvider), ThemeMode.system);
  });

  // TC-B3-01: choosing a mode takes effect now and is saved.
  test('TC-B3-01 select updates state and writes preferences', () async {
    final c = await containerWith({});
    await c.read(themeModeControllerProvider.notifier).select(ThemeMode.dark);
    expect(c.read(themeModeControllerProvider), ThemeMode.dark);
    expect(c.read(sharedPreferencesProvider).getString(ThemeModeController.storageKey), 'dark');
    await c.read(themeModeControllerProvider.notifier).select(ThemeMode.system);
    expect(c.read(sharedPreferencesProvider).getString('theme_mode'), 'system');
  });

  test('parse handles null', () {
    expect(ThemeModeController.parse(null), ThemeMode.system);
  });

  test('sharedPreferencesProvider must be overridden', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(() => c.read(sharedPreferencesProvider), throwsA(anything));
  });
}
