import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_notes_screen.dart' show GroupRoutes;
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/features/groups/presentation/simplify_setting.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/default_split_sheet.dart';
import 'package:splitify/features/history/presentation/history_routes.dart';
import 'package:splitify/features/export/presentation/export_action.dart';
import 'package:splitify/features/import_splitwise/presentation/import_routes.dart';

/// Group settings (`/groups/:id/settings`, 614), a clean Splitwise-like list (D-033): the group (cover, name,
/// type · currency; tap = the one-screen edit form), members with "Add people to group" and "Invite via link
/// or QR" and per-member actions in a sheet (rename, unlink a wrong claim, remove / leave when settled), then
/// default split and simplify debts, the data rows (export CSV, import from Splitwise, deleted items) and
/// archive / leave / delete (creator), each confirmed.
class GroupSettingsScreen extends ConsumerWidget {
  const GroupSettingsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final group = ref.watch(groupProvider(groupId)).value;
    final members = ref.watch(groupMembersProvider(groupId)).value ?? const [];
    final me = ref.watch(currentUserIdProvider);
    final back = AppBar(
      leading: AppIconButton(
        tooltip: l.back,
        icon: const Icon(AppIcons.back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(l.groupSettingsTitle),
    );
    if (group == null || group.deletedAt != null) {
      return Scaffold(
        appBar: back,
        body: EmptyState(icon: AppIcons.groups, title: l.groupNotFound),
      );
    }
    final archived = group.archivedAt != null;
    final isCreator = me != null && group.createdBy == me;
    final direct = group.type == 'direct';
    return Scaffold(
      appBar: back,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s3,
            AppSpacing.screen,
            AppSpacing.s10,
          ),
          children: [
            _GroupHeader(
              group: group,
              onTap: direct ? null : () => context.push('/groups/$groupId/edit'),
            ),
            const SizedBox(height: AppSpacing.s6),
            SectionLabel('${l.membersSection}\u00A0· ${members.length}'),
            DashedListRow(
              key: const Key('settings-add-member'),
              icon: AppIcons.userPlus,
              label: l.settingsAddPeople,
              onTap: () => unawaited(_addMember(context, ref, members.length)),
            ),
            DashedListRow(
              key: const Key('settings-invite'),
              icon: AppIcons.qr,
              label: l.settingsInviteLink,
              onTap: () => unawaited(showInviteSheet(context, groupId)),
            ),
            for (final m in members)
              _MemberRow(
                member: m,
                me: me,
                onTap: () => unawaited(_memberActions(context, ref, m, me)),
              ),
            const SizedBox(height: AppSpacing.s8),
            SectionLabel(l.settingsSectionSettings),
            // #35: new expenses start with this split (phase 08).
            DashedListRow(
              key: const Key('settings-default-split'),
              icon: AppIcons.stepSplit,
              label: l.expDefaultSplitTitle,
              value: l.splitKind(DefaultSplit.decode(group.defaultSplit)?.kind ?? SplitKind.equal),
              showDivider: false,
              onTap: () => unawaited(showDefaultSplitSheet(context, groupId)),
            ),
            // #17: simplify debts (phase 11); friend (direct) groups have only two people.
            if (!direct) SimplifySettingRow(group: group),
            // D-034 C5: the group notes (whiteboard).
            if (!direct)
              DashedListRow(
                key: const Key('settings-notes'),
                icon: AppIcons.notes,
                label: l.boardTitle,
                showDivider: false,
                onTap: () => context.push(GroupRoutes.notes(groupId)),
              ),
            const SizedBox(height: AppSpacing.s8),
            SectionLabel(l.settingsSectionData),
            // #22: every expense and payment as a CSV file, through the share sheet (phase 17).
            DashedListRow(
              key: const Key('settings-export'),
              icon: AppIcons.share,
              label: l.totExportCsv,
              onTap: () => unawaited(exportGroupCsv(context, ref, groupId)),
            ),
            // X1: import a Splitwise (or Splitify) CSV into this group (phase 18).
            if (!archived)
              DashedListRow(
                key: const Key('settings-import'),
                icon: AppIcons.fileImport,
                label: l.impTitle,
                onTap: () => context.push(ImportRoutes.forGroup(groupId)),
              ),
            // #20: deleted expenses and payments, restorable by any member (phase 12).
            DashedListRow(
              key: const Key('settings-deleted-items'),
              icon: AppIcons.restore,
              label: l.delTitle,
              showDivider: false,
              onTap: () => context.push(HistoryRoutes.deleted(groupId)),
            ),
            const SizedBox(height: AppSpacing.s8),
            DashedListRow(
              key: const Key('settings-archive'),
              icon: AppIcons.archive,
              label: archived ? l.unarchiveGroup : l.archiveGroup,
              onTap: () async {
                await ref.read(groupActionsProvider).setArchived(groupId, archived: !archived);
                if (context.mounted) {
                  showGroupMessage(context, archived ? l.groupUnarchivedDone : l.groupArchivedDone);
                }
              },
            ),
            DashedListRow(
              key: const Key('settings-leave'),
              icon: AppIcons.leave,
              label: l.leaveGroup,
              destructive: true,
              showDivider: isCreator,
              onTap: () => unawaited(_leave(context, ref)),
            ),
            if (isCreator)
              DashedListRow(
                key: const Key('settings-delete'),
                icon: AppIcons.trash,
                label: l.deleteGroup,
                destructive: true,
                showDivider: false,
                onTap: () => unawaited(_delete(context, ref)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final ok = await confirmAction(
      context,
      title: l.leaveGroupTitle,
      body: l.leaveGroupBody,
      confirm: l.leaveGroup,
      icon: AppIcons.leave,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(groupActionsProvider).leave(groupId);
      router.go('/groups');
    } on GroupFailure catch (e) {
      if (context.mounted) showGroupMessage(context, groupFailureText(l, e.code));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: l.deleteGroupTitle,
      body: l.deleteGroupBody,
      confirm: l.deleteGroup,
      icon: AppIcons.trash,
    );
    if (!ok) return;
    await ref.read(groupActionsProvider).delete(groupId);
    router.go('/groups');
    messenger.showSnackBar(SnackBar(content: Text(l.groupDeletedDone)));
  }

  Future<void> _addMember(BuildContext context, WidgetRef ref, int count) async {
    final l = AppLocalizations.of(context);
    if (count >= GroupRules.maxMembers) {
      showGroupMessage(context, l.groupErrorGroupFull);
      return;
    }
    final result = await showAppSheet<({String name, int tint})>(
      context,
      title: l.addMember,
      builder: (context) => MemberNameForm(
        hint: l.addMemberHint,
        confirm: l.addMember,
        initialTint: count % Avatar.tintCount,
        pickTint: true,
      ),
    );
    if (result == null) return;
    await ref.read(groupActionsProvider).addMember(groupId, result.name, tint: result.tint);
  }

  Future<void> _memberActions(
    BuildContext context,
    WidgetRef ref,
    LocalMember m,
    String? me,
  ) async {
    final l = AppLocalizations.of(context);
    final isMe = m.userId != null && m.userId == me;
    final canUnlink = !isMe && m.userId != null && m.claimedAt != null;
    final action = await showAppSheet<_MemberAction>(
      context,
      title: memberName(l, m, me),
      builder: (context) => Column(
        children: [
          DashedListRow(
            key: const Key('member-rename'),
            icon: AppIcons.edit,
            label: l.renameMember,
            onTap: () => Navigator.of(context).pop(_MemberAction.rename),
          ),
          if (canUnlink)
            DashedListRow(
              key: const Key('member-unlink'),
              icon: AppIcons.unlink,
              label: l.unlinkMember,
              onTap: () => Navigator.of(context).pop(_MemberAction.unlink),
            ),
          if (isMe)
            DashedListRow(
              key: const Key('member-leave'),
              icon: AppIcons.leave,
              label: l.leaveGroup,
              showDivider: false,
              onTap: () => Navigator.of(context).pop(_MemberAction.leave),
            )
          else
            DashedListRow(
              key: const Key('member-remove'),
              icon: AppIcons.trash,
              label: l.removeMember,
              destructive: true,
              showDivider: false,
              onTap: () => Navigator.of(context).pop(_MemberAction.remove),
            ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    final actions = ref.read(groupActionsProvider);
    try {
      switch (action) {
        case _MemberAction.rename:
          final result = await showAppSheet<({String name, int tint})>(
            context,
            title: l.renameMember,
            builder: (context) => MemberNameForm(
              initialName: m.displayName,
              confirm: l.saveLabel,
              initialTint: m.tint ?? 0,
            ),
          );
          if (result != null) await actions.renameMember(groupId, m.id, result.name);
        case _MemberAction.unlink:
          final name = memberName(l, m, me);
          if (await confirmAction(
            context,
            title: l.unlinkMemberTitle(name),
            body: l.unlinkMemberBody,
            confirm: l.unlinkMember,
            icon: AppIcons.unlink,
          )) {
            await actions.unlinkMember(groupId, m.id);
          }
        case _MemberAction.remove:
          final name = memberName(l, m, me);
          if (await confirmAction(
            context,
            title: l.removeMemberTitle(name),
            body: l.removeMemberBody,
            confirm: l.removeMember,
            icon: AppIcons.trash,
          )) {
            if (m.syncState == SyncState.synced) {
              await actions.removeMember(groupId, m.id);
            } else {
              // Never reached the server: drop it through the outbox like any other offline edit.
              await ref.read(membersRepositoryProvider).delete(m.id, groupId);
            }
          }
        case _MemberAction.leave:
          if (context.mounted) await _leave(context, ref);
      }
    } on GroupFailure catch (e) {
      if (context.mounted) showGroupMessage(context, groupFailureText(l, e.code));
    }
  }
}

enum _MemberAction { rename, unlink, remove, leave }

/// The group at the top of its settings: cover, name and "Trip · INR"; tap opens the edit form.
class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({required this.group, required this.onTap});

  final LocalGroup group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final photo = groupCoverImage(ref, group, width: 200);
    final family = coverFamilyFor(group.type);
    final caption = l.settingsGroupCaption(groupTypeLabel(l, group.type), group.mainCurrency);
    return Semantics(
      button: onTap != null,
      label: onTap == null ? null : l.editGroup,
      onTap: onTap,
      child: Pressable(
        key: const Key('settings-edit-group'),
        onTap: onTap,
        scale: AppMotion.rowPressScale,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadii.all16,
                child: SizedBox.square(
                  dimension: 56,
                  child: photo == null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CoverArt(seed: group.id, family: family),
                            Center(
                              child: Icon(
                                GroupCoverCard.iconFor(family),
                                size: 20,
                                color: c.onHero,
                              ),
                            ),
                          ],
                        )
                      : Image(image: photo, fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: context.text.title.w(600)),
                    const SizedBox(height: 2),
                    Text(caption, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              if (onTap != null) Icon(AppIcons.edit, size: 20, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.me, required this.onTap});

  final LocalMember member;
  final String? me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final m = member;
    final isMe = m.userId != null && m.userId == me;
    final name = memberName(l, m, me);
    final status = m.role == 'owner'
        ? l.memberOwner
        : m.userId == null
        ? l.memberNameOnly
        : m.claimedAt != null
        ? l.memberClaimed
        : null;
    return Column(
      children: [
        Pressable(
          key: Key('member-${m.id}'),
          onTap: onTap,
          scale: AppMotion.rowPressScale,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Row(
                children: [
                  Avatar(name: name, seed: m.id, tint: m.tint),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe && name != l.you ? l.memberYouSuffix(name) : name,
                          style: context.text.body.w(600),
                        ),
                        if (status != null)
                          Text(
                            status,
                            style: context.text.bodySmall.copyWith(color: c.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  if (m.syncState != SyncState.synced) ...[
                    const SyncMarker(compact: true),
                    const SizedBox(width: AppSpacing.s2),
                  ],
                  Icon(AppIcons.more, size: 20, color: c.textSecondary),
                ],
              ),
            ),
          ),
        ),
        const DashedDivider(),
      ],
    );
  }
}

/// Name field (+ optional colour swatches) for adding or renaming a member; pops `(name, tint)`.
class MemberNameForm extends StatefulWidget {
  const MemberNameForm({
    required this.confirm,
    this.hint,
    this.initialName = '',
    this.initialTint = 0,
    this.pickTint = false,
    super.key,
  });

  final String confirm;
  final String? hint;
  final String initialName;
  final int initialTint;
  final bool pickTint;

  @override
  State<MemberNameForm> createState() => _MemberNameFormState();
}

class _MemberNameFormState extends State<MemberNameForm> {
  late final _name = TextEditingController(text: widget.initialName);
  late int _tint = widget.initialTint;
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (GroupRules.memberName(_name.text) != null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop((name: _name.text.trim(), tint: _tint));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final name = _name.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.hint != null) ...[
            Text(
              widget.hint!,
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s6),
          ],
          UnderlineField(
            key: const Key('member-name'),
            label: l.memberNameLabel,
            required: true,
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            errorText: _showError && GroupRules.memberName(_name.text) != null
                ? l.memberNameInvalid
                : null,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.pickTint) ...[
            const SizedBox(height: AppSpacing.s6),
            SectionLabel(l.memberColour),
            const SizedBox(height: AppSpacing.s3),
            Wrap(
              spacing: AppSpacing.s3,
              runSpacing: AppSpacing.s3,
              children: [
                for (var i = 0; i < Avatar.tintCount; i++)
                  Semantics(
                    button: true,
                    selected: i == _tint,
                    label: l.memberColourOption(i + 1),
                    excludeSemantics: true,
                    onTap: () => setState(() => _tint = i),
                    child: Pressable(
                      key: Key('member-tint-$i'),
                      onTap: () => setState(() => _tint = i),
                      circle: true,
                      scale: 0.9,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == _tint ? c.primary : AppPalette.clear,
                            width: 2,
                          ),
                        ),
                        child: Avatar(name: name.isEmpty ? '?' : name, seed: 'tint', tint: i),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          PillButton(key: const Key('member-save'), label: widget.confirm, onPressed: _submit),
        ],
      ),
    );
  }
}
