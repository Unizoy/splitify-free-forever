// D-034 B3: the text of a shared reminder — group and friend-group wording, several currencies, the rule 13 UPI
// link for the rupee part only (percent-encoding, the 50-character note cap), and no link without a valid UPI ID.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/notifications/application/reminders.dart';
import 'package:splitify/l10n/app_localizations_en.dart';

import '../../balances/balance_fixtures.dart';

void main() {
  final l = AppLocalizationsEn();

  group('reminderShareText', () {
    test('a group: name, amount and group; no UPI ID means no link', () {
      final text = reminderShareText(
        l,
        name: 'Asha',
        owed: const {'INR': 20000},
        groupName: 'Goa trip',
        direct: false,
      );
      expect(text, 'Hi Asha, a reminder about ₹200 for “Goa trip”.');
    });

    test('our friend group says "you owe me"', () {
      final text = reminderShareText(
        l,
        name: 'Asha',
        owed: const {'INR': 25550},
        groupName: 'Me & Asha',
        direct: true,
      );
      expect(text, 'Hi Asha, a reminder about the ₹255.50 you owe me.');
    });

    test('with my UPI ID the rupee amount gets the standard upi://pay link (rule 13)', () {
      final text = reminderShareText(
        l,
        name: 'Asha',
        owed: const {'INR': 20050},
        groupName: 'Goa trip',
        direct: false,
        myVpa: ' mohit@OKAXIS ',
        myName: 'Mohit Bindal',
      );
      final lines = text.split('\n');
      expect(lines.first, 'Hi Asha, a reminder about ₹200.50 for “Goa trip”.');
      expect(
        lines.last,
        'You can pay me by UPI at mohit@okaxis: '
        'upi://pay?pa=mohit@okaxis&pn=Mohit%20Bindal&am=200.50&cu=INR&tn=Splitify%3A%20Goa%20trip',
      );
    });

    test('the note is cut to 50 characters and cleaned to ASCII', () {
      final text = reminderShareText(
        l,
        name: 'Asha',
        owed: const {'INR': 100},
        groupName: 'Goa trip with everyone from college — December 2026 edition',
        direct: false,
        myVpa: 'mohit@okaxis',
        myName: 'Mohit',
      );
      final tn = Uri.decodeComponent(RegExp(r'tn=([^&\s]*)').firstMatch(text)!.group(1)!);
      expect(tn.length, lessThanOrEqualTo(50));
      expect(tn, startsWith('Splitify: Goa trip with everyone from college'));
      expect(RegExp(r'[^\x20-\x7E]').hasMatch(tn), isFalse);
    });

    test('several currencies are listed; the link carries only the rupees (never converted)', () {
      final text = reminderShareText(
        l,
        name: 'Asha',
        owed: const {'INR': 20000, 'USD': 1500},
        groupName: 'Goa trip',
        direct: false,
        myVpa: 'mohit@okaxis',
      );
      expect(text, startsWith('Hi Asha, a reminder about ₹200 + \$15 for “Goa trip”.'));
      expect(text, contains('am=200.00&cu=INR'));
    });

    test('no rupees or an invalid UPI ID: no link', () {
      expect(
        reminderShareText(
          l,
          name: 'Asha',
          owed: const {'USD': 1500},
          groupName: 'Goa',
          direct: false,
          myVpa: 'mohit@okaxis',
        ),
        isNot(contains('upi://')),
      );
      expect(
        reminderShareText(
          l,
          name: 'Asha',
          owed: const {'INR': 1500},
          groupName: 'Goa',
          direct: false,
          myVpa: 'not a upi id',
        ),
        isNot(contains('upi://')),
      );
    });
  });

  group('owedToMe', () {
    test('what they owe me per currency as the Balances tab shows it', () {
      expect(owedToMe(goaMixed(), me: 'm1', them: 'm2'), {'INR': 120000});
      expect(
        owedToMe(goaMixed(), me: 'm1', them: 'm3'),
        isEmpty,
        reason: 'I owe Rahul',
      );
      // With simplify on, the simplified transfer counts.
      expect(owedToMe(goaOwed(simplify: true), me: 'm1', them: 'm2'), {'INR': 90000});
    });

    test('settled: nothing', () {
      expect(owedToMe(goaSettled(), me: 'm1', them: 'm2'), isEmpty);
      final empty = GroupBalances(
        groupId: 'g',
        groupName: 'G',
        mainCurrency: 'INR',
        members: const [],
        byCurrency: const {'INR': Balances(nets: {}, pairs: [], simplified: [])},
        meId: 'm1',
        hasRecords: false,
      );
      expect(owedToMe(empty, me: 'm1', them: 'm2'), isEmpty);
    });
  });
}
