// TC-12-04 [widget] the repeat picker on the expense details.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/rules/recurrence.dart';
import 'package:splitify/features/recurring/application/repeat_draft.dart';
import 'package:splitify/features/recurring/presentation/repeat_picker.dart';

import '../expenses/expense_fixtures.dart';
import '../expenses/presentation/presentation_harness.dart';

final _start = DateTime(2026, 11, 21);

/// Holds the draft like the editor does and records every change.
class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.changes, this.allowNever = true});

  final RepeatDraft initial;
  final List<RepeatDraft> changes;
  final bool allowNever;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late RepeatDraft _draft = widget.initial;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: RepeatPicker(
        value: _draft,
        start: _start,
        today: fixedToday,
        allowNever: widget.allowNever,
        onChanged: (d) {
          widget.changes.add(d);
          setState(() => _draft = d);
        },
      ),
    ),
  );
}

Future<List<RepeatDraft>> _pump(
  WidgetTester tester, {
  RepeatDraft initial = RepeatDraft.never,
  bool allowNever = true,
  double scale = 1,
}) async {
  usePhone(tester);
  final changes = <RepeatDraft>[];
  await tester.pumpWidget(
    expenseApp(
      _Host(initial: initial, changes: changes, allowNever: allowNever),
      scale: scale,
    ),
  );
  await settle(tester, 2);
  return changes;
}

String _hint(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('repeat-hint'))).data!;

void main() {
  // TC-12-04
  testWidgets('shows every interval and Never; Ends and the hint only while repeating', (
    tester,
  ) async {
    await _pump(tester);
    for (final k in [
      'repeat-never',
      'repeat-weekly',
      'repeat-fortnightly',
      'repeat-monthly',
      'repeat-yearly',
    ]) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.text('Every week'), findsOneWidget);
    expect(find.text('Every 2 weeks'), findsOneWidget);
    expect(find.text('Every month'), findsOneWidget);
    expect(find.text('Every year'), findsOneWidget);
    expect(find.byKey(const Key('repeat-no-end')), findsNothing);
    expect(find.byKey(const Key('repeat-hint')), findsNothing);
  });

  // TC-12-04
  testWidgets('each chip reports its interval through onChanged', (tester) async {
    final changes = await _pump(tester);
    final keys = {
      'repeat-weekly': RecurrenceInterval.weekly,
      'repeat-fortnightly': RecurrenceInterval.fortnightly,
      'repeat-monthly': RecurrenceInterval.monthly,
      'repeat-yearly': RecurrenceInterval.yearly,
    };
    for (final e in keys.entries) {
      await tester.tap(find.byKey(Key(e.key)));
      await settle(tester, 2);
      expect(changes.last, RepeatDraft(interval: e.value), reason: e.key);
    }
    expect(find.byKey(const Key('repeat-no-end')), findsOneWidget);
    expect(find.byKey(const Key('repeat-end-pick')), findsOneWidget);
    await tester.tap(find.byKey(const Key('repeat-never')));
    await settle(tester, 2);
    expect(changes.last, RepeatDraft.never);
    expect(changes.last.repeats, isFalse);
    expect(find.byKey(const Key('repeat-no-end')), findsNothing);
  });

  // TC-12-04
  testWidgets('Never is hidden when allowNever is false', (tester) async {
    await _pump(
      tester,
      initial: const RepeatDraft(interval: RecurrenceInterval.monthly),
      allowNever: false,
    );
    expect(find.byKey(const Key('repeat-never')), findsNothing);
    expect(find.byKey(const Key('repeat-monthly')), findsOneWidget);
  });

  // TC-12-04
  testWidgets('end date comes from the calendar sheet and can be cleared', (tester) async {
    final changes = await _pump(
      tester,
      initial: const RepeatDraft(interval: RecurrenceInterval.monthly),
    );
    await tester.tap(find.byKey(const Key('repeat-end-pick')));
    await settle(tester, 15);
    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(find.text('30'));
    await settle(tester, 15);
    expect(
      changes.last,
      RepeatDraft(interval: RecurrenceInterval.monthly, endsOn: DateTime(2026, 11, 30)),
    );
    expect(find.text('Until 30 Nov 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('repeat-no-end')));
    await settle(tester, 2);
    expect(changes.last.endsOn, isNull);
    expect(find.text('Pick an end date'), findsOneWidget);
  });

  // TC-12-04
  testWidgets('hint names the first copy for every interval', (tester) async {
    await _pump(tester, initial: const RepeatDraft(interval: RecurrenceInterval.monthly));
    expect(_hint(tester), 'A copy is added automatically on each date. First copy: 21 Dec 2026.');
    await tester.tap(find.byKey(const Key('repeat-weekly')));
    await settle(tester, 2);
    expect(_hint(tester), 'A copy is added automatically on each date. First copy: 28 Nov 2026.');
    await tester.tap(find.byKey(const Key('repeat-yearly')));
    await settle(tester, 2);
    expect(_hint(tester), 'A copy is added automatically on each date. First copy: 21 Nov 2027.');
  });

  // TC-12-04
  testWidgets('hint warns when the end date is before the expense date', (tester) async {
    await _pump(
      tester,
      initial: RepeatDraft(interval: RecurrenceInterval.monthly, endsOn: DateTime(2026, 11, 10)),
    );
    expect(_hint(tester), 'The end date can’t be before 21 Nov 2026');
  });

  // TC-12-04
  testWidgets('hint says no copies when the end date is before the first copy', (tester) async {
    await _pump(
      tester,
      initial: RepeatDraft(interval: RecurrenceInterval.monthly, endsOn: DateTime(2026, 11, 25)),
    );
    expect(_hint(tester), 'No copies: the end date is before the first one.');
  });

  // TC-12-04
  testWidgets('no overflow at 200 % text scale', (tester) async {
    await _pump(
      tester,
      initial: RepeatDraft(interval: RecurrenceInterval.fortnightly, endsOn: DateTime(2027, 3, 1)),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('repeat-hint')), findsOneWidget);
  });
}
