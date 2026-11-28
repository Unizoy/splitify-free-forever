import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/theme/theme.dart';

/// A row inside an expanded [AccordionCard].
class AccordionRow {
  const AccordionRow({required this.label, this.value, this.onTap});

  final String label;
  final String? value;
  final VoidCallback? onTap;
}

/// Settings accordion (614, 623): radius 28, 1 dp border, coloured leading
/// icon, title + subtitle, chevron that rotates; expands to rows with a value
/// and a chevron.
class AccordionCard extends StatefulWidget {
  const AccordionCard({
    required this.icon,
    required this.title,
    required this.rows,
    this.subtitle,
    this.iconColor,
    this.initiallyExpanded = false,
    super.key,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final List<AccordionRow> rows;
  final bool initiallyExpanded;

  @override
  State<AccordionCard> createState() => _AccordionCardState();
}

class _AccordionCardState extends State<AccordionCard> {
  late bool _open = widget.initiallyExpanded;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final motion = context.motion;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.all28,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Semantics(
              button: true,
              expanded: _open,
              child: Pressable(
                onTap: _toggle,
                scale: AppMotion.rowPressScale,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s5),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 26, color: widget.iconColor ?? c.info),
                      const SizedBox(width: AppSpacing.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title, style: context.text.title),
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                style: context.text.bodySmall
                                    .w(500)
                                    .copyWith(color: c.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: motion.base,
                        curve: AppMotion.standard,
                        child: Icon(AppIcons.chevronDown, size: 20, color: c.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: motion.base,
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: _open
                  ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
                          child: Divider(height: 1, thickness: 1, color: c.border),
                        ),
                        for (final row in widget.rows) _Row(row: row),
                        const SizedBox(height: AppSpacing.s2),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final AccordionRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final large = context.stackRows;
    final label = Text(row.label, style: context.text.body.w(600));
    final value = row.value == null
        ? null
        : Text(
            row.value!,
            textAlign: large ? TextAlign.start : TextAlign.end,
            style: context.text.body.w(500).copyWith(color: c.textSecondary),
          );
    return Semantics(
      button: row.onTap != null,
      child: Pressable(
        onTap: row.onTap,
        scale: AppMotion.rowPressScale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              62,
              AppSpacing.s3,
              AppSpacing.s5,
              AppSpacing.s3,
            ),
            child: Row(
              children: [
                if (large)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [label, ?value],
                    ),
                  )
                else ...[
                  Expanded(flex: 3, child: label),
                  if (value != null) ...[
                    const SizedBox(width: AppSpacing.s3),
                    Flexible(flex: 2, fit: FlexFit.tight, child: value),
                  ],
                ],
                const SizedBox(width: AppSpacing.s2),
                Icon(AppIcons.chevronRight, size: 18, color: c.textPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
