// TC-X4-06 (unit part): the expense editor prefilled from a captured payment, and saved with source 'capture'.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';

import '../../support/capture_fakes.dart';
import '../expenses/application/expense_test_env.dart';

void main() {
  late ExpenseEnv env;
  late FakeCaptureBridge bridge;

  // 20 Nov 2026, 08:30 UTC: the same calendar day in every zone from UTC-8 to UTC+15.
  final capturedAt = DateTime.utc(2026, 11, 20, 8, 30);

  setUp(() async {
    bridge = FakeCaptureBridge();
    env = await ExpenseEnv.create(overrides: [captureBridgeProvider.overrideWithValue(bridge)]);
  });
  tearDown(() => env.dispose());

  Future<void> import(Map<String, Object?> rawRecord) async {
    bridge.captures = [rawRecord];
    await env.container.read(captureRepositoryProvider).importNow();
  }

  ({String groupId, String captureId}) args([String id = captureId1]) =>
      (groupId: env.groupId, captureId: id);

  Future<ExpenseDraft> open([String id = captureId1]) async {
    final p = captureEditorProvider(args(id));
    env.container.listen(p, (_, _) {});
    return env.container.read(p.future);
  }

  group('prefill', () {
    // TC-X4-06
    test('amount from paise, payee as description, ref in the notes, my payer, INR', () async {
      await import(rawCapture(amount: 125050, at: capturedAt));
      final d = await open();
      // ScaledInput.format drops trailing zeros (same as editing a saved expense).
      expect(d.amountText, '1250.5');
      expect(d.description, 'Rahul');
      expect(d.notes, 'Paid via Google Pay · UPI ref 612345678901');
      expect(d.payerId, env.me);
      expect(d.currency, 'INR');
      expect(d.groupId, env.groupId);
      expect(d.captureId, captureId1);
      expect(d.isEdit, isFalse);
      final local = capturedAt.toLocal();
      expect(d.date, DateTime(local.year, local.month, local.day));
      expect(d.canSave, isTrue);
    });

    // TC-X4-06
    test('the note wins over the payee as description', () async {
      await import(rawCapture(note: 'Dinner split', at: capturedAt));
      expect((await open()).description, 'Dinner split');
    });

    // TC-X4-06
    test('no note and no payee: the app name is the description', () async {
      await import(rawCapture(payee: null, at: capturedAt));
      expect((await open()).description, 'Google Pay');
    });

    // TC-X4-06
    test('no ref: notes say only the app', () async {
      await import(rawCapture(ref: null, at: capturedAt));
      expect((await open()).notes, 'Paid via Google Pay');
    });

    // TC-X4-06
    test('whole rupees print without paise', () async {
      await import(rawCapture(amount: 50000, at: capturedAt));
      expect((await open()).amountText, '500');
    });

    // TC-X4-06
    test('unknown capture id throws ExpenseNotFound', () async {
      await expectLater(open(captureId2), throwsA(isA<ExpenseNotFound>()));
    });
  });

  group('save', () {
    // TC-X4-06
    test("writes the expense with source 'capture' and removes the capture", () async {
      await import(rawCapture(amount: 125050, at: capturedAt));
      await open();
      final controller = env.container.read(captureEditorProvider(args()).notifier);
      final id = await controller.save();
      expect(id, isNotNull);

      final row = await (env.db.select(
        env.db.expenses,
      )..where((e) => e.id.equals(id!))).getSingle();
      expect(row.source, 'capture');
      expect(row.total, 125050);
      expect(row.currency, 'INR');
      expect(row.description, 'Rahul');
      expect(row.notes, 'Paid via Google Pay · UPI ref 612345678901');
      expect(row.groupId, env.groupId);

      final out = await env.db.select(env.db.outbox).get();
      final payloads = [
        for (final o in out)
          if (o.recordId == id) jsonDecode(o.payload) as Map<String, Object?>,
      ];
      expect(payloads, isNotEmpty);
      expect(payloads.single['source'], 'capture');

      expect(await env.db.select(env.db.paymentCaptures).get(), isEmpty);
      expect(await env.container.read(captureRepositoryProvider).get(captureId1), isNull);
    });

    // TC-X4-06
    test('a capture that is not saved stays in the list', () async {
      await import(rawCapture(at: capturedAt));
      final d = await open();
      expect(d.canSave, isTrue);
      expect(await env.db.select(env.db.paymentCaptures).get(), hasLength(1));
    });
  });
}
