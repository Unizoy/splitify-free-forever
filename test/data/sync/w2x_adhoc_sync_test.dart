// W2-X F11 (0028): the phone keeps a several-friends group as type 'adhoc' (the server: type 'other' +
// is_adhoc), makes it offline in one transaction (group, then members, queued in that order) and hides it from
// the Groups list.
import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/data/sync/server_clock.dart';
import 'package:splitify/data/sync/sync_types.dart';

import '../../support/fakes.dart' show FakeClock, testDb;
import 'sync_fakes.dart' show gid, serverGroup;

const _adhoc = '01900000-0000-7000-8000-0000000000ad';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late GroupsRepository groups;

  setUp(() {
    db = testDb();
    clock = FakeClock(DateTime.utc(2026, 11, 28, 9));
    groups = GroupsRepository(db, LocalWriter(db, clock, ServerClock(clock, SyncDao(db))));
  });

  tearDown(() => db.close());

  Future<LocalGroup?> group(String id) =>
      (db.select(db.groups)..where((g) => g.id.equals(id))).getSingleOrNull();

  test('a pulled ad-hoc group is stored as type adhoc; a normal one keeps its type', () async {
    await PullApplier(db).apply(
      PullPage(
        serverTime: clock.now(),
        rows: {
          'groups': [
            serverGroup(),
            {
              ...serverGroup(name: 'Mohit, Asha & Rahul'),
              'id': _adhoc,
              'type': 'other',
              'is_adhoc': true,
            },
          ],
        },
        nextCursors: const {gid: 1, _adhoc: 1},
        userSeq: 0,
      ),
    );
    expect((await group(_adhoc))!.type, 'adhoc');
    expect((await group(gid))!.type, 'trip');
    // The Groups list never shows it.
    expect([for (final g in await groups.watchAll().first) g.id], [gid]);
  });

  test('createAdhoc writes the group, me and the people in one go, queued group first', () async {
    await groups.createAdhoc(
      id: _adhoc,
      name: 'Mohit, Asha & Rahul',
      ownerName: 'Mohit',
      ownerUserId: 'u1',
      mainCurrency: 'INR',
      people: const [
        (id: '01900000-0000-7000-8000-0000000000b2', name: 'Asha', tint: 1, userId: 'u2'),
        (id: '01900000-0000-7000-8000-0000000000b3', name: 'Rahul', tint: 2, userId: null),
      ],
    );
    final g = (await group(_adhoc))!;
    expect(g.type, 'adhoc');
    expect(g.syncState, SyncState.pending);
    final members = await (db.select(
      db.groupMembers,
    )..where((m) => m.groupId.equals(_adhoc))).get();
    members.sort((a, b) => a.position.compareTo(b.position));
    expect([for (final m in members) m.displayName], ['Mohit', 'Asha', 'Rahul']);
    expect([for (final m in members) m.userId], ['u1', 'u2', null]);
    expect([for (final m in members) m.tint], [null, 1, 2]);
    final out = await (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();
    expect([for (final o in out) o.entity], ['group', 'member', 'member']);
    final first = jsonDecode(out.first.payload) as Map<String, Object?>;
    expect(first['type'], 'adhoc');
    expect((first['owner_member']! as Map)['display_name'], 'Mohit');
    // The account of a picked friend is local only: the server links it from the origin member.
    expect((jsonDecode(out[1].payload) as Map)['user_id'], 'u2');
    expect(await groups.watchAll().first, isEmpty);
  });
}
