import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/platform/device_auth.dart';
import 'package:splitify/core/platform/secure_window.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/app_lock/domain/lock_policy.dart';

final deviceAuthProvider = Provider<DeviceAuth>((ref) => LocalDeviceAuth());
final secureWindowProvider = Provider<SecureWindow>((ref) => const ChannelSecureWindow());

/// What the lock screen or the settings page should tell the user.
enum LockNotice {
  /// The prompt was cancelled or failed.
  failed,

  /// The phone has no screen lock any more, so app lock turned itself off (never lock anyone out).
  turnedOff,

  /// Turning the lock on needs a screen lock on the phone first.
  needsScreenLock,
}

/// App lock state (X2).
@immutable
final class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.timeout,
    this.locked = false,
    this.covered = false,
    this.authenticating = false,
    this.notice,
  });

  final bool enabled;
  final LockTimeout timeout;

  /// The lock screen shows.
  final bool locked;

  /// The app is in the background with the lock on: a plain cover hides the last frame until the
  /// app is back (then it either locks or uncovers).
  final bool covered;
  final bool authenticating;
  final LockNotice? notice;

  AppLockState copyWith({
    bool? enabled,
    LockTimeout? timeout,
    bool? locked,
    bool? covered,
    bool? authenticating,
    LockNotice? Function()? notice,
  }) => AppLockState(
    enabled: enabled ?? this.enabled,
    timeout: timeout ?? this.timeout,
    locked: locked ?? this.locked,
    covered: covered ?? this.covered,
    authenticating: authenticating ?? this.authenticating,
    notice: notice == null ? this.notice : notice(),
  );
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

/// Lock on cold start and after the timeout in the background; unlock with the phone's own lock;
/// `FLAG_SECURE` while the lock screen shows, recents preview hidden while the lock is on.
class AppLockController extends Notifier<AppLockState> {
  static const enabledKey = 'app_lock.enabled';
  static const timeoutKey = 'app_lock.timeout_min';

  DateTime? _backgroundedAt;

  @override
  AppLockState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final enabled = prefs.getBool(enabledKey) ?? false;
    final s = AppLockState(
      enabled: enabled,
      timeout: LockTimeout.fromMinutes(prefs.getInt(timeoutKey)),
      locked: enabled,
    );
    scheduleMicrotask(() => _syncWindow(s));
    return s;
  }

  /// App lifecycle from the gate. Ignored while the system prompt is up (it pauses the app).
  void onLifecycle(AppLifecycleState life) {
    final s = state;
    if (!s.enabled || s.authenticating) return;
    switch (life) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgroundedAt ??= ref.read(clockProvider).now();
        if (!s.covered) state = s.copyWith(covered: true);
      case AppLifecycleState.resumed:
        final lock = shouldLockOnResume(
          enabled: s.enabled,
          backgroundedAt: _backgroundedAt,
          now: ref.read(clockProvider).now(),
          timeout: s.timeout,
        );
        _backgroundedAt = null;
        _set(s.copyWith(covered: false, locked: s.locked || lock));
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Lock screen → system prompt. No screen lock left → the lock turns itself off.
  Future<void> unlock(String reason) async {
    if (state.authenticating || !state.locked) return;
    state = state.copyWith(authenticating: true, notice: () => null);
    final result = await ref.read(deviceAuthProvider).authenticate(reason);
    switch (result) {
      case DeviceAuthResult.success:
        _set(state.copyWith(authenticating: false, locked: false));
      case DeviceAuthResult.failed:
        state = state.copyWith(authenticating: false, notice: () => LockNotice.failed);
      case DeviceAuthResult.unavailable:
        await _save(enabled: false);
        _set(
          state.copyWith(
            authenticating: false,
            enabled: false,
            locked: false,
            notice: () => LockNotice.turnedOff,
          ),
        );
    }
  }

  /// Settings switch. Both directions ask for the phone's lock first (turning on proves there is
  /// one; turning off can't be done by someone else holding the unlocked phone… after a timeout).
  Future<bool> setEnabled({required bool on, required String reason}) async {
    if (on == state.enabled || state.authenticating) return false;
    final auth = ref.read(deviceAuthProvider);
    if (on && !await auth.available()) {
      state = state.copyWith(notice: () => LockNotice.needsScreenLock);
      return false;
    }
    state = state.copyWith(authenticating: true, notice: () => null);
    final result = await auth.authenticate(reason);
    if (result != DeviceAuthResult.success) {
      state = state.copyWith(
        authenticating: false,
        notice: () =>
            result == DeviceAuthResult.unavailable ? LockNotice.needsScreenLock : LockNotice.failed,
      );
      return false;
    }
    await _save(enabled: on);
    _set(state.copyWith(authenticating: false, enabled: on, locked: false));
    return true;
  }

  Future<void> setTimeout(LockTimeout timeout) async {
    await ref.read(sharedPreferencesProvider).setInt(timeoutKey, timeout.minutes);
    state = state.copyWith(timeout: timeout);
  }

  void clearNotice() => state = state.copyWith(notice: () => null);

  Future<void> _save({required bool enabled}) =>
      ref.read(sharedPreferencesProvider).setBool(enabledKey, enabled);

  void _set(AppLockState s) {
    final before = state;
    state = s;
    if (before.locked != s.locked || before.enabled != s.enabled) unawaited(_syncWindow(s));
  }

  Future<void> _syncWindow(AppLockState s) async {
    final window = ref.read(secureWindowProvider);
    await window.setSecure(on: s.enabled && s.locked);
    await window.setRecentsHidden(hidden: s.enabled);
  }
}
