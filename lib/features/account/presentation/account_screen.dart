import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/account/presentation/account_settings_sheet.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/balances/application/account_stats.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Account tab (`/account`, 542): gear for the settings sheet, big avatar,
/// "YOU", the wallet showpiece with my overall balance per currency (phase 09, rule 3; tap = by
/// group) and the stats cards from the phone's database.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider).value;
    final mine = ref.watch(myBalancesProvider).value;
    final stats = ref.watch(accountStatsProvider).value;
    final first = profile?.defaultCurrency ?? 'INR';
    final totals = mine?.totals ?? const <String, int>{};
    final codes = orderCurrencies(totals.keys, first);
    final status = mine?.status ?? BalanceStatus.settled;
    final mixed = status == BalanceStatus.mixed;
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
                  key: const Key('account-wallet'),
                  brandLabel: l.walletBrand,
                  amounts: codes.isEmpty
                      ? [listMoney(0, first)]
                      : [
                          for (final code in codes)
                            mixed
                                ? signedMoney(totals[code]!, code)
                                : listMoney(totals[code]!.abs(), code),
                        ],
                  statusLabel: status == BalanceStatus.settled
                      ? l.allSettled
                      : statusText(l, status),
                  caption: l.acrossGroups(stats?.groups ?? 0),
                  onTap: () => showWalletBreakdown(context),
                ),
                // Rule 3: overall balances come from local rows; say so while some are not on the server.
                if (ref.watch(anyUnsyncedProvider).value ?? false) ...[
                  const SizedBox(height: AppSpacing.s3),
                  const SyncMarker(key: Key('account-sync-marker')),
                ],
                const SizedBox(height: AppSpacing.s5),
                DotMatrixCard(
                  title: l.yourSpending,
                  stats: [
                    (
                      value: listMoney(stats?.spentThisMonth ?? 0, stats?.currency ?? first),
                      label: l.statThisMonth,
                    ),
                    (value: '${stats?.groups ?? 0}', label: l.statGroups),
                    (value: '${stats?.people ?? 0}', label: l.statPeople),
                  ],
                  onTap: () => showComingSoon(context),
                ),
                const SizedBox(height: AppSpacing.s5),
                MetalCard(
                  title: l.yourStats,
                  stats: [
                    (value: '${stats?.expenses ?? 0}', label: l.statExpenses),
                    (value: '${stats?.groups ?? 0}', label: l.statGroups),
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

/// Wallet tap: my balance in every group (archived ones too), each opening its group.
Future<void> showWalletBreakdown(BuildContext context) {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  return showAppSheet<void>(
    context,
    title: l.walletBreakdownTitle,
    builder: (sheet) => _Breakdown(
      open: (id) {
        Navigator.of(sheet).pop();
        router.push('/groups/$id').ignore();
      },
    ),
  );
}

class _Breakdown extends ConsumerWidget {
  const _Breakdown({required this.open});

  final ValueChanged<String> open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final groups = ref.watch(allGroupBalancesProvider).value ?? const <GroupBalances>[];
    final mine = ref.watch(myBalancesProvider).value;
    final rows = [
      for (final g in groups)
        if (g.meId != null && (mine?.byGroup[g.groupId]?.isNotEmpty ?? false)) g,
    ];
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s4),
        child: Text(
          l.walletBreakdownEmpty,
          key: const Key('wallet-breakdown-empty'),
          style: context.text.body.copyWith(color: context.colors.textSecondary),
        ),
      );
    }
    return Column(
      key: const Key('wallet-breakdown'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          Builder(
            builder: (context) {
              final g = rows[i];
              final raw = mine!.byGroup[g.groupId]!;
              final nets = {
                for (final code in orderCurrencies(raw.keys, g.mainCurrency)) code: raw[code]!,
              };
              final status = balanceStatusOf(nets.values);
              return AmountRow(
                key: Key('wallet-group-${g.groupId}'),
                title: g.groupName,
                amountText: amountsText(nets),
                amountCaption: statusText(l, status),
                tone: toneOf(status),
                showDivider: i < rows.length - 1,
                onTap: () => open(g.groupId),
              );
            },
          ),
      ],
    );
  }
}
