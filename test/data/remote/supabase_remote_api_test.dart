import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  SupabaseRemoteApi api(
    Object? Function(String fn, Map<String, Object?> p) rpc, {
    Object? refreshError,
  }) => SupabaseRemoteApi((fn, p) async => rpc(fn, p), () async {
    if (refreshError != null) throw refreshError;
  });

  test('maps RPC responses and parameters', () async {
    late Map<String, Object?> sent;
    final a = api((fn, p) {
      sent = {'fn': fn, ...p};
      return fn == 'apply_mutations'
          ? {
              'server_time': '2026-11-21T10:00:00Z',
              'results': [
                {'mutation_id': 'm', 'status': 'rejected', 'code': 'NOT_MEMBER'},
              ],
            }
          : {
              'server_time': '2026-11-21T10:00:00Z',
              'rows': {
                'groups': [
                  {'id': 'g'},
                ],
              },
              'next_cursors': {'g': 4},
              'user_seq': 2,
              'lost_groups': ['x'],
              'has_more': true,
            };
    });
    final r = await a.applyMutations([
      {'mutation_id': 'm'},
    ]);
    expect(sent['fn'], 'apply_mutations');
    expect(
      (r.results.single.status, r.results.single.code),
      (MutationStatus.rejected, 'NOT_MEMBER'),
    );
    final page = await a.pullChanges(cursors: {'g': 1}, userSeq: 0, pageSize: 10);
    expect(sent, {
      'fn': 'pull_changes',
      'cursors': {'g': 1},
      'since_user_seq': 0,
      'page_size': 10,
    });
    expect(page.nextCursors, {'g': 4});
    expect(page.lostGroups, ['x']);
    expect((page.userSeq, page.hasMore), (2, true));
    expect(page.rows['groups']!.single['id'], 'g');
    final empty = PullPage.fromJson({'server_time': '2026-11-21T10:00:00Z'});
    expect(empty.rows, isEmpty);
    expect((empty.hasMore, empty.userSeq), (false, 0));
  });

  test('maps errors to sync exceptions', () async {
    Future<Object?> call(Object error) =>
        api((_, _) => throw error).pullChanges(cursors: {}, userSeq: 0);
    await expectLater(
      call(const PostgrestException(message: 'JWT expired', code: 'PGRST301')),
      throwsA(isA<AuthExpiredException>()),
    );
    await expectLater(
      call(const PostgrestException(message: 'x', code: '503')),
      throwsA(isA<NetworkException>()),
    );
    await expectLater(
      call(const PostgrestException(message: 'bad', code: '22023')),
      throwsA(isA<RemoteException>().having((e) => e.code, 'code', '22023')),
    );
    await expectLater(
      call(const PostgrestException(message: 'bad')),
      throwsA(isA<RemoteException>().having((e) => e.code, 'code', 'bad')),
    );
    await expectLater(call(const AuthException('expired')), throwsA(isA<AuthExpiredException>()));
    await expectLater(call(const SocketException('down')), throwsA(isA<NetworkException>()));
    await expectLater(call(const HttpException('reset')), throwsA(isA<NetworkException>()));
    await expectLater(call(TimeoutException('slow')), throwsA(isA<NetworkException>()));
    await expectLater(
      api((_, _) => 'not a map').pullChanges(cursors: {}, userSeq: 0),
      throwsA(isA<RemoteException>()),
    );
    expect(const NetworkException().toString(), contains('network'));
    expect(const AuthExpiredException().toString(), contains('Auth'));
    expect(const RemoteException('X').toString(), contains('X'));
  });

  test('refresh failures become AuthExpiredException', () async {
    await api((_, _) => null).refreshSession();
    await expectLater(
      api((_, _) => null, refreshError: const AuthException('no')).refreshSession(),
      throwsA(isA<AuthExpiredException>()),
    );
  });
}
