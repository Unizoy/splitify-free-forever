import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/widget/domain/widget_data.dart';

const WidgetLabels _labels = (
  brand: 'Splitify',
  owed: 'You are owed',
  owe: 'You owe',
  settled: 'All settled up',
  mixed: 'Owed and owe',
  hidden: 'Amounts hidden',
  updatedTemplate: 'Updated %s',
  notSynced: 'Not synced yet',
  signedOut: 'Sign in',
);

Map<String, Object> _build({
  bool signedIn = true,
  Map<String, int> totals = const {},
  String first = 'INR',
  bool unsynced = false,
  DateTime? lastSync,
  bool hideAmounts = false,
}) => buildWidgetData(
  labels: _labels,
  signedIn: signedIn,
  totals: totals,
  first: first,
  unsynced: unsynced,
  lastSync: lastSync,
  hideAmounts: hideAmounts,
);

void main() {
  // TC-X3-01
  group('TC-X3-01 buildWidgetData', () {
    test('signed out: tone signed_out, empty lines', () {
      final d = _build(
        signedIn: false,
        totals: {'INR': 500},
        unsynced: true,
        lastSync: DateTime.utc(2026, 11, 22),
      );
      expect(d[WidgetKeys.tone], 'signed_out');
      expect(d[WidgetKeys.status], 'Sign in');
      expect(d[WidgetKeys.line1], '');
      expect(d[WidgetKeys.line2], '');
      expect(d[WidgetKeys.pending], '');
      expect(d[WidgetKeys.updatedAt], '0');
      expect(d[WidgetKeys.brand], 'Splitify');
    });

    test('owed', () {
      final d = _build(totals: {'INR': 125000});
      expect(d[WidgetKeys.tone], 'owed');
      expect(d[WidgetKeys.status], 'YOU ARE OWED');
      expect(d[WidgetKeys.line1], '₹1,250');
      expect(d[WidgetKeys.line2], '');
    });

    test('owe shows the magnitude without a sign', () {
      final d = _build(totals: {'INR': -125050});
      expect(d[WidgetKeys.tone], 'owe');
      expect(d[WidgetKeys.status], 'YOU OWE');
      expect(d[WidgetKeys.line1], '₹1,250.50');
    });

    test('settled: line1 is zero in the first currency', () {
      final d = _build(totals: {'INR': 0, 'USD': 0}, first: 'USD');
      expect(d[WidgetKeys.tone], 'settled');
      expect(d[WidgetKeys.status], 'ALL SETTLED UP');
      expect(d[WidgetKeys.line1], MoneyFormatter.list.format(0, 'USD'));
      expect(d[WidgetKeys.line2], '');
      expect(_build()[WidgetKeys.line1], '₹0');
    });

    test('mixed keeps signs', () {
      final d = _build(totals: {'INR': 10000, 'USD': -2500});
      expect(d[WidgetKeys.tone], 'mixed');
      expect(d[WidgetKeys.status], 'OWED AND OWE');
      const signed = MoneyFormatter(hideZeroFraction: true, sign: MoneySign.always);
      expect(d[WidgetKeys.line1], signed.format(10000, 'INR'));
      expect(d[WidgetKeys.line1], startsWith('+'));
      expect(d[WidgetKeys.line2], signed.format(-2500, 'USD'));
      expect(d[WidgetKeys.line2], startsWith('−'));
    });

    test('first currency first, then by absolute amount, top 2 only', () {
      final d = _build(totals: {'EUR': 100, 'USD': -9000, 'INR': 50000, 'GBP': 8000}, first: 'EUR');
      const signed = MoneyFormatter(hideZeroFraction: true, sign: MoneySign.always);
      expect(d[WidgetKeys.line1], signed.format(100, 'EUR'));
      expect(d[WidgetKeys.line2], signed.format(50000, 'INR'));
      final text = '${d[WidgetKeys.line1]} ${d[WidgetKeys.line2]}';
      expect(text, isNot(contains(signed.format(-9000, 'USD'))));
      expect(text, isNot(contains(signed.format(8000, 'GBP'))));
    });

    test('zero currencies are skipped', () {
      final d = _build(totals: {'INR': 0, 'USD': 700});
      expect(d[WidgetKeys.line1], MoneyFormatter.list.format(700, 'USD'));
      expect(d[WidgetKeys.line2], '');
    });

    test('hideAmounts: hidden label, no digits anywhere in the values', () {
      final d = _build(
        totals: {'INR': 123456, 'USD': -789},
        hideAmounts: true,
        lastSync: DateTime.utc(2026, 11, 22),
        unsynced: true,
      );
      expect(d[WidgetKeys.hidden], isTrue);
      expect(d[WidgetKeys.line1], 'Amounts hidden');
      expect(d[WidgetKeys.line2], '');
      for (final k in [
        WidgetKeys.status,
        WidgetKeys.tone,
        WidgetKeys.line1,
        WidgetKeys.line2,
        WidgetKeys.pending,
        WidgetKeys.brand,
      ]) {
        expect('${d[k]}', isNot(matches(RegExp(r'\d'))), reason: k);
      }
    });

    test('hideAmounts with nothing owed: lines stay empty', () {
      final d = _build(hideAmounts: true);
      expect(d[WidgetKeys.line1], '');
      expect(d[WidgetKeys.line2], '');
    });

    test('unsynced shows the pending label, synced leaves it empty', () {
      expect(_build(totals: {'INR': 1}, unsynced: true)[WidgetKeys.pending], 'Not synced yet');
      expect(_build(totals: {'INR': 1})[WidgetKeys.pending], '');
    });

    test('updated_at is the last sync in epoch milliseconds, 0 when never', () {
      final at = DateTime.utc(2026, 11, 22, 8, 30);
      expect(_build(lastSync: at)[WidgetKeys.updatedAt], '${at.millisecondsSinceEpoch}');
      expect(_build()[WidgetKeys.updatedAt], '0');
      expect(_build()[WidgetKeys.updatedTemplate], 'Updated %s');
    });
  });
}
