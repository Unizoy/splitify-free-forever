import 'package:flutter/services.dart';

/// Android's own settings screens (`MainActivity.kt` channel `splitify/settings`).
abstract interface class SystemSettings {
  /// Opens Splitify's notification settings in Android (app info on Android 7); false when nothing opened.
  Future<bool> openNotificationSettings();
}

class ChannelSystemSettings implements SystemSettings {
  const ChannelSystemSettings();

  static const _channel = MethodChannel('splitify/settings');

  @override
  Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ?? false;
    } on MissingPluginException {
      // Tests and platforms without the channel.
      return false;
    } on PlatformException {
      return false;
    }
  }
}
