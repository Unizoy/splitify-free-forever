import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/domain/rules/capture_validator.dart';

void main() {
  final now = DateTime.utc(2026, 11, 22, 12);
  const id = '0f8fad5b-d9cb-469f-a165-70867728950e';
  Map<String, Object?> record([Map<String, Object?> change = const {}]) => {
    'id': id,
    'amount': 50000,
    'currency': 'INR',
    'payee': 'Rahul Sharma',
    'note': null,
    'ref': '612345678901',
    'app_package': 'com.google.android.apps.nbu.paisa.user',
    'app_name': 'Google Pay',
    'source': 'notification',
    'captured_at': now.subtract(const Duration(minutes: 3)).millisecondsSinceEpoch,
    ...change,
  };

  group('CaptureValidator.parse', () {
    test('a good record becomes a PaymentCapture', () {
      final c = CaptureValidator.parse(record(), now: now)!;
      expect(c.id, id);
      expect(c.amount, 50000);
      expect(c.currency, 'INR');
      expect(c.payee, 'Rahul Sharma');
      expect(c.ref, '612345678901');
      expect(c.source, CaptureSource.notification);
      expect(c.capturedAt, now.subtract(const Duration(minutes: 3)));
      expect(c, CaptureValidator.parse(record(), now: now));
      expect(c.hashCode, CaptureValidator.parse(record(), now: now)!.hashCode);
    });

    test('optional fields may be null; text is trimmed', () {
      final c = CaptureValidator.parse(
        record({'payee': '  Swiggy ', 'ref': null, 'note': 'Dinner'}),
        now: now,
      )!;
      expect(c.payee, 'Swiggy');
      expect(c.ref, isNull);
      expect(c.note, 'Dinner');
    });

    final bad = <String, Map<String, Object?>>{
      'not a map': const {},
      'bad id': {'id': 'g1'},
      'zero amount': {'amount': 0},
      'negative amount': {'amount': -5},
      'too big': {'amount': CaptureValidator.maxAmount + 1},
      'float amount': {'amount': 500.5},
      'other currency': {'currency': 'USD'},
      'unknown source': {'source': 'email'},
      'bad package': {'app_package': 'not a package'},
      'no app name': {'app_name': null},
      'long payee': {'payee': 'x' * 61},
      'control chars': {'payee': 'Rahul\nSharma'},
      'empty payee': {'payee': '   '},
      'bad ref': {'ref': '12-34'},
      'short ref': {'ref': '123'},
      'older than 7 days': {
        'captured_at': now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
      },
      'in the future': {'captured_at': now.add(const Duration(hours: 1)).millisecondsSinceEpoch},
      'time not int': {'captured_at': '2026-11-22'},
    };
    for (final e in bad.entries) {
      test('rejects ${e.key}', () {
        final raw = e.key == 'not a map' ? 'nope' : record(e.value);
        expect(CaptureValidator.parse(raw, now: now), isNull);
      });
    }
  });

  group('parseCaptureLink', () {
    const group = '6f1e2d3c-4b5a-4978-8a6b-5c4d3e2f1a0b';
    test('scheme link with and without a group', () {
      expect(parseCaptureLink(Uri.parse('splitify://capture?id=$id')), (
        captureId: id,
        groupId: null,
      ));
      expect(parseCaptureLink(Uri.parse('splitify://capture?id=$id&group=$group')), (
        captureId: id,
        groupId: group,
      ));
      expect(parseCaptureLink(Uri.parse('/capture?id=$id')), (captureId: id, groupId: null));
    });

    test('rejects other links and malformed ids', () {
      expect(parseCaptureLink(Uri.parse('splitify://join?code=abc')), isNull);
      expect(parseCaptureLink(Uri.parse('splitify://capture')), isNull);
      expect(parseCaptureLink(Uri.parse('splitify://capture?id=1;drop')), isNull);
      expect(parseCaptureLink(Uri.parse('splitify://capture?id=$id&group=evil')), isNull);
    });
  });

  group('CaptureSettings', () {
    test('off by default and round-trips JSON', () {
      const s = CaptureSettings();
      expect(s.enabled, isFalse);
      expect(s.notifications, isTrue);
      expect(s.smart, isFalse);
      final on = s.copyWith(enabled: true, apps: {'com.whatsapp': true}, theme: 'dark');
      expect(CaptureSettings.fromJson(on.toJson()), on);
      expect(CaptureSettings.fromJson(null), s);
      const whatsapp = CaptureApp(
        package: 'com.whatsapp',
        name: 'WhatsApp',
        kind: 'upi',
        defaultOn: false,
      );
      expect(s.appOn(whatsapp), isFalse);
      expect(on.appOn(whatsapp), isTrue);
    });
  });
}
