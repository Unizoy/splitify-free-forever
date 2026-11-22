import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/errors/failure.dart';
import 'package:splitify/core/logging/log_buffer.dart';
import 'package:splitify/core/logging/logger.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/core/utils/uuid.dart';

import '../support/factories.dart';
import '../support/fakes.dart';

void main() {
  group('Env', () {
    test('Env.fromValues throws listing keys when values are missing', () {
      expect(
        () => Env.fromValues(
          supabaseUrl: '',
          supabasePublishableKey: 'k',
          googleWebClientId: '',
          devLogin: 'true',
          e2ePassword: '',
        ),
        throwsA(isA<EnvException>().having((e) => e.missingKeys, 'missingKeys', ['SUPABASE_URL'])),
      );
    });

    test('Env.fromValues parses devLogin when all values are set', () {
      final env = Env.fromValues(
        supabaseUrl: 'https://x.example',
        supabasePublishableKey: 'k',
        googleWebClientId: 'g',
        devLogin: 'true',
        e2ePassword: '',
      );
      expect(env.devLogin, isTrue);
      expect(env.e2ePassword, isEmpty);
      expect(env.hasGoogle, isTrue);
      // TC-B1-08: release builds never offer the developer sign-in.
      expect(env.devLoginAvailable(releaseMode: true), isFalse);
      expect(env.devLoginAvailable(releaseMode: false), isTrue);
    });

    test('D-020: missing or placeholder Google client id means not configured', () {
      expect(isConfiguredValue(''), isFalse);
      expect(isConfiguredValue('your-web-client-id.apps.googleusercontent.com'), isFalse);
      final env = Env.fromValues(
        supabaseUrl: 'https://x.example',
        supabasePublishableKey: 'k',
        googleWebClientId: '',
        devLogin: 'false',
        e2ePassword: '',
      );
      expect(env.hasGoogle, isFalse);
      expect(env.devLoginAvailable(releaseMode: false), isFalse);
      expect(env.emailOtpLength, 6, reason: 'EMAIL_OTP_LENGTH missing → Supabase default');
    });

    test('S-232 EMAIL_OTP_LENGTH: 6 to 10 digits, anything else means 6', () {
      Env env(String raw) => Env.fromValues(
        supabaseUrl: 'https://x.example',
        supabasePublishableKey: 'k',
        googleWebClientId: '',
        devLogin: 'false',
        e2ePassword: '',
        emailOtpLength: raw,
      );
      expect(env('8').emailOtpLength, 8);
      expect(env(' 10 ').emailOtpLength, 10);
      for (final bad in ['', 'eight', '5', '11', '-6']) {
        expect(Env.parseOtpLength(bad), 6, reason: bad);
      }
    });

    test('Env.load throws when no dart-defines are given', () {
      expect(Env.load, throwsA(isA<EnvException>()));
      expect(const EnvException(['A']).toString(), contains('A'));
    });
  });

  group('LogBuffer', () {
    test('LogBuffer keeps only the newest lines when over capacity', () {
      final b = LogBuffer(capacity: 3);
      for (var i = 1; i <= 5; i++) {
        b.add('line $i');
      }
      expect(b.lines, ['line 3', 'line 4', 'line 5']);
      expect(b.export(), 'line 3\nline 4\nline 5');
      b.clear();
      expect(b.lines, isEmpty);
    });

    test('initLogging writes records into the buffer', () {
      final b = LogBuffer();
      initLogging(buffer: b, toConsole: false);
      Logger('t').info('hello');
      Logger('t').severe('bad', StateError('boom'));
      expect(b.lines.first, contains('[t] hello'));
      expect(b.lines.last, contains('boom'));
    });
  });

  group('misc', () {
    test('newId returns distinct v7 uuids', () {
      final a = newId();
      final b = newId();
      expect(a, isNot(b));
      expect(a[14], '7');
    });

    test('FakeClock advances only when asked', () {
      final c = FakeClock(DateTime.utc(2026));
      c.advance(const Duration(days: 1));
      expect(c.now(), DateTime.utc(2026, 1, 2));
      expect(const SystemClock().now().isUtc, isTrue);
    });

    test('failures print their type and message', () {
      expect(const OfflineFailure().toString(), 'Failure: offline');
      expect(const UnknownFailure('x').message, 'x');
    });

    test('test id factory is stable', () {
      expect(id(255), '00000000-0000-7000-8000-0000000000ff');
    });
  });
}
