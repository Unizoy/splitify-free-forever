import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/presentation/activity_feed.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart'
    show PageTitle, SectionLabel;
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// A group's own feed (`/groups/:id/activity`, #18) with the same filters as the Activity tab.
class GroupActivityScreen extends ConsumerStatefulWidget {
  const GroupActivityScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupActivityScreen> createState() => _GroupActivityScreenState();
}

class _GroupActivityScreenState extends ConsumerState<GroupActivityScreen> {
  ActivityFilter _filter = ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final group = ref.watch(groupProvider(widget.groupId)).value;
    final async = ref.watch(activityItemsProvider(widget.groupId));
    final items = async.value;
    final shown = items == null ? null : filterActivity(items, _filter);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s2,
            AppSpacing.screen,
            AppSpacing.s8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppIconButton(
                  tooltip: l.back,
                  icon: const Icon(AppIcons.back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              PageTitle(title: l.actTitle, subtitle: group?.name),
              const SizedBox(height: AppSpacing.s6),
              ActivityFilters(value: _filter, onChanged: (f) => setState(() => _filter = f)),
              const SizedBox(height: AppSpacing.s4),
              if (shown == null)
                async.hasError
                    ? EmptyState(icon: AppIcons.warning, title: l.authErrorUnknown)
                    : const FeedSkeleton()
              else if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: EmptyState(
                    icon: AppIcons.activity,
                    title: l.actEmptyFilteredTitle,
                    message: l.actEmptyFilteredBody,
                  ),
                )
              else
                ActivityFeed(items: shown, showGroup: false),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Recent activity" at the bottom of the group's Expenses tab: the newest three rows and
/// "See all activity". Hidden until there is something to show.
class GroupActivitySection extends ConsumerWidget {
  const GroupActivitySection({required this.groupId, super.key});

  final String groupId;

  /// Rows shown before "See all activity".
  static const preview = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(activityItemsProvider(groupId)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final top = items.take(preview).toList();
    return Column(
      key: const Key('group-activity-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s8),
        SectionLabel(l.actRecent),
        for (var i = 0; i < top.length; i++)
          ActivityRow(item: top[i], showGroup: false, showDivider: i < top.length - 1),
        DashedListRow(
          key: const Key('group-activity-all'),
          icon: AppIcons.activity,
          label: l.actSeeAll,
          showDivider: false,
          onTap: () => unawaited(context.push(PaymentRoutes.groupActivity(groupId))),
        ),
      ],
    );
  }
}
