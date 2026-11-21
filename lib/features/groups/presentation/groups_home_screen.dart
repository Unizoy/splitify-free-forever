import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Groups home (`/groups`, 438): hero with the overall glass card (real totals in phase 09), the 2-column
/// grid of group covers, the archived section, and Join / New. Reads the phone's database (offline-first).
class GroupsHomeScreen extends ConsumerStatefulWidget {
  const GroupsHomeScreen({super.key});

  @override
  ConsumerState<GroupsHomeScreen> createState() => _GroupsHomeScreenState();
}

class _GroupsHomeScreenState extends ConsumerState<GroupsHomeScreen> {
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    // Pull what changed on the server since last time (the outbox pushes first).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(syncNowProvider)().catchError((Object _) {}));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groupsAsync = ref.watch(groupsListProvider);
    final offline = ref.watch(syncOfflineProvider).value ?? false;
    final groups = groupsAsync.value;
    final active = [...?groups?.where((g) => g.archivedAt == null)];
    final archived = [...?groups?.where((g) => g.archivedAt != null)];

    final Widget content;
    if (groups == null && groupsAsync.hasError) {
      content = EmptyState(icon: AppIcons.warning, title: l.authErrorUnknown);
    } else if (groups == null) {
      content = const _GridSkeleton();
    } else if (groups.isEmpty) {
      content = EmptyState(
        icon: AppIcons.groups,
        title: l.emptyGroupsTitle,
        message: l.emptyGroupsBody,
        actions: [
          PillButton(
            key: const Key('groups-empty-new'),
            label: l.newGroup,
            onPressed: () => context.push('/groups/new'),
          ),
          PillButton(
            key: const Key('groups-empty-join'),
            label: l.joinGroupShort,
            variant: PillVariant.outline,
            onPressed: () => context.push('/join'),
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active.isNotEmpty) _GroupGrid(groups: active),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            DashedListRow(
              key: const Key('groups-archived'),
              icon: AppIcons.archive,
              label: l.archivedGroups,
              value: '${archived.length}',
              showDivider: false,
              onTap: () => setState(() => _showArchived = !_showArchived),
            ),
            if (_showArchived) ...[
              const SizedBox(height: AppSpacing.s3),
              _GroupGrid(groups: archived),
            ],
          ],
        ],
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: _Hero(groupCount: active.length),
          bottom: OverlapSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s2),
                      child: SectionLabel(l.activeGroups(active.length)),
                    ),
                    if (groups != null && groups.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PillButton(
                            key: const Key('groups-join'),
                            label: l.joinShort,
                            icon: AppIcons.qr,
                            variant: PillVariant.outline,
                            size: PillSize.medium,
                            expand: false,
                            onPressed: () => context.push('/join'),
                          ),
                          const SizedBox(width: AppSpacing.s2),
                          PillButton(
                            key: const Key('groups-new'),
                            label: l.newShort,
                            icon: AppIcons.plus,
                            size: PillSize.medium,
                            expand: false,
                            onPressed: () => context.push('/groups/new'),
                          ),
                        ],
                      ),
                  ],
                ),
                if (offline) ...[const SizedBox(height: AppSpacing.s4), const _OfflineNote()],
                const SizedBox(height: AppSpacing.s4),
                content,
                const SizedBox(height: AppSpacing.navReserve),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.groupCount});

  final int groupCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return HeroHeader(
      title: l.groupsHero,
      art: (seed: 'groups-home', family: CoverFamily.other),
      actions: [
        HeroIconButton(
          icon: AppIcons.search,
          tooltip: l.search,
          onPressed: () => showComingSoon(context),
        ),
        HeroIconButton(
          icon: AppIcons.bell,
          tooltip: l.notifications,
          onPressed: () => showComingSoon(context),
        ),
      ],
      // Phase 09 replaces the placeholder total with the server's per-currency balances.
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.s3,
              runSpacing: AppSpacing.s3,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: c.onHero, shape: BoxShape.circle),
                      child: Icon(AppIcons.wallet, size: 18, color: c.primaryFill),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Text(l.overall, style: context.text.title.copyWith(color: c.onHero)),
                  ],
                ),
                StatusPill(
                  label: l.allSettled,
                  icon: AppIcons.checkCircle,
                  tone: StatusPillTone.flat,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(l.zeroRupees, style: context.text.amountHero.copyWith(color: c.onHero)),
            const SizedBox(height: AppSpacing.s1),
            Text(
              groupCount == 0 ? l.glassEmptyHint : l.acrossGroups(groupCount),
              style: context.text.body.copyWith(color: c.onHero.withValues(alpha: 0.78)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupGrid extends StatelessWidget {
  const _GroupGrid({required this.groups});

  final List<LocalGroup> groups;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.gutter,
      crossAxisSpacing: AppSpacing.gutter,
      childAspectRatio: GroupCoverCard.aspectRatioFor(context),
      children: [
        for (final g in groups)
          GroupCoverCard(
            key: Key('group-card-${g.id}'),
            seed: g.id,
            family: coverFamilyFor(g.type),
            name: g.name,
            // Balances arrive in phase 09; until then every group reads as settled.
            statusLabel: g.archivedAt == null ? l.settled : l.archivedLabel,
            unsynced: g.syncState != SyncState.synced,
            onTap: () => context.push('/groups/${g.id}'),
          ),
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: AppLocalizations.of(context).groupsLoading,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.gutter,
        crossAxisSpacing: AppSpacing.gutter,
        childAspectRatio: GroupCoverCard.aspectRatioFor(context),
        children: [
          for (var i = 0; i < 2; i++)
            DecoratedBox(
              decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all28),
            ),
        ],
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      key: const Key('groups-offline'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      decoration: BoxDecoration(color: c.infoContainer, borderRadius: AppRadii.all16),
      child: Row(
        children: [
          Icon(AppIcons.unsynced, size: 18, color: c.info),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              AppLocalizations.of(context).groupsOffline,
              style: context.text.bodySmall.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
