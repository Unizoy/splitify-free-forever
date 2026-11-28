import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/presentation/editor/paid_split_sheet.dart'
    show PayerChip;
import 'package:splitify/features/expenses/presentation/editor/step_body.dart' show SectionLabel;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/split_editor.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Group settings → Default split (#35) as a sheet (D-033: a sheet instead of a page): equal, percentages
/// or shares; new expenses in the group start from it while the members stay the same (S-081). Saving
/// closes the sheet and says so; closing it any other way keeps the saved split.
Future<void> showDefaultSplitSheet(BuildContext context, String groupId) {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  // The sheet sits on the root navigator, outside a ProviderScope the page may have (tests, D-032).
  final container = ProviderScope.containerOf(context, listen: false);
  return showAppSheet<void>(
    context,
    title: l.expDefaultSplitTitle,
    builder: (sheet) => UncontrolledProviderScope(
      container: container,
      child: DefaultSplitSheet(
        groupId: groupId,
        onSaved: () {
          Navigator.of(sheet).pop();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l.expDefaultSplitSaved)));
        },
      ),
    ),
  );
}

/// The default split editor inside its sheet.
class DefaultSplitSheet extends ConsumerStatefulWidget {
  const DefaultSplitSheet({required this.groupId, required this.onSaved, super.key});

  final String groupId;
  final VoidCallback onSaved;

  @override
  ConsumerState<DefaultSplitSheet> createState() => _DefaultSplitSheetState();
}

class _DefaultSplitSheetState extends ConsumerState<DefaultSplitSheet> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ref.read(defaultSplitProvider(widget.groupId).notifier).save();
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final state = ref.watch(defaultSplitProvider(widget.groupId));
    final controller = ref.read(defaultSplitProvider(widget.groupId).notifier);
    final s = state.value;
    if (s == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Center(
          child: state.hasError
              ? EmptyState(icon: AppIcons.warning, title: l.expLoadError)
              : DotsPulse(color: c.primary, semanticLabel: l.loading),
        ),
      );
    }
    final footer = splitFooter(
      l,
      s.split,
      null,
      'INR',
      percentOnly: true,
      nameOf: (id) => s.members.where((m) => m.id == id).firstOrNull?.name ?? '',
    );
    return Padding(
      // Percentages use the number keyboard: keep the rows and Save above it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        key: const Key('default-split-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.expDefaultSplitBody(s.groupName),
            style: context.text.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s5),
          // W2-X P-10: who pays by default (none = whoever adds the expense).
          SectionLabel(l.expPaidByLabel),
          Wrap(
            key: const Key('default-payer'),
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              IconChip(
                key: const Key('default-payer-anyone'),
                label: l.w2xDefaultPayerAnyone,
                icon: AppIcons.groups,
                selected: s.payer == null,
                onTap: () => controller.setPayer(null),
              ),
              for (final m in s.members)
                PayerChip(
                  key: Key('default-payer-${m.id}'),
                  member: m,
                  selected: s.payer == m.id,
                  onTap: () => controller.setPayer(m.id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          SectionLabel(l.expSplitSectionLabel),
          SplitKindPicker(
            value: s.split.kind,
            kinds: DefaultSplit.kinds,
            onChanged: controller.select,
          ),
          const SizedBox(height: AppSpacing.s4),
          SplitMemberRows(
            split: s.split,
            members: s.members,
            currency: 'INR',
            allowToggle: false,
            onChanged: (next) => controller.edit((_) => next),
          ),
          const SizedBox(height: AppSpacing.s4),
          SplitFooterLine(footer: footer),
          const SizedBox(height: AppSpacing.s4),
          PillButton(
            key: const Key('default-split-save'),
            label: l.saveLabel,
            loading: _saving,
            onPressed: s.canSave && !_saving ? () => unawaited(_save()) : null,
          ),
        ],
      ),
    );
  }
}
