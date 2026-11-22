import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/history_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  SupabaseHistoryRemote remoteWith(VersionsQuery q) => SupabaseHistoryRemote(q);
  Future<List<Map<String, Object?>>> call(SupabaseHistoryRemote r) => r.versions('e1', afterSeq: 3);

  group('UnconfiguredHistoryRemote', () {
    test('fails like being offline', () async {
      await expectLater(
        const UnconfiguredHistoryRemote().versions('e1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('SupabaseHistoryRemote', () {
    test('passes the record and cursor to the query and maps rows to string-keyed maps', () async {
      String? gotId;
      int? gotAfter;
      final r = remoteWith((id, after) async {
        gotId = id;
        gotAfter = after;
        return [
          <dynamic, dynamic>{'id': 1, 'seq': 4, 'op': 'update'},
          <String, Object?>{'id': 2, 'seq': 5, 'op': 'delete'},
        ];
      });
      final rows = await call(r);
      expect(gotId, 'e1');
      expect(gotAfter, 3);
      expect(rows, [
        {'id': 1, 'seq': 4, 'op': 'update'},
        {'id': 2, 'seq': 5, 'op': 'delete'},
      ]);
    });

    test('an empty answer is an empty list', () async {
      expect(await call(remoteWith((_, _) async => const [])), isEmpty);
    });

    test('selects the columns the cache needs', () {
      for (final c in [
        'table_name',
        'record_id',
        'group_id',
        'op',
        'snapshot',
        'changed_by',
        'changed_at',
        'seq',
      ]) {
        expect(SupabaseHistoryRemote.columns, contains(c));
      }
    });

    test('a server error becomes a RemoteException with its code', () async {
      final r = remoteWith(
        (_, _) async => throw const sb.PostgrestException(message: 'denied', code: '42501'),
      );
      await expectLater(
        call(r),
        throwsA(isA<RemoteException>().having((e) => e.code, 'code', '42501')),
      );
    });

    test('a 5xx or gateway error becomes a NetworkException', () async {
      final r = remoteWith(
        (_, _) async => throw const sb.PostgrestException(message: 'bad gateway', code: '502'),
      );
      await expectLater(call(r), throwsA(isA<NetworkException>()));
    });

    test('an expired JWT becomes AuthExpiredException', () async {
      final r = remoteWith(
        (_, _) async => throw const sb.PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      );
      await expectLater(call(r), throwsA(isA<AuthExpiredException>()));
    });

    test('an auth error becomes AuthExpiredException', () async {
      final r = remoteWith((_, _) async => throw const sb.AuthException('session gone'));
      await expectLater(call(r), throwsA(isA<AuthExpiredException>()));
    });

    test('a timeout becomes NetworkException(timeout)', () async {
      final r = remoteWith((_, _) async => throw TimeoutException('slow'));
      await expectLater(
        call(r),
        throwsA(isA<NetworkException>().having((e) => e.message, 'message', 'timeout')),
      );
    });

    test('socket and other client failures become NetworkException', () async {
      final r = remoteWith((_, _) async => throw const SocketException('no route'));
      await expectLater(
        call(r),
        throwsA(isA<NetworkException>().having((e) => e.message, 'message', 'SocketException')),
      );
      final h = remoteWith((_, _) async => throw const HttpException('reset'));
      await expectLater(call(h), throwsA(isA<NetworkException>()));
    });
  });
}
