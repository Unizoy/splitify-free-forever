import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/account/presentation/account_settings_sheet.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Account tab (`/account`, 542): gear for the settings sheet, big avatar,
/// "YOU", the wallet showpiece and the stats cards. The header shows the
/// profile (phase 05); phase 09 brings the real balances.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider).value;
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: AppPalette.clear,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.s2,
              AppSpacing.screen,
              bottom + AppSpacing.s6,
            ),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    tooltip: l.accountSettings,
                    onPressed: () => showAccountSettings(context),
                    icon: Icon(AppIcons.settings, size: 30, color: c.textPrimary),
                  ),
                ),
                if (profile == null)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.float(c, dark: context.isDark),
                    ),
                    child: Icon(AppIcons.user, size: 42, color: c.onPrimaryContainer),
                  )
                else
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: () => context.push('/account/profile'),
                      child: Avatar(
                        name: profile.displayName,
                        seed: profile.id,
                        size: AvatarSize.s96,
                        ring: true,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.s5),
                Semantics(
                  header: true,
                  child: Text(
                    profile?.displayName ?? l.yourAccount,
                    textAlign: TextAlign.center,
                    style: context.text.headline.copyWith(fontSize: 26, height: 1.2),
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  l.you.toUpperCase(),
                  style: context.text.labelCaps.copyWith(color: c.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: AppSpacing.s8),
                WalletCard(
                  brandLabel: l.walletBrand,
                  amounts: [l.zeroRupees],
                  statusLabel: l.allSettled,
                  caption: l.acrossGroups(0),
                  onTap: () => showComingSoon(context),
                ),
                const SizedBox(height: AppSpacing.s5),
                DotMatrixCard(
                  title: l.yourSpending,
                  stats: [
                    (value: l.zeroRupees, label: l.statThisMonth),
                    (value: '0', label: l.statGroups),
                    (value: '0', label: l.statPeople),
                  ],
                  onTap: () => showComingSoon(context),
                ),
                const SizedBox(height: AppSpacing.s5),
                MetalCard(
                  title: l.yourStats,
                  stats: [(value: '0', label: l.statExpenses), (value: '0', label: l.statGroups)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
