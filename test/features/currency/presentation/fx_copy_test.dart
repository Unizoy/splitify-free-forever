// TC-32-04: how rates and their sources read (displayRate, sourceLine, noRateText).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';
import 'package:splitify/features/currency/presentation/fx_copy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

FxRate _rate(FxSource source, DateTime effective, {bool fallback = false}) => FxRate(
  from: 'USD',
  to: 'INR',
  rate: '75',
  effectiveDate: effective,
  source: source,
  isFallback: fallback,
);

/// Runs [body] with a localized context.
Future<void> _withContext(WidgetTester t, void Function(BuildContext context) body) async {
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox();
        },
      ),
    ),
  );
}

void main() {
  group('displayRate', () {
    // TC-32-04
    test('from 1 up it shows 4 decimals, no trailing zeros', () {
      expect(displayRate('89.6437142330'), '89.6437');
      expect(displayRate('75.0000000000'), '75');
      expect(displayRate('75'), '75');
      expect(displayRate('1'), '1');
      expect(displayRate('1.5'), '1.5');
      expect(displayRate('83.12345'), '83.1235'); // half away from zero
      expect(displayRate('1234.56784'), '1234.5678');
    });

    // TC-32-04
    test('below 1 it shows 4 significant digits', () {
      expect(displayRate('0.0033512345'), '0.003351');
      expect(displayRate('0.5'), '0.5');
      expect(displayRate('0.9999999'), '1');
      expect(displayRate('0.0123456'), '0.01235');
      expect(displayRate('0.0000001234'), '0.0000001234');
      expect(displayRate('0.0000000123'), '0.0000000123');
      // never more than the 10 decimals a rate can have
      expect(displayRate('0.0000000001'), '0.0000000001');
    });

    // TC-32-04
    test('text that is not a rate is returned as is', () {
      expect(displayRate('abc'), 'abc');
      expect(displayRate(''), '');
      expect(displayRate('0'), '0');
      expect(displayRate('-3'), '-3');
      expect(displayRate('1.12345678901'), '1.12345678901');
    });
  });

  group('sourceLine', () {
    // TC-32-04
    testWidgets('a Frankfurter rate names the day it is from', (t) async {
      late String line;
      await _withContext(t, (c) {
        line = sourceLine(c, _rate(FxSource.frankfurter, DateTime.utc(2026, 11, 20)));
      });
      expect(line, 'Frankfurter\u00A0· 20\u00A0Nov\u00A02026');
    });

    // TC-32-04
    testWidgets('an earlier day than asked says "the latest before"', (t) async {
      late String line;
      await _withContext(t, (c) {
        line = sourceLine(
          c,
          _rate(FxSource.frankfurter, DateTime.utc(2026, 11, 17), fallback: true),
          asked: DateTime.utc(2026, 11, 18),
        );
      });
      expect(
        line,
        'Frankfurter\u00A0· 17\u00A0Nov\u00A02026 (latest before 18\u00A0Nov\u00A02026)',
      );
    });

    // TC-32-04
    testWidgets('a fallback without an asked day, or on the asked day, is the plain line', (
      t,
    ) async {
      late String noAsked;
      late String same;
      await _withContext(t, (c) {
        final r = _rate(FxSource.frankfurter, DateTime.utc(2026, 11, 17), fallback: true);
        noAsked = sourceLine(c, r);
        same = sourceLine(c, r, asked: DateTime.utc(2026, 11, 17));
      });
      expect(noAsked, 'Frankfurter\u00A0· 17\u00A0Nov\u00A02026');
      expect(same, 'Frankfurter\u00A0· 17\u00A0Nov\u00A02026');
    });

    // TC-32-04
    testWidgets('a typed rate says so', (t) async {
      late String line;
      await _withContext(t, (c) {
        line = sourceLine(c, _rate(FxSource.manual, DateTime.utc(2026, 11, 21)));
      });
      expect(line, 'Rate you typed\u00A0· 21\u00A0Nov\u00A02026');
    });
  });

  group('noRateText', () {
    // TC-32-04
    testWidgets('an unlisted currency has no published rate', (t) async {
      late String ved;
      late String two;
      await _withContext(t, (c) {
        FxNeedsManualRate missing(List<String> codes) => FxNeedsManualRate(
          from: 'VED',
          to: 'INR',
          date: DateTime.utc(2026, 11, 20),
          reason: FxMissingReason.unlistedCurrency,
          currencies: codes,
        );
        ved = noRateText(c, missing(['VED']));
        two = noRateText(c, missing(['VED', 'XYZ']));
      });
      expect(ved, 'VED has no published rate. Type the rate.');
      expect(two, 'VED, XYZ has no published rate. Type the rate.');
    });

    // TC-32-04
    testWidgets('no cached rates ask for a typed rate or a connection', (t) async {
      late String text;
      await _withContext(t, (c) {
        text = noRateText(
          c,
          FxNeedsManualRate(
            from: 'USD',
            to: 'INR',
            date: DateTime.utc(2026, 11, 20),
            reason: FxMissingReason.noRates,
            currencies: const ['USD', 'INR'],
          ),
        );
      });
      expect(
        text,
        'No saved rate for 20\u00A0Nov\u00A02026 on this phone. Type the rate, or connect to the internet.',
      );
    });
  });

  group('rateLine and fxDate', () {
    // TC-32-04
    testWidgets('"1 USD = 89.6437 INR" and the day', (t) async {
      late String line;
      late String day;
      await _withContext(t, (c) {
        line = rateLine(AppLocalizations.of(c), 'USD', 'INR', '89.6437142330');
        day = fxDate(c, DateTime.utc(2026, 1, 5));
      });
      expect(line, '1 USD = 89.6437 INR');
      expect(day, '5\u00A0Jan\u00A02026');
    });
  });
}
