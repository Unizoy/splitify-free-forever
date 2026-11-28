import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/core/money/amount_expression.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/core/time/clock.dart' show LocalToday;
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/application/balance_views.dart' show orderCurrencies;
import 'package:splitify/features/balances/application/balances_providers.dart'
    show ledgerRepositoryProvider;
import 'package:splitify/features/expenses/application/expense_draft.dart' show isoDate;
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/payments/application/batch_allocation.dart';
import 'package:splitify/features/payments/application/settle_controller.dart'
    show SettleNotFound, maxPaymentNote;

/// "Settle everything with Asha" in one currency (D-034 B1): `/settle/all?friend=<key>&currency=INR`.
typedef SettleAllArgs = ({String friendKey, String currency});

/// One group in the batch: our member ids there and what it shows between us (positive = they owe me).
typedef SettleAllGroup = ({
  String groupId,
  String name,
  String type,
  String meId,
  String friendMemberId,
  int owed,
});

/// The groups [friend] and I can settle in [currency] at once: every shared group (and our direct group)
/// with a balance between us in it, as its Balances tab shows it. Archived groups are read-only on the
/// server (`GROUP_ARCHIVED`), so they stay out (their rows still show on the friend page).
List<SettleAllGroup> settleAllGroups(Friend friend, String currency) => [
  for (final link in friend.links)
    if (link.group.archivedAt == null)
      if (_owedIn(link, currency) case final owed when owed != 0)
        (
          groupId: link.group.id,
          name: link.group.name,
          type: link.group.type,
          meId: link.meId,
          friendMemberId: link.friendMemberId,
          owed: owed,
        ),
];

int _owedIn(FriendLink link, String currency) => link.transfers
    .where((t) => t.currency == currency)
    .fold<int>(
      0,
      (a, t) =>
          a + (t.transfer.from == link.friendMemberId ? t.transfer.amount : -t.transfer.amount),
    );

/// An "Everything with Asha · ₹455 · 2 groups" row of the friend's Settle up sheet.
typedef SettleAllOption = ({String currency, int net, int groups});

/// One option per currency where [friend] and I have balances in two or more groups that do not cancel out
/// ([first] currency first, then alphabetical). Currencies are never mixed (rule 4).
List<SettleAllOption> settleAllOptions(Friend friend, {String first = 'INR'}) {
  final codes = {
    for (final link in friend.links)
      for (final t in link.transfers) t.currency,
  };
  return [
    for (final c in orderCurrencies(codes, first))
      if (settleAllGroups(friend, c) case final groups when groups.length > 1)
        if (batchNet(groups.map(_owed)) case final net when net != 0)
          (currency: c, net: net, groups: groups.length),
  ];
}

GroupOwed _owed(SettleAllGroup g) => (groupId: g.groupId, owed: g.owed);

/// The batch form: one amount (prefilled with the whole balance), one date, method and note; saving writes one
/// payment per group.
class SettleAllDraft {
  const SettleAllDraft({
    required this.friendKey,
    required this.friendName,
    required this.me,
    required this.friend,
    required this.currency,
    required this.groups,
    required this.date,
    this.friendUserId,
    this.othersOpen = false,
    this.amountText = '',
    this.amountEdited = false,
    this.method = 'cash',
    this.note = '',
  });

  final String friendKey;
  final String friendName;

  /// The friend's account (their UPI ID), null for a name-only friend.
  final String? friendUserId;

  /// Our member rows in the first group (avatars).
  final LocalMember me;
  final LocalMember friend;
  final String currency;
  final List<SettleAllGroup> groups;

  /// Something stays open between us after the whole batch (another currency, an archived group).
  final bool othersOpen;
  final String amountText;
  final bool amountEdited;
  final String method;
  final DateTime date;
  final String note;

  List<GroupOwed> get owedByGroup => [for (final g in groups) _owed(g)];

  /// Overall in [currency], positive = they owe me.
  int get net => batchNet(owedByGroup);

  /// They pay me (else I pay them).
  bool get friendPays => net > 0;

  /// What settles everything.
  int get total => net.abs();

  AmountResult get amountResult => AmountExpression.evaluate(amountText, currency);

  int? get amount => switch (amountResult) {
    AmountOk(:final minor) => minor,
    _ => null,
  };

  /// More than the whole balance: blocked inline (a batch never pays a group more than it owes).
  bool get over => (amount ?? 0) > total;

  bool get noteTooLong => note.trim().length > maxPaymentNote;

  bool get canSave => amount != null && !over && !noteTooLong;

  /// The payments a save writes (empty while the form is not valid).
  List<BatchPart> get parts => canSave ? allocateBatch(owedByGroup, amount!) : const [];

  /// What this payment pays in [groupId] (0 = nothing).
  int partIn(String groupId) =>
      parts.where((p) => p.groupId == groupId).fold<int>(0, (a, p) => a + p.amount);

  /// Saving leaves us square in every currency.
  bool get settlesEverything => !othersOpen && amount == total;

  SettleAllDraft copyWith({
    String? amountText,
    bool? amountEdited,
    String? method,
    DateTime? date,
    String? note,
  }) => SettleAllDraft(
    friendKey: friendKey,
    friendName: friendName,
    friendUserId: friendUserId,
    me: me,
    friend: friend,
    currency: currency,
    groups: groups,
    othersOpen: othersOpen,
    date: date ?? this.date,
    amountText: amountText ?? this.amountText,
    amountEdited: amountEdited ?? this.amountEdited,
    method: method ?? this.method,
    note: note ?? this.note,
  );
}

/// [minor] as amount-field text, money style ("455.50", whole amounts "455").
String owedFieldText(int minor, String currency) {
  if (minor <= 0) return '';
  final decimals = Currencies.exponentOf(currency);
  final text = ScaledInput.format(minor, decimals);
  final dot = text.indexOf('.');
  return dot < 0 ? text : text.padRight(dot + 1 + decimals, '0');
}

Duration? _noRetry(int retryCount, Object error) => null;

final settleAllProvider = AsyncNotifierProvider.autoDispose
    .family<SettleAllController, SettleAllDraft, SettleAllArgs>(
      SettleAllController.new,
      retry: _noRetry,
    );

/// Loads the friend's balances from this phone (one snapshot, like [SettleController]) and saves the batch
/// through the payments repository → outbox, one payment per group in allocation order (offline-first).
class SettleAllController extends AsyncNotifier<SettleAllDraft> {
  SettleAllController(this.args);

  final SettleAllArgs args;

  @override
  Future<SettleAllDraft> build() async {
    final uid = ref.read(currentUserIdProvider);
    final ledgers = await ref.read(ledgerRepositoryProvider).loadAll();
    final profiles = await ref.read(friendsRepositoryProvider).watchProfiles().first;
    final friend = friendsOf(
      ledgers,
      uid,
      profileNames: {for (final p in profiles.values) p.id: p.displayName},
    ).where((f) => f.key == args.friendKey).firstOrNull;
    if (friend == null) throw const SettleNotFound();
    final groups = settleAllGroups(friend, args.currency);
    if (groups.isEmpty || batchNet(groups.map(_owed)) == 0) throw const SettleNotFound();
    final first = friend.links.firstWhere((l) => l.group.id == groups.first.groupId);
    LocalMember member(String id) => first.ledger.members.firstWhere((m) => m.id == id);
    final inBatch = {for (final g in groups) g.groupId};
    final othersOpen = friend.links.any(
      (l) => l.transfers.any((t) => t.currency != args.currency || !inBatch.contains(l.group.id)),
    );
    final today = ref.read(clockProvider).today(); // the phone's calendar day (S-413)
    final draft = SettleAllDraft(
      friendKey: friend.key,
      friendName: friend.name,
      friendUserId: friend.userId,
      me: member(first.meId),
      friend: member(first.friendMemberId),
      currency: args.currency,
      groups: groups,
      othersOpen: othersOpen,
      date: DateTime(today.year, today.month, today.day),
    );
    return draft.copyWith(amountText: owedFieldText(draft.total, draft.currency));
  }

  void _set(SettleAllDraft Function(SettleAllDraft d) f) {
    final d = state.value;
    if (d != null) state = AsyncData(f(d));
  }

  void setAmountText(String text) => _set((d) => d.copyWith(amountText: text, amountEdited: true));

  /// Fills in the whole balance.
  void useTotal() =>
      _set((d) => d.copyWith(amountText: owedFieldText(d.total, d.currency), amountEdited: true));

  void setMethod(String method) => _set((d) => d.copyWith(method: method));

  void setDate(DateTime date) => _set((d) => d.copyWith(date: date));

  void setNote(String note) => _set((d) => d.copyWith(note: note));

  /// Writes one payment per group (offline-first, queued in this order) in ONE local transaction, so the
  /// batch lands whole or not at all (S-405, `LocalWriter.writeAll`); returns their ids, or null when the
  /// form is not valid. Every part is a valid payment on its own (≤ what its group owes).
  Future<List<String>?> save() async {
    final d = state.value;
    if (d == null || !d.canSave) return null;
    final repo = ref.read(paymentsRepositoryProvider);
    final createdAt = ref.read(clockProvider).now().toUtc().toIso8601String();
    final note = d.note.trim();
    // One push for the friend per batch, not one per group (W2-Y, 0030): the server only reads this id.
    final batch = d.parts.length > 1 ? newId() : null;
    return repo.saveAll([
      for (final p in d.parts)
        if (d.groups.firstWhere((g) => g.groupId == p.groupId) case final g)
          (
            groupId: g.groupId,
            data: {
              'from_member': p.friendPays ? g.friendMemberId : g.meId,
              'to_member': p.friendPays ? g.meId : g.friendMemberId,
              'amount': p.amount,
              'currency': d.currency,
              'date': isoDate(d.date),
              'method': d.method,
              'note': note.isEmpty ? null : note,
              'created_at': createdAt,
              'batch_id': ?batch,
            },
          ),
    ]);
  }
}
