import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart';
import 'package:splitify/features/expenses/presentation/split_editor.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Step 2 "Who paid?": one OptionTile per person (you first) + "Multiple people", which opens an
/// amount per person with the live "left / over" footer in the sticky bar (#10). Payers need not be
/// in the split.
class PaidByStep extends StatelessWidget {
  const PaidByStep({
    required this.draft,
    required this.onPayer,
    required this.onMultiple,
    required this.onPayerText,
    super.key,
  });

  final ExpenseDraft draft;
  final ValueChanged<String> onPayer;
  final VoidCallback onMultiple;
  final void Function(String memberId, String text) onPayerText;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final people = [...draft.members.where((m) => m.isMe), ...draft.members.where((m) => !m.isMe)];
    final several = draft.multiplePayers;
    return StepBody(
      question: l.expPaidByQuestion,
      children: [
        for (final m in people) ...[
          OptionTile(
            key: Key('payer-${m.id}'),
            label: m.isMe ? l.you : m.name,
            selected: draft.payerId == m.id,
            leading: Avatar(name: m.name, seed: m.id, size: AvatarSize.s32),
            onTap: () => onPayer(m.id),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        OptionTile(
          key: const Key('payer-multiple'),
          label: l.expMultiplePeople,
          selected: several,
          leading: Icon(AppIcons.groups, size: 20, color: context.colors.primary),
          onTap: onMultiple,
        ),
        if (several) ...[
          const SizedBox(height: AppSpacing.s5),
          PayerAmounts(draft: draft, people: people, onChanged: onPayerText),
        ],
      ],
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
    // The card opens below the person list: bring it into view once.
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

/// Names of the payers for sentences: "you", "you and Asha", "you and 2 others".
String payerNames(AppLocalizations l, ExpenseDraft d, {bool capital = false}) {
  final ids = d.payerIds;
  String name(String id) {
    final m = d.member(id);
    if (m == null) return '';
    if (m.isMe) return capital ? l.you : l.expYouLower;
    return m.name;
  }

  final ordered = [
    ...ids.where((id) => d.member(id)?.isMe ?? false),
    ...ids.where((id) => !(d.member(id)?.isMe ?? false)),
  ];
  if (ordered.isEmpty) return l.expSeveralPeople;
  final first = name(ordered.first);
  return switch (ordered.length) {
    1 => first,
    2 => l.payersTwo(first, name(ordered[1])),
    _ => l.payersMany(first, ordered.length - 1),
  };
}

/// Step 3 "How should it be split?": kind row + one row per person; the live footer sits in the
/// sticky bar.
class SplitStep extends StatelessWidget {
  const SplitStep({required this.draft, required this.onSplit, super.key});

  final ExpenseDraft draft;
  final ValueChanged<SplitDraft> onSplit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StepBody(
      question: l.expSplitQuestion,
      children: [
        SplitKindPicker(
          value: draft.split.kind,
          onChanged: (k) => onSplit(draft.split.switchTo(k, total: draft.total)),
        ),
        const SizedBox(height: AppSpacing.s4),
        SplitMemberRows(
          split: draft.split,
          members: draft.members,
          currency: draft.currency,
          total: draft.total,
          onChanged: onSplit,
        ),
      ],
    );
  }
}
