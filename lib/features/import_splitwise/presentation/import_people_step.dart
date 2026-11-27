import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';
import 'package:splitify/features/import_splitwise/presentation/import_copy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The one setup screen of the import (D-033), after a file is read: the file (with Change), from Account
/// "Import into" (a new group named after the file, or one of my groups), then who is who — one row per
/// person of the file with their net and what they become (a member, a new name-only member or skipped).
class ImportSetupStep extends ConsumerWidget {
  const ImportSetupStep({
    required this.state,
    required this.groupName,
    required this.accountEntry,
    required this.nameController,
    required this.onChangeFile,
    required this.onNewGroup,
    required this.onGroup,
    required this.onChoice,
    super.key,
  });

  final ImportState state;

  /// The target group's name (for the hint).
  final String groupName;

  /// Started from Account: the target group is picked here.
  final bool accountEntry;
  final TextEditingController nameController;
  final VoidCallback onChangeFile;
  final VoidCallback onNewGroup;
  final ValueChanged<String> onGroup;
  final void Function(String name, MemberChoice choice) onChoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final file = state.parsed!.file;
    final problem = state.mappingProblem;
    final groups = !accountEntry
        ? const <LocalGroup>[]
        : [
            for (final g in ref.watch(groupsListProvider).value ?? const <LocalGroup>[])
              if (g.archivedAt == null && g.deletedAt == null) g,
          ];
    return ListView(
      key: const Key('import-setup'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s3,
        AppSpacing.screen,
        AppSpacing.s8,
      ),
      children: [
        ImportCard(
          key: const Key('import-file'),
          padding: AppSpacing.s4,
          child: Row(
            children: [
              ImportIconBadge(icon: AppIcons.fileCsv, color: c.primary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.fileName ?? l.impTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.body.w(600),
                    ),
                    Text(
                      l.impFileRows(file.rows.length, file.currencies.join(', ')),
                      style: context.text.bodySmall.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('import-change-file'),
                onPressed: onChangeFile,
                child: Text(
                  l.impChangeFile,
                  style: context.text.body.w(700).copyWith(color: c.primary),
                ),
              ),
            ],
          ),
        ),
        if (accountEntry) ...[
          const SizedBox(height: AppSpacing.s6),
          SectionLabel(l.impIntoGroup),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              IconChip(
                key: const Key('import-new-group'),
                label: l.impNewGroup,
                icon: AppIcons.plus,
                selected: state.creatingGroup,
                onTap: onNewGroup,
              ),
              for (final g in groups)
                IconChip(
                  key: Key('import-group-${g.id}'),
                  label: g.name,
                  selected: !state.creatingGroup && state.groupId == g.id,
                  onTap: () => onGroup(g.id),
                ),
            ],
          ),
          if (state.creatingGroup) ...[
            const SizedBox(height: AppSpacing.s4),
            UnderlineField(
              key: const Key('import-group-name'),
              label: l.impGroupName,
              hint: l.impGroupNameHint,
              controller: nameController,
              required: true,
              textCapitalization: TextCapitalization.words,
              errorText: GroupRules.name(nameController.text) == GroupFieldError.tooLong
                  ? l.groupNameTooLong
                  : null,
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.s6),
        SectionLabel(l.impPeopleQuestion),
        Text(
          state.creatingGroup ? l.impPeopleHintNew : l.impPeopleHint(groupName),
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s2),
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
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
      decoration: BoxDecoration(color: fill, borderRadius: AppRadii.allPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall.w(600).copyWith(color: ink),
            ),
          ),
          const SizedBox(width: AppSpacing.s1),
          Icon(AppIcons.chevronDown, size: 16, color: ink),
        ],
      ),
    );
    // Large text: the choice goes under the name instead of squeezing both (AmountRow does the same).
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: context.text.title.w(500)),
        const SizedBox(height: 2),
        Text(caption, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
        if (large) ...[const SizedBox(height: AppSpacing.s2), pill],
      ],
    );
    return Semantics(
      button: true,
      child: Pressable(
        key: Key('import-person-$name'),
        onTap: onTap,
        scale: AppMotion.rowPressScale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Row(
                crossAxisAlignment: large ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Avatar(name: name, seed: 'import-$name'),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(child: who),
                  if (!large) ...[
                    const SizedBox(width: AppSpacing.s3),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: pill),
                  ],
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
