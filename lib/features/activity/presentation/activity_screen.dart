import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/presentation/activity_feed.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Activity tab (`/activity`, #18): hero with the bell (phase 13), filter chips, every group's
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
    final c = context.colors;
    final async = ref.watch(activityItemsProvider(null));
    final items = async.value;
    final Widget content;
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
      content = shown.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: EmptyState(
                icon: AppIcons.activity,
                title: l.actEmptyFilteredTitle,
                message: l.actEmptyFilteredBody,
              ),
            )
          : ActivityFeed(items: shown);
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: HeroHeader(
            title: l.activityHero,
            art: (seed: 'activity-home', family: CoverFamily.trip),
            actions: [
              HeroIconButton(
                icon: AppIcons.bell,
                tooltip: l.notifications,
                onPressed: () => showComingSoon(context),
              ),
            ],
          ),
          bottom: OverlapSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.navActivity.toUpperCase(),
                    style: context.text.labelCaps.copyWith(color: c.textSecondary),
                  ),
                ),
                if (items != null && items.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  ActivityFilters(value: _filter, onChanged: (f) => setState(() => _filter = f)),
                ],
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
