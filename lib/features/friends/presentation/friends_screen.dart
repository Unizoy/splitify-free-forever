import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Friends tab (`/friends`). Phase 02 shell: hero with a search pill and the
/// empty state; phase 11 lists real friends.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: HeroHeader(
            title: l.friendsHero,
            art: (seed: 'friends-home', family: CoverFamily.couple),
            child: Semantics(
              button: true,
              label: l.search,
              excludeSemantics: true,
              child: Material(
                color: c.surface,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => showComingSoon(context),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.search, color: c.textSecondary),
                        const SizedBox(width: AppSpacing.s3),
                        Text(
                          l.search,
                          style: context.text.body.w(500).copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          bottom: OverlapSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.navFriends.toUpperCase(),
                  style: context.text.labelCaps.copyWith(color: c.textSecondary),
                ),
                EmptyState(
                  icon: AppIcons.friends,
                  title: l.emptyFriendsTitle,
                  message: l.emptyFriendsBody,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
