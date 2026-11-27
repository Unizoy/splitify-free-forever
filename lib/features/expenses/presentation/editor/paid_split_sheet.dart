import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/application/two_person.dart';
import 'package:splitify/features/expenses/presentation/editor/items_editor.dart';
import 'package:splitify/features/expenses/presentation/editor/two_person_sheet.dart'
    show answerLine;
import 'package:splitify/features/expenses/presentation/editor/step_body.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/split_editor.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The one "Paid by · split" sheet of the expense editor (D-032): who paid (one person, or several with
/// an amount each, #10; payers need not be in the split), then how it is split (#5–9) with the live
/// footers. Every change goes straight into the draft, so closing the sheet keeps it.
class PaidSplitPanel extends StatelessWidget {
  const PaidSplitPanel({
    required this.draft,
    required this.onPayer,
    required this.onMultiple,
    required this.onPayerText,
    required this.onSplit,
    required this.onDone,
    this.onUseTotal,
    super.key,
  });

  final ExpenseDraft draft;
  final ValueChanged<String> onPayer;
  final VoidCallback onMultiple;
  final void Function(String memberId, String text) onPayerText;
  final ValueChanged<SplitDraft> onSplit;
  final VoidCallback onDone;

  /// "Use items total": the amount becomes what the lines come to (minor units). Null hides it.
  final ValueChanged<int>? onUseTotal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = draft;
    final people = [...d.members.where((m) => m.isMe), ...d.members.where((m) => !m.isMe)];
    final several = d.multiplePayers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.expPaidByLabel),
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            for (final m in people)
              _PayerChip(
                key: Key('payer-${m.id}'),
                member: m,
                selected: d.payerId == m.id,
                onTap: () => onPayer(m.id),
              ),
            IconChip(
              key: const Key('payer-multiple'),
              label: l.expMultiplePeople,
              icon: AppIcons.groups,
              selected: several,
              onTap: onMultiple,
            ),
          ],
        ),
        if (several) ...[
          const SizedBox(height: AppSpacing.s4),
          PayerAmounts(draft: d, people: people, onChanged: onPayerText),
          const SizedBox(height: AppSpacing.s3),
          SplitFooterLine(
            key: const Key('payers-footer'),
            textKey: const Key('payers-footer-text'),
            footer: payersFooter(l, d),
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        SectionLabel(l.expSplitSectionLabel),
        SplitKindPicker(
          value: d.split.kind,
          items: d.split.isItems,
          onItems: () => onSplit(d.split.switchToItems()),
          onChanged: (k) => onSplit(d.split.switchTo(k, total: d.total)),
        ),
        const SizedBox(height: AppSpacing.s4),
        if (d.split.isItems)
          ItemsEditor(
            split: d.split,
            members: d.members,
            currency: d.currency,
            total: d.total,
            onChanged: onSplit,
          )
        else
          SplitMemberRows(
            split: d.split,
            members: d.members,
            currency: d.currency,
            total: d.total,
            onChanged: onSplit,
          ),
        const SizedBox(height: AppSpacing.s3),
        SplitFooterLine(footer: splitSheetFooter(l, d, payers: false)),
        if (_itemsTotal(d) case final int itemsTotal when onUseTotal != null) ...[
          const SizedBox(height: AppSpacing.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PillButton(
              key: const Key('items-use-total'),
              label: l.entryItemsUseTotal(MoneyFormatter.detail.format(itemsTotal, d.currency)),
              variant: PillVariant.outline,
              size: PillSize.medium,
              expand: false,
              onPressed: () => onUseTotal!(itemsTotal),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s6),
        PillButton(key: const Key('paid-split-done'), label: l.loanAmountDone, onPressed: onDone),
      ],
    );
  }
}

/// What the Items lines come to when the amount is missing or differs from it (offers "Use items total").
int? _itemsTotal(ExpenseDraft d) {
  final items = d.split.items;
  final t = items?.total;
  if (items == null || t == null || t <= 0 || t == d.total) return null;
  return t;
}

/// A person to pick as the one payer: avatar and name on a pill (filled ink when chosen).
class _PayerChip extends StatelessWidget {
  const _PayerChip({required this.member, required this.selected, required this.onTap, super.key});

  final EditorMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final name = member.isMe ? l.you : member.name;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.allPill,
        scale: 0.95,
        haptic: PressHaptic.selection,
        child: Material(
          color: selected ? c.ink : c.surface,
          shape: StadiumBorder(side: BorderSide(color: selected ? c.ink : c.border, width: 1.2)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.s2,
                AppSpacing.s1,
                AppSpacing.s4,
                AppSpacing.s1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(name: member.name, seed: member.id, size: AvatarSize.s32),
                  const SizedBox(width: AppSpacing.s2),
                  Flexible(
                    child: Text(
                      name,
                      style: context.text.body
                          .w(600)
                          .copyWith(color: selected ? c.onInk : c.textPrimary),
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

/// "Multiple people": an amount per person on a card, with what each typed amount means below.
class PayerAmounts extends StatefulWidget {
  const PayerAmounts({
    required this.draft,
    required this.people,
    required this.onChanged,
    super.key,
  });

  final ExpenseDraft draft;
  final List<EditorMember> people;
  final void Function(String memberId, String text) onChanged;

  @override
  State<PayerAmounts> createState() => _PayerAmountsState();
}

class _PayerAmountsState extends State<PayerAmounts> {
  @override
  void initState() {
    super.initState();
    // The card opens below the person chips: bring it into view once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(Scrollable.ensureVisible(context, duration: context.motion.base, alignment: 0.1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final people = widget.people;
    final onChanged = widget.onChanged;
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final inputs = draft.payerInputs;
    final symbol = Currencies.of(draft.currency).symbol;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Container(
      key: const Key('payer-amounts'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s4,
        AppSpacing.s5,
        AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.all28,
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card(c, dark: context.isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.payersMultipleHint,
            style: context.text.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s2),
          for (var i = 0; i < people.length; i++) ...[
            _PayerRow(
              key: ValueKey('payer-row-${people[i].id}'),
              member: people[i],
              initial: inputs[people[i].id] ?? '',
              symbol: symbol,
              large: large,
              onChanged: (t) => onChanged(people[i].id, t),
            ),
            if (i < people.length - 1) const DashedDivider(),
          ],
        ],
      ),
    );
  }
}

class _PayerRow extends StatelessWidget {
  const _PayerRow({
    required this.member,
    required this.initial,
    required this.symbol,
    required this.large,
    required this.onChanged,
    super.key,
  });

  final EditorMember member;
  final String initial;
  final String symbol;
  final bool large;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = member.isMe ? l.you : member.name;
    final identity = Row(
      children: [
        Avatar(name: member.name, seed: member.id),
        const SizedBox(width: AppSpacing.s3),
        Expanded(child: Text(name, style: context.text.body.w(600))),
      ],
    );
    final field = ValueField(
      key: ValueKey('payer-amount-${member.id}'),
      initial: initial,
      prefix: symbol,
      semanticLabel: l.payerAmountLabel(name),
      onChanged: onChanged,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        child: large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: AppSpacing.s2),
                  Align(alignment: AlignmentDirectional.centerEnd, child: field),
                ],
              )
            : Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: AppSpacing.s3),
                  field,
                ],
              ),
      ),
    );
  }
}

/// The live footer for "Multiple people": "₹800 of ₹1,200 · ₹400 left", "… over" or "₹1,200 covered".
({String text, bool error}) payersFooter(AppLocalizations l, ExpenseDraft d) {
  String money(int v) => MoneyFormatter.list.format(v, d.currency);
  final total = d.total;
  final check = d.payersCheck;
  return switch (check) {
    PayersReady() => (text: l.payersDone(money(total ?? 0)), error: false),
    PayersInvalid(code: 'AMOUNT_NOT_POSITIVE') => (text: l.expErrNeedAmount, error: true),
    PayersInvalid(code: PayersInvalid.invalidInput) => (text: l.expErrInvalidInput, error: true),
    PayersInvalid(code: PayersInvalid.noPayers) => (text: l.payersNone, error: true),
    PayersInvalid(:final remaining) when remaining > 0 => (
      text: l.expFooterLeft(money(d.payerSum), money(total ?? 0), money(remaining)),
      error: true,
    ),
    PayersInvalid(:final remaining) => (
      text: l.expFooterOver(money(d.payerSum), money(total ?? 0), money(-remaining)),
      error: true,
    ),
  };
}

/// The editor's one-line summary of who paid and how it is split (D-032): "Paid by You · split equally",
/// "2 people paid · split by shares".
String paidSplitSummary(AppLocalizations l, ExpenseDraft d) {
  String name(String id) {
    final m = d.member(id);
    if (m == null) return '';
    return m.isMe ? l.you : m.name;
  }

  final ids = d.payerIds;
  final paid = ids.length == 1 ? l.expPillPaidBy(name(ids.first)) : l.expPillPeoplePaid(ids.length);
  final answer = d.twoPersonAnswer;
  final other = d.otherPerson;
  if (answer != null && answer.full && other != null) {
    return l.expPillSummary(
      paid,
      answer.iPaid ? l.entryPillTheyOweFull(other.name) : l.entryPillYouOweFull,
    );
  }
  if (d.split.isItems) return l.expPillSummary(paid, l.entryPillSplitItems);
  final how = switch (d.split.kind) {
    SplitKind.equal => l.expPillSplitEqual,
    SplitKind.exact => l.expPillSplitExact,
    SplitKind.percent => l.expPillSplitPercent,
    SplitKind.shares => l.expPillSplitShares,
    SplitKind.adjust => l.expPillSplitAdjust,
  };
  return l.expPillSummary(paid, how);
}

/// The line under the summary pill (a payers problem first, "₹400 left") and at the foot of the sheet
/// ([payers] false: the sheet shows that problem under the amounts): the split's footer ("3 people · ₹400
/// each", "₹200 left"). Without an amount yet it only counts the people, so a fresh screen shows no error.
SplitFooter splitSheetFooter(AppLocalizations l, ExpenseDraft d, {bool payers = true}) {
  final total = d.total;
  if (total == null) {
    if (d.split.isItems) {
      final t = d.split.items?.total ?? 0;
      return t > 0
          ? (text: l.entryItemsComesTo(_money(t, d)), error: false)
          : (text: l.expErrNeedAmount, error: false);
    }
    return (text: l.expFooterPeople(d.split.participants.length), error: false);
  }
  if (payers && d.multiplePayers && !d.payersOk) return payersFooter(l, d);
  // Two people (D-034 A1): the answer's own line ("Asha owes you ₹150").
  final answer = d.twoPersonAnswer;
  if (answer != null && d.splitCheck is SplitReady) {
    return (text: answerLine(l, d, answer), error: false);
  }
  return splitFooter(l, d.split, total, d.currency, nameOf: (id) => d.member(id)?.name ?? '');
}

String _money(int v, ExpenseDraft d) => MoneyFormatter.list.format(v, d.currency);
