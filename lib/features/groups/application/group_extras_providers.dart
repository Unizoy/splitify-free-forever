import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';

/// This phone's preferences, or null where none are set up (some widget tests and goldens): the small UI
/// choices below then simply start from their defaults.
SharedPreferences? _prefs(Ref ref) {
  try {
    return ref.watch(sharedPreferencesProvider);
  } on Object {
    return null;
  }
}

/// The Groups list filter (D-034 C3): All / Outstanding / I owe / Owe me, kept on this phone.
final groupFilterProvider = NotifierProvider<GroupFilterController, GroupFilter>(
  GroupFilterController.new,
);

class GroupFilterController extends Notifier<GroupFilter> {
  /// SharedPreferences key.
  static const storageKey = 'groups.filter';

  @override
  GroupFilter build() => GroupFilter.parse(_prefs(ref)?.getString(storageKey));

  void select(GroupFilter filter) {
    if (filter == state) return;
    state = filter;
    final prefs = _prefs(ref);
    if (prefs != null) unawaited(prefs.setString(storageKey, filter.name));
  }
}

/// Whether the "who owes whom" lines under a group's status pill are folded away (D-034 C1), per group,
/// kept on this phone. Open by default.
final groupLinesCollapsedProvider = NotifierProvider.family<GroupLinesCollapsed, bool, String>(
  GroupLinesCollapsed.new,
);

class GroupLinesCollapsed extends Notifier<bool> {
  GroupLinesCollapsed(this.groupId);

  final String groupId;

  /// SharedPreferences key of [groupId].
  static String storageKey(String groupId) => 'group.lines.collapsed.$groupId';

  @override
  bool build() => _prefs(ref)?.getBool(storageKey(groupId)) ?? false;

  void toggle() {
    state = !state;
    final prefs = _prefs(ref);
    if (prefs == null) return;
    unawaited(state ? prefs.setBool(storageKey(groupId), true) : prefs.remove(storageKey(groupId)));
  }
}

/// Short phones (< 700 dp tall) start with the "who owes whom" lines folded, so the list shows below the
/// hero (R3-A, S-446); this is whether the reader opened them there, for this run of the app only.
final groupLinesOpenedShortProvider = NotifierProvider.family<GroupLinesOpenedShort, bool, String>(
  GroupLinesOpenedShort.new,
);

class GroupLinesOpenedShort extends Notifier<bool> {
  GroupLinesOpenedShort(this.groupId);

  final String groupId;

  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// Who last changed a group's notes and when (D-034 C5): the newest `whiteboard_updated` activity, or my own
/// change still in the outbox ([pending]).
typedef NotesEdit = ({String? memberId, String? userId, DateTime at, bool pending});

final groupNotesEditProvider = StreamProvider.autoDispose.family<NotesEdit?, String>((
  ref,
  groupId,
) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .customSelect(
        'SELECT * FROM ('
        "SELECT created_at AS at, actor_member_id AS member, actor_user_id AS user, 0 AS pending, seq AS n "
        "FROM activity WHERE group_id = ?1 AND type = 'whiteboard_updated' ORDER BY seq DESC LIMIT 1) "
        'UNION ALL SELECT * FROM ('
        'SELECT created_at AS at, NULL AS member, NULL AS user, 1 AS pending, seq AS n FROM outbox '
        "WHERE entity = ?2 AND record_id = ?1 AND payload LIKE '%\"whiteboard\"%' "
        'ORDER BY seq DESC LIMIT 1)',
        variables: [Variable<String>(groupId), Variable<String>(SyncEntity.group.wire)],
        readsFrom: {db.activity, db.outbox},
      )
      .watch()
      .map((rows) {
        NotesEdit? best;
        for (final r in rows) {
          final at = DateTime.tryParse(r.read<String?>('at') ?? '')?.toLocal();
          if (at == null) continue;
          final pending = r.read<int>('pending') == 1;
          // My unsynced edit is always the newest one on this phone.
          if (best != null && !pending && !at.isAfter(best.at)) continue;
          if (best != null && best.pending) continue;
          best = (
            memberId: r.read<String?>('member'),
            userId: r.read<String?>('user'),
            at: at,
            pending: pending,
          );
        }
        return best;
      });
});
