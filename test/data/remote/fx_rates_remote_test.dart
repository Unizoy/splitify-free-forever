import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// Transitive dependency of supabase_flutter; only the test client is needed.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// Same as above.
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:splitify/data/remote/fx_rates_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  group('parseRemoteFxRate', () {
    test('reads a row and trims the char(3) code', () {
      final r = parseRemoteFxRate({
        'date': '2026-11-20',
        'currency': 'USD ',
        'rate': '1.0825000000',
        'fetched_at': '2026-11-20T14:00:00+00:00',
      });
      expect(r.date, '2026-11-20');
      expect(r.currency, 'USD');
      expect(r.rate, '1.0825000000');
      expect(r.fetchedAt, '2026-11-20T14:00:00+00:00');
    });

    test('a bad row is a BAD_RESPONSE RemoteException', () {
      const good = {
        'date': '2026-11-20',
        'currency': 'USD',
        'rate': '1.08',
        'fetched_at': '2026-11-20T14:00:00Z',
      };
      for (final key in good.keys) {
        expect(
          () => parseRemoteFxRate({...good, key: 1.08}),
          throwsA(isA<RemoteException>().having((e) => e.code, 'code', 'BAD_RESPONSE')),
          reason: key,
        );
        expect(() => parseRemoteFxRate({...good}..remove(key)), throwsA(isA<RemoteException>()));
      }
    });
  });

  group('UnconfiguredFxRatesRemote', () {
    test('every call is offline', () {
      const remote = UnconfiguredFxRatesRemote();
      expect(
        remote.changedSince(since: null, fromDate: '2026-01-01'),
        throwsA(isA<NetworkException>()),
      );
      expect(remote.between({'USD'}, '2026-01-01', '2026-01-10'), throwsA(isA<NetworkException>()));
    });
  });

  group('SupabaseFxRatesRemote', () {
    late List<http.Request> requests;
    late SupabaseFxRatesRemote Function(http.Response Function(http.Request)) make;

    setUp(() {
      requests = [];
      make = (reply) => SupabaseFxRatesRemote(
        sb.SupabaseClient(
          'https://x.example',
          'k',
          httpClient: MockClient((req) async {
            requests.add(req);
            final r = reply(req);
            return http.Response(
              r.body,
              r.statusCode,
              headers: {'content-type': 'application/json'},
              request: req,
            );
          }),
        ),
      );
    });

    test('a 400 comes back mapped, never as a raw PostgrestException', () async {
      final remote = make(
        (_) => http.Response(jsonEncode({'code': '42501', 'message': 'denied'}), 400),
      );
      await expectLater(
        remote.changedSince(since: null, fromDate: '2026-01-01'),
        throwsA(isA<RemoteException>().having((e) => e.code, 'code', '42501')),
      );
      await expectLater(
        remote.between({'USD'}, '2026-01-01', '2026-01-10'),
        throwsA(isA<RemoteException>()),
      );
    });

    test('changedSince asks for exact text rates, newest cursor, a page and parses rows', () async {
      final remote = make(
        (_) => http.Response(
          jsonEncode([
            {
              'date': '2026-11-20',
              'currency': 'USD',
              'rate': '1.0825000000',
              'fetched_at': '2026-11-20T14:00:00+00:00',
            },
          ]),
          200,
        ),
      );
      final rows = await remote.changedSince(
        since: '2026-11-19T00:00:00Z',
        fromDate: '2026-08-01',
        offset: 1000,
        limit: 500,
      );
      expect(rows.single.currency, 'USD');
      expect(rows.single.rate, '1.0825000000');
      final q = requests.single.url.queryParameters;
      expect(q['select'], 'date,currency,rate::text,fetched_at');
      expect(q['fetched_at'], 'gt.2026-11-19T00:00:00Z');
      expect(q['order'], 'fetched_at.asc.nullslast,date.asc.nullslast,currency.asc.nullslast');
      expect(requests.single.url.path, endsWith('/fx_rates'));
      expect(q['offset'], '1000');
      expect(q['limit'], '500');
    });

    test('between filters by currencies and dates', () async {
      final remote = make((_) => http.Response('[]', 200));
      expect(await remote.between({'USD', 'GBP'}, '2026-11-01', '2026-11-10'), isEmpty);
      final url = requests.single.url.toString();
      expect(url, contains('currency=in.'));
      expect(url, contains('GBP'));
      expect(url, contains('date=lte.2026-11-10'));
    });

    test('a bad row from the server is a BAD_RESPONSE', () async {
      final remote = make(
        (_) => http.Response(
          jsonEncode([
            {'date': 5},
          ]),
          200,
        ),
      );
      await expectLater(
        remote.between({'USD'}, '2026-11-01', '2026-11-10'),
        throwsA(isA<RemoteException>().having((e) => e.code, 'code', 'BAD_RESPONSE')),
      );
    });

    test('JWT and server errors map like sync does', () async {
      final jwt = make(
        (_) => http.Response(jsonEncode({'code': 'PGRST301', 'message': 'JWT expired'}), 401),
      );
      await expectLater(
        jwt.between({'USD'}, '2026-11-01', '2026-11-10'),
        throwsA(isA<AuthExpiredException>()),
      );
      final down = make(
        (_) => http.Response(jsonEncode({'code': '503', 'message': 'unavailable'}), 503),
      );
      await expectLater(
        down.between({'USD'}, '2026-11-01', '2026-11-10'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
