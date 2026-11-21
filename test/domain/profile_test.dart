import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/domain/rules/profile_rules.dart';

import '../support/fakes.dart';

void main() {
  group('TC-B2-01 UPI ID regex', () {
    const ok = ['asha@okaxis', 'a.b-c_d@ybl', '98765@paytm', 'ab@upi', 'Name.Surname@okhdfcbank'];
    const bad = [
      '',
      'a@okaxis', // name part needs 2+
      'asha',
      'asha@',
      '@okaxis',
      'asha@1bank', // bank must start with a letter
      'asha@b', // bank needs 2+
      'as ha@okaxis',
      'asha@ok@axis',
      'asha!@okaxis',
    ];
    for (final v in ok) {
      test('accepts $v', () => expect(ProfileRules.isValidUpiId(v), isTrue));
    }
    for (final v in bad) {
      test('rejects "$v"', () => expect(ProfileRules.isValidUpiId(v), isFalse));
    }
    test('trims spaces', () => expect(ProfileRules.isValidUpiId('  asha@okaxis '), isTrue));
  });

  group('TC-B2-02 UPI QR parser', () {
    test('reads pa from a upi://pay QR', () {
      expect(
        ProfileRules.upiIdFromQr('upi://pay?pa=asha.rao@okaxis&pn=Asha%20Rao&cu=INR'),
        'asha.rao@okaxis',
      );
      expect(ProfileRules.upiIdFromQr('UPI://PAY?pa=asha@ybl'), 'asha@ybl');
    });
    test('rejects other QRs and bad ids', () {
      expect(ProfileRules.upiIdFromQr('https://example.com/?pa=asha@ybl'), isNull);
      expect(ProfileRules.upiIdFromQr('upi://mandate?pa=asha@ybl'), isNull);
      expect(ProfileRules.upiIdFromQr('upi://pay?pn=Asha'), isNull);
      expect(ProfileRules.upiIdFromQr('upi://pay?pa=nope'), isNull);
      expect(ProfileRules.upiIdFromQr('::not a uri::'), isNull);
    });
  });

  test('name rule: 1..50 trimmed characters', () {
    expect(ProfileRules.isValidName(' Asha '), isTrue);
    expect(ProfileRules.isValidName('   '), isFalse);
    expect(ProfileRules.isValidName('x' * 50), isTrue);
    expect(ProfileRules.isValidName('x' * 51), isFalse);
  });

  test('Profile json round trip, copyWith and equality', () {
    final p = Profile.fromJson(sampleProfile.toJson());
    expect(p, sampleProfile);
    expect(p.hashCode, sampleProfile.hashCode);
    expect(p.defaultCurrency, 'INR');
    final q = p.copyWith(displayName: 'Asha', avatarPath: 'a/b.jpg', defaultCurrency: 'USD');
    expect(q.displayName, 'Asha');
    expect(q.avatarPath, 'a/b.jpg');
    expect(q == p, isFalse);
    final r = q.copyWith(clearUpi: true, clearAvatar: true);
    expect(r.upiId, isNull);
    expect(r.avatarPath, isNull);
    expect(r.defaultCurrency, 'USD');
    expect(
      Profile.fromJson(const {'id': 'x', 'display_name': 'X', 'default_currency': 'EUR'}),
      const Profile(id: 'x', displayName: 'X', defaultCurrency: 'EUR'),
    );
    expect(Profile.fromJson(const {'id': 'x', 'display_name': 'X'}).defaultCurrency, 'INR');
  });
}
