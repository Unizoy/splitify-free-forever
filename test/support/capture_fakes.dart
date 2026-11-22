import 'package:splitify/data/device/capture_bridge.dart';
import 'package:splitify/domain/entities/payment_capture.dart';

/// Scripted [CaptureBridge] for the payment bubble tests (phase 18b): reports `supported`, hands out a
/// configurable export and records every call.
class FakeCaptureBridge implements CaptureBridge {
  FakeCaptureBridge({
    this.captures = const [],
    this.dismissedByBubble = const [],
    this.permissionState = const CapturePermissions(supported: true, sdk: 35),
    this.settingsState = const CaptureSettings(),
    this.appList = const [],
    this.supported = true,
    this.sampleShown = false,
  });

  /// Raw records returned by [export] (as the native store would).
  List<Object?> captures;

  /// Ids the bubble dismissed, returned by [export].
  List<String> dismissedByBubble;

  CapturePermissions permissionState;
  CaptureSettings settingsState;
  List<CaptureApp> appList;
  bool sampleShown;

  @override
  bool supported;

  int exports = 0;
  final acks = <({List<String> captures, List<String> dismissed})>[];
  final dismissed = <String>[];
  final opened = <String>[];
  final saved = <CaptureSettings>[];
  final recents = <List<CaptureChip>>[];
  final samples = <({String payee, String app})>[];
  int resets = 0;

  /// Makes [export] wait, so a test can start concurrent imports.
  Future<void>? exportGate;

  @override
  Future<CaptureExport> export() async {
    exports++;
    await exportGate;
    return (captures: captures, dismissed: dismissedByBubble);
  }

  @override
  Future<void> ack({required List<String> captures, required List<String> dismissed}) async =>
      acks.add((captures: captures, dismissed: dismissed));

  @override
  Future<void> dismiss(String id) async => dismissed.add(id);

  @override
  Future<CapturePermissions> permissions() async => permissionState;

  @override
  Future<bool> open(String access) async {
    opened.add(access);
    return true;
  }

  @override
  Future<CaptureSettings> settings() async => settingsState;

  @override
  Future<void> saveSettings(CaptureSettings s) async {
    saved.add(s);
    settingsState = s;
  }

  @override
  Future<List<CaptureApp>> apps() async => appList;

  @override
  Future<void> setRecents(List<CaptureChip> chips) async => recents.add(chips);

  @override
  Future<bool> showSample({required String payee, required String app}) async {
    samples.add((payee: payee, app: app));
    return sampleShown;
  }

  @override
  Future<void> reset() async => resets++;
}

/// A raw capture record as the native store exports it.
Map<String, Object?> rawCapture({
  String id = '0f8fad5b-d9cb-469f-a165-70867728950e',
  int amount = 50000,
  String? payee = 'Rahul',
  String? note,
  String? ref = '612345678901',
  String package = 'com.google.android.apps.nbu.paisa.user',
  String appName = 'Google Pay',
  String source = 'notification',
  required DateTime at,
}) => {
  'id': id,
  'amount': amount,
  'currency': 'INR',
  'payee': payee,
  'note': note,
  'ref': ref,
  'app_package': package,
  'app_name': appName,
  'source': source,
  'captured_at': at.toUtc().millisecondsSinceEpoch,
}..removeWhere((k, v) => v == null);

/// Capture ids for tests (UUIDs, as the validator requires).
const captureId1 = '0f8fad5b-d9cb-469f-a165-70867728950e';
const captureId2 = '1a2b3c4d-1111-4222-8333-444455556666';
const captureId3 = '2b3c4d5e-2222-4333-9444-555566667777';
const captureId4 = '3c4d5e6f-3333-4444-a555-666677778888';
