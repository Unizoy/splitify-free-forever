import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/features/expenses/application/amount_input.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/with_picker.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/friends/presentation/friend_widgets.dart' show groupTypeIcon;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "With you and" + the group chip (Splitwise's first row, D-032/D-033): the group, or the friend of a
/// friend expense (#2). Tapping the chip opens the picker of recent groups and friends ([onPick]); a saved
/// expense or a template keeps its group, so the chip is read-only there ([onPick] null). With nobody
/// picked yet (the + of the tab bar) a dashed "Choose group or friend" chip and the most recent groups /
/// friends as one-tap suggestions ([onQuickPick]) show instead.
class WithRow extends ConsumerWidget {
  const WithRow({
    required this.draft,
    required this.offline,
    this.onPick,
    this.onQuickPick,
    this.showError = false,
    super.key,
  });

  final ExpenseDraft draft;

  /// Saved on this phone only for now: the chip says so.
  final bool offline;
  final VoidCallback? onPick;
  final ValueChanged<String>? onQuickPick;

  /// After a Save attempt without a group: says what is missing.
  final bool showError;

  /// Suggestions shown before anything is picked.
  static const quickPicks = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final targets = ref.watch(withTargetsProvider) ?? const <WithTarget>[];
    if (!draft.hasGroup) {
      final recent = targets.take(quickPicks);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l.expWithLabel, style: context.text.body.copyWith(color: c.textSecondary)),
              _ChooseChip(onTap: onPick, error: showError),
            ],
          ),
          if (showError) ...[
            const SizedBox(height: AppSpacing.s1),
            Semantics(
              liveRegion: true,
              child: Text(
                l.expWithMissing,
                key: const Key('with-error'),
                style: context.text.caption.copyWith(color: c.oweText, fontSize: 13),
              ),
            ),
          ],
          if (recent.isNotEmpty && onQuickPick != null) ...[
            const SizedBox(height: AppSpacing.s2),
            SingleChildScrollView(
              key: const Key('with-suggestions'),
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final t in recent) ...[
                    _QuickPick(target: t, onTap: () => onQuickPick!(t.groupId)),
                    const SizedBox(width: AppSpacing.s2),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    }
    final friend = draft.friend;
    final name = friend?.name ?? draft.groupName;
    final target = targets.where((t) => t.groupId == draft.groupId).firstOrNull;
    final tap = onPick;
    final chip = Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.s1,
        AppSpacing.s1,
        tap == null ? AppSpacing.s4 : AppSpacing.s3,
        AppSpacing.s1,
      ),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: StadiumBorder(side: BorderSide(color: c.border, width: 1.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (friend != null)
            Avatar(name: friend.name, seed: friend.id, size: AvatarSize.s32)
          else if (target != null)
            WithThumb(target: target, size: 32)
          else
            TintedIcon(icon: groupTypeIcon(draft.groupType), color: c.primary, size: 32),
          const SizedBox(width: AppSpacing.s2),
          Flexible(child: Text(name, style: context.text.body.w(600))),
          if (tap != null) ...[
            const SizedBox(width: AppSpacing.s1),
            Icon(AppIcons.chevronDown, size: 16, color: c.textSecondary),
          ],
        ],
      ),
    );
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.expWithLabel, style: context.text.body.copyWith(color: c.textSecondary)),
        Semantics(
          key: const Key('expense-with'),
          container: true,
          button: tap != null,
          label: name,
          hint: tap == null ? null : l.expWithChange,
          excludeSemantics: true,
          onTap: tap,
          child: tap == null
              ? chip
              : Pressable(
                  key: const Key('expense-with-chip'),
                  onTap: tap,
                  borderRadius: AppRadii.allPill,
                  scale: 0.96,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
                    child: Center(widthFactor: 1, child: chip),
                  ),
                ),
        ),
        if (offline)
          StatusPill(
            key: const Key('expense-offline'),
            label: l.expOfflinePill(name),
            icon: AppIcons.unsynced,
            tone: StatusPillTone.flat,
          ),
      ],
    );
  }
}

/// The dashed "Choose group or friend" chip of a new expense with nobody picked yet.
class _ChooseChip extends StatelessWidget {
  const _ChooseChip({required this.onTap, required this.error});

  final VoidCallback? onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final color = error ? c.oweText : c.primary;
    return Semantics(
      key: const Key('expense-with'),
      button: true,
      label: l.expWithChoose,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        key: const Key('expense-with-choose'),
        onTap: onTap,
        borderRadius: AppRadii.allPill,
        scale: 0.96,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
          child: Center(
            widthFactor: 1,
            child: CustomPaint(
              painter: DashedBorderPainter(color: color, strokeWidth: 1.4, dash: 5, gap: 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.plus, size: 16, color: color),
                    const SizedBox(width: AppSpacing.s1),
                    Flexible(
                      child: Text(
                        l.expWithChoose,
                        style: context.text.body.w(600).copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One suggested group or friend under the dashed chip: picture + name, one tap picks it.
class _QuickPick extends StatelessWidget {
  const _QuickPick({required this.target, required this.onTap});

  final WithTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: target.name,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        key: Key('with-quick-${target.groupId}'),
        onTap: onTap,
        borderRadius: AppRadii.allPill,
        scale: 0.95,
        haptic: PressHaptic.selection,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.s1,
                AppSpacing.s1,
                AppSpacing.s3,
                AppSpacing.s1,
              ),
              decoration: ShapeDecoration(
                color: c.surface,
                shape: StadiumBorder(side: BorderSide(color: c.border, width: 1.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WithThumb(target: target, size: 28),
                  const SizedBox(width: AppSpacing.s2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      target.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall.w(600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The category as a round tinted icon beside the description; tapping it opens the category picker.
/// While the description picked it (auto-category, D-028) a tiny "Auto" tag sits under the icon.
class CategoryButton extends StatelessWidget {
  const CategoryButton({
    required this.category,
    required this.auto,
    required this.onTap,
    super.key,
  });

  /// `parent.sub` key.
  final String category;

  /// Suggested from the description (not picked, not saved).
  final bool auto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final motion = context.motion;
    final label = l.category(category);
    return Semantics(
      key: const Key('category-hint'),
      button: true,
      label: auto ? l.expCategoryAutoLabel(label) : l.expCategoryHintLabel(label),
      hint: l.expCategoryPick,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        key: const Key('category-button'),
        onTap: onTap,
        circle: true,
        scale: 0.92,
        child: SizedBox(
          width: 64,
          height: 72,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              AnimatedSwitcher(
                duration: motion.base,
                switchInCurve: AppMotion.standard,
                switchOutCurve: AppMotion.standard,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: TintedIcon.category(categoryOf(category), size: 56, key: ValueKey(category)),
              ),
              Positioned(
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: auto ? 1 : 0,
                  duration: motion.fast,
                  // A badge on the icon: kept small so it never covers it at large text sizes.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.2,
                    child: TagChip(
                      key: const Key('category-auto'),
                      label: l.expCategoryAuto,
                      icon: AppIcons.sparkle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The amount (D-032): a large field on the phone's own number keyboard (no custom keypad, so only one
/// keyboard is ever up), caps label, dashed underline that turns solid on focus, error below. The text
/// becomes integer minor units through `AmountExpression` in the draft.
class AmountField extends StatefulWidget {
  const AmountField({
    required this.controller,
    required this.focusNode,
    required this.currency,
    required this.onChanged,
    this.errorText,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// ISO code: how many decimals the field takes.
  final String currency;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(AmountField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final exponent = Currencies.exponentOf(widget.currency);
    final focused = widget.focusNode.hasFocus;
    final error = widget.errorText;
    final lineColor = error != null ? c.oweText : (focused ? c.primary : c.divider);
    final style = context.text.amountHero;
    final hint = exponent == 0 ? '0' : '0.${'0' * exponent}';
    final spoken = [l.expAmountLabel, l.required].join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  text: l.expAmountLabel.toUpperCase(),
                  children: [
                    TextSpan(
                      text: '*',
                      style: context.text.labelCaps.copyWith(color: c.oweText),
                    ),
                  ],
                ),
                // Spoken like UnderlineField's required label: "Amount, required".
                semanticsLabel: spoken,
                style: context.text.labelCaps.copyWith(color: c.textSecondary),
              ),
              // Big digits, but not so big at 200 % text that a lakh no longer fits.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.5,
                child: TextField(
                  key: const Key('expense-amount-input'),
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  keyboardType: TextInputType.numberWithOptions(decimal: exponent > 0),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [_AmountFormatter(exponent)],
                  autocorrect: false,
                  enableSuggestions: false,
                  style: style,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                    hintText: hint,
                    hintStyle: style.copyWith(color: c.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: focused ? 1.5 : 1,
          width: double.infinity,
          child: focused || error != null
              ? ColoredBox(color: lineColor)
              : CustomPaint(painter: DashedLinePainter(color: lineColor, dash: 5, gap: 4)),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.s1),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              key: const Key('amount-error'),
              style: context.text.caption.copyWith(color: c.oweText, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

/// Keeps only what [AmountInput] accepts; a refused key leaves the text as it was.
class _AmountFormatter extends TextInputFormatter {
  _AmountFormatter(this.exponent);

  final int exponent;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final kept = AmountInput.accept(newValue.text, exponent);
    if (kept == null) return oldValue;
    if (kept == newValue.text) return newValue;
    return TextEditingValue(
      text: kept,
      selection: TextSelection.collapsed(offset: kept.length),
    );
  }
}

/// "Paid by You · split equally" with the live line under it ("3 people · ₹400 each", or in red what
/// is left to assign). Tapping opens the one Paid by · split sheet.
class PaidSplitPill extends StatelessWidget {
  const PaidSplitPill({
    required this.summary,
    required this.footer,
    required this.onTap,
    super.key,
  });

  final String summary;
  final SplitFooter footer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final error = footer.error;
    return Semantics(
      button: true,
      label: summary,
      value: footer.text,
      hint: l.expPaidSplitHint,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        key: const Key('split-summary'),
        onTap: onTap,
        borderRadius: AppRadii.all24,
        child: AnimatedContainer(
          duration: context.motion.fast,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s3,
            AppSpacing.s3,
            AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: AppRadii.all24,
            border: Border.all(color: error ? c.oweText : AppPalette.clear, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(AppIcons.stepSplit, size: 22, color: c.onPrimaryContainer),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary,
                      key: const Key('split-summary-text'),
                      style: context.text.body.w(700).copyWith(color: c.onPrimaryContainer),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      footer.text,
                      key: const Key('split-summary-footer'),
                      style: context.text.bodySmall
                          .w(600)
                          .copyWith(
                            color: error ? c.oweText : c.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Icon(AppIcons.chevronRight, size: 18, color: c.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// One compact chip of the bottom toolbar (date, notes, receipt, repeat): icon and short label; filled
/// ink once it holds something.
class ToolChip extends StatelessWidget {
  const ToolChip({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.active = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final bool active;

  /// Null shows the chip read-only (a repeating expense's first date).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.onInk : c.textPrimary;
    return Semantics(
      button: onTap != null,
      selected: active,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.allPill,
        scale: 0.95,
        haptic: PressHaptic.selection,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
          child: Center(
            widthFactor: 1,
            child: Material(
              color: active ? c.ink : c.surface,
              shape: StadiumBorder(side: BorderSide(color: active ? c.ink : c.border, width: 1.2)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: active ? c.onInk : c.primary),
                    const SizedBox(width: AppSpacing.s1),
                    Text(label, style: context.text.bodySmall.w(600).copyWith(color: fg)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
