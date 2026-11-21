import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Activity tab (`/activity`). Phase 02 shell: hero with the bell and the
/// blob-background empty state; phase 09 shows the feed.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.navActivity.toUpperCase(),
                  style: context.text.labelCaps.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s4),
                ClipRRect(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
