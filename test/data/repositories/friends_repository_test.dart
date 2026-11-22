// TC-2-03 / TC-26-04: local reads of profiles and the direct (friend) group of two accounts.
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/friends_repository.dart';

import '../../support/ledger_seed.dart';
import '../sync/sync_fakes.dart' show memoryDb;

Future<void> _profile(AppDatabase db, String id, String name, {String? upi, String? deletedAt}) =>
    db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: id,
            displayName: name,
            upiId: Value(upi),
            defaultCurrency: const Value('INR'),
            deletedAt: Value(deletedAt),
            seq: const Value(1),
          ),
        );

void main() {
  late AppDatabase db;
  late FriendsRepository repo;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = memoryDb();
    repo = FriendsRepository(db);
  });
  tearDown(() => db.close());

  group('profiles', () {
    // TC-26-04
    test('watchProfiles lists live profiles by account id and follows changes', () async {
      await _profile(db, 'u1', 'Mohit', upi: 'mohit@okaxis');
      await _profile(db, 'u2', 'Asha Rao', upi: 'asha@oksbi');
      await _profile(db, 'u3', 'Gone', deletedAt: '2026-11-01T00:00:00Z');
      final stream = repo.watchProfiles().asBroadcastStream();
      final first = await stream.first;
      expect(first.keys, unorderedEquals(['u1', 'u2']));
      expect(first['u2']!.displayName, 'Asha Rao');
      expect(first['u2']!.upiId, 'asha@oksbi');

      final next = expectLater(
        stream,
        emitsThrough(predicate<Map<String, LocalProfile>>((m) => m.keys.contains('u4'))),
      );
      await _profile(db, 'u4', 'Dev');
      await next;
    });

    // TC-26-04
    test('watchProfile gives one profile, or null when there is none or it is deleted', () async {
      await _profile(db, 'u2', 'Asha Rao', upi: 'asha@oksbi');
      await _profile(db, 'u3', 'Gone', deletedAt: '2026-11-01T00:00:00Z');
      expect((await repo.watchProfile('u2').first)!.upiId, 'asha@oksbi');
      expect(await repo.watchProfile('u3').first, isNull);
      expect(await repo.watchProfile('nobody').first, isNull);
    });
  });

  group('findDirectGroup', () {
    Future<void> direct(
      String id, {
      String type = 'direct',
      String? deletedAt,
      String createdAt = '2026-11-01T10:00:00Z',
      String meStatus = 'active',
      String friendStatus = 'active',
      String? friendDeleted,
      String? friendUser = 'u2',
    }) => db.seed(
      groups: [seedGroup(id: id, type: type, deletedAt: deletedAt, createdAt: createdAt)],
      members: [
        seedMember('$id-me', groupId: id, userId: 'u1', status: meStatus),
        seedMember(
          '$id-fr',
          groupId: id,
          userId: friendUser,
          position: 1,
          status: friendStatus,
          deletedAt: friendDeleted,
        ),
      ],
    );

    // TC-2-03
    test('finds the live direct group where both are active members', () async {
      await direct('d1');
      expect(await repo.findDirectGroup('u1', 'u2'), 'd1');
      expect(await repo.findDirectGroup('u2', 'u1'), 'd1');
    });

    // TC-2-03
    test('null when there is none, for another friend, or only a normal group', () async {
      expect(await repo.findDirectGroup('u1', 'u2'), isNull);
      await direct('n1', type: 'trip');
      expect(await repo.findDirectGroup('u1', 'u2'), isNull);
      await direct('d1');
      expect(await repo.findDirectGroup('u1', 'u3'), isNull);
    });

    // TC-2-03
    test('ignores deleted groups and groups where either of us is not active any more', () async {
      await direct('d-del', deletedAt: '2026-11-02T00:00:00Z');
      await direct('d-me-left', meStatus: 'removed');
      await direct('d-fr-left', friendStatus: 'removed');
      await direct('d-fr-gone', friendDeleted: '2026-11-03T00:00:00Z');
      expect(await repo.findDirectGroup('u1', 'u2'), isNull);
      await direct('d-ok', createdAt: '2026-11-09T10:00:00Z');
      expect(await repo.findDirectGroup('u1', 'u2'), 'd-ok');
    });

    // TC-2-03
    test('a direct group with a name-only member is not the account direct group', () async {
      await direct('d-name', friendUser: null);
      expect(await repo.findDirectGroup('u1', 'u2'), isNull);
    });

    // TC-2-03
    test('the oldest direct group wins when there are several', () async {
      await direct('d-new', createdAt: '2026-11-09T10:00:00Z');
      await direct('d-old', createdAt: '2026-11-01T10:00:00Z');
      expect(await repo.findDirectGroup('u1', 'u2'), 'd-old');
    });

    // TC-2-03 (S-116)
    test('memberOf finds the active member of an account in a group', () async {
      await direct('d1');
      expect(await repo.memberOf('d1', 'u2'), 'd1-fr');
      expect(await repo.memberOf('d1', 'u9'), isNull);
      await direct('d2', friendStatus: 'left');
      expect(await repo.memberOf('d2', 'u2'), isNull);
    });
  });
}
