import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/paid_split_steps.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/split_editor.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Step 5 "All good?": summary card, the Splitwise-style sentence "Paid by **you and Asha** and split
/// **equally between 4 people**" (tappable parts jump to their step) and who owes what.
class ReviewStep extends StatelessWidget {
  const ReviewStep({
    required this.draft,
    required this.onEditPayer,
    required this.onEditSplit,
    super.key,
  });

  final ExpenseDraft draft;
  final VoidCallback onEditPayer;
  final VoidCallback onEditSplit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final total = draft.total;
    final check = draft.splitCheck;
    final shares = check is SplitReady ? check.shares : const <String, int>{};
    final paid = total == null ? const <String, int>{} : draft.paidFor(total);
    final category = categoryOf(draft.category);
    String money(int v) => MoneyFormatter.detail.format(v, draft.currency);
    final people = [
      for (final m in draft.members)
        if ((shares[m.id] ?? 0) != 0 || (paid[m.id] ?? 0) != 0) m,
    ];

    return StepBody(
      question: l.expReviewQuestion,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s5),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadii.all28,
            border: Border.all(color: c.border),
            boxShadow: AppShadows.card(c, dark: context.isDark),
          ),
          child: Column(
            children: [
              TintedIcon.category(category, size: 56),
              const SizedBox(height: AppSpacing.s3),
              Text(
                draft.description.trim(),
                textAlign: TextAlign.center,
                style: context.text.title,
              ),
              const SizedBox(height: AppSpacing.s1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  total == null ? '—' : money(total),
                  maxLines: 1,
                  style: context.text.amountHero,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                '${shortDate(context, draft.date)}  ·  ${l.category(draft.category)}',
                textAlign: TextAlign.center,
                style: context.text.bodySmall.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        _Sentence(draft: draft, onEditPayer: onEditPayer, onEditSplit: onEditSplit),
        const SizedBox(height: AppSpacing.s6),
        if (check is SplitInvalid)
          SplitFooterLine(
            footer: splitFooter(
              l,
              draft.split,
              total,
              draft.currency,
              nameOf: (id) => draft.member(id)?.name ?? '',
            ),
          )
        else
          for (var i = 0; i < people.length; i++) ...[
            _PersonLine(
              name: people[i].isMe ? l.you : people[i].name,
              avatarName: people[i].name,
              seed: people[i].id,
              owes: shares[people[i].id] ?? 0,
              paid: paid[people[i].id] ?? 0,
              money: money,
            ),
            if (i < people.length - 1) const DashedDivider(),
          ],
      ],
    );
  }
}

class _PersonLine extends StatelessWidget {
  const _PersonLine({
    required this.name,
    required this.avatarName,
    required this.seed,
    required this.owes,
    required this.paid,
    required this.money,
  });

  final String name;
  final String avatarName;
  final String seed;
  final int owes;
  final int paid;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final tabular = context.text.body.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
        child: Row(
          children: [
            Avatar(name: avatarName, seed: seed, size: AvatarSize.s32),
            const SizedBox(width: AppSpacing.s3),
            Expanded(child: Text(name, style: context.text.body.w(600))),
            const SizedBox(width: AppSpacing.s3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  owes == 0 ? l.expOwesNothing : l.expOwes(money(owes)),
                  textAlign: TextAlign.end,
                  style: tabular.w(600),
                ),
                if (paid != 0)
                  Text(
                    l.expPaidAmount(money(paid)),
                    textAlign: TextAlign.end,
                    style: context.text.bodySmall.w(600).copyWith(color: c.owedText),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Paid by **you** and split **equally between 4 people**" with tappable bold parts.
class _Sentence extends StatefulWidget {
  const _Sentence({required this.draft, required this.onEditPayer, required this.onEditSplit});

  final ExpenseDraft draft;
  final VoidCallback onEditPayer;
  final VoidCallback onEditSplit;

  @override
  State<_Sentence> createState() => _SentenceState();
}

class _SentenceState extends State<_Sentence> {
  late final _payerTap = TapGestureRecognizer()..onTap = () => widget.onEditPayer();
  late final _splitTap = TapGestureRecognizer()..onTap = () => widget.onEditSplit();

  @override
  void dispose() {
    _payerTap.dispose();
    _splitTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = widget.draft;
    final payerText = payerNames(l, d);
    final how = switch (d.split.kind) {
      SplitKind.equal => l.expHowEqual(d.split.participants.length),
      SplitKind.exact => l.expHowExact,
      SplitKind.percent => l.expHowPercent,
      SplitKind.shares => l.expHowShares,
      SplitKind.adjust => l.expHowAdjust,
    };
    final strong = context.text.title
        .w(700)
        .copyWith(
          color: c.primary,
          decoration: TextDecoration.underline,
          decorationColor: c.primary.withValues(alpha: 0.35),
          decorationThickness: 2,
        );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: l.expReviewPaidBy),
          TextSpan(text: payerText, style: strong, recognizer: _payerTap),
          TextSpan(text: l.expReviewAndSplit),
          TextSpan(text: how, style: strong, recognizer: _splitTap),
        ],
      ),
      key: const Key('review-sentence'),
      textAlign: TextAlign.center,
      style: context.text.title.w(500).copyWith(color: c.textSecondary, height: 1.5),
    );
  }
}
