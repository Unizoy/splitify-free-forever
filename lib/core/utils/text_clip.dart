import 'package:characters/characters.dart';

/// [text] shortened to at most [maxUnits] UTF-16 code units, cut between whole characters (grapheme
/// clusters: an emoji with its skin tone, a flag, a ZWJ family, a letter with its accent), never inside one
/// (R4, S-473). `String.substring` could keep half an emoji, which is saved and synced as a broken "�".
///
/// Counting UTF-16 units keeps the caller's `length` checks and is never more than the server's
/// `char_length` (code points). Text that already fits is returned as it is; spaces are not trimmed.
String clipText(String text, int maxUnits) {
  if (text.length <= maxUnits) return text;
  final out = StringBuffer();
  var used = 0;
  for (final c in text.characters) {
    if (used + c.length > maxUnits) break;
    out.write(c);
    used += c.length;
  }
  return out.toString();
}
