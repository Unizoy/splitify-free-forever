/// Group and member form rules (08 #1, #4; limits from the cross-cutting rules).
enum GroupFieldError { required, tooLong }

abstract final class GroupRules {
  static const nameMax = 60;
  static const memberNameMax = 50;
  static const maxMembers = 100;
  static const types = ['trip', 'home', 'couple', 'other'];

  /// Group name: 1..60 characters after trimming (TC-1-01).
  static GroupFieldError? name(String value) => _check(value, nameMax);

  /// Member display name: 1..50 characters after trimming.
  static GroupFieldError? memberName(String value) => _check(value, memberNameMax);

  static GroupFieldError? _check(String value, int max) {
    final t = value.trim();
    if (t.isEmpty) return GroupFieldError.required;
    if (t.characters.length > max) return GroupFieldError.tooLong;
    return null;
  }

  /// Unknown types fall back to `other` (the server checks the same list).
  static String type(String value) => types.contains(value) ? value : 'other';
}

extension on String {
  Iterable<int> get characters => runes;
}
