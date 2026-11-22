import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Scrolling body of one stepper step: centred question (532 "When are you travelling?") then
/// the step's content with 20 dp side margins.
class StepBody extends StatelessWidget {
  const StepBody({required this.question, required this.children, super.key});

  final String question;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s6,
        AppSpacing.screen,
        AppSpacing.s8,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(question, textAlign: TextAlign.center, style: context.text.headline),
        ),
        const SizedBox(height: AppSpacing.s6),
        ...children,
      ],
    );
  }
}

/// Letter-spaced caps section label ("CATEGORY").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;

  /// Small widget after the label (the category's "Auto" tag).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: trailing == null
          ? label
          : Row(
              children: [
                label,
                const SizedBox(width: AppSpacing.s2),
                trailing!,
              ],
            ),
    );
  }
}
