import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
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

/// Import from Splitwise (`/groups/:id/import`, `/account/import`; 08 X1), in three short steps (D-033):
/// pick the file, then on the same screen the group (Account entry: a new group named after the file, or one
/// of mine) and who is who → preview with the totals check → import → done ("Delete this import").
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({this.groupId, super.key});

  /// Target group; null when started from Account (picked on the setup screen).
  final String? groupId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _groupName = TextEditingController();

  ImportController get _c => ref.read(importControllerProvider(widget.groupId).notifier);

  @override
  void initState() {
    super.initState();
    _groupName.addListener(() => _c.renameNewGroup(_groupName.text));
  }

  @override
  void dispose() {
    _groupName.dispose();
    super.dispose();
  }

  Future<void> _pick() => _c.pickFile(
    categoryKeys: importCategoryKeys(AppLocalizations.of(context)),
    myName: _myName(AppLocalizations.of(context)),
  );

  void _leave() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.go('/groups');
    }
  }

  void _back(ImportState s) {
    switch (s.step) {
      case ImportStep.running:
        return;
      case ImportStep.preview:
        AppHaptics.selection();
        _c.goTo(ImportStep.people);
      case ImportStep.file:
      case ImportStep.group:
      case ImportStep.people:
      case ImportStep.done:
        _leave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(importControllerProvider(widget.groupId));
    ref.listen(importControllerProvider(widget.groupId).select((s) => s.newGroupName), (_, name) {
      if (name != null && name != _groupName.text) _groupName.text = name;
    });
    final targetId = s.result?.groupId ?? s.groupId;
    final group = targetId == null ? null : ref.watch(groupProvider(targetId)).value;
    final groupName = group?.name ?? s.newGroupName ?? '';
    final body = switch (s.step) {
      ImportStep.file => ImportFileStep(state: s, onPick: () => unawaited(_pick())),
      ImportStep.group || ImportStep.people => ImportSetupStep(
        state: s,
        groupName: groupName,
        accountEntry: widget.groupId == null,
        nameController: _groupName,
        onChangeFile: () => unawaited(_pick()),
        onNewGroup: () {
          if (!s.creatingGroup) {
            _c.chooseNewGroup(groupNameFromFile(s.fileName ?? ''), myName: _myName(l));
          }
        },
        onGroup: (id) => unawaited(_c.chooseGroup(id)),
        onChoice: _c.setChoice,
      ),
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
    final bar = _bar(l, s);
    return PopScope(
      canPop: s.step != ImportStep.preview && s.step != ImportStep.running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(s);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: s.step == ImportStep.running
              ? null
              : AppIconButton(
                  tooltip: l.back,
                  icon: const Icon(AppIcons.back),
                  onPressed: () => _back(s),
                ),
          automaticallyImplyLeading: false,
          title: Text(s.step == ImportStep.preview ? l.impStepPreview : l.impTitle),
        ),
        body: PageBody(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.motion.base,
                  switchInCurve: AppMotion.standard,
                  child: KeyedSubtree(
                    key: ValueKey(s.step == ImportStep.group ? ImportStep.people : s.step),
                    child: body,
                  ),
                ),
              ),
              // In the body: the Scaffold lifts it above the keyboard (the group name field, D-032).
              ?bar,
            ],
          ),
        ),
      ),
    );
  }

  Widget? _bar(AppLocalizations l, ImportState s) {
    switch (s.step) {
      case ImportStep.file:
      case ImportStep.running:
        return null;
      case ImportStep.group:
      case ImportStep.people:
        return StickyActionBar(
          primary: PillButton(
            key: const Key('import-continue'),
            label: l.impPreviewButton,
            onPressed: s.canPreview
                ? () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _c.goTo(ImportStep.preview);
                  }
                : null,
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
