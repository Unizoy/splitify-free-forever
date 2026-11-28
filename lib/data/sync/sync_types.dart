/// Synced entities as named in `apply_mutations` (`wire`) and in the local/server tables (`table`).
enum SyncEntity {
  group('group', 'groups'),
  member('member', 'group_members'),
  expense('expense', 'expenses'),
  payment('payment', 'payments'),
  comment('comment', 'comments'),
  recurring('recurring', 'recurring_templates'),

  /// A photo or PDF of an expense (W2-Y, 0029); its files go up through `pending_uploads`.
  attachment('attachment', 'expense_attachments');

  const SyncEntity(this.wire, this.table);

  final String wire;
  final String table;
}

/// Mutation operations (deletes are soft; restore undoes them).
enum SyncOp { upsert, delete, restore }

/// Values of the `sync_state` column.
abstract final class SyncState {
  static const synced = 'synced';
  static const pending = 'pending';
  static const failed = 'failed';
}

/// Values of `outbox.status`.
abstract final class OutboxStatus {
  static const queued = 'queued';
  static const inFlight = 'in_flight';
  static const failed = 'failed';
}

/// Engine state shown by the sync status providers.
enum SyncPhase { idle, syncing, offline, error, signedOut }
