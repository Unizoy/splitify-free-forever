/// App lock timing rules (X2, planning/08-feature-specs.md): lock on every cold start and when the
/// app comes back after at least the chosen time in the background (1, 5 or 15 minutes; default 1).
library;

/// How long Splitify may stay in the background before it asks again.
enum LockTimeout {
  min1(1),
  min5(5),
  min15(15);

  const LockTimeout(this.minutes);

  final int minutes;

  Duration get duration => Duration(minutes: minutes);

  static const fallback = LockTimeout.min1;

  /// The saved value, or the default for anything unknown.
  static LockTimeout fromMinutes(int? minutes) =>
      values.where((t) => t.minutes == minutes).firstOrNull ?? fallback;
}

/// Whether coming back to the foreground at [now] must show the lock screen (TC-X2-01).
/// [backgroundedAt] null means the app never left (nothing to do). A clock that moved backwards
/// counts as "long enough" so a changed phone time can't skip the lock.
bool shouldLockOnResume({
  required bool enabled,
  required DateTime? backgroundedAt,
  required DateTime now,
  required LockTimeout timeout,
}) {
  if (!enabled || backgroundedAt == null) return false;
  final away = now.difference(backgroundedAt);
  return away.isNegative || away >= timeout.duration;
}
