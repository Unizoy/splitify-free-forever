import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/itemize_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart' show SectionLabel;
import 'package:splitify/features/expenses/presentation/split_editor.dart' show ValueField;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The Items split (D-034 A2): one card per receipt line (optional name, price, who had it), "Add item",
/// the extras (tax, service charge, tip, discount — amounts, shared in proportion) and what each person
/// pays. Every change goes straight into the draft through [onChanged].
class ItemsEditor extends StatefulWidget {
  const ItemsEditor({
    required this.split,
    required this.members,
    required this.currency,
    required this.onChanged,
    this.total,
    super.key,
  });

  /// An Items split ([SplitDraft.isItems]).
  final SplitDraft split;
  final List<EditorMember> members;
  final String currency;
  final ValueChanged<SplitDraft> onChanged;

  /// The expense amount (null: not typed yet).
  final int? total;

  @override
  State<ItemsEditor> createState() => _ItemsEditorState();
}

class _ItemsEditorState extends State<ItemsEditor> {
  late bool _extrasOpen = widget.split.items?.hasExtras ?? false;

  ItemizeDraft get _items => widget.split.items!;

  void _set(ItemizeDraft next) => widget.onChanged(widget.split.withItems(next));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final items = _items;
    final byId = {for (final m in widget.members) m.id: m};
    final people = [
      for (final id in widget.split.members)
        if (byId[id] != null) byId[id]!,
    ];
    final symbol = Currencies.of(widget.currency).symbol;
    final shares = widget.split.values;
    return Column(
      key: const Key('items-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in items.items.indexed) ...[
          _ItemCard(
            key: ValueKey('item-${item.key}'),
            item: item,
            number: i + 1,
            people: people,
            symbol: symbol,
            canRemove: items.items.length > 1,
            onName: (t) => _set(_items.setName(item.key, t)),
            onAmount: (t) => _set(_items.setAmount(item.key, t)),
            onToggle: (id) => _set(_items.toggleMember(item.key, id)),
            onRemove: () => _set(_items.removeItem(item.key)),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        if (items.canAdd)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PillButton(
              key: const Key('item-add'),
              label: l.entryItemAdd,
              icon: AppIcons.plus,
              variant: PillVariant.outline,
              size: PillSize.medium,
              expand: false,
              onPressed: () => _set(_items.addItem(widget.split.chosen)),
            ),
          ),
        const SizedBox(height: AppSpacing.s5),
        _ExtrasToggle(open: _extrasOpen, onTap: () => setState(() => _extrasOpen = !_extrasOpen)),
        if (_extrasOpen) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            l.entryItemsExtrasHint,
            style: context.text.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s2),
          for (final e in ItemExtra.values)
            _ExtraRow(
              key: ValueKey('extra-${e.name}'),
              extra: e,
              initial: items.extras[e] ?? '',
              symbol: symbol,
              onChanged: (t) => _set(_items.setExtra(e, t)),
            ),
        ],
        const SizedBox(height: AppSpacing.s5),
        SectionLabel(l.entryItemsEach),
        for (final (i, p) in people.indexed)
          _ShareRow(
            key: ValueKey('item-share-${p.id}'),
            member: p,
            share: shares?[p.id],
            currency: widget.currency,
            divider: i < people.length - 1,
          ),
      ],
    );
  }
}

/// One line: name + price on top, then who had it.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.number,
    required this.people,
    required this.symbol,
    required this.canRemove,
    required this.onName,
    required this.onAmount,
    required this.onToggle,
    required this.onRemove,
    super.key,
  });

  final ItemDraft item;
  final int number;
  final List<EditorMember> people;
  final String symbol;
  final bool canRemove;
  final ValueChanged<String> onName;
  final ValueChanged<String> onAmount;
  final ValueChanged<String> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final name = _NameField(
      key: ValueKey('item-name-${item.key}'),
      initial: item.name,
      semanticLabel: l.entryItemNameLabel(number),
      onChanged: onName,
    );
    final price = ValueField(
      key: ValueKey('item-amount-${item.key}'),
      initial: item.amountText,
      prefix: symbol,
      semanticLabel: l.entryItemAmountLabel(number),
      onChanged: onAmount,
    );
    final remove = canRemove
        ? AppIconButton(
            key: ValueKey('item-remove-${item.key}'),
            tooltip: l.entryItemRemove(number),
            icon: Icon(AppIcons.close, size: 18, color: c.textSecondary),
            onPressed: onRemove,
          )
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s2,
        AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.all24,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (large) ...[
            Row(
              children: [
                Expanded(child: name),
                ?remove,
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            Align(alignment: AlignmentDirectional.centerEnd, child: price),
          ] else
            Row(
              children: [
                Expanded(child: name),
                const SizedBox(width: AppSpacing.s2),
                price,
                ?remove,
              ],
            ),
          const SizedBox(height: AppSpacing.s2),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.s2),
            child: Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s1,
              children: [
                for (final p in people)
                  _PersonToggle(
                    key: ValueKey('item-${item.key}-person-${p.id}'),
                    member: p,
                    selected: item.members.contains(p.id),
                    semanticLabel: l.entryItemPersonLabel(p.isMe ? l.you : p.name, number),
                    onTap: () => onToggle(p.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The optional item name on a muted pill (text keyboard, sentence case).
class _NameField extends StatefulWidget {
  const _NameField({
    required this.initial,
    required this.semanticLabel,
    required this.onChanged,
    super.key,
  });

  final String initial;
  final String semanticLabel;
  final ValueChanged<String> onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final style = context.text.body.w(600);
    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
        child: TextField(
          controller: _controller,
          style: style,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(maxItemName)],
          cursorColor: c.primary,
          onChanged: widget.onChanged,
          decoration: pillInputDecoration(
            context: context,
            hint: l.entryItemHint,
            style: style,
            hintStyle: style.copyWith(color: c.textTertiary),
          ),
        ),
      ),
    );
  }
}

/// A person on a line: small avatar + first name; filled ink when they had it.
class _PersonToggle extends StatelessWidget {
  const _PersonToggle({
    required this.member,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final EditorMember member;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final name = member.isMe ? l.you : member.name.split(' ').first;
    return Semantics(
      button: true,
      checked: selected,
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
            child: AnimatedContainer(
              duration: context.motion.fast,
              curve: context.motion.fastCurve,
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.s1,
                AppSpacing.s1,
                AppSpacing.s3,
                AppSpacing.s1,
              ),
              decoration: ShapeDecoration(
                color: selected ? c.ink : c.surface,
                shape: StadiumBorder(
                  side: BorderSide(color: selected ? c.ink : c.border, width: 1.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: selected ? 1 : 0.5,
                    child: Avatar(name: member.name, seed: member.id, size: AvatarSize.s32),
                  ),
                  const SizedBox(width: AppSpacing.s1),
                  Flexible(
                    child: Text(
                      name,
                      style: context.text.bodySmall
                          .w(600)
                          .copyWith(color: selected ? c.onInk : c.textSecondary),
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

class _ExtrasToggle extends StatelessWidget {
  const _ExtrasToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      button: true,
      expanded: open,
      label: l.entryItemsExtras,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        key: const Key('items-extras'),
        onTap: onTap,
        borderRadius: AppRadii.all16,
        scale: AppMotion.rowPressScale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
          child: Row(
            children: [
              Icon(AppIcons.tag, size: 20, color: c.primary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  l.entryItemsExtras,
                  style: context.text.body.w(600).copyWith(color: c.primary),
                ),
              ),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: context.motion.fast,
                child: Icon(AppIcons.chevronDown, size: 18, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.extra,
    required this.initial,
    required this.symbol,
    required this.onChanged,
    super.key,
  });

  final ItemExtra extra;
  final String initial;
  final String symbol;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = extraLabel(l, extra);
    final discount = extra == ItemExtra.discount;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.text.body.w(500))),
            const SizedBox(width: AppSpacing.s3),
            ValueField(
              key: ValueKey('extra-field-${extra.name}'),
              initial: initial,
              prefix: discount ? '−$symbol' : symbol,
              semanticLabel: label,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Tax (GST)", "Service charge", "Tip", "Discount".
String extraLabel(AppLocalizations l, ItemExtra e) => switch (e) {
  ItemExtra.tax => l.entryExtraTax,
  ItemExtra.service => l.entryExtraService,
  ItemExtra.tip => l.entryExtraTip,
  ItemExtra.discount => l.entryExtraDiscount,
};

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.member,
    required this.share,
    required this.currency,
    required this.divider,
    super.key,
  });

  final EditorMember member;
  final int? share;
  final String currency;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final v = share;
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: Row(
              children: [
                Avatar(name: member.name, seed: member.id, size: AvatarSize.s32),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Text(member.isMe ? l.you : member.name, style: context.text.body.w(600)),
                ),
                Text(
                  v == null ? '—' : MoneyFormatter.detail.format(v, currency),
                  style: context.text.amount
                      .w(600)
                      .copyWith(color: v == null || v == 0 ? c.textSecondary : c.textPrimary),
                ),
              ],
            ),
          ),
          if (divider) const DashedDivider(),
        ],
      ),
    );
  }
}
