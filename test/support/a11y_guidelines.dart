import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Final QA (S-258): every enabled semantics node marked as a button must carry the tap action, or TalkBack,
/// Switch Access and Voice Access cannot press it. On the emulator `uiautomator dump` showed such buttons as
/// `clickable="false"`: `Semantics(button: true, excludeSemantics: true, child: InkWell(onTap: …))` drops the
/// child's tap with the rest of its semantics.
const AccessibilityGuideline buttonsHaveTapGuideline = _ButtonsHaveTap();

class _ButtonsHaveTap extends AccessibilityGuideline {
  const _ButtonsHaveTap();

  @override
  String get description => 'Enabled buttons can be pressed by accessibility services';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final RenderView view in tester.binding.renderViews) {
      result += _traverse(view.owner!.semanticsOwner!.rootSemanticsNode!);
    }
    return result;
  }

  Evaluation _traverse(SemanticsNode node) {
    var result = const Evaluation.pass();
    node.visitChildren((child) {
      result += _traverse(child);
      return true;
    });
    if (node.isMergedIntoParent || node.isInvisible || node.flagsCollection.isHidden) {
      return result;
    }
    final flags = node.flagsCollection;
    if (!flags.isButton || flags.isEnabled == ui.Tristate.isFalse) return result;
    final data = node.getSemanticsData();
    if (!data.hasAction(ui.SemanticsAction.tap)) {
      result += Evaluation.fail(
        '$node "${data.label}": button without a tap action (accessibility services cannot press it).',
      );
    }
    return result;
  }
}
