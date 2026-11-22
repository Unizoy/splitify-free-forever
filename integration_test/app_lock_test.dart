// TC-X2-02 (phase 18): app lock with the phone's real lock screen. Needs a device PIN and a host script
// that answers the system prompt, so it only runs with --dart-define=LOCK_E2E=true:
//   powershell -File tool\e2e\run_lock_e2e.ps1
// The script sets PIN 1234 (`adb shell locksettings set-pin 1234`), watches this test's `LOCK-*` prints,
// checks FLAG_SECURE while locked, types the PIN, sends the app home and back, and clears the PIN.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/app_lock/application/app_lock_controller.dart';
import 'package:splitify/features/app_lock/presentation/app_lock_gate.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

const _run = bool.fromEnvironment('LOCK_E2E');

/// Real time plus a jump the test adds while the app is in the background.
class _JumpClock implements Clock {
  Duration jump = Duration.zero;

  @override
  DateTime now() => DateTime.now().toUtc().add(jump);
}

/// Waits on the real clock without pumping: frames stop while the system prompt or the home screen
/// is in front (LEARNINGS phase 11), and the controller reacts to lifecycle events on its own.
Future<void> _until(WidgetTester t, bool Function() done, String what, {int seconds = 90}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (done()) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) await t.pump();
      return;
    }
  }
  fail('Timed out: $what');
}

/// Pumps (only while the app is in front) until [finder] is gone: on a slow emulator the app resumes a moment
/// after the system prompt closes, so one pump right after the unlock can still show the lock screen (phase 19).
Future<void> _gone(WidgetTester t, Finder finder) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC-X2-02 locked on start, unlock with the device PIN, lock again after the timeout',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppLockController.enabledKey, true);
      await prefs.setInt(AppLockController.timeoutKey, 1);
      final clock = _JumpClock();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(container.dispose);
      final lockScreen = find.byKey(const Key('lock-screen'));

      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            builder: (context, child) => AppLockGate(child: child!),
            home: const Scaffold(
              body: Center(child: Text('secret balances', key: Key('content'))),
            ),
          ),
        ),
      );
      await t.pump(const Duration(seconds: 1));

      // Cold start: locked, the system prompt is up (host types the PIN).
      expect(lockScreen, findsOneWidget);
      expect(container.read(appLockProvider).locked, isTrue);
      debugPrint('LOCK-PROMPT 1');
      await _until(t, () => !container.read(appLockProvider).locked, 'first unlock');
      await _gone(t, lockScreen);
      expect(lockScreen, findsNothing);
      expect(find.byKey(const Key('content')), findsOneWidget);
      debugPrint('LOCK-UNLOCKED 1');

      // Home and back after "2 minutes" (the clock jumps while paused): locked again.
      debugPrint('LOCK-BACKGROUND');
      await _until(
        t,
        () =>
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.hidden,
        'app in the background',
        seconds: 30,
      );
      clock.jump = const Duration(minutes: 2);
      await _until(
        t,
        () => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
        'app back',
        seconds: 30,
      );
      await t.pump(const Duration(milliseconds: 500));
      expect(container.read(appLockProvider).locked, isTrue);
      expect(lockScreen, findsOneWidget);
      debugPrint('LOCK-PROMPT 2');
      await _until(t, () => !container.read(appLockProvider).locked, 'second unlock');
      debugPrint('LOCK-UNLOCKED 2');
    },
    skip: !_run,
  );
}
