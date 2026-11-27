/// Group invite codes (08 #3): 8 Crockford base32 characters, shown `ABCD-EFGH`, QR/deep link
/// `splitify://join?code=ABCDEFGH`. Same normalisation as `private.normalize_invite_code` in SQL.
abstract final class InviteCode {
  static const length = 8;
  static final _valid = RegExp(r'^[0-9A-HJKMNP-TV-Z]{8}$');

  /// Upper case, only letters and digits, O → 0, I/L → 1 (TC-3-01).
  static String normalize(String input) {
    final b = StringBuffer();
    for (final ch in input.toUpperCase().split('')) {
      final c = switch (ch) {
        'O' => '0',
        'I' || 'L' => '1',
        _ => ch,
      };
      if (RegExp('[0-9A-Z]').hasMatch(c)) b.write(c);
    }
    return b.toString();
  }

  /// True when [input] normalises to a well-formed code.
  static bool isValid(String input) => _valid.hasMatch(normalize(input));

  /// `ABCDEFGH` → `ABCD-EFGH`; partial input gets the dash once it has more than 4 characters.
  static String display(String input) {
    final n = normalize(input);
    final s = n.length > length ? n.substring(0, length) : n;
    return s.length <= 4 ? s : '${s.substring(0, 4)}-${s.substring(4)}';
  }

  /// QR payload and share link.
  static String link(String code) => 'splitify://join?code=${normalize(code)}';

  /// A code from a scanned QR / deep link / pasted text, or null.
  static String? parse(String raw) {
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    final fromLink = uri?.queryParameters['code'];
    final candidate = normalize(fromLink ?? text);
    return _valid.hasMatch(candidate) ? candidate : null;
  }

  static final _inText = RegExp(
    r'(?<![0-9A-Za-z])([0-9A-Za-z]{4})(-?)([0-9A-Za-z]{4})(?![0-9A-Za-z])',
  );

  /// A code inside pasted text (D-033): the link, a bare code, or the shared invite message
  /// ("… Free Forever: code ABCD-EFGH"). A dashed `ABCD-EFGH` wins over other 8-letter words, else the
  /// last one; null when nothing in the text is a code.
  static String? find(String text) {
    final direct = parse(text);
    if (direct != null) return direct;
    final link = RegExp(r'code=([0-9A-Za-z-]+)').firstMatch(text);
    if (link != null) {
      final code = parse(link.group(1)!);
      if (code != null) return code;
    }
    String? dashed;
    String? plain;
    for (final m in _inText.allMatches(text)) {
      final code = normalize('${m.group(1)}${m.group(3)}');
      if (!_valid.hasMatch(code)) continue;
      if (m.group(2)!.isNotEmpty) {
        dashed = code;
      } else {
        plain = code;
      }
    }
    return dashed ?? plain;
  }
}
