import 'package:flutter/services.dart';

/// Window privacy flags of the Android activity (X2, `MainActivity.kt` channel `splitify/window`).
abstract interface class SecureWindow {
  /// `FLAG_SECURE` on/off: blank in recents and no screenshots (only while the lock screen shows).
  Future<void> setSecure({required bool on});

  /// Hide the app's preview in recent apps (Android 13+ `setRecentsScreenshotEnabled(false)`)
  /// while app lock is on, without blocking screenshots in normal use.
  Future<void> setRecentsHidden({required bool hidden});
}

class ChannelSecureWindow implements SecureWindow {
  const ChannelSecureWindow();

  static const _channel = MethodChannel('splitify/window');

  @override
  Future<void> setSecure({required bool on}) => _call('setSecure', on);

  @override
  Future<void> setRecentsHidden({required bool hidden}) => _call('setRecentsHidden', hidden);

  Future<void> _call(String method, bool value) async {
    try {
      await _channel.invokeMethod<void>(method, value);
    } on MissingPluginException {
      // Tests and platforms without the channel.
    } on PlatformException {
      // Older Android versions: nothing to do.
    }
  }
}
