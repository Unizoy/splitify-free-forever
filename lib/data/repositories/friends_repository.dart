import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';

/// Local reads for the Friends tab and Pay via UPI (phase 11): the profiles this phone has (self and
/// co-members, pulled by sync) and the friend (`direct`) group of two accounts.
class FriendsRepository {
  FriendsRepository(this.db);

  final AppDatabase db;

  /// Profiles by account id (names, UPI IDs), updated by every pull.
  Stream<Map<String, LocalProfile>> watchProfiles() => (db.select(
    db.profiles,
  )..where((p) => p.deletedAt.isNull())).watch().map((rows) => {for (final p in rows) p.id: p});

  /// One profile (null when this phone does not have it).
  Stream<LocalProfile?> watchProfile(String userId) => (db.select(
    db.profiles,
  )..where((p) => p.id.equals(userId) & p.deletedAt.isNull())).watchSingleOrNull();

  /// The live direct group where both accounts are active members, oldest first; null when there is none.
  Future<String?> findDirectGroup(String myUserId, String friendUserId) async {
    final row = await db
        .customSelect(
          'SELECT g.id AS id FROM "groups" g '
          'JOIN group_members a ON a.group_id = g.id AND a.user_id = ?1 '
          "AND a.status = 'active' AND a.deleted_at IS NULL "
          'JOIN group_members b ON b.group_id = g.id AND b.user_id = ?2 '
          "AND b.status = 'active' AND b.deleted_at IS NULL "
          "WHERE g.type = 'direct' AND g.deleted_at IS NULL "
          'ORDER BY g.created_at, g.id LIMIT 1',
          variables: [Variable<String>(myUserId), Variable<String>(friendUserId)],
          readsFrom: {db.groups, db.groupMembers},
        )
        .getSingleOrNull();
    return row?.read<String>('id');
  }
}
