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
        throwsA(
          isA<EnvException>().having((e) => e.missingKeys, 'missingKeys', [
            'SUPABASE_URL',
            'GOOGLE_WEB_CLIENT_ID',
          ]),
        ),
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
