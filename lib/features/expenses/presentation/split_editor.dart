import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Split-type row `= · 1.23 · % · 1:2 · ±` (Splitwise order, #5–9) with the chosen kind's help line, and
/// the "By items" chip (D-034 A2) when [onItems] is given.
class SplitKindPicker extends StatelessWidget {
  const SplitKindPicker({
    required this.value,
    required this.onChanged,
    this.kinds = SplitKind.values,
    this.items = false,
    this.onItems,
    super.key,
  });

  final SplitKind value;
  final ValueChanged<SplitKind> onChanged;
  final List<SplitKind> kinds;

  /// The Items split is on (it is saved as exact amounts, so `1.23` stays lit with the chip).
  final bool items;

  /// Turns the Items split on; null hides the chip (the group default split has no items).
  final VoidCallback? onItems;

  static String symbol(SplitKind k) => switch (k) {
    SplitKind.equal => '=',
    SplitKind.exact => '1.23',
    SplitKind.percent => '%',
    SplitKind.shares => '1:2',
    SplitKind.adjust => '±',
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The kinds are symbols (spoken as names), so they stay compact at large text sizes.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SegmentedPill<SplitKind>(
            key: const Key('split-kind'),
            value: value,
            onChanged: onChanged,
            items: [
              for (final k in kinds)
                SegmentedPillItem(value: k, label: symbol(k), semanticLabel: l.splitKind(k)),
            ],
          ),
        ),
        if (onItems != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Center(
            child: IconChip(
              key: const Key('split-items'),
              label: l.entrySplitItems,
              icon: AppIcons.receipt,
              selected: items,
              onTap: onItems,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s3),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: items ? l.entrySplitItems : l.splitKind(value),
                style: context.text.bodySmall.w(700).copyWith(color: c.textPrimary),
              ),
              const TextSpan(text: '  ·  '),
              TextSpan(text: items ? l.entrySplitItemsHint : l.splitHint(value)),
            ],
          ),
          textAlign: TextAlign.center,
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

/// One row per person for the current split kind (#5–9): a tick for equal/adjust, an amount for
/// exact, a percentage, a shares stepper, or a signed adjustment. The caption under each name shows
/// the resulting share of [total] when the split is valid.
class SplitMemberRows extends StatelessWidget {
  const SplitMemberRows({
    required this.split,
    required this.members,
    required this.currency,
    required this.onChanged,
    this.total,
    this.allowToggle = true,
    super.key,
  });

  final SplitDraft split;
  final List<EditorMember> members;
  final String currency;
  final ValueChanged<SplitDraft> onChanged;

  /// Expense total in minor units (null: no amount yet, or a default split).
  final int? total;

  /// Equal split ticks (off for the default-split editor, where equal means everyone).
  final bool allowToggle;

  @override
  Widget build(BuildContext context) {
    final check = total == null ? null : split.check(total);
    final shares = check is SplitReady ? check.shares : null;
    final byId = {for (final m in members) m.id: m};
    final ids = split.members;
    return Column(
      children: [
        for (var i = 0; i < ids.length; i++)
          _MemberRow(
            key: ValueKey('split-row-${ids[i]}'),
            id: ids[i],
            member: byId[ids[i]],
            split: split,
            share: shares?[ids[i]],
            currency: currency,
            allowToggle: allowToggle,
            onChanged: onChanged,
            last: i == ids.length - 1,
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.id,
    required this.member,
    required this.split,
    required this.share,
    required this.currency,
    required this.allowToggle,
    required this.onChanged,
    required this.last,
    super.key,
  });

  final String id;
  final EditorMember? member;
  final SplitDraft split;
  final int? share;
  final String currency;
  final bool allowToggle;
  final ValueChanged<SplitDraft> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final name = member == null ? '' : (member!.isMe ? l.you : member!.name);
    final included = !split.usesInclusion || split.included.contains(id);
    final toggles = split.usesInclusion && allowToggle;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;

    final caption = switch ((included, share)) {
      (false, _) => l.expNotIncluded,
      (true, final int v) => MoneyFormatter.detail.format(v, currency),
      _ => null,
    };

    final controls = <Widget>[
      if (split.kind == SplitKind.exact)
        ValueField(
          key: ValueKey('exact-$id'),
          initial: split.text[id] ?? '',
          prefix: Currencies.of(currency).symbol,
          semanticLabel: l.expMemberAmountLabel(name),
          onChanged: (t) => onChanged(split.setText(id, t)),
        ),
      if (split.kind == SplitKind.percent)
        ValueField(
          key: ValueKey('percent-$id'),
          initial: split.text[id] ?? '',
          suffix: '%',
          semanticLabel: l.expMemberPercentLabel(name),
          onChanged: (t) => onChanged(split.setText(id, t)),
        ),
      if (split.kind == SplitKind.adjust && included)
        ValueField(
          key: ValueKey('adjust-$id'),
          initial: split.text[id] ?? '',
          prefix: '±${Currencies.of(currency).symbol}',
          signed: true,
          semanticLabel: l.expMemberAdjustLabel(name),
          onChanged: (t) => onChanged(split.setText(id, t)),
        ),
      if (split.kind == SplitKind.shares)
        QuantityStepper(
          key: ValueKey('shares-$id'),
          value: (split.shareUnits[id] ?? 0) ~/ 1000,
          semanticLabel: l.expMemberSharesLabel(name),
          onChanged: (v) => onChanged(split.setShareUnits(id, v * 1000)),
        ),
      if (toggles) ...[
        if (split.kind == SplitKind.adjust && included) const SizedBox(width: AppSpacing.s1),
        _TickCircle(
          key: ValueKey('tick-$id'),
          selected: included,
          label: l.expIncludeMember(name),
          onTap: () => onChanged(split.toggle(id)),
        ),
      ],
    ];

    final identity = Row(
      children: [
        Opacity(
          opacity: included ? 1 : 0.45,
          child: Avatar(name: member?.name ?? name, seed: id),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: context.text.body
                    .w(600)
                    .copyWith(color: included ? c.textPrimary : c.textSecondary),
              ),
              if (caption != null)
                Text(
                  caption,
                  style: context.text.bodySmall.copyWith(
                    color: c.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final row = large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              if (controls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s2),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: controls),
              ],
            ],
          )
        : Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: AppSpacing.s3),
              ...controls,
            ],
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          onTap: toggles ? () => onChanged(split.toggle(id)) : null,
          borderRadius: AppRadii.all16,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: row,
            ),
          ),
        ),
        if (!last) const DashedDivider(),
      ],
    );
  }
}

/// Round tick (equal / adjust inclusion): filled indigo with a check, or an empty outline.
class _TickCircle extends StatelessWidget {
  const _TickCircle({required this.selected, required this.label, required this.onTap, super.key});

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      checked: selected,
      label: label,
      button: true,
      excludeSemantics: true,
      onTap: tap,
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        circle: true,
        scale: 0.9,
        child: SizedBox.square(
          dimension: AppSpacing.minTouch,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion.fast,
              curve: context.motion.fastCurve,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? c.primaryFill : AppPalette.clear,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? c.primaryFill : c.divider, width: 1.5),
              ),
              child: selected ? Icon(AppIcons.check, size: 16, color: c.onPrimaryFill) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact value input on a muted pill (exact amount, percentage, adjustment, a payer's amount).
class ValueField extends StatefulWidget {
  const ValueField({
    required this.initial,
    required this.onChanged,
    required this.semanticLabel,
    this.prefix,
    this.suffix,
    this.signed = false,
    super.key,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final String semanticLabel;
  final String? prefix;
  final String? suffix;
  final bool signed;

  @override
  State<ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<ValueField> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.text.body
        .w(600)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final affix = context.text.body.w(500).copyWith(color: c.textSecondary);
    final width = MediaQuery.textScalerOf(context).scale(112).clamp(112, 220).toDouble();
    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: AnimatedContainer(
        duration: context.motion.fast,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: AppRadii.all16,
          border: Border.all(color: _focus.hasFocus ? c.primary : AppPalette.clear, width: 1.5),
        ),
        child: Row(
          children: [
            if (widget.prefix != null) Text(widget.prefix!, style: affix),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  textAlign: TextAlign.end,
                  textAlignVertical: TextAlignVertical.center,
                  style: style,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: widget.signed,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(widget.signed ? r'[0-9.\-]' : r'[0-9.]'),
                    ),
                    LengthLimitingTextInputFormatter(15),
                  ],
                  textInputAction: TextInputAction.next,
                  onChanged: widget.onChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    hintText: 0.toString(),
                    hintStyle: style.copyWith(color: c.textSecondary),
                  ),
                ),
              ),
            ),
            if (widget.suffix != null) ...[
              const SizedBox(width: AppSpacing.s1),
              Text(widget.suffix!, style: affix),
            ],
          ],
        ),
      ),
    );
  }
}

/// The live footer line: check or warning icon with text in `owedText` / `oweText`.
class SplitFooterLine extends StatelessWidget {
  const SplitFooterLine({
    required this.footer,
    this.textKey = const Key('split-footer'),
    super.key,
  });

  final SplitFooter footer;

  /// Key of the text (tests read the footer through it).
  final Key textKey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = footer.error ? c.oweText : c.owedText;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(footer.error ? AppIcons.warning : AppIcons.checkCircle, size: 18, color: color),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              footer.text,
              key: textKey,
              style: context.text.bodySmall.w(600).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
