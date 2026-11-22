// TC-19-07: the ToggleRow / PillSwitch used by the notification settings.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';

class _Host extends StatefulWidget {
  const _Host({this.initial = false, this.enabled = true, this.calls});

  final bool initial;
  final bool enabled;
  final List<bool>? calls;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool value = widget.initial;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ToggleRow(
        key: const Key('row'),
        icon: AppIcons.bell,
        title: 'Reminders',
        subtitle: 'Someone reminds you to settle up',
        value: value,
        onChanged: widget.enabled
            ? (v) {
                widget.calls?.add(v);
                setState(() => value = v);
              }
            : null,
      ),
    ),
  );
}

Future<void> _pump(WidgetTester t, Widget host) async {
  usePhone(t);
  await t.pumpWidget(expenseApp(host));
  await settle(t);
}

bool _switchValue(WidgetTester t) => t.widget<PillSwitch>(find.byType(PillSwitch)).value;

void main() {
  group('ToggleRow', () {
    // TC-19-07
    testWidgets('shows title, hint and the switch', (t) async {
      await _pump(t, const _Host());
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Someone reminds you to settle up'), findsOneWidget);
      expect(_switchValue(t), isFalse);
    });

    // TC-19-07
    testWidgets('tapping the row asks for the opposite value', (t) async {
      final calls = <bool>[];
      await _pump(t, _Host(calls: calls));
      await t.tap(find.text('Reminders'));
      await settle(t);
      expect(calls, [true]);
      expect(_switchValue(t), isTrue);
      await t.tap(find.byType(PillSwitch));
      await settle(t);
      expect(calls, [true, false]);
      expect(_switchValue(t), isFalse);
    });

    // TC-19-07
    testWidgets('the row is at least 48 dp high', (t) async {
      await _pump(t, const _Host());
      expect(t.getSize(find.byKey(const Key('row'))).height, greaterThanOrEqualTo(48));
    });

    // TC-19-07
    testWidgets('screen readers hear title, hint and the toggled state, and can tap', (t) async {
      final h = t.ensureSemantics();
      final calls = <bool>[];
      await _pump(t, _Host(initial: true, calls: calls));
      var node = t.getSemantics(find.byKey(const Key('row')));
      expect(node.label, 'Reminders, Someone reminds you to settle up');
      expect(node.flagsCollection.isToggled, Tristate.isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      t.semantics.tap(find.semantics.byLabel('Reminders, Someone reminds you to settle up'));
      await settle(t);
      expect(calls, [false]);
      node = t.getSemantics(find.byKey(const Key('row')));
      expect(node.flagsCollection.isToggled, Tristate.isFalse);
      h.dispose();
    });

    // TC-19-07
    testWidgets('without onChanged the row is disabled', (t) async {
      final h = t.ensureSemantics();
      await _pump(t, const _Host(initial: true, enabled: false));
      await t.tap(find.text('Reminders'));
      await settle(t);
      expect(_switchValue(t), isTrue);
      expect(t.widget<PillSwitch>(find.byType(PillSwitch)).enabled, isFalse);
      final node = t.getSemantics(find.byKey(const Key('row')));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      h.dispose();
    });

    // TC-19-07
    testWidgets('a custom leading replaces the icon and no hint means a title-only label', (
      t,
    ) async {
      final h = t.ensureSemantics();
      usePhone(t);
      await t.pumpWidget(
        expenseApp(
          Scaffold(
            body: ToggleRow(
              key: const Key('row'),
              leading: const SizedBox(key: Key('lead'), width: 36, height: 36),
              title: 'Goa trip',
              value: true,
              onChanged: (_) {},
              showDivider: false,
            ),
          ),
        ),
      );
      await settle(t);
      expect(find.byKey(const Key('lead')), findsOneWidget);
      expect(find.byIcon(AppIcons.bell), findsNothing);
      expect(t.getSemantics(find.byKey(const Key('row'))).label, 'Goa trip');
      h.dispose();
    });
  });

  group('PillSwitch', () {
    Future<void> pumpSwitch(WidgetTester t, {required bool value, bool enabled = true}) async {
      usePhone(t);
      await t.pumpWidget(
        expenseApp(
          Scaffold(
            body: Center(
              child: PillSwitch(value: value, enabled: enabled),
            ),
          ),
        ),
      );
      await settle(t);
    }

    // TC-19-07
    testWidgets('is 52 x 32, the knob on the right when on and a check inside', (t) async {
      await pumpSwitch(t, value: true);
      expect(t.getSize(find.byType(PillSwitch)), const Size(52, 32));
      expect(find.byIcon(AppIcons.check), findsOneWidget);
      final align = t.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.alignment, AlignmentDirectional.centerEnd);
    });

    // TC-19-07
    testWidgets('off: knob on the left, no check', (t) async {
      await pumpSwitch(t, value: false);
      expect(find.byIcon(AppIcons.check), findsNothing);
      final align = t.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.alignment, AlignmentDirectional.centerStart);
    });

    // TC-19-07
    testWidgets('disabled looks muted and shows no check even when on', (t) async {
      await pumpSwitch(t, value: true, enabled: false);
      expect(find.byIcon(AppIcons.check), findsNothing);
    });
  });
}
