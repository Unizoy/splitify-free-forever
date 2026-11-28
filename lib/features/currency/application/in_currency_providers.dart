import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/currency/application/conversion_actions.dart' show fxRecordsOf;
import 'package:splitify/features/currency/domain/in_currency.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show currentUserIdProvider;

SharedPreferences? _prefs(Ref ref) {
  try {
    return ref.watch(sharedPreferencesProvider);
  } on Object {
    return null;
  }
}

/// "Show in INR" (W2-X P-9) on the Home overall card and friend pages: one switch for both, kept on this phone.
final showInHomeCurrencyProvider = NotifierProvider<ShowInHomeCurrency, bool>(
  ShowInHomeCurrency.new,
);

class ShowInHomeCurrency extends Notifier<bool> {
  /// SharedPreferences key.
  static const storageKey = 'balances.showInHomeCurrency';

  @override
  bool build() => _prefs(ref)?.getBool(storageKey) ?? false;

  void set({required bool on}) {
    if (on == state) return;
    state = on;
    final prefs = _prefs(ref);
    if (prefs != null) unawaited(prefs.setBool(storageKey, on));
  }
}

/// My active member id in [ledger] for account [uid].
String? _meIn(GroupLedger ledger, String? uid) => uid == null
    ? null
    : ledger.members
          .where((m) => m.userId == uid && m.status == 'active' && m.deletedAt == null)
          .map((m) => m.id)
          .firstOrNull;

/// My overall balance in [target] over every group I am in, from saved conversions only (P-9).
InCurrency myTotalIn(String target, List<GroupLedger> ledgers, String? uid) {
  var out = InCurrency(currency: target);
  for (final l in ledgers) {
    final me = _meIn(l, uid);
    if (me == null) continue;
    out = out + myNetIn(target, me, fxRecordsOf(l));
  }
  return out;
}

/// What a friend and I owe each other in [target] across our groups, as each group shows it (P-9).
InCurrency friendTotalIn(String target, Friend friend) {
  var out = InCurrency(currency: target);
  for (final link in friend.links) {
    out =
        out +
        pairIn(
          target,
          me: link.meId,
          friend: link.friendMemberId,
          order: [for (final m in link.ledger.members) m.id],
          records: fxRecordsOf(link.ledger),
          simplify: link.balances.simplify,
          shown: link.amounts,
        );
  }
  return out;
}

/// [myTotalIn] of this phone's groups; null while they load.
final myTotalInProvider = Provider.autoDispose.family<InCurrency?, String>((ref, target) {
  final ledgers = ref.watch(allLedgersProvider).value;
  if (ledgers == null) return null;
  return myTotalIn(target, ledgers, ref.watch(currentUserIdProvider));
});
