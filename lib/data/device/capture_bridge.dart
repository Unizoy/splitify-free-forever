import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/config/build_flavor.dart';
import 'package:splitify/domain/entities/payment_capture.dart';

final _log = Logger('capture');

/// What the native store hands over: raw capture records (checked by `CaptureValidator` before use) and the ids
/// the bubble dismissed.
typedef CaptureExport = ({List<Object?> captures, List<String> dismissed});

/// Recent group or friend for the bubble's chips.
typedef CaptureChip = ({String id, String name, bool friend});

/// The phone side of the payment bubble (phase 18b, S-224): MethodChannel `splitify/capture` to the Kotlin
/// `CaptureChannel`. [NoCaptureBridge] is used off Android and in tests.
abstract class CaptureBridge {
  bool get supported;
  Future<CaptureExport> export();
  Future<void> ack({required List<String> captures, required List<String> dismissed});
  Future<void> dismiss(String id);
  Future<CapturePermissions> permissions();

  /// Opens the system screen for [access] (`appInfo` for "Allow restricted settings").
  Future<bool> open(String access);
  Future<CaptureSettings> settings();
  Future<void> saveSettings(CaptureSettings s);
  Future<List<CaptureApp>> apps();
  Future<void> setRecents(List<CaptureChip> chips);

  /// Shows a sample bubble (or its notification); true when the bubble itself is on screen.
  Future<bool> showSample({required String payee, required String app});

  /// Sign-out: forget captures and chips (keeps the switches, which belong to the phone).
  Future<void> reset();
}

class MethodChannelCaptureBridge implements CaptureBridge {
  MethodChannelCaptureBridge([MethodChannel? channel])
    : _ch = channel ?? const MethodChannel('splitify/capture');

  final MethodChannel _ch;

  /// Android builds of the `full` flavour (D-028); the `standard` flavour's channel only opens system screens.
  @override
  bool get supported => BuildFlavor.capture && defaultTargetPlatform == TargetPlatform.android;

  Future<Map<String, Object?>> _json(String method, [Map<String, Object?>? args]) async {
    final s = await _ch.invokeMethod<String>(method, args);
    return s == null ? const {} : (jsonDecode(s) as Map).cast<String, Object?>();
  }

  @override
  Future<CaptureExport> export() async {
    try {
      final j = await _json('export');
      return (
        captures: (j['captures'] as List?) ?? const <Object?>[],
        dismissed: [for (final d in (j['dismissed'] as List?) ?? const <Object?>[]) d.toString()],
      );
    } on PlatformException catch (e) {
      _log.warning('capture export failed: ${e.code}');
      return (captures: const <Object?>[], dismissed: const <String>[]);
    } on MissingPluginException {
      return (captures: const <Object?>[], dismissed: const <String>[]);
    }
  }

  /// Calls [method]; off Android (tests) the channel has no handler and the call is a no-op.
  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      _log.warning('capture $method failed: ${e.code}');
      return null;
    }
  }

  @override
  Future<void> ack({required List<String> captures, required List<String> dismissed}) =>
      _call<void>('ack', {'captures': captures, 'dismissed': dismissed});

  @override
  Future<void> dismiss(String id) => _call<void>('dismiss', {'id': id});

  @override
  Future<CapturePermissions> permissions() async {
    try {
      final j = await _json('permissions');
      return CapturePermissions(
        supported: j['supported'] == true,
        sdk: (j['sdk'] as int?) ?? 0,
        notifications: j['notifications'] == true,
        overlay: j['overlay'] == true,
        accessibility: j['accessibility'] == true,
        postNotifications: j['post_notifications'] == true,
        listening: j['listening'] == true,
        smartConnected: j['smart_connected'] == true,
      );
    } on MissingPluginException {
      return const CapturePermissions();
    }
  }

  @override
  Future<bool> open(String access) async => await _call<bool>('open', {'access': access}) ?? false;

  @override
  Future<CaptureSettings> settings() async {
    try {
      return CaptureSettings.fromJson(await _json('config'));
    } on MissingPluginException {
      return const CaptureSettings();
    }
  }

  @override
  Future<void> saveSettings(CaptureSettings s) =>
      _call<void>('setConfig', {'json': jsonEncode(s.toJson())});

  @override
  Future<List<CaptureApp>> apps() async {
    try {
      final s = await _ch.invokeMethod<String>('apps');
      final list = s == null ? const <Object?>[] : jsonDecode(s) as List;
      return [
        for (final a in list.cast<Map<Object?, Object?>>())
          CaptureApp(
            package: a['package']! as String,
            name: a['name']! as String,
            kind: a['kind']! as String,
            defaultOn: a['default_on'] != false,
            installed: a['installed'] == true,
          ),
      ];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> setRecents(List<CaptureChip> chips) async {
    try {
      await _ch.invokeMethod<void>('setRecents', {
        'json': jsonEncode([
          for (final c in chips) {'id': c.id, 'name': c.name, 'friend': c.friend},
        ]),
      });
    } on MissingPluginException {
      // not on Android
    }
  }

  @override
  Future<bool> showSample({required String payee, required String app}) async =>
      await _call<bool>('sample', {'payee': payee, 'app': app}) ?? false;

  @override
  Future<void> reset() async {
    try {
      await _ch.invokeMethod<void>('reset');
    } on MissingPluginException {
      // not on Android
    }
  }
}

/// Off Android (and the default in tests): nothing to capture.
class NoCaptureBridge implements CaptureBridge {
  const NoCaptureBridge();

  @override
  bool get supported => false;
  @override
  Future<CaptureExport> export() async =>
      (captures: const <Object?>[], dismissed: const <String>[]);
  @override
  Future<void> ack({required List<String> captures, required List<String> dismissed}) async {}
  @override
  Future<void> dismiss(String id) async {}
  @override
  Future<CapturePermissions> permissions() async => const CapturePermissions();
  @override
  Future<bool> open(String access) async => false;
  @override
  Future<CaptureSettings> settings() async => const CaptureSettings();
  @override
  Future<void> saveSettings(CaptureSettings s) async {}
  @override
  Future<List<CaptureApp>> apps() async => const [];
  @override
  Future<void> setRecents(List<CaptureChip> chips) async {}
  @override
  Future<bool> showSample({required String payee, required String app}) async => false;
  @override
  Future<void> reset() async {}
}
