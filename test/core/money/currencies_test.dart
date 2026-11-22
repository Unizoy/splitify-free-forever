// Currency table (planning/05-money-engine.md §1; phase 03 task T2). No catalog id.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/currency.dart';

/// Frankfurter v2 `/v2/currencies` fiat list, 161 codes
/// (planning/research/05-supabase-fcm-fx.md, checked 2026-11-21).
const _frankfurterV2 =
    'AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BHD BIF BMD BND BOB BRL BSD BTN BWP BYN '
    'BZD CAD CDF CHF CLP CMD CNH CNY COP CRC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP '
    'GBP GEL GGP GHS GIP GMD GNF GTQ GYD HKD HNL HTG HUF IDR ILS IMP INR IQD IRR ISK JEP JMD JOD '
    'JPY KES KGS KHR KMF KPW KRW KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP '
    'MRU MUR MVR MWK MXN MYR MZN NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON '
    'RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SLE SOS SRD SSP STN SVC SYP SZL THB TJS TMT TND TOP '
    'TRY TTD TWD TZS UAH UGX USD UYU UZS VES VND VUV WST XAF XCD XCG XDR XOF XPF YER ZAR ZMW ZWG';

/// Frankfurter entries that are not spendable currencies and stay out of the table.
const _notInTable = {'CMD', 'XDR'};

/// Spec §1 exponent lists.
const _exponent0 = {
  'BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG', 'RWF', 'UGX', 'UYI', 'VND', //
  'VUV', 'XAF', 'XOF', 'XPF',
};
const _exponent3 = {'BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND'};

int _specExponent(String code) {
  if (_exponent0.contains(code)) return 0;
  if (_exponent3.contains(code)) return 3;
  return 2;
}

void main() {
  final table = Currencies.all.values.toList();
  final frankfurter = _frankfurterV2.split(' ').toSet();

  group('Currencies.all', () {
    test('has 160 currencies, 159 with Frankfurter rates', () {
      expect(frankfurter, hasLength(161));
      expect(table, hasLength(160));
      expect(table.where((c) => c.frankfurter), hasLength(159));
    });

    test('keys are the codes, three upper-case letters, in code order', () {
      for (final MapEntry(:key, :value) in Currencies.all.entries) {
        expect(value.code, key);
        expect(key, matches(RegExp(r'^[A-Z]{3}$')));
      }
      final codes = Currencies.all.keys.toList();
      expect(codes, [...codes]..sort());
    });

    test('contains every Frankfurter v2 currency except CMD and XDR, flagged true', () {
      for (final code in frankfurter.difference(_notInTable)) {
        expect(Currencies.all[code]?.frankfurter, isTrue, reason: code);
      }
      for (final code in _notInTable) {
        expect(Currencies.all.containsKey(code), isFalse, reason: code);
      }
    });

    test('frankfurter is true only for codes Frankfurter v2 publishes (VED is false)', () {
      for (final c in table.where((c) => c.frankfurter)) {
        expect(frankfurter, contains(c.code));
      }
      expect(table.where((c) => !c.frankfurter).map((c) => c.code), ['VED']);
    });

    test('every exponent follows the spec rule (0 / 3 lists, else 2)', () {
      for (final c in table) {
        expect(c.exponent, _specExponent(c.code), reason: c.code);
      }
      expect(Currencies.all['JPY']!.minorPerMajor, 1);
      expect(Currencies.all['INR']!.minorPerMajor, 100);
      expect(Currencies.all['KWD']!.minorPerMajor, 1000);
    });

    test('symbols are unique and safe for pasted-amount cleaning', () {
      final symbols = table.map((c) => c.symbol).toList();
      expect(symbols.toSet(), hasLength(symbols.length));
      for (final s in symbols) {
        expect(s, isNotEmpty);
        expect(s, isNot(matches(RegExp(r'[0-9.,+\-−×*÷/\s]'))), reason: s);
      }
    });

    test('names are non-empty and unique', () {
      final names = table.map((c) => c.name).toList();
      expect(names.every((n) => n.trim().isNotEmpty), isTrue);
      expect(names.toSet(), hasLength(names.length));
    });

    test('common symbols; ambiguous signs get a prefix or the code', () {
      const expected = {
        'INR': '₹',
        'USD': r'$',
        'EUR': '€',
        'GBP': '£',
        'JPY': '¥',
        'CNY': 'CN¥',
        'KRW': '₩',
        'VND': '₫',
        'THB': '฿',
        'CAD': r'CA$',
        'AUD': r'A$',
        'HKD': r'HK$',
        'SGD': r'S$',
        'NZD': r'NZ$',
        'MXN': r'MX$',
        'AED': 'AED',
        'SAR': 'SAR',
        'LKR': 'LKR',
        'NPR': 'NPR',
        'BDT': 'BDT',
        'AFN': 'AFN',
        'AMD': 'AMD',
        'KHR': 'KHR',
        'CHF': 'CHF',
      };
      expected.forEach(
        (code, symbol) => expect(Currencies.all[code]!.symbol, symbol, reason: code),
      );
    });
  });

  group('Currency', () {
    test('equal by code; prints the code', () {
      const a = Currency(code: 'TST', exponent: 2, symbol: 'T', name: 'Test');
      const b = Currency(code: 'TST', exponent: 0, symbol: 'X', name: 'Other', frankfurter: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(Currencies.inr));
      expect(a == Object(), isFalse);
      expect(Currencies.inr.toString(), 'INR');
      expect(a.frankfurter, isFalse);
    });
  });

  group('Currencies.inr', () {
    test('is the INR table entry', () {
      expect(identical(Currencies.all['INR'], Currencies.inr), isTrue);
      expect(Currencies.inr.symbol, '₹');
      expect(Currencies.inr.exponent, 2);
      expect(Currencies.inr.name, 'Indian Rupee');
      expect(Currencies.inr.frankfurter, isTrue);
    });
  });

  group('Currencies.exponentOf', () {
    test('known codes come from the table', () {
      expect(Currencies.exponentOf('INR'), 2);
      expect(Currencies.exponentOf('JPY'), 0);
      expect(Currencies.exponentOf('VND'), 0);
      expect(Currencies.exponentOf('KWD'), 3);
      expect(Currencies.exponentOf('BHD'), 3);
    });

    test('unknown codes use the ISO rule', () {
      expect(Currencies.exponentOf('UYI'), 0);
      expect(Currencies.exponentOf('XYZ'), 2);
      expect(Currencies.exponentOf('CMD'), 2);
    });
  });

  group('Currencies.of', () {
    test('returns the table entry for known codes', () {
      expect(identical(Currencies.of('USD'), Currencies.all['USD']), isTrue);
    });

    test('builds a generic entry for unknown codes', () {
      final c = Currencies.of('XYZ');
      expect(c, isA<Currency>());
      expect(c.code, 'XYZ');
      expect(c.symbol, 'XYZ');
      expect(c.name, 'XYZ');
      expect(c.exponent, 2);
      expect(c.frankfurter, isFalse);
      expect(Currencies.of('UYI').exponent, 0);
    });
  });
}
