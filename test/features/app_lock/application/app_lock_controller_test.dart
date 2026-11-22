import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/platform/device_auth.dart';
import 'package:splitify/core/platform/secure_window.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/app_lock/application/app_lock_controller.dart';
import 'package:splitify/features/app_lock/domain/lock_policy.dart';

import '../../../support/fakes.dart';

class _FakeDeviceAuth implements DeviceAuth {
  bool isAvailable = true;
  final results = <DeviceAuthResult>[];
  final reasons = <String>[];
  Completer<DeviceAuthResult>? hold;

  @override
  Future<bool> available() async => isAvailable;

  @override
  Future<DeviceAuthResult> authenticate(String reason) {
    reasons.add(reason);
    final h = hold;
    if (h != null) return h.future;
    return Future.value(results.isEmpty ? DeviceAuthResult.success : results.removeAt(0));
  }
}

class _FakeWindow implements SecureWindow {
  final secure = <bool>[];
  final recents = <bool>[];

  @override
  Future<void> setSecure({required bool on}) async => secure.add(on);

  @override
  Future<void> setRecentsHidden({required bool hidden}) async => recents.add(hidden);
}

void main() {
  late FakeClock clock;
  late _FakeDeviceAuth auth;
  late _FakeWindow window;
  late SharedPreferences prefs;

  Future<ProviderContainer> make([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    clock = FakeClock(DateTime.utc(2026, 11, 22, 10));
    auth = _FakeDeviceAuth();
    window = _FakeWindow();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(clock),
        deviceAuthProvider.overrideWithValue(auth),
        secureWindowProvider.overrideWithValue(window),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  AppLockController ctl(ProviderContainer c) => c.read(appLockProvider.notifier);
  AppLockState st(ProviderContainer c) => c.read(appLockProvider);

  // TC-X2-01
  group('TC-X2-01 start and lifecycle', () {
    test('cold start with the lock on is locked', () async {
      final c = await make({AppLockController.enabledKey: true, AppLockController.timeoutKey: 5});
      expect(st(c).enabled, isTrue);
      expect(st(c).locked, isTrue);
      expect(st(c).timeout, LockTimeout.min5);
    });

    test('cold start with the lock off is not locked', () async {
      final c = await make();
      expect(st(c).enabled, isFalse);
      expect(st(c).locked, isFalse);
      expect(st(c).timeout, LockTimeout.min1);
    });

    test('paused covers; resumed before the timeout uncovers without lock', () async {
      final c = await make({AppLockController.enabledKey: true});
      await ctl(c).unlock('r');
      ctl(c).onLifecycle(AppLifecycleState.paused);
      expect(st(c).covered, isTrue);
      clock.advance(const Duration(seconds: 59));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(st(c).covered, isFalse);
      expect(st(c).locked, isFalse);
    });

    test('resumed after the timeout locks', () async {
      final c = await make({AppLockController.enabledKey: true});
      await ctl(c).unlock('r');
      ctl(c).onLifecycle(AppLifecycleState.hidden);
      clock.advance(const Duration(minutes: 1));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(st(c).covered, isFalse);
      expect(st(c).locked, isTrue);
    });

    test('lifecycle is ignored while the lock is off', () async {
      final c = await make();
      ctl(c).onLifecycle(AppLifecycleState.paused);
      expect(st(c).covered, isFalse);
    });

    test('lifecycle is ignored while authenticating', () async {
      final c = await make({AppLockController.enabledKey: true});
      auth.hold = Completer();
      final f = ctl(c).unlock('r');
      expect(st(c).authenticating, isTrue);
      ctl(c).onLifecycle(AppLifecycleState.paused);
      expect(st(c).covered, isFalse);
      auth.hold!.complete(DeviceAuthResult.success);
      await f;
    });
  });

  group('unlock', () {
    test('success unlocks and clears FLAG_SECURE', () async {
      final c = await make({AppLockController.enabledKey: true});
      st(c);
      await Future<void>.delayed(Duration.zero);
      expect(window.secure, [true]);
      await ctl(c).unlock('Unlock Splitify');
      expect(auth.reasons, ['Unlock Splitify']);
      expect(st(c).locked, isFalse);
      expect(st(c).authenticating, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(window.secure.last, isFalse);
    });

    test('failure stays locked with the failed notice', () async {
      final c = await make({AppLockController.enabledKey: true});
      auth.results.add(DeviceAuthResult.failed);
      await ctl(c).unlock('r');
      expect(st(c).locked, isTrue);
      expect(st(c).authenticating, isFalse);
      expect(st(c).notice, LockNotice.failed);
      ctl(c).clearNotice();
      expect(st(c).notice, isNull);
    });

    test('unavailable turns the lock off', () async {
      final c = await make({AppLockController.enabledKey: true});
      auth.results.add(DeviceAuthResult.unavailable);
      await ctl(c).unlock('r');
      expect(st(c).enabled, isFalse);
      expect(st(c).locked, isFalse);
      expect(st(c).notice, LockNotice.turnedOff);
      expect(prefs.getBool(AppLockController.enabledKey), isFalse);
    });

    test('does nothing when not locked', () async {
      final c = await make();
      await ctl(c).unlock('r');
      expect(auth.reasons, isEmpty);
    });
  });

  group('setEnabled', () {
    test('on without a phone screen lock: needsScreenLock, stays off', () async {
      final c = await make();
      auth.isAvailable = false;
      final ok = await ctl(c).setEnabled(on: true, reason: 'r');
      expect(ok, isFalse);
      expect(st(c).enabled, isFalse);
      expect(st(c).notice, LockNotice.needsScreenLock);
      expect(auth.reasons, isEmpty);
    });

    test('on with success saves the pref and hides recents', () async {
      final c = await make();
      final ok = await ctl(c).setEnabled(on: true, reason: 'r');
      expect(ok, isTrue);
      expect(st(c).enabled, isTrue);
      expect(st(c).locked, isFalse);
      expect(prefs.getBool(AppLockController.enabledKey), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(window.recents.last, isTrue);
      expect(window.secure.last, isFalse);
    });

    test('on with a failed prompt stays off', () async {
      final c = await make();
      auth.results.add(DeviceAuthResult.failed);
      expect(await ctl(c).setEnabled(on: true, reason: 'r'), isFalse);
      expect(st(c).enabled, isFalse);
      expect(st(c).notice, LockNotice.failed);
      expect(prefs.getBool(AppLockController.enabledKey), isNull);
    });

    test('off needs a successful auth', () async {
      final c = await make({AppLockController.enabledKey: true});
      await ctl(c).unlock('r');
      auth.results.add(DeviceAuthResult.failed);
      expect(await ctl(c).setEnabled(on: false, reason: 'r'), isFalse);
      expect(st(c).enabled, isTrue);
      expect(prefs.getBool(AppLockController.enabledKey), isTrue);

      expect(await ctl(c).setEnabled(on: false, reason: 'r'), isTrue);
      expect(st(c).enabled, isFalse);
      expect(prefs.getBool(AppLockController.enabledKey), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(window.recents.last, isFalse);
    });

    test('same value is a no-op', () async {
      final c = await make();
      expect(await ctl(c).setEnabled(on: false, reason: 'r'), isFalse);
      expect(auth.reasons, isEmpty);
    });
  });

  test('setTimeout saves the pref and updates the state', () async {
    final c = await make();
    await ctl(c).setTimeout(LockTimeout.min15);
    expect(st(c).timeout, LockTimeout.min15);
    expect(prefs.getInt(AppLockController.timeoutKey), 15);
  });

  test('window flags: secure only while enabled and locked', () async {
    final c = await make({AppLockController.enabledKey: true});
    st(c);
    await Future<void>.delayed(Duration.zero);
    expect(window.secure, [true]);
    expect(window.recents, [true]);
    await ctl(c).unlock('r');
    await Future<void>.delayed(Duration.zero);
    expect(window.secure, [true, false]);
    // Locked again after the timeout in the background.
    ctl(c).onLifecycle(AppLifecycleState.paused);
    clock.advance(const Duration(minutes: 2));
    ctl(c).onLifecycle(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(window.secure, [true, false, true]);
  });
}
