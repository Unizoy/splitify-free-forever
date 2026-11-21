import 'package:flutter/material.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart';
import 'package:splitify/features/expenses/presentation/split_editor.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Step 2 "Who paid?": one OptionTile per person (you first) + "Multiple people" (phase 10).
class PaidByStep extends StatelessWidget {
  const PaidByStep({required this.draft, required this.onPayer, super.key});

  final ExpenseDraft draft;
  final ValueChanged<String> onPayer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final people = [...draft.members.where((m) => m.isMe), ...draft.members.where((m) => !m.isMe)];
    final several = draft.payerId == null && draft.payers.length > 1;
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
          onTap: () => showComingSoon(context),
        ),
        if (several) ...[
          const SizedBox(height: AppSpacing.s3),
          Text(
            l.expMultiplePaidNote,
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(color: c.textSecondary),
          ),
        ],
      ],
    );
  }
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
