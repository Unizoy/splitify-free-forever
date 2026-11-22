import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/features/import_splitwise/presentation/import_done_step.dart';
import 'package:splitify/features/import_splitwise/presentation/import_file_step.dart';
import 'package:splitify/features/import_splitwise/presentation/import_people_step.dart';
import 'package:splitify/features/import_splitwise/presentation/import_preview_step.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Import from Splitwise (`/groups/:id/import`, `/account/import`; 08 X1): StepHeader with
/// File · (Group) · People · Preview · Done.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({this.groupId, super.key});

  /// Target group; null when started from Account (the flow asks).
  final String? groupId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _groupName = TextEditingController();
  bool _newSelected = true;

  ImportController get _c => ref.read(importControllerProvider(widget.groupId).notifier);

  List<ImportStep> get _steps => [
    ImportStep.file,
    if (widget.groupId == null) ImportStep.group,
    ImportStep.people,
    ImportStep.preview,
    ImportStep.done,
  ];

  @override
  void dispose() {
    _groupName.dispose();
    super.dispose();
  }

  int _headerIndex(ImportStep s) =>
      _steps.indexOf(s == ImportStep.running ? ImportStep.preview : s);

  void _back(ImportState s) {
    final i = _steps.indexOf(s.step);
    if (s.step == ImportStep.running) return;
    if (i <= 0 || s.step == ImportStep.done) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      } else {
        context.go('/groups');
      }
      return;
    }
    HapticFeedback.selectionClick();
    _c.goTo(_steps[i - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(importControllerProvider(widget.groupId));
    ref.listen(importControllerProvider(widget.groupId).select((s) => s.newGroupName), (_, name) {
      if (name != null && _groupName.text.isEmpty) _groupName.text = name;
    });
    final targetId = s.result?.groupId ?? s.groupId;
    final group = targetId == null ? null : ref.watch(groupProvider(targetId)).value;
    final groupName = group?.name ?? s.newGroupName ?? '';
    final body = switch (s.step) {
      ImportStep.file => ImportFileStep(
        state: s,
        onPick: () => unawaited(_c.pickFile(categoryKeys: importCategoryKeys(l))),
      ),
      ImportStep.group => ImportGroupStep(
        nameController: _groupName,
        newSelected: _newSelected,
        onNew: () => setState(() => _newSelected = true),
        onGroup: (id) => unawaited(_c.chooseGroup(id)),
      ),
      ImportStep.people => ImportPeopleStep(state: s, groupName: groupName, onChoice: _c.setChoice),
      ImportStep.preview => ImportPreviewStep(
        state: s,
        onAcceptMismatch: (v) => _c.setAcceptMismatch(value: v),
      ),
      ImportStep.running => ImportRunningStep(state: s),
      ImportStep.done => ImportDoneStep(
        state: s,
        groupName: groupName,
        onDelete: () => unawaited(_delete()),
      ),
    };
    return PopScope(
      canPop: s.step == ImportStep.file || s.step == ImportStep.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(s);
      },
      child: Scaffold(
        body: Column(
          children: [
            StepHeader(
              steps: [
                for (final step in _steps)
                  switch (step) {
                    ImportStep.file => StepItem(label: l.impStepFile, icon: AppIcons.fileCsv),
                    ImportStep.group => StepItem(label: l.impStepGroup, icon: AppIcons.groups),
                    ImportStep.people => StepItem(label: l.impStepPeople, icon: AppIcons.friends),
                    ImportStep.preview => StepItem(
                      label: l.impStepPreview,
                      icon: AppIcons.stepReview,
                    ),
                    _ => StepItem(label: l.impStepDone, icon: AppIcons.checkCircle),
                  },
              ],
              current: _headerIndex(s.step),
              statusText: groupName.isEmpty ? l.impTitle : groupName,
              statusIcon: AppIcons.fileImport,
              onBack: () => _back(s),
              onHome: s.step == ImportStep.running ? null : () => context.go('/groups'),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: context.motion.base,
                switchInCurve: AppMotion.standard,
                child: KeyedSubtree(key: ValueKey(s.step), child: body),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _bar(l, s),
      ),
    );
  }

  Widget? _bar(AppLocalizations l, ImportState s) {
    switch (s.step) {
      case ImportStep.file:
      case ImportStep.running:
        return null;
      case ImportStep.group:
        return ListenableBuilder(
          listenable: _groupName,
          builder: (context, _) => StickyActionBar(
            primary: PillButton(
              key: const Key('import-continue'),
              label: l.impContinue,
              onPressed: _newSelected && GroupRules.name(_groupName.text) == null
                  ? () => _c.chooseNewGroup(_groupName.text, myName: _myName(l))
                  : null,
            ),
          ),
        );
      case ImportStep.people:
        return StickyActionBar(
          primary: PillButton(
            key: const Key('import-continue'),
            label: l.impContinue,
            onPressed: s.mappingProblem == null ? () => _c.goTo(ImportStep.preview) : null,
          ),
        );
      case ImportStep.preview:
        return StickyActionBar(
          primary: PillButton(
            key: const Key('import-run'),
            label: l.impImportButton(s.recordCount),
            icon: AppIcons.fileImport,
            variant: PillVariant.money,
            onPressed: s.canImport
                ? () => unawaited(
                    _c.runImport(
                      ownerName: _myName(l),
                      fallbackDescription: l.impFallbackDescription,
                    ),
                  )
                : null,
          ),
        );
      case ImportStep.done:
        final groupId = s.result!.groupId;
        return StickyActionBar(
          primary: PillButton(
            key: const Key('import-open-group'),
            label: l.impOpenGroup,
            onPressed: () => context.go('/groups/$groupId'),
          ),
        );
    }
  }

  String _myName(AppLocalizations l) {
    final name = ref.read(profileProvider).value?.displayName.trim() ?? '';
    return name.isEmpty ? l.you : name;
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await confirmAction(
      context,
      title: l.impDeleteTitle,
      body: l.impDeleteBody,
      confirm: l.impDeleteImport,
      icon: AppIcons.trash,
    );
    if (ok) await _c.deleteImport();
  }
}

/// Lower-case category label (as Splitify's export writes it) → D-016 key.
Map<String, String> importCategoryKeys(AppLocalizations l) => {
  for (final subs in ExpenseCategories.tree.values)
    for (final key in subs) l.category(key).toLowerCase(): key,
};
