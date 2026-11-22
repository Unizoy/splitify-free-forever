import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/capture/presentation/payments_to_add.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/payments/presentation/settle_picker.dart';
import 'package:splitify/features/search/presentation/search_screen.dart' show SearchRoutes;
import 'package:splitify/features/sync/presentation/sync_refresh.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Groups home (`/groups`, 438): hero with the overall glass card (my balance per currency, rule 3), the
/// 2-column grid of group covers (unsettled first), the archived section, and Join / New. Reads the
/// phone's database (offline-first).
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
    final mine = ref.watch(myBalancesProvider).value;
    final byGroup = mine?.byGroup ?? const <String, Map<String, int>>{};
    bool open(LocalGroup g) => byGroup[g.id]?.isNotEmpty ?? false;
    // Unsettled groups first (S-076 amendment); otherwise newest first.
    final active = [
      ...?groups?.where((g) => g.archivedAt == null && open(g)),
      ...?groups?.where((g) => g.archivedAt == null && !open(g)),
    ];
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
          if (active.isNotEmpty) _GroupGrid(groups: active, balances: byGroup),
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
              _GroupGrid(groups: archived, balances: byGroup),
            ],
          ],
        ],
      );
    }

    return Scaffold(
      body: SyncRefresh(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: OverlapColumn(
            top: _Hero(groupCount: active.length, balances: mine),
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
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.groupCount, required this.balances});

  final int groupCount;
  final MyBalances? balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final b = balances;
    final first = ref.watch(profileProvider).value?.defaultCurrency ?? 'INR';
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final totals = b?.totals ?? const <String, int>{};
    final codes = orderCurrencies(totals.keys, first);
    final status = b?.status ?? BalanceStatus.settled;
    final mixed = status == BalanceStatus.mixed;
    String amount(String code) =>
        mixed ? signedMoney(totals[code]!, code) : listMoney(totals[code]!.abs(), code);
    final owing = b?.peopleOwingMe ?? 0;
    final owed = b?.peopleIOwe ?? 0;
    final caption = [
      l.homeGroupsCount(groupCount),
      if (owing > 0) l.homePeopleOweYou(owing),
      if (owed > 0) l.homeYouOwePeople(owed),
    ].join('\u00A0· ');
    return HeroHeader(
      title: l.groupsHero,
      art: (seed: 'groups-home', family: CoverFamily.other),
      actions: [
        HeroIconButton(
          key: const Key('groups-search'),
          icon: AppIcons.search,
          tooltip: l.searchTooltip,
          onPressed: () => unawaited(context.push(SearchRoutes.search())),
        ),
        HeroIconButton(
          key: const Key('groups-bell'),
          icon: AppIcons.bell,
          tooltip: l.notifications,
          badge: unread,
          semanticLabel: l.notifBellLabel(unread),
          onPressed: () => unawaited(context.push('/notifications')),
        ),
      ],
      child: GlassCard(
        key: const Key('groups-glass'),
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
                  key: Key('groups-status-${status.name}'),
                  label: status == BalanceStatus.settled ? l.allSettled : statusText(l, status),
                  icon: status == BalanceStatus.settled ? AppIcons.checkCircle : AppIcons.coins,
                  tone: StatusPillTone.flat,
                  iconColor: status == BalanceStatus.settled ? null : toneOf(status).onDarkColor(c),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                codes.isEmpty ? listMoney(0, first) : amount(codes.first),
                key: const Key('groups-overall-amount'),
                style: context.text.amountHero.copyWith(
                  color: codes.isEmpty || mixed ? c.onHero : toneOf(status).onDarkColor(c),
                ),
              ),
            ),
            if (codes.length > 1)
              Text(
                [for (final code in codes.skip(1)) amount(code)].join('\u00A0· '),
                style: context.text.amount.w(700).copyWith(color: c.onHero),
              ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              groupCount == 0 ? l.glassEmptyHint : caption,
              style: context.text.body.copyWith(color: c.onHero.withValues(alpha: 0.78)),
            ),
            if (b?.unsynced ?? false) ...[
              const SizedBox(height: AppSpacing.s3),
              const _GlassSyncMarker(),
            ],
            // Payment bubble (phase 18b): "N payments to add" while some wait.
            const PaymentsToAddPill(),
            // Nothing to settle when everything is settled (final QA).
            if (groupCount > 0 && status != BalanceStatus.settled) ...[
              const SizedBox(height: AppSpacing.s4),
              PillButton(
                key: const Key('groups-settle'),
                label: l.settleUp,
                variant: PillVariant.inverse,
                size: PillSize.medium,
                onPressed: () => unawaited(
                  showSettleEverywhere(
                    context,
                    ref.read(allGroupBalancesProvider).value ?? const [],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Not synced yet" on the glass card: the marker on a light pill so it reads over the hero.
class _GlassSyncMarker extends StatelessWidget {
  const _GlassSyncMarker();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('groups-sync-marker'),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
    decoration: BoxDecoration(color: context.colors.bg, borderRadius: AppRadii.allPill),
    child: const SyncMarker(),
  );
}

class _GroupGrid extends ConsumerWidget {
  const _GroupGrid({required this.groups, required this.balances});

  final List<LocalGroup> groups;

  /// Group id -> my non-zero nets there.
  final Map<String, Map<String, int>> balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Any pending row of the group (not just the group row) marks its card (T2, phase 15).
    final unsynced = ref.watch(unsyncedGroupIdsProvider).value ?? const <String>{};
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
          _groupCard(
            l,
            context,
            g,
            balances,
            unsynced: g.syncState != SyncState.synced || unsynced.contains(g.id),
            photo: groupCoverImage(ref, g, width: 600),
          ),
      ],
    );
  }
}

/// One cover card with my balance in that group.
Widget _groupCard(
  AppLocalizations l,
  BuildContext context,
  LocalGroup g,
  Map<String, Map<String, int>> balances, {
  required bool unsynced,
  ImageProvider? photo,
}) {
  final raw = balances[g.id] ?? const <String, int>{};
  final mine = {
    for (final code in orderCurrencies(raw.keys, g.mainCurrency.trim())) code: raw[code]!,
  };
  final status = balanceStatusOf(mine.values);
  return GroupCoverCard(
    key: Key('group-card-${g.id}'),
    seed: g.id,
    family: coverFamilyFor(g.type),
    name: g.name,
    statusLabel: g.archivedAt != null && status == BalanceStatus.settled
        ? l.archivedLabel
        : statusText(l, status),
    amountText: mine.isEmpty ? null : amountsText(mine),
    tone: toneOf(status),
    unsynced: unsynced,
    photo: photo,
    onTap: () => context.push('/groups/${g.id}'),
  );
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
