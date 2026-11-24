import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/activity/presentation/group_activity_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/features/groups/presentation/group_tabs.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/payments/presentation/settle_picker.dart';
import 'package:splitify/features/sync/presentation/sync_refresh.dart';

/// Group detail (`/groups/:id`, 455 hero + 712 tabs): generated cover hero with back, invite and settings,
/// serif name, status pill, avatar stack; FolderTabs Expenses · Balances · Totals; sticky Add expense /
/// Settle up. Phase 08 fills the Expenses tab, phase 09 the balances, the status pill and Settle up.
class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.groupId, this.initialTab, super.key});

  final String groupId;

  /// `?tab=balances` / `?tab=totals` (a reminder notification opens the Balances tab, phase 13).
  final String? initialTab;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  late int _tab = switch (widget.initialTab) {
    'balances' => 1,
    'totals' => 2,
    _ => 0,
  };

  /// The page scrolled the sheet under the status bar: the rows below the sheet header are not inside the
  /// [OverlapColumn], so its own scrim is gone once it scrolls away (S-255) — this one stays.
  final _heroKey = GlobalKey();
  bool _underBar = false;

  bool _onScroll(ScrollUpdateNotification n) {
    if (n.depth != 0) return false;
    final hero = _heroKey.currentContext?.size?.height;
    if (hero == null) return false;
    final under =
        n.metrics.pixels >= hero - AppSpacing.sheetOverlap - MediaQuery.paddingOf(context).top;
    if (under != _underBar) setState(() => _underBar = under);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    // Until the page's own read answers, the Groups list's copy draws it, so the card's cover hero flies
    // on the first frame of the push (S-288).
    final group =
        groupAsync.value ??
        (groupAsync.isLoading
            ? ref.watch(groupsListProvider).value?.where((g) => g.id == widget.groupId).firstOrNull
            : null);
    if (group == null || group.deletedAt != null) {
      return Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => _close(context),
          ),
        ),
        body: groupAsync.isLoading
            ? const SizedBox.shrink()
            : EmptyState(icon: AppIcons.groups, title: l.groupNotFound),
      );
    }
    final members = ref.watch(groupMembersProvider(widget.groupId)).value ?? const [];
    final unsynced = ref.watch(groupUnsyncedProvider(widget.groupId)).value ?? false;
    final me = ref.watch(currentUserIdProvider);
    final balances = ref.watch(groupBalancesProvider(widget.groupId)).value;
    final archived = group.archivedAt != null;
    final sides = EdgeInsets.symmetric(horizontal: AppSpacing.screen);
    final bottomSpace = AppSpacing.s8 + MediaQuery.paddingOf(context).bottom + AppSpacing.s6;
    // Slivers (S-167, phase 19): hero + sheet header first, then the Expenses tab's rows as a lazy list, so a
    // group with thousands of records opens with one screen of rows built.
    final scrolled = SyncRefresh(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: OverlapColumn(
              top: KeyedSubtree(
                key: _heroKey,
                child: _Hero(group: group, members: members, me: me, balances: balances),
              ),
              bottom: OverlapSheet(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.s6 + AppSpacing.s1,
                  AppSpacing.screen,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (archived) ...[
                      _ArchivedBanner(groupId: group.id),
                      const SizedBox(height: AppSpacing.s5),
                    ],
                    FolderTabs(
                      index: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                      tabs: [
                        FolderTab(label: l.groupTabExpenses, icon: AppIcons.receipt),
                        FolderTab(label: l.groupTabBalances, icon: AppIcons.coins),
                        FolderTab(label: l.groupTabTotals, icon: AppIcons.chart),
                      ],
                    ),
                    if (unsynced) ...[
                      const SizedBox(height: AppSpacing.s3),
                      const Align(alignment: AlignmentDirectional.centerStart, child: SyncMarker()),
                    ],
                    const SizedBox(height: AppSpacing.s2),
                    // The picked tab's content fades in (S-263).
                    if (_tab == 1)
                      FadeIn(
                        key: const ValueKey(1),
                        child: GroupBalancesTab(groupId: group.id),
                      ),
                    if (_tab == 2)
                      FadeIn(
                        key: const ValueKey(2),
                        child: GroupTotalsTab(groupId: group.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_tab == 0) ...[
            FadeIn(
              key: const ValueKey(0),
              sliver: true,
              child: SliverPadding(
                padding: sides,
                sliver: ExpenseListSliver(groupId: group.id),
              ),
            ),
            SliverPadding(
              padding: sides,
              sliver: SliverToBoxAdapter(child: GroupActivitySection(groupId: group.id)),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
        ],
      ),
    );
    return Scaffold(
      body: Stack(
        children: [
          NotificationListener<ScrollUpdateNotification>(
            onNotification: _onScroll,
            child: scrolled,
          ),
          if (_underBar)
            Positioned(
              key: const Key('group-status-scrim'),
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: ColoredBox(color: context.colors.bg),
            ),
        ],
      ),
      bottomNavigationBar: archived ? null : _ActionBar(groupId: widget.groupId),
    );
  }

  static void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/groups');
    }
  }
}

/// Add expense (amber, opens the phase 08 stepper) + Settle up (phase 09). Settle up keeps its natural
/// width so its label never wraps; at large text the two stack.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settle = PillButton(
      key: const Key('group-settle'),
      label: l.settleUp,
      variant: PillVariant.outline,
      expand: false,
      onPressed: () => unawaited(showSettlePicker(context, groupId)),
    );
    final add = PillButton(
      key: const Key('group-add-expense'),
      label: l.addExpense,
      icon: AppIcons.add,
      variant: PillVariant.money,
      onPressed: () => unawaited(context.push(ExpenseRoutes.add(groupId))),
    );
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return StickyActionBar(
      primary: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                add,
                const SizedBox(height: AppSpacing.s2),
                settle,
              ],
            )
          : Row(
              children: [
                settle,
                const SizedBox(width: AppSpacing.s3),
                Expanded(child: add),
              ],
            ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.group, required this.members, required this.me, this.balances});

  final LocalGroup group;
  final List<LocalMember> members;
  final String? me;
  final GroupBalances? balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return HeroHeader(
      heroTag: AppHeroTags.group(group.id),
      art: (seed: group.id, family: coverFamilyFor(group.type)),
      photo: groupCoverImage(ref, group, width: 1200),
      leading: HeroIconButton(
        icon: AppIcons.back,
        tooltip: l.back,
        onPressed: () => _GroupDetailScreenState._close(context),
      ),
      actions: [
        if (group.archivedAt == null)
          HeroIconButton(
            key: const Key('group-loan'),
            icon: AppIcons.loan,
            tooltip: l.loanAction,
            onPressed: () => unawaited(context.push(ExpenseRoutes.addLoan(group.id))),
          ),
        HeroIconButton(
          key: const Key('group-invite'),
          icon: AppIcons.userPlus,
          tooltip: l.invitePeople,
          onPressed: () => unawaited(showInviteSheet(context, group.id)),
        ),
        HeroIconButton(
          key: const Key('group-settings'),
          icon: AppIcons.settings,
          tooltip: l.groupSettingsTitle,
          onPressed: () => context.push('/groups/${group.id}/settings'),
        ),
      ],
      title: group.name,
      child: Column(
        children: [
          // The pill keeps its shape at 200 % text (like the serif titles, 06 §4).
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: AppText.maxSerifScale,
            child: _StatusPill(
              archived: group.archivedAt != null,
              mine: balances?.myNets ?? const {},
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              AvatarStack(people: [for (final m in members) memberPerson(l, m, me)], max: 4),
              Text(
                l.groupMembersCount(members.length),
                style: context.text.body.w(600).copyWith(color: c.onHero),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "You are owed ₹1,200" (lime on dark green) / "You owe ₹300" (red) / "All settled" / archived.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.archived, required this.mine});

  final bool archived;

  /// My non-zero nets per currency.
  final Map<String, int> mine;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (archived) {
      return StatusPill(label: l.archivedLabel, icon: AppIcons.archive, tone: StatusPillTone.glass);
    }
    final amounts = amountsText(mine);
    return switch (balanceStatusOf(mine.values)) {
      BalanceStatus.owed => StatusPill(
        key: const Key('group-status-owed'),
        label: l.balPillOwed(amounts),
        icon: AppIcons.coins,
        tone: StatusPillTone.positive,
      ),
      BalanceStatus.owe => StatusPill(
        key: const Key('group-status-owe'),
        label: l.balPillOwe(amounts),
        icon: AppIcons.coins,
        tone: StatusPillTone.negative,
      ),
      BalanceStatus.mixed => StatusPill(
        key: const Key('group-status-mixed'),
        label: '${l.statusOwedAndOwe}\u00A0· $amounts',
        icon: AppIcons.coins,
        tone: StatusPillTone.glass,
      ),
      BalanceStatus.settled => StatusPill(
        key: const Key('group-status-settled'),
        label: l.allSettled,
        icon: AppIcons.checkCircle,
        tone: StatusPillTone.glass,
      ),
    };
  }
}

class _ArchivedBanner extends ConsumerWidget {
  const _ArchivedBanner({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      key: const Key('group-archived-banner'),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: c.infoContainer, borderRadius: AppRadii.all16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.archive, size: 20, color: c.info),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  l.groupArchivedBanner,
                  style: context.text.body.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          PillButton(
            key: const Key('group-unarchive'),
            label: l.unarchiveGroup,
            variant: PillVariant.outline,
            size: PillSize.medium,
            expand: false,
            onPressed: () async {
              await ref.read(groupActionsProvider).setArchived(groupId, archived: false);
              if (context.mounted) showGroupMessage(context, l.groupUnarchivedDone);
            },
          ),
        ],
      ),
    );
  }
}
