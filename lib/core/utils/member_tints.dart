/// Chosen avatar colours of group members by member id (final QA, S-251).
///
/// The member reads of the data layer [remember] every member they load; an [Avatar] that is only given a
/// member id (editor, expense detail, history, comments …) then still shows that member's colour, so a person
/// looks the same on every screen. Members without a chosen colour fall back to the id hash.
abstract final class MemberTints {
  static final _byId = <String, int>{};

  /// Records the colours of [members] (`(id, tint)` pairs); a null tint forgets an earlier one.
  static void remember(Iterable<({String id, int? tint})> members) {
    for (final m in members) {
      final t = m.tint;
      if (t == null) {
        _byId.remove(m.id);
      } else {
        _byId[m.id] = t;
      }
    }
  }

  /// The chosen colour of member [id], if one is known.
  static int? of(String id) => _byId[id];

  /// Forgets everything (sign-out, tests).
  static void clear() => _byId.clear();
}
