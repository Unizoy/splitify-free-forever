// TC-5-03, TC-6-03, TC-7-03, TC-8-03, TC-9-03: split editors in the editor's Paid by · split sheet (D-032):
// live footer, Save gating, kinds.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/split_editor.dart';

import '../expense_fixtures.dart';
import 'presentation_harness.dart';

void main() {
  SplitDraft base() => SplitDraft.initial(ids, 2);

  Future<EditorHandle> split(WidgetTester t, SplitKind kind, {SplitDraft? draft}) async {
    final h = await pumpEditor(t, sampleDraft(kind: kind, split: draft));
    await openPaidSplit(t);
    return h;
  }

  Future<void> tapSharesButton(WidgetTester t, String id, String tooltip) async {
    await t.tap(
      find.descendant(of: find.byKey(ValueKey('shares-$id')), matching: find.byTooltip(tooltip)),
    );
    await settle(t);
  }

  group('equal', () {
    // TC-5-03
    testWidgets('footer shows the per-person amount and updates with the ticks', (t) async {
      final h = await split(t, SplitKind.equal);
      expect(footerText(t), '3 people\u00A0· ₹400 each');
      expect(topSaveEnabled(t), isTrue);
      await tapKey(t, 'tick-m4');
      expect(footerText(t), '4 people\u00A0· ₹300 each');
      expect(h.draft.split.included, hasLength(4));
    });

    // TC-5-03
    testWidgets('untick everyone: error footer and Save disabled', (t) async {
      await split(t, SplitKind.equal);
      for (final id in ['m1', 'm2', 'm3']) {
        await tapKey(t, 'tick-$id');
      }
      expect(footerText(t), 'Pick at least one person');
      expect(topSaveEnabled(t), isFalse);
      await tapKey(t, 'tick-m2');
      expect(footerText(t), '1 person\u00A0· ₹1,200 each');
      expect(topSaveEnabled(t), isTrue);
    });

    // TC-5-03
    testWidgets('tapping the row toggles the person; unticked rows say Not included', (t) async {
      final h = await split(t, SplitKind.equal);
      expect(find.text('Not included'), findsOneWidget);
      // The split row (the payer chips above name him too).
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('split-row-m3')),
          matching: find.text('Rahul Mehta'),
        ),
      );
      await settle(t);
      expect(h.draft.split.included, isNot(contains('m3')));
      expect(find.text('Not included'), findsNWidgets(2));
    });
  });

  group('exact', () {
    // TC-6-03
    testWidgets('exact amounts that add up show "done" and Save is enabled', (t) async {
      await split(t, SplitKind.exact);
      expect(footerText(t), '₹1,200\u00A0· done');
      expect(topSaveEnabled(t), isTrue);
    });

    // TC-6-03
    testWidgets('amounts short of the total show what is left; fixing them enables Save', (
      t,
    ) async {
      final h = await split(
        t,
        SplitKind.exact,
        draft: base().withValues(SplitKind.exact, {'m1': 50000, 'm2': 30000}),
      );
      expect(footerText(t), '₹800 of ₹1,200\u00A0· ₹400 left');
      expect(topSaveEnabled(t), isFalse);
      await t.enterText(fieldIn('exact-m3'), '400');
      await settle(t);
      expect(footerText(t), '₹1,200\u00A0· done');
      expect(topSaveEnabled(t), isTrue);
      expect(h.draft.split.text['m3'], '400');
    });

    // TC-6-03
    testWidgets('amounts above the total show how much is over', (t) async {
      await split(
        t,
        SplitKind.exact,
        draft: base().withValues(SplitKind.exact, {'m1': 90000, 'm2': 40000}),
      );
      expect(footerText(t), '₹1,300 of ₹1,200\u00A0· ₹100 over');
      expect(topSaveEnabled(t), isFalse);
    });

    // TC-6-03
    testWidgets('text that is not a number asks to check the numbers', (t) async {
      await split(t, SplitKind.exact);
      await t.enterText(fieldIn('exact-m1'), '.');
      await settle(t);
      expect(footerText(t), 'Check the numbers you typed');
      expect(topSaveEnabled(t), isFalse);
    });
  });

  group('percent', () {
    // TC-7-03
    testWidgets('100 % shows done', (t) async {
      await split(t, SplitKind.percent);
      expect(footerText(t), '100%\u00A0· done');
      expect(topSaveEnabled(t), isTrue);
    });

    // TC-7-03
    testWidgets('below 100 % shows what is left, above shows what is over', (t) async {
      await split(t, SplitKind.percent);
      await t.enterText(fieldIn('percent-m4'), '5');
      await settle(t);
      expect(footerText(t), '95% of 100%\u00A0· 5% left');
      expect(topSaveEnabled(t), isFalse);
      await t.enterText(fieldIn('percent-m4'), '15');
      await settle(t);
      expect(footerText(t), '105% of 100%\u00A0· 5% over');
      expect(topSaveEnabled(t), isFalse);
      await t.enterText(fieldIn('percent-m4'), '10');
      await settle(t);
      expect(footerText(t), '100%\u00A0· done');
      expect(topSaveEnabled(t), isTrue);
    });
  });

  group('shares', () {
    // TC-8-03
    testWidgets('shows the total shares and the steppers change them', (t) async {
      final h = await split(t, SplitKind.shares);
      expect(footerText(t), '4 shares in total');
      await tapSharesButton(t, 'm4', 'Increase');
      expect(h.draft.split.shareUnits['m4'], 1000);
      expect(footerText(t), '5 shares in total');
    });

    // TC-8-03
    testWidgets('everyone at zero: asks for at least one share, Save disabled', (t) async {
      await split(
        t,
        SplitKind.shares,
        draft: base().withValues(SplitKind.shares, {for (final i in ids) i: 0}),
      );
      expect(footerText(t), 'Give someone at least one share');
      expect(topSaveEnabled(t), isFalse);
      await tapSharesButton(t, 'm2', 'Increase');
      expect(topSaveEnabled(t), isTrue);
    });

    // TC-8-03
    testWidgets('the decrease button lowers shares', (t) async {
      final h = await split(t, SplitKind.shares);
      await tapSharesButton(t, 'm1', 'Decrease');
      expect(h.draft.split.shareUnits['m1'], 1000);
    });
  });

  group('adjust', () {
    // TC-9-03
    testWidgets('valid adjustments show the rest split equally', (t) async {
      await split(t, SplitKind.adjust);
      // 1,200 minus the adjustments (100 - 50) = 1,150 split between the 2 ticked people.
      expect(footerText(t), '₹1,150 split equally after adjustments');
      expect(topSaveEnabled(t), isTrue);
    });

    // TC-9-03
    testWidgets('adjustments above the total are an error', (t) async {
      await split(t, SplitKind.adjust, draft: base().withValues(SplitKind.adjust, {'m1': 150000}));
      expect(footerText(t), 'Adjustments are ₹300 more than the total');
      expect(topSaveEnabled(t), isFalse);
    });

    // TC-9-03
    testWidgets('a share that would go below zero names the person', (t) async {
      await split(t, SplitKind.adjust, draft: base().withValues(SplitKind.adjust, {'m2': -50000}));
      expect(footerText(t), "Asha Rao's share can't go below ₹0");
      expect(topSaveEnabled(t), isFalse);
    });

    // TC-9-03
    testWidgets('typing an adjustment updates the draft; unticked people have no field', (t) async {
      final h = await split(
        t,
        SplitKind.adjust,
        draft: base().toggle('m4').withValues(SplitKind.adjust, {}),
      );
      expect(fieldIn('adjust-m4'), findsNothing);
      await t.enterText(fieldIn('adjust-m3'), '20');
      await settle(t);
      expect(h.draft.split.text['m3'], '20');
      await tapKey(t, 'tick-m4');
      expect(fieldIn('adjust-m4'), findsOneWidget);
    });
  });

  group('switching kinds', () {
    // TC-5..9-03
    testWidgets('the segmented pill keeps the chosen people', (t) async {
      final h = await split(t, SplitKind.equal);
      expect(h.draft.split.participants, ['m1', 'm2', 'm3']);
      for (final (symbol, kind) in <(String, SplitKind)>[
        ('1.23', SplitKind.exact),
        ('%', SplitKind.percent),
        ('1:2', SplitKind.shares),
        ('±', SplitKind.adjust),
        ('=', SplitKind.equal),
      ]) {
        await tapKind(t, symbol);
        expect(h.draft.split.kind, kind);
      }
      expect(h.draft.split.included, {'m1', 'm2', 'm3'});
    });

    // TC-6-03
    testWidgets('equal to exact fills in the equal amounts of the total', (t) async {
      await split(t, SplitKind.equal);
      await tapKind(t, '1.23');
      expect(footerText(t), '₹1,200\u00A0· done');
      expect(
        find.textContaining('Type what each person owes.', findRichText: true),
        findsOneWidget,
      );
    });

    // TC-5-03
    testWidgets('the kind picker is labelled for screen readers', (t) async {
      final handle = t.ensureSemantics();
      await split(t, SplitKind.equal);
      for (final name in ['Equally', 'Exact amounts', 'Percentages', 'Shares', 'Adjustment']) {
        expect(find.bySemanticsLabel(name), findsWidgets, reason: name);
      }
      expect(SplitKindPicker.symbol(SplitKind.percent), '%');
      handle.dispose();
    });
  });

  group('large text', () {
    // TC-5-03
    testWidgets('rows stack their controls at big text sizes', (t) async {
      usePhone(t);
      await t.pumpWidget(
        expenseApp(
          Scaffold(
            body: SingleChildScrollView(
              child: SplitMemberRows(
                split: base().withValues(SplitKind.exact, {'m1': 50000}),
                members: people,
                currency: 'INR',
                total: 120000,
                onChanged: (_) {},
              ),
            ),
          ),
          scale: 2,
        ),
      );
      await settle(t);
      expect(fieldIn('exact-m1'), findsOneWidget);
    });
  });
}
