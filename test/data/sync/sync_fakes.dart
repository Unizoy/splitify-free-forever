import 'dart:async';

import 'package:drift/native.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

class FakeClock implements Clock {
  FakeClock(this.time);
  DateTime time;

  @override
  DateTime now() => time;
}

/// Scripted server: queue responses (or exceptions) per call; records every request.
class FakeRemoteApi implements RemoteApi {
  final applyScript = <Object Function(List<Map<String, Object?>> batch)>[];
  final pullScript = <Object Function(Map<String, int> cursors, int userSeq)>[];
  final applied = <List<Map<String, Object?>>>[];
  final pulls = <Map<String, int>>[];
  Object? refreshError;
  int refreshes = 0;
  DateTime serverTime = DateTime.utc(2026, 11, 21, 10);

  /// Default when no script is left: everything applied, pull returns nothing new.
  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) async {
    applied.add(batch);
    final r = applyScript.isEmpty ? null : applyScript.removeAt(0)(batch);
    if (r is Exception) throw r;
    return r as ApplyResponse? ?? appliedAll(batch, serverTime);
  }

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) async {
    pulls.add(cursors);
    final r = pullScript.isEmpty ? null : pullScript.removeAt(0)(cursors, userSeq);
    if (r is Exception) throw r;
    return r as PullPage? ??
        PullPage(serverTime: serverTime, rows: const {}, nextCursors: cursors, userSeq: userSeq);
  }

  @override
  Future<void> refreshSession() async {
    refreshes++;
    if (refreshError != null) throw refreshError!;
  }
}

ApplyResponse appliedAll(
  List<Map<String, Object?>> batch,
  DateTime t, [
  MutationStatus s = MutationStatus.applied,
]) => ApplyResponse(t, [for (final m in batch) MutationResult(m['mutation_id']! as String, s)]);

/// Timers that tests fire by hand.
class ManualTimers {
  final scheduled = <(Duration, void Function())>[];

  Timer call(Duration d, void Function() cb) {
    scheduled.add((d, cb));
    return _NoopTimer();
  }
}

class _NoopTimer implements Timer {
  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}

const gid = '01900000-0000-7000-8000-000000000001';
const m1 = '01900000-0000-7000-8000-0000000000a1';
const m2 = '01900000-0000-7000-8000-0000000000b1';

Map<String, Object?> serverGroup({int seq = 1, String name = 'Goa', String? deletedAt}) => {
  'id': gid,
  'name': name,
  'type': 'trip',
  'main_currency': 'INR',
  'cover_kind': 'generated',
  'simplify_debts': false,
  'default_split': null,
  'created_at': '2026-11-20T10:00:00Z',
  'deleted_at': deletedAt,
  'seq': seq,
};

Map<String, Object?> serverMember(String id, int position, {int seq = 2}) => {
  'id': id,
  'group_id': gid,
  'user_id': null,
  'display_name': 'M$position',
  'position': position,
  'role': position == 0 ? 'owner' : 'member',
  'status': 'active',
  'tint': null,
  'seq': seq,
};

Map<String, Object?> serverExpense(
  String id, {
  int seq = 3,
  int total = 10000,
  String description = 'Dinner',
  String? deletedAt,
  Object? fxRate,
}) => {
  'id': id,
  'group_id': gid,
  'kind': 'expense',
  'description': description,
  'notes': null,
  'category': 'food.dining',
  'date': '2026-11-20',
  'currency': 'INR',
  'total': total,
  'payers': {m1: total},
  'shares': {m1: total - total ~/ 2, m2: total ~/ 2},
  'split_kind': 'equal',
  'split_values': null,
  'fx_rate': fxRate,
  'source': 'app',
  'deleted_at': deletedAt,
  'seq': seq,
};
