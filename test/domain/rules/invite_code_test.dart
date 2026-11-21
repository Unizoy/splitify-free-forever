import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/domain/rules/invite_code.dart';

void main() {
  group('TC-3-01 invite code format and normalisation', () {
    test('normalises case, dashes, spaces, O/0 and I/L/1', () {
      expect(InviteCode.normalize('abcd-efgh'), 'ABCDEFGH');
      expect(InviteCode.normalize(' o1l-i '), '0111');
      expect(InviteCode.isValid('abcd-efgh'), isTrue);
      expect(InviteCode.isValid('ABCD-EFG'), isFalse);
      expect(InviteCode.isValid('ABCD-EFGU'), isFalse);
    });

    test('display adds the dash after four characters', () {
      expect(InviteCode.display('abcd'), 'ABCD');
      expect(InviteCode.display('abcde'), 'ABCD-E');
      expect(InviteCode.display('abcdefghjk'), 'ABCD-EFGH');
    });

    test('link and parse round-trip; parse accepts raw codes and rejects junk', () {
      expect(InviteCode.link('abcd-efgh'), 'splitify://join?code=ABCDEFGH');
      expect(InviteCode.parse('splitify://join?code=ABCDEFGH'), 'ABCDEFGH');
      expect(InviteCode.parse(' abcd-efgh '), 'ABCDEFGH');
      expect(InviteCode.parse('https://example.com'), isNull);
    });
  });

  group('TC-1-01 group form validation', () {
    test('name 1..60 after trimming', () {
      expect(GroupRules.name('  '), GroupFieldError.required);
      expect(GroupRules.name('Goa trip'), isNull);
      expect(GroupRules.name('x' * 60), isNull);
      expect(GroupRules.name('x' * 61), GroupFieldError.tooLong);
    });

    test('member name 1..50; unknown types fall back to other', () {
      expect(GroupRules.memberName(''), GroupFieldError.required);
      expect(GroupRules.memberName('x' * 51), GroupFieldError.tooLong);
      expect(GroupRules.memberName('Rahul'), isNull);
      expect(GroupRules.type('trip'), 'trip');
      expect(GroupRules.type('direct'), 'other');
    });
  });
}
