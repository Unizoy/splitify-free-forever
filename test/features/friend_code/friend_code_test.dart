// D-034 B4: the friend-code parser (links, bare and dashed codes, the shared message, group invites routed to the
// join screen), the link, and the deep-link redirect `splitify://friend?code=…` → `/friends/code/…`.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/app/router.dart' show linkRedirect;
import 'package:splitify/features/friend_code/domain/friend_code.dart';
import 'package:splitify/l10n/app_localizations_en.dart';

void main() {
  group('FriendCode.read', () {
    test('a friend link, any case, with other parameters', () {
      expect(FriendCode.read('splitify://friend?code=ABCD2345'), const FriendCodeRead('ABCD2345'));
      expect(FriendCode.read('splitify://friend?code=abcd-2345'), const FriendCodeRead('ABCD2345'));
      expect(
        FriendCode.read('splitify://friend?ref=x&code=ABCD2345'),
        const FriendCodeRead('ABCD2345'),
      );
    });

    test('a bare or dashed code; O and I/L read as 0 and 1 (like invite codes)', () {
      expect(FriendCode.read('ABCD-2345'), const FriendCodeRead('ABCD2345'));
      expect(FriendCode.read(' abcd2345 '), const FriendCodeRead('ABCD2345'));
      expect(FriendCode.read('ABCDOIL5'), const FriendCodeRead('ABCD0115'));
    });

    test('the whole shared message', () {
      final l = AppLocalizationsEn();
      final message = l.friendCodeShareText('ABCD-2345', FriendCode.link('ABCD2345'));
      expect(FriendCode.read(message), const FriendCodeRead('ABCD2345'));
      expect(
        FriendCode.read('Hey, add me: code WXYZ-6789 thanks'),
        const FriendCodeRead('WXYZ6789'),
      );
    });

    test('a group invite link is told apart (it belongs on the join screen)', () {
      expect(FriendCode.read('splitify://join?code=ABCD2345'), const GroupInviteRead('ABCD2345'));
    });

    test('nothing that is a code', () {
      expect(FriendCode.read(''), isNull);
      expect(FriendCode.read('hello there'), isNull);
      expect(FriendCode.read('upi://pay?pa=asha@okaxis&am=10.00'), isNull);
      expect(FriendCode.read('splitify://friend?code=ABC'), isNull);
      expect(
        FriendCode.read('splitify://friend?code=UUUUUUUU'),
        isNull,
        reason: 'U is not Crockford',
      );
    });
  });

  test('the QR payload and share link', () {
    expect(FriendCode.link('abcd-2345'), 'splitify://friend?code=ABCD2345');
    expect(FriendCode.display('abcd2345'), 'ABCD-2345');
  });

  group('deep link (the one WP-B clause in router.dart)', () {
    test('splitify://friend?code=X opens add a friend by code with X', () {
      expect(linkRedirect(Uri.parse('splitify://friend?code=ABCD2345')), '/friends/code/ABCD2345');
    });

    test('without a code it opens the empty form; in-app paths are left alone', () {
      expect(linkRedirect(Uri.parse('splitify://friend')), '/friends/code');
      expect(linkRedirect(Uri.parse('/friends/code/ABCD2345')), isNull);
      expect(linkRedirect(Uri.parse('/friends/u%3Au2')), isNull);
    });

    test('group invites still go to join', () {
      expect(linkRedirect(Uri.parse('splitify://join?code=ABCD2345')), '/join?code=ABCD2345');
    });
  });
}
