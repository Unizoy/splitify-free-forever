// TC-X4-01 / TC-X4-07 in Dart (phase 18b, S-229): the shared vectors through the same recipes JSON the Kotlin
// parser uses; every parsed debit, exported the way the native store does it, must pass CaptureValidator.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/features/capture/domain/capture_validator.dart';

import 'recipe_evaluator.dart';

void main() {
  final evaluator = RecipeEvaluator.load();
  final vectors =
      (jsonDecode(File('test/fixtures/payment_capture_vectors.json').readAsStringSync())
              as Map<String, Object?>)['vectors']!
          as List<Object?>;
  final now = DateTime.utc(2026, 11, 22, 12);

  test('at least 40 shared vectors, 15 of them ignore cases', () {
    expect(vectors.length, greaterThanOrEqualTo(40));
    final ignores = vectors.where((v) => ((v! as Map)['expect'] as Map)['kind'] == 'ignore');
    expect(ignores.length, greaterThanOrEqualTo(15));
  });

  for (final raw in vectors) {
    final v = raw! as Map<String, Object?>;
    final id = v['id']! as String;
    test('vector $id', () {
      final debug = (v['build'] ?? 'debug') == 'debug';
      final expected = v['expect']! as Map<String, Object?>;
      final got = v['channel'] == 'screen'
          ? evaluator.screen(v['package']! as String, v['text']! as String, debug: debug)
          : evaluator.notification(
              v['package']! as String,
              (v['title'] ?? '') as String,
              (v['text'] ?? '') as String,
              debug: debug,
            );
      switch (expected['kind']) {
        case 'debit':
          expect(got.kind, 'debit', reason: '$got');
          for (final k in ['amount', 'payee', 'ref', 'source', 'rule']) {
            expect(got.fields[k], expected[k], reason: '$id.$k');
          }
          // Exported like CaptureStore.export() → must pass the app-side validator unchanged.
          final record = {
            'id': '0f8fad5b-d9cb-469f-a165-70867728950e',
            'amount': got.fields['amount'],
            'currency': 'INR',
            'payee': got.fields['payee'],
            'note': null,
            'ref': got.fields['ref'],
            'app_package': v['package'],
            'app_name': 'App',
            'source': got.fields['source'],
            'captured_at': now.millisecondsSinceEpoch,
          };
          final parsed = CaptureValidator.parse(record, now: now);
          expect(parsed, isNotNull, reason: 'validator rejected $record');
          expect(parsed!.amount, expected['amount']);
          expect(parsed.source, CaptureSource.fromWire(expected['source']));
        case 'ignore':
          expect((got.kind, got.fields['reason']), ('ignore', expected['reason']));
        default:
          expect((got.kind, got.fields['stage']), ('stage', expected['stage']));
      }
    });
  }

  group('text rules match Kotlin TextNorm', () {
    test('paise from Indian amounts, no floats', () {
      expect(toPaise('1,234.50'), 123450);
      expect(toPaise('1234.5'), 123450);
      expect(toPaise('1,23,456.50'), 12345650);
      expect(toPaise('0.01'), 1);
      expect(toPaise('12.345'), isNull);
      expect(toPaise('1.2.3'), isNull);
      expect(toPaise(''), isNull);
      expect(toPaise('12345678901'), isNull);
    });

    test('normalising and payee clean-up', () {
      expect(normalize('  Paid ₹500\n\nto Rahul '), 'Paid ₹500 to Rahul');
      expect(joinTitle('Paid', 'Details'), 'Paid. Details');
      expect(joinTitle('Paid:', 'Details'), 'Paid: Details');
      expect(cleanPayee('RAHUL SHARMA.'), 'Rahul Sharma');
      expect(cleanPayee('..GAME ON'), 'Game On');
      expect(cleanPayee('rahul@okaxis'), 'rahul@okaxis');
      expect(cleanPayee(' .. '), isNull);
      expect(cleanPayee('x' * 80)!.length, 60);
    });
  });
}
