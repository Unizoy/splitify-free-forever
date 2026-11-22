import 'package:flutter/services.dart' show appFlavor;

/// The Android build flavour (D-028, android/app/build.gradle.kts): `standard` (the default, GitHub/sideload) has
/// no payment bubble; `full` (adb installs, a future Play Store listing) has it.
abstract final class BuildFlavor {
  /// `standard`, `full`, or null when built without a flavour.
  static const String? name = appFlavor;

  /// The payment bubble (phase 18b) is compiled into this build: only the `full` flavour, unless
  /// `--dart-define=CAPTURE=true|false` says otherwise. Without it the bubble's row, screens, routes and
  /// "Payments to add" stay hidden and the native side has no capture services.
  static const bool capture = bool.fromEnvironment('CAPTURE', defaultValue: appFlavor == 'full');
}
