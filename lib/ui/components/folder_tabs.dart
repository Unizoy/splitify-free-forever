import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/components/word_fit_text.dart';
import 'package:splitify/ui/painters/folder_tab_painter.dart';
import 'package:splitify/ui/theme/theme.dart';

/// One tab of [FolderTabs].
class FolderTab {
  const FolderTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// File-folder tabs (712): the active tab is the page colour with an outline
/// and joins the content below; inactive tabs are `chip` grey with a slanted
/// edge, tucked behind. Group detail: Expenses · Balances · Totals.
class FolderTabs extends StatelessWidget {
  const FolderTabs({required this.tabs, required this.index, required this.onChanged, super.key});

  final List<FolderTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  static const _slant = 26.0;

  /// Start/end padding, icon and gap around a tab label.
  static const _labelChrome = 48.0;

  /// The icon and its gap inside [_labelChrome].
  static const _iconChrome = 28.0;

  /// Narrower tabs show their label only.
  static const _iconMinTab = 104.0;

  /// Width of the widest of [labels] at the reader's text size.
  static double _widest(BuildContext context, List<String> labels, TextStyle style) {
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = tabs.length;
        final tabWidth = (constraints.maxWidth - _slant) / n;
        // Icons only while every label still fits beside them at the reader's text size; otherwise the
        // icons go first, so labels keep one shared, readable size instead of shrinking (R3-A, S-446).
        final style = context.text.body.w(700);
        final icons =
            tabWidth >= _iconMinTab &&
            _widest(context, [for (final t in tabs) t.label], style) <= tabWidth - _labelChrome;
        final scaler = sharedLabelScaler(
          context,
          labels: [for (final t in tabs) t.label],
          style: style,
          maxWidth: tabWidth - (icons ? _labelChrome : _labelChrome - _iconChrome),
          minFactor: 0.7,
        );
        final order = [
          for (var i = 0; i < n; i++)
            if (i != index) i,
          index,
        ];
        return IntrinsicHeight(
          child: Stack(
            children: [
              // Baseline under the strip, broken by the active tab's fill.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 1, color: c.border),
              ),
              Row(children: [for (var i = 0; i < n; i++) SizedBox(width: tabWidth)]),
              for (final i in order)
                Positioned(
                  left: tabWidth * i,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: _Tab(
                    tab: tabs[i],
                    active: i == index,
                    scaler: scaler,
                    icon: icons,
                    onTap: () {
                      if (i == index) return;
                      AppHaptics.selection();
                      onChanged(i);
                    },
                  ),
                ),
              // Sizing child: tallest label decides the strip height. It sits on top, so it must not take
              // the taps meant for the tab below it.
              IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: tabWidth,
                      child: _TabLabel(tab: tabs[index], active: true, scaler: scaler, icon: icons),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.scaler,
    required this.icon,
  });

  final FolderTab tab;
  final bool active;
  final VoidCallback onTap;
  final TextScaler scaler;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: Pressable(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.r24)),
        // The active tab's fill cross-fades in (the indicator moves smoothly, S-263).
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: active ? c.bg : c.chip),
          duration: context.motion.fast,
          curve: context.motion.fastCurve,
          builder: (context, fill, child) => CustomPaint(
            painter: FolderTabPainter(
              fill: fill ?? (active ? c.bg : c.chip),
              stroke: active ? c.border : null,
              slant: FolderTabs._slant,
            ),
            child: child,
          ),
          child: _TabLabel(tab: tab, active: active, scaler: scaler, icon: icon),
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.tab,
    required this.active,
    required this.scaler,
    required this.icon,
  });

  final FolderTab tab;
  final bool active;
  final TextScaler scaler;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.textPrimary : c.textSecondary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.s4, 14, AppSpacing.s1, 14),
        child: Row(
          children: [
            if (icon) ...[
              Icon(tab.icon, size: 20, color: active ? c.primary : c.textSecondary),
              const SizedBox(width: AppSpacing.s2),
            ],
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  textScaler: scaler,
                  style: context.text.body.w(700).copyWith(color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
