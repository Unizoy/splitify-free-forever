/// Comment limits (08 cross-cutting "Limits": comment 1..1000 characters after trimming; same check as the
/// server's `comments.body` constraint, counted in characters like Postgres `char_length`).
abstract final class CommentRules {
  static const maxLength = 1000;

  /// The text to save, or null when it is empty or too long.
  static String? clean(String text) {
    final t = text.trim();
    if (t.isEmpty || t.runes.length > maxLength) return null;
    return t;
  }

  /// True when [text] is longer than allowed (the composer shows a hint).
  static bool tooLong(String text) => text.trim().runes.length > maxLength;
}
