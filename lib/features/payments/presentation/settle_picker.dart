import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart' show TransferRow;
import 'package:splitify/features/groups/presentation/group_visuals.dart' show SectionLabel;
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Group "Settle up": a sheet with the transfers the Balances tab shows (mine first), each opening
/// Settle up prefilled, plus "Record a different payment".
Future<void> showSettlePicker(BuildContext context, String groupId) {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  return showAppSheet<void>(
    context,
    title: l.settleUp,
    builder: (sheet) => _GroupPicker(
      groupId: groupId,
      open: (route) {
        Navigator.of(sheet).pop();
        unawaited(router.push(route));
      },
    ),
  );
}

class _GroupPicker extends ConsumerWidget {
  const _GroupPicker({required this.groupId, required this.open});

  final String groupId;
  final ValueChanged<String> open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final b = ref.watch(groupBalancesProvider(groupId)).value;
    if (b == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Center(
          child: DotsPulse(color: context.colors.primary, semanticLabel: l.loading),
        ),
      );
    }
    final all = settleSuggestions(b);
    return Column(
      key: const Key('settle-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s4),
            child: Text(
              l.settleGroupSettled,
              style: context.text.body.copyWith(color: context.colors.textSecondary),
            ),
          )
        else ...[
          SectionLabel(l.settleSuggested),
          for (var i = 0; i < all.length; i++)
            TransferRow(
              balances: b,
              currency: all[i].currency,
              transfer: all[i].transfer,
              showDivider: i < all.length - 1,
              onSettle: () => open(
                PaymentRoutes.settle(
                  groupId,
                  from: all[i].transfer.from,
                  to: all[i].transfer.to,
                  currency: all[i].currency,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.s4),
        ],
        PillButton(
          key: const Key('settle-other'),
          label: l.settleOther,
          variant: PillVariant.outline,
          onPressed: () => open(PaymentRoutes.settle(groupId)),
        ),
      ],
    );
  }
}

/// Groups home "Settle up": my transfers in every group (what each Balances tab shows between me and
/// someone else); a snackbar when there is nothing to settle.
Future<void> showSettleEverywhere(BuildContext context, List<GroupBalances> groups) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final mine = [
    for (final g in groups)
      if (g.meId != null)
        (
          group: g,
          items: [
            for (final s in settleSuggestions(g))
              if (s.transfer.from == g.meId || s.transfer.to == g.meId) s,
          ],
        ),
  ].where((x) => x.items.isNotEmpty).toList();
  if (mine.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.allSettledSnack)));
    return;
  }
  await showAppSheet<void>(
    context,
    title: l.settleWithTitle,
    builder: (sheet) => Column(
      key: const Key('settle-everywhere'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final x in mine) ...[
          SectionLabel(x.group.groupName),
          for (var i = 0; i < x.items.length; i++)
            TransferRow(
              balances: x.group,
              currency: x.items[i].currency,
              transfer: x.items[i].transfer,
              showDivider: i < x.items.length - 1,
              onSettle: () {
                Navigator.of(sheet).pop();
                unawaited(
                  router.push(
                    PaymentRoutes.settle(
                      x.group.groupId,
                      from: x.items[i].transfer.from,
                      to: x.items[i].transfer.to,
                      currency: x.items[i].currency,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: AppSpacing.s4),
        ],
      ],
    ),
  );
}
