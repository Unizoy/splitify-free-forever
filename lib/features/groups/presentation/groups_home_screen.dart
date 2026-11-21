import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Groups home (`/groups`, 438). Phase 02 shell: hero with the overall glass
/// card and the empty state; phase 07 fills in real groups.
class GroupsHomeScreen extends StatelessWidget {
  const GroupsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: HeroHeader(
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
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: c.onHero, shape: BoxShape.circle),
                        child: Icon(AppIcons.wallet, size: 18, color: c.primaryFill),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Text(l.overall, style: context.text.title.copyWith(color: c.onHero)),
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
                    l.glassEmptyHint,
                    style: context.text.body.copyWith(color: c.onHero.withValues(alpha: 0.78)),
                  ),
                ],
              ),
            ),
          ),
          bottom: OverlapSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.activeGroups(0).toUpperCase(),
                  style: context.text.labelCaps.copyWith(color: c.textSecondary),
                ),
                EmptyState(
                  icon: AppIcons.groups,
                  title: l.emptyGroupsTitle,
                  message: l.emptyGroupsBody,
                  actions: [
                    PillButton(
                      label: l.createGroup,
                      icon: AppIcons.add,
                      onPressed: () => showComingSoon(context),
                    ),
                    PillButton(
                      label: l.joinGroup,
                      variant: PillVariant.outline,
                      onPressed: () => showComingSoon(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
