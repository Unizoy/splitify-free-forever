/// Notification kinds = Android channels = settings rows (08 #19, `0016_notifications.sql`).
enum NotificationKind {
  expenses,
  payments,
  reminders,
  comments,
  groups,

  /// The monthly summary (W2-Y, 0030): opt-in, so its push is off until switched on ([NotificationPrefs.monthlySummary]).
  summary;

  /// Kinds with the usual per-kind switches (the summary has its own switch).
  static const List<NotificationKind> switchable = [
    expenses,
    payments,
    reminders,
    comments,
    groups,
  ];

  /// The kind of a server `kind` value, or null when unknown (a newer server).
  static NotificationKind? tryParse(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// Where a notification shows: as a push on the phone or in the app's bell list.
enum NotificationChannel { push, inapp }

/// The signed-in person's notification settings (TC-19-05). Missing entries mean "on" (the server's rule);
/// [mutedGroupIds] keep the bell but stop pushes for those groups.
class NotificationPrefs {
  const NotificationPrefs({
    this.off = const {},
    this.mutedGroupIds = const {},
    this.monthlySummary = false,
  });

  /// Reads `notification_settings` / `upsert_notification_settings` JSON
  /// (`{kinds: {kind: {push, inapp}}, muted_group_ids: [...]}`). Unknown kinds and non-boolean values are
  /// ignored, so a newer server never breaks the app.
  factory NotificationPrefs.fromJson(Map<String, Object?> json) {
    final off = <(NotificationKind, NotificationChannel)>{};
    var summary = false;
    final kinds = json['kinds'];
    if (kinds is Map) {
      for (final e in kinds.entries) {
        final kind = NotificationKind.tryParse(e.key as String?);
        final v = e.value;
        if (kind == null || v is! Map) continue;
        for (final ch in NotificationChannel.values) {
          if (kind == NotificationKind.summary && ch == NotificationChannel.push) {
            summary = v[ch.name] == true;
          } else if (v[ch.name] == false) {
            off.add((kind, ch));
          }
        }
      }
    }
    final muted = json['muted_group_ids'];
    return NotificationPrefs(
      off: off,
      mutedGroupIds: {
        if (muted is List)
          for (final g in muted)
            if (g is String) g,
      },
      monthlySummary: summary,
    );
  }

  /// Kinds and channels turned off.
  final Set<(NotificationKind, NotificationChannel)> off;
  final Set<String> mutedGroupIds;

  /// The monthly summary push (opt-in; the server's `kinds.summary.push = true`).
  final bool monthlySummary;

  bool isOn(NotificationKind kind, NotificationChannel channel) =>
      kind == NotificationKind.summary && channel == NotificationChannel.push
      ? monthlySummary
      : !off.contains((kind, channel));

  bool isMuted(String groupId) => mutedGroupIds.contains(groupId);

  /// Copy with [kind] / [channel] switched [on] or off.
  NotificationPrefs withKind(
    NotificationKind kind,
    NotificationChannel channel, {
    required bool on,
  }) {
    if (kind == NotificationKind.summary && channel == NotificationChannel.push) {
      return NotificationPrefs(off: off, mutedGroupIds: mutedGroupIds, monthlySummary: on);
    }
    final next = {...off};
    if (on) {
      next.remove((kind, channel));
    } else {
      next.add((kind, channel));
    }
    return NotificationPrefs(
      off: next,
      mutedGroupIds: mutedGroupIds,
      monthlySummary: monthlySummary,
    );
  }

  /// Copy with [groupId] muted or not.
  NotificationPrefs withMuted(String groupId, {required bool muted}) => NotificationPrefs(
    off: off,
    mutedGroupIds: muted ? {...mutedGroupIds, groupId} : ({...mutedGroupIds}..remove(groupId)),
    monthlySummary: monthlySummary,
  );

  /// `kinds` argument of `upsert_notification_settings`: only the switched-off channels, in a stable order, plus
  /// `summary.push: true` while the monthly summary is on (left out when off: a missing entry means off there).
  Map<String, Object?> kindsJson() => {
    for (final k in NotificationKind.values)
      if (off.any((o) => o.$1 == k) || (k == NotificationKind.summary && monthlySummary))
        k.name: {
          if (k == NotificationKind.summary && monthlySummary) NotificationChannel.push.name: true,
          for (final ch in NotificationChannel.values)
            if (off.contains((k, ch))) ch.name: false,
        },
  };

  /// Muted group ids, sorted.
  List<String> mutedJson() => mutedGroupIds.toList()..sort();

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.off.length == off.length &&
      other.off.containsAll(off) &&
      other.mutedGroupIds.length == mutedGroupIds.length &&
      other.mutedGroupIds.containsAll(mutedGroupIds) &&
      other.monthlySummary == monthlySummary;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(off),
    Object.hashAllUnordered(mutedGroupIds),
    monthlySummary,
  );
}
