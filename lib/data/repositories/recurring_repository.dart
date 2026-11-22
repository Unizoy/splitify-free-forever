import 'package:drift/drift.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/recurrence.dart';

/// Recurring bills (#12): repeat rules of a group, written offline through the outbox like every other
/// record (entity `recurring`). The server keeps `next_date` and adds the copies; the phone writes its own
/// guess of `next_date` (same rule as the server: the first copy on or after the day of the save, never
/// before) so a pending template already shows "Next on …".
class RecurringRepository {
  RecurringRepository(this.db, this.writer);

  final AppDatabase db;
  final LocalWriter writer;

  Stream<LocalRecurring?> watchOne(String id) =>
      (db.select(db.recurringTemplates)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// The template behind an expense: the one that made it (a copy, [recurringId]) or the one started
  /// from it (`expense_id`); a live active one first, then the newest.
  Stream<LocalRecurring?> watchForExpense(String expenseId, {String? recurringId}) {
    return (db.select(db.recurringTemplates)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                (recurringId == null
                    ? t.expenseId.equals(expenseId)
                    : t.id.equals(recurringId) | t.expenseId.equals(expenseId)),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.active),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Live templates of a group, active first.
  Stream<List<LocalRecurring>> watchForGroup(String groupId) =>
      (db.select(db.recurringTemplates)
            ..where((t) => t.groupId.equals(groupId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.active), (t) => OrderingTerm.asc(t.nextDate)]))
          .watch();

  /// Starts repeating [expenseId] (anchor = its date); [template] = the expense fields of every copy.
  Future<String> create({
    required String groupId,
    required String expenseId,
    required Recurrence rule,
    required Map<String, Object?> template,
  }) async {
    final id = newId();
    await writer.write(SyncEntity.recurring, SyncOp.upsert, id, groupId, {
      'expense_id': expenseId,
      'interval': rule.interval.key,
      'anchor_date': formatIsoDate(rule.anchor),
      'ends_on': rule.endsOn == null ? null : formatIsoDate(rule.endsOn!),
      'active': true,
      'template': template,
      'next_date': _guess(rule),
      'created_at': writer.clock.now().toUtc().toIso8601String(),
    });
    return id;
  }

  /// "Edit future copies": new expense fields and/or a new schedule (copies already made stay as they are).
  Future<void> edit(
    LocalRecurring t, {
    Map<String, Object?>? template,
    RecurrenceInterval? interval,
    DateTime? endsOn,
    bool clearEnd = false,
  }) {
    final rule = Recurrence(
      interval: interval ?? RecurrenceInterval.parse(t.interval),
      anchor: parseIsoDate(t.anchorDate),
      endsOn: clearEnd ? null : (endsOn ?? (t.endsOn == null ? null : parseIsoDate(t.endsOn!))),
    );
    final scheduleChanged =
        rule.interval.key != t.interval ||
        (rule.endsOn == null ? null : formatIsoDate(rule.endsOn!)) != t.endsOn;
    return writer.write(SyncEntity.recurring, SyncOp.upsert, t.id, t.groupId, {
      'template': ?template,
      if (scheduleChanged) ...{
        'interval': rule.interval.key,
        'ends_on': rule.endsOn == null ? null : formatIsoDate(rule.endsOn!),
        'next_date': _guess(rule),
      },
    });
  }

  /// "Stop repeating": no more copies; the copies already made stay.
  Future<void> stop(LocalRecurring t) =>
      writer.write(SyncEntity.recurring, SyncOp.upsert, t.id, t.groupId, {'active': false});

  /// "Repeat again" after a stop: copies start again from today (missed ones are not added).
  Future<void> resume(LocalRecurring t) => writer.write(
    SyncEntity.recurring,
    SyncOp.upsert,
    t.id,
    t.groupId,
    {'active': true, 'next_date': _guess(ruleOf(t))},
  );

  /// The template's repeat rule.
  static Recurrence ruleOf(LocalRecurring t) =>
      Recurrence.parse(interval: t.interval, anchor: t.anchorDate, endsOn: t.endsOn);

  /// First copy on or after today (the phone's calendar day), as the server will set it.
  String? _guess(Recurrence rule) {
    final now = writer.clock.now();
    final next = rule.nextAfter(DateTime.utc(now.year, now.month, now.day - 1));
    return next == null ? null : formatIsoDate(next);
  }
}
