import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/status_pill.dart';
import 'package:splitify/ui/theme/theme.dart';

/// One step of a [StepHeader].
class StepItem {
  const StepItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Stepper header (532/534) on a `bgSubtle` band that runs under the status
/// bar: back arrow, centred indigo status pill, home circle; below, the step
/// labels and icons joined by 2 dp lines. Active = indigo, done = check,
/// to-do = tertiary grey.
class StepHeader extends StatelessWidget {
  const StepHeader({
    required this.steps,
    required this.current,
    required this.statusText,
    this.statusIcon = AppIcons.shieldCheckFill,
    this.onBack,
    this.onHome,
    this.onStepTap,
    super.key,
  });

  final List<StepItem> steps;

  /// Index of the active step.
  final int current;
  final String statusText;
  final IconData statusIcon;
  final VoidCallback? onBack;
  final VoidCallback? onHome;

  /// Jump to a step (null = steps are not tappable).
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: c.bgSubtle,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s2,
            AppSpacing.s2,
            AppSpacing.s2,
            AppSpacing.s4,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                    tooltip: l.back,
                    icon: Icon(AppIcons.back, color: c.textPrimary),
                  ),
                  Expanded(
                    child: Center(
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: StatusPill(label: statusText, icon: statusIcon),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onHome,
                    tooltip: l.home,
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: c.primaryFill, shape: BoxShape.circle),
                      child: Icon(AppIcons.home, size: 18, color: c.onPrimaryFill),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              Row(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Expanded(
                      child: _StepCell(
                        step: steps[i],
                        index: i,
                        current: current,
                        last: i == steps.length - 1,
                        onTap: onStepTap == null ? null : () => onStepTap!(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCell extends StatelessWidget {
  const _StepCell({
    required this.step,
    required this.index,
    required this.current,
    required this.last,
    this.onTap,
  });

  final StepItem step;
  final int index;
  final int current;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final done = index < current;
    final active = index == current;
    final color = active ? c.primary : (done ? c.textPrimary : c.textTertiary);
    final label = done ? l.stepDone(step.label) : (active ? l.stepCurrent(step.label) : step.label);
    final cell = Semantics(
      label: label,
      button: onTap != null,
      excludeSemantics: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            // One clamped scale for every step (like the capsule nav, S-015, S-242): the labels keep
            // the same size, and the icon row stays level.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  step.label,
                  maxLines: 1,
                  style: context.text.bodySmall
                      .w(active ? 600 : 500)
                      .copyWith(color: active ? c.primary : c.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: _Line(
                  beforeIcon: true,
                  color: index == 0 ? AppPalette.clear : (index <= current ? c.primary : c.divider),
                ),
              ),
              Icon(
                done ? AppIcons.checkCircle : step.icon,
                size: 26,
                color: done ? c.owedText : color,
              ),
              Expanded(
                child: _Line(
                  color: last ? AppPalette.clear : (index < current ? c.primary : c.divider),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return cell;
    return InkWell(onTap: onTap, borderRadius: AppRadii.all16, child: cell);
  }
}

/// Half of a connector: runs from the cell edge to the icon, so the halves
/// of neighbouring cells join into one continuous 2 dp line.
class _Line extends StatelessWidget {
  const _Line({required this.color, this.beforeIcon = false});

  final Color color;
  final bool beforeIcon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: beforeIcon
        ? const EdgeInsetsDirectional.only(end: 6)
        : const EdgeInsetsDirectional.only(start: 6),
    child: Container(
      height: 2,
      decoration: BoxDecoration(color: color, borderRadius: AppRadii.allPill),
    ),
  );
}
