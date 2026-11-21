import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/split_editor.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Group settings → Default split (#35): equal, percentages or shares; new expenses in the group
/// start from it while the members stay the same (S-081).
class DefaultSplitScreen extends ConsumerStatefulWidget {
  const DefaultSplitScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<DefaultSplitScreen> createState() => _DefaultSplitScreenState();
}

class _DefaultSplitScreenState extends ConsumerState<DefaultSplitScreen> {
  bool _saving = false;

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final ok = await ref.read(defaultSplitProvider(widget.groupId).notifier).save();
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.expDefaultSplitSaved)));
    await navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final state = ref.watch(defaultSplitProvider(widget.groupId));
    final controller = ref.read(defaultSplitProvider(widget.groupId).notifier);
    final s = state.value;
    final footer = s == null
        ? null
        : splitFooter(
            l,
            s.split,
            null,
            'INR',
            percentOnly: true,
            nameOf: (id) => s.members.where((m) => m.id == id).firstOrNull?.name ?? '',
          );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: s == null
          ? Center(
              child: state.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      child: EmptyState(icon: AppIcons.warning, title: l.expLoadError),
                    )
                  : DotsPulse(color: c.primary, semanticLabel: l.loading),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.s2,
                AppSpacing.screen,
                AppSpacing.s8,
              ),
              children: [
                Semantics(
                  header: true,
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: AppText.maxSerifScale,
                    child: Text(l.expDefaultSplitTitle, style: context.text.sheetTitle),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  l.expDefaultSplitBody(s.groupName),
                  style: context.text.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s8),
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
              ],
            ),
      bottomNavigationBar: s == null
          ? null
          : StickyActionBar(
              summary: SplitFooterLine(footer: footer!),
              primary: PillButton(
                key: const Key('default-split-save'),
                label: l.saveLabel,
                loading: _saving,
                onPressed: s.canSave ? () => unawaited(_save()) : null,
              ),
            ),
    );
  }
}
