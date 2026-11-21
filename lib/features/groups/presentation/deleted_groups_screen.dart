import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Account → Deleted groups (`/account/deleted-groups`, 08 #1): groups this user deleted, restorable for
/// 30 days (the server checks the window and that only the creator restores, TC-1-07).
class DeletedGroupsScreen extends ConsumerWidget {
  const DeletedGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final groups = ref.watch(deletedGroupsProvider).value ?? const [];
    final now = ref.watch(groupActionsProvider).clock.now();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s2,
          AppSpacing.screen,
          AppSpacing.s10,
        ),
        children: [
          PageTitle(title: l.deletedGroups, subtitle: l.deletedGroupsBody),
          const SizedBox(height: AppSpacing.s6),
          if (groups.isEmpty)
            EmptyState(
              icon: AppIcons.restore,
              title: l.deletedGroupsEmpty,
              message: l.deletedGroupsEmptyBody,
            ),
          for (final g in groups) ...[
            _DeletedRow(
              name: g.name,
              id: g.id,
              type: g.type,
              daysLeft: restoreDaysLeft(g.deletedAt!, now),
              onRestore: () async {
                await ref.read(groupActionsProvider).restore(g.id);
                if (context.mounted) showGroupMessage(context, l.groupRestoredDone);
              },
            ),
            const DashedDivider(),
          ],
        ],
      ),
    );
  }
}

/// One deleted group: cover, name, days left, Restore (below the text at large sizes).
class _DeletedRow extends StatelessWidget {
  const _DeletedRow({
    required this.name,
    required this.id,
    required this.type,
    required this.daysLeft,
    required this.onRestore,
  });

  final String name;
  final String id;
  final String type;
  final int daysLeft;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final button = PillButton(
      key: Key('restore-$id'),
      label: l.restore,
      icon: AppIcons.restore,
      variant: PillVariant.outline,
      size: PillSize.medium,
      expand: false,
      onPressed: daysLeft < 0 ? null : onRestore,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: context.text.body.w(600)),
        Text(
          daysLeft < 0 ? l.restoreExpired : l.restoreDaysLeft(daysLeft),
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
    final cover = ClipRRect(
      borderRadius: AppRadii.all16,
      child: SizedBox.square(
        dimension: 48,
        child: CoverArt(seed: id, family: coverFamilyFor(type)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    cover,
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                button,
              ],
            )
          : Row(
              children: [
                cover,
                const SizedBox(width: AppSpacing.s3),
                Expanded(child: text),
                const SizedBox(width: AppSpacing.s3),
                button,
              ],
            ),
    );
  }
}
