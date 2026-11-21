import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  final calls = <(String, Map<String, Object?>)>[];
  Object? Function(String name) answer = (_) => null;

  final remote = SupabaseGroupsRemote((name, params) async {
    calls.add((name, params));
    final a = answer(name);
    if (a is Exception) throw a;
    return a;
  });

  setUp(calls.clear);

  test('TC-3-02 preview maps the group, members and unclaimed spots', () async {
    answer = (_) => {
      'group': {
        'id': 'g1',
        'name': 'Goa trip',
        'type': 'trip',
        'member_count': 3,
        'archived': false,
      },
      'already_member': false,
      'unclaimed': [
        {'id': 'm1', 'display_name': 'Rahul', 'tint': 1},
      ],
    };
    final p = await remote.preview('abcd-efgh');
    expect(calls.single.$1, 'preview_join');
    expect(calls.single.$2, {'code': 'abcd-efgh'});
    expect(
      (p.groupId, p.name, p.type, p.memberCount, p.archived, p.alreadyMember),
      ('g1', 'Goa trip', 'trip', 3, false, false),
    );
    expect(p.unclaimed.single, (id: 'm1', name: 'Rahul', tint: 1));
  });

  test('wrong code comes back as INVALID_CODE', () async {
    answer = (_) => {'error': 'INVALID_CODE'};
    await expectLater(
      remote.preview('x'),
      throwsA(isA<GroupFailure>().having((f) => f.code, 'code', GroupFailureCode.invalidCode)),
    );
    await expectLater(remote.join('x'), throwsA(isA<GroupFailure>()));
  });

  test('TC-4-01 join / claim sends the member id and returns the group', () async {
    answer = (_) => {'group_id': 'g1', 'member_id': 'm1', 'status': 'claimed'};
    expect(await remote.join('ABCDEFGH', claimMemberId: 'm1'), 'g1');
    expect(calls.single.$2, {'code': 'ABCDEFGH', 'claim_member_id': 'm1'});
  });

  test('rotate, leave, remove, unlink call their RPCs', () async {
    answer = (name) => name == 'rotate_invite_code' ? 'NEWCODE1' : {'status': 'ok'};
    expect(await remote.rotateCode('g1'), 'NEWCODE1');
    await remote.leave('g1');
    await remote.removeMember('g1', 'm2');
    await remote.unlinkMember('g1', 'm3');
    expect(
      [for (final c in calls) c.$1],
      ['rotate_invite_code', 'leave_group', 'remove_member', 'unlink_member'],
    );
    expect(calls[2].$2, {'group_id': 'g1', 'member_id': 'm2'});
  });

  test('server codes and network errors map to failures', () async {
    final cases = {
      'RATE_LIMITED': GroupFailureCode.rateLimited,
      'ALREADY_CLAIMED': GroupFailureCode.alreadyClaimed,
      'MEMBER_NOT_FOUND': GroupFailureCode.memberNotFound,
      'NONZERO_BALANCE': GroupFailureCode.nonzeroBalance,
      'NOT_MEMBER': GroupFailureCode.notMember,
      'NOT_CLAIMED': GroupFailureCode.notClaimed,
      'GROUP_FULL': GroupFailureCode.groupFull,
      'CLAIM_REQUIRED': GroupFailureCode.claimRequired,
      'WHAT': GroupFailureCode.unknown,
    };
    for (final e in cases.entries) {
      answer = (_) => sb.PostgrestException(message: e.key);
      await expectLater(
        remote.leave('g1'),
        throwsA(isA<GroupFailure>().having((f) => f.code, e.key, e.value)),
      );
    }
    answer = (_) => const SocketException('down');
    await expectLater(
      remote.rotateCode('g1'),
      throwsA(isA<GroupFailure>().having((f) => f.code, 'code', GroupFailureCode.offline)),
    );
    answer = (_) => TimeoutException('slow');
    await expectLater(
      remote.unlinkMember('g1', 'm'),
      throwsA(isA<GroupFailure>().having((f) => f.code, 'code', GroupFailureCode.offline)),
    );
    expect(const GroupFailure(GroupFailureCode.offline).toString(), 'GroupFailure(offline)');
  });

  test('fromClient wires a real client', () {
    final r = SupabaseGroupsRemote.fromClient(sb.SupabaseClient('https://x.example', 'k'));
    expect(r.rpc, isNotNull);
  });
}
