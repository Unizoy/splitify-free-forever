import 'package:flutter/material.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/two_person.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The short "Paid by · split" sheet when the expense is between me and one other person (D-034 A1,
/// Splitwise's four answers): you paid / they paid, split equally / owed the full amount, each with its
/// live line ("Asha owes you ₹150"), and "More options" for the full sheet. One tap picks and closes.
class TwoPersonPanel extends StatelessWidget {
  const TwoPersonPanel({
    required this.draft,
    required this.onAnswer,
    required this.onMore,
    super.key,
  });

  final ExpenseDraft draft;
  final ValueChanged<TwoPersonAnswer> onAnswer;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = draft;
    final other = d.otherPerson;
    if (other == null) return const SizedBox.shrink();
    final me = d.members.firstWhere((m) => m.isMe);
    final current = d.twoPersonAnswer;
    return Column(
      key: const Key('two-person'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in TwoPersonAnswer.values) ...[
          _AnswerTile(
            key: Key('answer-${a.name}'),
            payer: a.iPaid ? me : other,
            title: switch (a) {
              TwoPersonAnswer.youPaidEqual => l.entryAnswerYouPaidEqual,
              TwoPersonAnswer.youOwedFull => l.entryAnswerYouOwedFull,
              TwoPersonAnswer.theyPaidEqual => l.entryAnswerTheyPaidEqual(other.name),
              TwoPersonAnswer.theyOwedFull => l.entryAnswerTheyOwedFull(other.name),
            },
            line: answerLine(l, d, a),
            owed: a.iPaid,
            selected: current == a,
            onTap: () => onAnswer(a),
          ),
          const SizedBox(height: AppSpacing.s2),
        ],
        const SizedBox(height: AppSpacing.s1),
        _MoreTile(onTap: onMore),
      ],
    );
  }
}

/// The live line of answer [a]: "Asha owes you ₹150" (or "… half" / "… all of it" without an amount).
String answerLine(AppLocalizations l, ExpenseDraft d, TwoPersonAnswer a) {
  final other = d.otherPerson;
  if (other == null) return '';
  final net = d.netFor(a);
  if (net == null) {
    return switch (a) {
      TwoPersonAnswer.youPaidEqual => l.entryAnswerOwesYouHalf(other.name),
      TwoPersonAnswer.youOwedFull => l.entryAnswerOwesYouAll(other.name),
      TwoPersonAnswer.theyPaidEqual => l.entryAnswerYouOweHalf(other.name),
      TwoPersonAnswer.theyOwedFull => l.entryAnswerYouOweAll(other.name),
    };
  }
  final amount = MoneyFormatter.detail.format(net.abs(), d.currency);
  return net >= 0
      ? l.entryAnswerOwesYou(other.name, amount)
      : l.entryAnswerYouOwe(other.name, amount);
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.payer,
    required this.title,
    required this.line,
    required this.owed,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final EditorMember payer;
  final String title;
  final String line;

  /// The line is money coming to me (lime) rather than going out (red).
  final bool owed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $line',
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.all16,
        scale: AppMotion.rowPressScale,
        haptic: PressHaptic.selection,
        child: AnimatedContainer(
          duration: context.motion.fast,
          curve: context.motion.fastCurve,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : c.surface,
            borderRadius: AppRadii.all16,
            border: Border.all(color: selected ? c.primary : c.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Avatar(name: payer.name, seed: payer.id, size: AvatarSize.s32),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.body.w(600)),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: context.text.bodySmall
                          .w(600)
                          .copyWith(
                            color: owed ? c.owedText : c.oweText,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.s2),
                Icon(AppIcons.checkCircle, size: 22, color: c.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      button: true,
      label: '${l.entryMoreOptions}, ${l.entryMoreOptionsHint}',
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        key: const Key('answer-more'),
        onTap: onTap,
        borderRadius: AppRadii.all16,
        scale: AppMotion.rowPressScale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
            child: Row(
              children: [
                TintedIcon(icon: AppIcons.more, color: c.primary, size: 32),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.entryMoreOptions,
                        style: context.text.body.w(600).copyWith(color: c.primary),
                      ),
                      Text(
                        l.entryMoreOptionsHint,
                        style: context.text.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.chevronRight, size: 18, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
