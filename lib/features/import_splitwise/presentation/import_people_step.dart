import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart' show StepBody;
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';
import 'package:splitify/features/import_splitwise/presentation/import_copy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Account entry only: import into one of my groups or a new one (named from the file).
class ImportGroupStep extends ConsumerWidget {
  const ImportGroupStep({
    required this.nameController,
    required this.newSelected,
    required this.onNew,
    required this.onGroup,
    super.key,
  });

  final TextEditingController nameController;
  final bool newSelected;
  final VoidCallback onNew;
  final ValueChanged<String> onGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final groups = [
      for (final g in ref.watch(groupsListProvider).value ?? const <LocalGroup>[])
        if (g.archivedAt == null) g,
    ];
    return StepBody(
      question: l.impGroupQuestion,
      children: [
        OptionTile(
          key: const Key('import-new-group'),
          label: l.impNewGroup,
          selected: newSelected,
          leading: Icon(AppIcons.plus, color: context.colors.primary),
          onTap: onNew,
        ),
        if (newSelected) ...[
          const SizedBox(height: AppSpacing.s4),
          UnderlineField(
            key: const Key('import-group-name'),
            label: l.impGroupName,
            hint: l.impGroupNameHint,
            controller: nameController,
            required: true,
            textCapitalization: TextCapitalization.words,
          ),
        ],
        if (groups.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s8),
          SectionLabel(l.impYourGroups),
          const SizedBox(height: AppSpacing.s3),
          for (final g in groups) ...[
            OptionTile(key: Key('import-group-${g.id}'), label: g.name, onTap: () => onGroup(g.id)),
            const SizedBox(height: AppSpacing.s3),
          ],
        ],
      ],
    );
  }
}

/// Matching people: one row per person of the file with their net in the file and what they become
/// (a member, a new name-only member or skipped); tap opens the choice sheet.
class ImportPeopleStep extends StatelessWidget {
  const ImportPeopleStep({
    required this.state,
    required this.groupName,
    required this.onChoice,
    super.key,
  });

  final ImportState state;
  final String groupName;
  final void Function(String name, MemberChoice choice) onChoice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final file = state.parsed!.file;
    final problem = state.mappingProblem;
    return StepBody(
      question: l.impPeopleQuestion,
      children: [
        Text(
          state.creatingGroup ? l.impPeopleHintNew : l.impPeopleHint(groupName),
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s5),
        for (final (i, name) in file.members.indexed)
          _PersonRow(
            name: name,
            caption: importNetsLine(l, file.columnSums, name) ?? l.impNetZero,
            choice: state.mapping[name] ?? const SkipPerson(),
            members: state.members,
            showDivider: i < file.members.length - 1,
            onTap: () => unawaited(_pick(context, name)),
          ),
        if (problem != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            mappingProblemText(l, problem),
            key: const Key('import-mapping-problem'),
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(color: c.oweText),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(BuildContext context, String name) async {
    final l = AppLocalizations.of(context);
    final current = state.mapping[name];
    final picked = await showAppSheet<MemberChoice>(
      context,
      title: l.impPickFor(name),
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in state.members) ...[
            OptionTile(
              key: Key('import-choice-${m.id}'),
              label: m.isMe ? l.you : m.name,
              selected: current == UseMember(m.id),
              leading: Avatar(name: m.isMe ? l.you : m.name, seed: m.id, size: AvatarSize.s32),
              onTap: () => Navigator.of(sheet).pop(UseMember(m.id)),
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
          OptionTile(
            key: const Key('import-choice-new'),
            label: l.impAddNew(clipName(name)),
            selected: current is NewMember,
            leading: Icon(AppIcons.userPlus, color: context.colors.primary),
            onTap: () => Navigator.of(sheet).pop(NewMember(clipName(name))),
          ),
          const SizedBox(height: AppSpacing.s3),
          OptionTile(
            key: const Key('import-choice-skip'),
            label: l.impSkip(name),
            selected: current is SkipPerson,
            onTap: () => Navigator.of(sheet).pop(const SkipPerson()),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            l.impSkipBody,
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
    if (picked != null) onChoice(name, picked);
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    required this.caption,
    required this.choice,
    required this.members,
    required this.showDivider,
    required this.onTap,
  });

  final String name;
  final String caption;
  final MemberChoice choice;
  final List<MappingMember> members;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final (label, fill, ink) = switch (choice) {
      UseMember(:final memberId) => (
        _memberLabel(l, memberId),
        c.primaryContainer,
        c.onPrimaryContainer,
      ),
      NewMember() => (l.impChoiceNew, c.chip, c.textPrimary),
      SkipPerson() => (l.impChoiceSkip, c.surfaceMuted, c.textSecondary),
    };
    return Semantics(
      button: true,
      child: InkWell(
        key: Key('import-person-$name'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Row(
                children: [
                  Avatar(name: name, seed: 'import-$name'),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: context.text.title.w(500)),
                        const SizedBox(height: 2),
                        Text(
                          caption,
                          style: context.text.bodySmall.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s3,
                        vertical: AppSpacing.s2,
                      ),
                      decoration: BoxDecoration(color: fill, borderRadius: AppRadii.allPill),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall.w(600).copyWith(color: ink),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s1),
                          Icon(AppIcons.chevronDown, size: 16, color: ink),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showDivider) Divider(height: 1, thickness: 1, color: c.divider),
          ],
        ),
      ),
    );
  }

  String _memberLabel(AppLocalizations l, String id) {
    final m = members.where((m) => m.id == id).firstOrNull;
    if (m == null) return l.impChoiceNew;
    return m.isMe ? l.you : m.name;
  }
}
