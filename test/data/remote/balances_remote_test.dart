import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  final calls = <(String, Map<String, Object?>)>[];
  Object? Function(String name) answer = (_) => null;

  final remote = SupabaseBalancesRemote((name, params) async {
    calls.add((name, params));
    final a = answer(name);
    if (a is Exception) throw a;
    return a;
  });

  setUp(calls.clear);

  group('ServerGroupBalances.fromJson', () {
    test('parses nets, pairs and simplified per currency', () {
      final s = ServerGroupBalances.fromJson({
        'group_id': 'g1',
        'main_currency': 'USD ',
        'simplify_debts': true,
        'currencies': {
          'INR': {
            'nets': {'a': 20000, 'b': -10000.0, 'c': -10000},
            'pairs': [
              ['b', 'a', 10000],
              ['c', 'a', 10000.0],
            ],
            'simplified': [
              ['b', 'a', 10000],
            ],
          },
        },
      });
      expect((s.groupId, s.mainCurrency, s.simplify), ('g1', 'USD', true));
      final inr = s.currencies['INR']!;
      expect(inr.nets, {'a': 20000, 'b': -10000, 'c': -10000});
      expect(inr.pairs, [const Transfer('b', 'a', 10000), const Transfer('c', 'a', 10000)]);
      expect(inr.simplified, [const Transfer('b', 'a', 10000)]);
    });

    test('missing parts default: INR, simplify off, no currencies', () {
      final s = ServerGroupBalances.fromJson({'group_id': 'g2'});
      expect((s.mainCurrency, s.simplify), ('INR', false));
      expect(s.currencies, isEmpty);
      final b = ServerGroupBalances.fromJson({
        'group_id': 'g2',
        'currencies': {'EUR': <String, Object?>{}},
      }).currencies['EUR']!;
      expect(b.nets, isEmpty);
      expect(b.pairs, isEmpty);
      expect(b.simplified, isEmpty);
    });
  });

  group('ServerOverview.fromJson', () {
    test('parses totals, groups and people', () {
      final o = ServerOverview.fromJson({
        'totals': {'INR': 5000, 'USD': -200},
        'groups': [
          {
            'group_id': 'g1',
            'member_id': 'm1',
            'balances': {'INR': 5000},
          },
        ],
        'friends': [
          {
            'user_id': 'u2',
            'name': 'Asha',
            'balances': {'INR': 5000},
          },
          {
            'member_id': 'm9',
            'group_id': 'g1',
            'balances': {'USD': -200},
          },
        ],
      });
      expect(o.totals, {'INR': 5000, 'USD': -200});
      final g = o.groups.single;
      expect((g.groupId, g.memberId), ('g1', 'm1'));
      expect(g.balances, {'INR': 5000});
      final p0 = o.people[0];
      expect((p0.userId, p0.memberId, p0.groupId, p0.name), ('u2', null, null, 'Asha'));
      expect(p0.balances, {'INR': 5000});
      final p1 = o.people[1];
      expect((p1.userId, p1.memberId, p1.groupId, p1.name), (null, 'm9', 'g1', ''));
      expect(p1.balances, {'USD': -200});
    });

    test('an empty answer is empty', () {
      final o = ServerOverview.fromJson(const {});
      expect(o.totals, isEmpty);
      expect(o.groups, isEmpty);
      expect(o.people, isEmpty);
    });
  });

  test('minorMap turns JSON numbers into ints and null into empty', () {
    expect(minorMap({'INR': 100, 'USD': 2.0}), {'INR': 100, 'USD': 2});
    expect(minorMap(null), isEmpty);
  });

  group('SupabaseBalancesRemote', () {
    test('groupBalances calls group_balances with the group id', () async {
      answer = (_) => {'group_id': 'g1', 'currencies': <String, Object?>{}};
      final s = await remote.groupBalances('g1');
      expect(calls.single.$1, 'group_balances');
      expect(calls.single.$2, {'group_id': 'g1'});
      expect(s.groupId, 'g1');
    });

    test('myOverview calls my_overview without parameters', () async {
      answer = (_) => {
        'totals': {'INR': 1},
      };
      final o = await remote.myOverview();
      expect(calls.single.$1, 'my_overview');
      expect(calls.single.$2, isEmpty);
      expect(o.totals, {'INR': 1});
    });

    test('a non-object answer is a RemoteException BAD_RESPONSE', () async {
      answer = (_) => [1, 2];
      await expectLater(
        remote.myOverview(),
        throwsA(isA<RemoteException>().having((e) => e.code, 'code', 'BAD_RESPONSE')),
      );
    });

    test('errors map like sync: auth, network, remote', () async {
      answer = (_) => sb.PostgrestException(message: 'JWT expired', code: 'PGRST301');
      await expectLater(remote.groupBalances('g'), throwsA(isA<AuthExpiredException>()));
      answer = (_) => const sb.AuthException('gone');
      await expectLater(remote.groupBalances('g'), throwsA(isA<AuthExpiredException>()));
      answer = (_) => sb.PostgrestException(message: 'down', code: '503');
      await expectLater(remote.groupBalances('g'), throwsA(isA<NetworkException>()));
      answer = (_) => sb.PostgrestException(message: 'NOT_MEMBER');
      await expectLater(
        remote.groupBalances('g'),
        throwsA(isA<RemoteException>().having((e) => e.code, 'code', 'NOT_MEMBER')),
      );
      answer = (_) => const SocketException('no route');
      await expectLater(
        remote.groupBalances('g'),
        throwsA(isA<NetworkException>().having((e) => e.message, 'message', 'no route')),
      );
      answer = (_) => const HttpException('reset');
      await expectLater(remote.myOverview(), throwsA(isA<NetworkException>()));
    });

    test('a timed-out call is offline', () async {
      answer = (_) => TimeoutException('slow');
      await expectLater(
        remote.myOverview(),
        throwsA(isA<NetworkException>().having((e) => e.message, 'message', 'timeout')),
      );
    });

    test('fromClient wires a real client; calls fail fast as a mapped error', () async {
      final r = SupabaseBalancesRemote.fromClient(sb.SupabaseClient('https://x.example', 'k'));
      await expectLater(
        r.myOverview(),
        throwsA(
          anyOf(isA<NetworkException>(), isA<RemoteException>(), isA<AuthExpiredException>()),
        ),
      );
    });
  });

  test('UnconfiguredBalancesRemote is always offline', () async {
    const r = UnconfiguredBalancesRemote();
    await expectLater(r.groupBalances('g'), throwsA(isA<NetworkException>()));
    await expectLater(r.myOverview(), throwsA(isA<NetworkException>()));
  });
}
