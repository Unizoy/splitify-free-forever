import 'package:drift/drift.dart';
import 'package:splitify/core/utils/member_tints.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_types.dart';

/// Read streams + write-with-outbox for the synced entities (offline-sync rules 1–6). Writes take snake_case
/// server columns; feature controllers build them (money already split by `lib/core/money`).
abstract class _Repo {
  _Repo(this.db, this.writer, this.entity);

  final AppDatabase db;
  final LocalWriter writer;
  final SyncEntity entity;

  /// Creates (new id when [id] is null) or edits a record; returns its id.
  Future<String> save(String groupId, Map<String, Object?> data, {String? id}) async {
    final rid = id ?? newId();
    await writer.write(entity, SyncOp.upsert, rid, groupId, data);
    return rid;
  }

  Future<void> delete(String id, String groupId) =>
      writer.write(entity, SyncOp.delete, id, groupId);

  Future<void> restore(String id, String groupId) =>
      writer.write(entity, SyncOp.restore, id, groupId);
}

class GroupsRepository extends _Repo {
  GroupsRepository(AppDatabase db, LocalWriter writer) : super(db, writer, SyncEntity.group);

  /// Groups tab: live, not deleted, not friend (`direct`) groups, newest first.
  Stream<List<LocalGroup>> watchAll() =>
      (db.select(db.groups)
            ..where((g) => g.deletedAt.isNull() & g.type.equals('direct').not())
            ..orderBy([(g) => OrderingTerm.desc(g.createdAt), (g) => OrderingTerm.desc(g.id)]))
          .watch();

  Stream<LocalGroup?> watchOne(String id) =>
      (db.select(db.groups)..where((g) => g.id.equals(id))).watchSingleOrNull();

  /// New group with the creator as owner member (the server creates the same member, TC-1-02). [id] lets
  /// the form preview the generated cover before saving.
  Future<String> create({
    required String name,
    required String ownerName,
    String type = 'other',
    String mainCurrency = 'INR',
    String? ownerUserId,
    String? id,
  }) async {
    id ??= newId();
    final ownerId = newId();
    final createdAt = writer.clock.now().toUtc().toIso8601String();
    await writer.write(SyncEntity.group, SyncOp.upsert, id, id, {
      'name': name,
      'type': type,
      'main_currency': mainCurrency,
      'created_at': createdAt,
      'created_by': ?ownerUserId,
      'owner_member': {'id': ownerId, 'display_name': ownerName},
    });
    await writer.writeShadow(SyncEntity.member, {
      'id': ownerId,
      'group_id': id,
      'user_id': ownerUserId,
      'display_name': ownerName,
      'position': 0,
      'role': 'owner',
      'created_at': createdAt,
    });
    return id;
  }

  /// Save the group itself (its id is its scope).
  Future<void> update(String id, Map<String, Object?> data) => save(id, data, id: id);

  /// Archive (read-only, own section) or bring back; any member (08 #1).
  Future<void> setArchived(String id, {required bool archived}) =>
      update(id, {'archived_at': archived ? writer.clock.now().toUtc().toIso8601String() : null});

  /// Soft-deleted groups this user created, newest first (Account → Deleted groups, 30-day restore).
  Stream<List<LocalGroup>> watchDeletedBy(String userId) =>
      (db.select(db.groups)
            ..where(
              (g) =>
                  g.deletedAt.isNotNull() &
                  g.createdBy.equals(userId) &
                  g.type.equals('direct').not(),
            )
            ..orderBy([(g) => OrderingTerm.desc(g.deletedAt)]))
          .watch();
}

class MembersRepository extends _Repo {
  MembersRepository(AppDatabase db, LocalWriter writer) : super(db, writer, SyncEntity.member);

  /// Active members of a group in position order (left/removed members drop out).
  Stream<List<LocalMember>> watchForGroup(String groupId) =>
      (db.select(db.groupMembers)
            ..where(
              (m) => m.groupId.equals(groupId) & m.deletedAt.isNull() & m.status.equals('active'),
            )
            ..orderBy([(m) => OrderingTerm.asc(m.position)]))
          .watch()
          .map(rememberTints);

  /// Active members of all groups (avatar stacks on the Groups tab).
  Stream<List<LocalMember>> watchAllActive() =>
      (db.select(db.groupMembers)
            ..where((m) => m.deletedAt.isNull() & m.status.equals('active'))
            ..orderBy([(m) => OrderingTerm.asc(m.position)]))
          .watch()
          .map(rememberTints);

  /// Name-only member (rule 8) at the next position, with an optional avatar tint 0..4.
  Future<String> addNameOnly(String groupId, String name, {int? tint}) async {
    final max = db.groupMembers.position.max();
    final row =
        await (db.selectOnly(db.groupMembers)
              ..addColumns([max])
              ..where(db.groupMembers.groupId.equals(groupId)))
            .getSingle();
    final next = (row.read(max) ?? -1) + 1;
    return save(groupId, {'display_name': name, 'position': next, 'tint': tint ?? next % 5});
  }

  /// Rename (for a linked member only the fallback name changes, 08 #4).
  Future<void> rename(String groupId, String memberId, String name) =>
      save(groupId, {'display_name': name}, id: memberId);
}

class ExpensesRepository extends _Repo {
  ExpensesRepository(AppDatabase db, LocalWriter writer) : super(db, writer, SyncEntity.expense);

  Stream<List<LocalExpense>> watchForGroup(String groupId) =>
      (db.select(db.expenses)
            ..where((e) => e.groupId.equals(groupId) & e.deletedAt.isNull())
            ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.id)]))
          .watch();

  Stream<LocalExpense?> watchOne(String id) =>
      (db.select(db.expenses)..where((e) => e.id.equals(id))).watchSingleOrNull();

  /// Per-member parts of a group's live expenses (local balances, 04 §5).
  Stream<List<ExpensePart>> watchParts(String groupId) =>
      (db.select(db.expenseParts)..where((p) => p.groupId.equals(groupId))).watch();
}

class PaymentsRepository extends _Repo {
  PaymentsRepository(AppDatabase db, LocalWriter writer) : super(db, writer, SyncEntity.payment);

  Stream<List<LocalPayment>> watchForGroup(String groupId) =>
      (db.select(db.payments)
            ..where((p) => p.groupId.equals(groupId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.desc(p.date), (p) => OrderingTerm.desc(p.id)]))
          .watch();
}

class CommentsRepository extends _Repo {
  CommentsRepository(AppDatabase db, LocalWriter writer) : super(db, writer, SyncEntity.comment);

  Stream<List<LocalComment>> watchForTarget(String targetId) =>
      (db.select(db.comments)
            ..where((c) => c.targetId.equals(targetId) & c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.createdAt), (c) => OrderingTerm.asc(c.id)]))
          .watch();
}

/// True while any row of the group is not on the server yet (drives the `SyncMarker`, 04 §5).
Stream<bool> watchGroupUnsynced(AppDatabase db, String groupId) => db
    .customSelect(
      "SELECT EXISTS (SELECT 1 FROM expenses WHERE group_id = ?1 AND sync_state <> 'synced' "
      "UNION ALL SELECT 1 FROM payments WHERE group_id = ?1 AND sync_state <> 'synced' "
      "UNION ALL SELECT 1 FROM group_members WHERE group_id = ?1 AND sync_state <> 'synced' "
      "UNION ALL SELECT 1 FROM \"groups\" WHERE id = ?1 AND sync_state <> 'synced') AS u",
      variables: [Variable<String>(groupId)],
      readsFrom: {db.expenses, db.payments, db.groupMembers, db.groups},
    )
    .map((r) => r.read<bool>('u'))
    .watchSingle();

/// Notes the chosen avatar colour of every member read (S-251), so avatars that only know a member id
/// match the member everywhere; returns [rows] unchanged.
List<LocalMember> rememberTints(List<LocalMember> rows) {
  MemberTints.remember([for (final m in rows) (id: m.id, tint: m.tint)]);
  return rows;
}
