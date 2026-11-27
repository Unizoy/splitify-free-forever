import 'package:splitify/domain/rules/invite_code.dart';

/// What a scanned QR, a pasted text or a deep link holds (D-034 B4).
sealed class CodeRead {
  const CodeRead();
}

/// A personal friend code (`splitify://friend?code=…`, or a bare / dashed code).
final class FriendCodeRead extends CodeRead {
  const FriendCodeRead(this.code);

  /// Normalised `ABCDEFGH`.
  final String code;

  @override
  bool operator ==(Object other) => other is FriendCodeRead && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// A group invite (`splitify://join?code=…`): it belongs on the join screen.
final class GroupInviteRead extends CodeRead {
  const GroupInviteRead(this.code);

  final String code;

  @override
  bool operator ==(Object other) => other is GroupInviteRead && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Personal friend codes: 8 Crockford base32 characters like invite codes (same normalisation as
/// `private.normalize_invite_code`), shown `ABCD-EFGH`; QR and link `splitify://friend?code=ABCDEFGH`.
abstract final class FriendCode {
  static final _friendLink = RegExp(r'friend\?(?:[^\s]*&)?code=([0-9A-Za-z-]+)');
  static final _joinLink = RegExp(r'join\?(?:[^\s]*&)?code=([0-9A-Za-z-]+)');

  /// QR payload and share link.
  static String link(String code) => 'splitify://friend?code=${InviteCode.normalize(code)}';

  static String display(String code) => InviteCode.display(code);

  /// What [raw] holds: a friend link wins, then a group invite link, then a code inside the text (the shared
  /// message "… code ABCD-EFGH (splitify://friend?code=…)", a bare code); null when nothing is a code.
  static CodeRead? read(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final friend = _friendLink.firstMatch(text);
    if (friend != null) {
      final code = InviteCode.parse(friend.group(1)!);
      return code == null ? null : FriendCodeRead(code);
    }
    final join = _joinLink.firstMatch(text);
    if (join != null) {
      final code = InviteCode.parse(join.group(1)!);
      return code == null ? null : GroupInviteRead(code);
    }
    final code = InviteCode.find(text);
    return code == null ? null : FriendCodeRead(code);
  }
}
