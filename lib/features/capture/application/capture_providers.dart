import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/device/capture_bridge.dart';
import 'package:splitify/data/repositories/capture_repository.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';

/// The native side: MethodChannel on Android; nothing elsewhere and under `flutter test` (host tests have no
/// capture services; widget tests override this with a fake).
final captureBridgeProvider = Provider<CaptureBridge>(
  (ref) =>
      !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          !Platform.environment.containsKey('FLUTTER_TEST')
      ? MethodChannelCaptureBridge()
      : const NoCaptureBridge(),
);

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(captureBridgeProvider),
    ref.watch(clockProvider),
  ),
);

/// "Payments to add", newest first (phase 18b, S-228).
final pendingCapturesProvider = StreamProvider<List<PaymentCapture>>(
  (ref) => ref.watch(captureBridgeProvider).supported
      ? ref.watch(captureRepositoryProvider).watchPending()
      : Stream.value(const <PaymentCapture>[]),
);

/// Live state of the three accesses; refreshed on resume (`ref.invalidate`).
final capturePermissionsProvider = FutureProvider.autoDispose<CapturePermissions>(
  (ref) => ref.watch(captureBridgeProvider).permissions(),
);

/// The allow-listed apps for the per-app switches (installed ones first).
final captureAppsProvider = FutureProvider.autoDispose<List<CaptureApp>>((ref) async {
  final apps = await ref.watch(captureBridgeProvider).apps();
  return [
    for (final a in apps)
      if (a.installed) a,
    for (final a in apps)
      if (!a.installed) a,
  ];
});

/// The feature's switches, stored on the native side (the services read them without Flutter).
final captureSettingsProvider = AsyncNotifierProvider<CaptureSettingsController, CaptureSettings>(
  CaptureSettingsController.new,
);

class CaptureSettingsController extends AsyncNotifier<CaptureSettings> {
  @override
  Future<CaptureSettings> build() async {
    final s = await ref.read(captureBridgeProvider).settings();
    final theme = ref.read(themeModeControllerProvider).name;
    if (s.theme == theme) return s;
    final synced = s.copyWith(theme: theme);
    unawaited(ref.read(captureBridgeProvider).saveSettings(synced));
    return synced;
  }

  Future<void> change(CaptureSettings Function(CaptureSettings s) edit) async {
    final now = state.value ?? const CaptureSettings();
    final next = edit(now);
    state = AsyncData(next);
    await ref.read(captureBridgeProvider).saveSettings(next);
  }

  /// The app's theme changed: the bubble follows it.
  Future<void> theme(ThemeMode mode) => change((s) => s.copyWith(theme: mode.name));
}
