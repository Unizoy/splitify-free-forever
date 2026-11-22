import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Decoration for a text field that sits inside a pill (search, comment composer): no border or fill of its
/// own, and vertical padding so the field itself — the part that takes taps and TalkBack focus — is at least
/// 48 dp tall with its text centred (phase 19 accessibility sweep). [style] is the field's text style.
InputDecoration pillInputDecoration({
  required BuildContext context,
  required String hint,
  required TextStyle style,
  required TextStyle hintStyle,
}) {
  final line = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 16) * (style.height ?? 1.2);
  final pad = ((AppSpacing.minTouch - line) / 2).clamp(0.0, AppSpacing.minTouch / 2);
  return InputDecoration(
    hintText: hint,
    hintStyle: hintStyle,
    isDense: true,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    contentPadding: EdgeInsets.symmetric(vertical: pad.ceilToDouble()),
  );
}
