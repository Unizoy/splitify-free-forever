// Shared helpers for the payment bubble widget tests and goldens (phase 18b).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/ui/components/components.dart';

import '../../support/capture_fakes.dart';
import '../expenses/expense_fixtures.dart';
import '../expenses/presentation/presentation_harness.dart';

/// Three allow-listed apps: two installed (one switched off by default), one not on the phone.
const sampleApps = [
  CaptureApp(
    package: 'com.google.android.apps.nbu.paisa.user',
    name: 'Google Pay',
    kind: 'upi',
    installed: true,
  ),
  CaptureApp(package: 'com.phonepe.app', name: 'PhonePe', kind: 'upi', installed: true),
  CaptureApp(package: 'com.hdfc.sms', name: 'HDFC Bank SMS', kind: 'sms', defaultOn: false),
];

/// A capture as the repository hands it out.
PaymentCapture sampleCapture({
  String id = captureId1,
  int amount = 125050,
  String? payee = 'Rahul',
  String? ref = '612345678901',
  String appName = 'Google Pay',
  CaptureSource source = CaptureSource.notification,
  DateTime? at,
}) => PaymentCapture(
  id: id,
  amount: amount,
  payee: payee,
  ref: ref,
  appPackage: 'com.google.android.apps.nbu.paisa.user',
  appName: appName,
  source: source,
  capturedAt: at ?? DateTime.utc(2026, 11, 21, 4, 30),
);

/// Writes [c] to the local payment_captures table (what an import does).
Future<void> storeCapture(AppDatabase db, PaymentCapture c) => db
    .into(db.paymentCaptures)
    .insertOnConflictUpdate(
      LocalPaymentCapture(
        id: c.id,
        amount: c.amount,
        currency: c.currency,
        payee: c.payee,
        note: c.note,
        ref: c.ref,
        appPackage: c.appPackage,
        appName: c.appName,
        source: c.source.name,
        capturedAt: c.capturedAt.toUtc().toIso8601String(),
      ),
    );

/// Overrides that put the capture providers on [bridge] (and give the theme controller its preferences).
Future<List<Override>> captureOverrides(FakeCaptureBridge bridge) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    captureBridgeProvider.overrideWithValue(bridge),
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];
}

/// [screen] on a tall phone so every row can be tapped.
Future<void> pumpCapture(
  WidgetTester t,
  Widget screen, {
  required FakeCaptureBridge bridge,
  List<Override> overrides = const [],
  double height = 3200,
}) async {
  usePhone(t);
  t.view.physicalSize = Size(412, height);
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    expenseApp(
      screen,
      size: Size(412, height),
      overrides: [...await captureOverrides(bridge), ...overrides],
    ),
  );
  await settle(t);
}

/// Value of the switch inside the row [key].
bool switchOn(WidgetTester t, String key) => t
    .widget<PillSwitch>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(PillSwitch)),
    )
    .value;

/// True when the toggle row [key] reacts to taps.
bool rowEnabled(WidgetTester t, String key) =>
    t.widget<ToggleRow>(find.byKey(Key(key))).onChanged != null;
