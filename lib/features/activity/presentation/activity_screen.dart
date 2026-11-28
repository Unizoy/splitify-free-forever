import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/application/monthly_summary.dart';
import 'package:splitify/features/activity/presentation/activity_feed.dart';
import 'package:splitify/features/activity/presentation/monthly_summary_card.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/search/presentation/search_screen.dart' show SearchRoutes;
import 'package:splitify/features/sync/presentation/sync_refresh.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Activity tab (`/activity`, #18): hero with the bell and its unread badge (opens `/notifications`), filter chips, every group's
/// activity newest first by day, my unsynced changes with the "not synced yet" marker; blob
/// empty state.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  ActivityFilter _filter = ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(activityItemsProvider(null));
    final items = async.value;
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final month = ref.watch(monthSummaryProvider);
    Widget? content;
    Widget? feed;
    if (items == null) {
      content = async.hasError
          ? EmptyState(icon: AppIcons.warning, title: l.authErrorUnknown)
          : const FeedSkeleton();
    } else if (items.isEmpty) {
      content = ClipRRect(
        borderRadius: AppRadii.all28,
        child: BlobBackground(
          child: SizedBox(
            width: double.infinity,
            child: EmptyState(
              icon: AppIcons.chat,
              title: l.emptyActivityTitle,
              message: l.emptyActivityBody,
            ),
          ),
        ),
      );
    } else {
      final shown = filterActivity(items, _filter);
      if (shown.isEmpty) {
        content = Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          child: EmptyState(
            icon: AppIcons.activity,
            title: l.actEmptyFilteredTitle,
            message: l.actEmptyFilteredBody,
          ),
        );
      } else {
        // Up to 300 rows: a lazy sliver after the sheet header builds only what is on screen (S-267).
        feed = ActivityFeed(items: shown, sliver: true);
      }
    }
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final header = OverlapColumn(
      top: HeroHeader(
        title: l.activityHero,
        art: (seed: 'activity-home', family: CoverFamily.trip),
        actions: [
          HeroIconButton(
            key: const Key('activity-search'),
            icon: AppIcons.search,
            tooltip: l.searchTooltip,
            onPressed: () => unawaited(context.push(SearchRoutes.search())),
          ),
          HeroIconButton(
            key: const Key('activity-bell'),
            icon: AppIcons.bell,
            tooltip: l.notifications,
            badge: unread,
            semanticLabel: l.notifBellLabel(unread),
            onPressed: () => unawaited(context.push('/notifications')),
          ),
        ],
      ),
      bottom: OverlapSheet(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s6 + AppSpacing.s1,
          AppSpacing.screen,
          feed == null ? bottomInset + AppSpacing.s6 : 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // F14 (W2-Y): last month's summary in the first days of a month; × folds it away (S-451).
            MotionSwitcher(
              grow: true,
              child: month == null
                  ? const SizedBox(key: ValueKey('month-none'), width: double.infinity)
                  : Column(
                      key: ValueKey('month-${month.key}'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MonthlySummaryCard(summary: month),
                        const SizedBox(height: AppSpacing.s4),
                      ],
                    ),
            ),
            // The hero says "Activity": the filters come first (D-033).
            if (items != null && items.isNotEmpty) ...[
              ActivityFilters(value: _filter, onChanged: (f) => setState(() => _filter = f)),
              const SizedBox(height: AppSpacing.s2),
            ],
            if (content != null) ...[content, const SizedBox(height: AppSpacing.navReserve)],
          ],
        ),
      ),
    );
    return Scaffold(
      body: SyncRefresh(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: header),
            if (feed != null) ...[
              EntranceScope(
                child: SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  sliver: feed,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.navReserve)),
            ],
          ],
        ),
      ),
    );
  }
}
