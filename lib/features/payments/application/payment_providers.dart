import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

/// Payment methods (#25), in chip order.
const paymentMethods = ['cash', 'upi', 'bank', 'other'];

/// One payment as the list and the detail screen show it.
final class PaymentView {
  const PaymentView({
    required this.payment,
    required this.names,
    this.meId,
    this.userNames = const {},
  });

  final LocalPayment payment;

  /// Display names by member id (removed members too).
  final Map<String, String> names;

  /// The viewer's member id in this group, if any.
  final String? meId;

  /// Display names by account id (who recorded the payment; final QA: the detail said only "Added on").
  final Map<String, String> userNames;

  String nameOf(String memberId) => names[memberId] ?? '';

  bool get iPaid => meId != null && payment.fromMember == meId;
  bool get iReceived => meId != null && payment.toMember == meId;
  bool get unsynced => payment.syncState != SyncState.synced;

  /// Soft-deleted (rule 9): the detail page shows it read-only with Restore (D-034 B2).
  bool get deleted => payment.deletedAt != null;
}

List<PaymentView> paymentViews(
  List<LocalPayment> payments,
  List<LocalMember> members,
  String? userId,
) {
  final names = {for (final m in members) m.id: m.displayName};
  final userNames = {
    for (final m in members)
      if (m.userId != null) m.userId!: m.displayName,
  };
  final meId = members
      .where(
        (m) => userId != null && m.userId == userId && m.deletedAt == null && m.status == 'active',
      )
      .map((m) => m.id)
      .firstOrNull;
  return [
    for (final p in payments)
      PaymentView(payment: p, names: names, meId: meId, userNames: userNames),
  ];
}

final _groupPaymentsProvider = StreamProvider.autoDispose.family<List<LocalPayment>, String>(
  (ref, groupId) => ref.watch(paymentsRepositoryProvider).watchForGroup(groupId),
);

final _allMembersProvider = StreamProvider.autoDispose.family<List<LocalMember>, String>(
  (ref, groupId) => ref.watch(expensesRepositoryProvider).watchAllMembers(groupId),
);

final _paymentProvider = StreamProvider.autoDispose.family<LocalPayment?, String>(
  (ref, id) => ref.watch(ledgerRepositoryProvider).watchPayment(id),
);

/// The group's live payments (slim rows in the Expenses tab), newest first.
final groupPaymentViewsProvider = Provider.autoDispose
    .family<AsyncValue<List<PaymentView>>, String>((ref, groupId) {
      final p = ref.watch(_groupPaymentsProvider(groupId));
      final m = ref.watch(_allMembersProvider(groupId));
      for (final v in [p, m]) {
        if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
      }
      if (!p.hasValue || !m.hasValue) return const AsyncLoading();
      return AsyncData(
        paymentViews(p.requireValue, m.requireValue, ref.watch(currentUserIdProvider)),
      );
    });

/// One payment (detail screen), deleted ones too (opened from Activity they show Restore, D-034 B2); data(null)
/// when it is not on this phone.
final paymentViewProvider = Provider.autoDispose.family<AsyncValue<PaymentView?>, String>((
  ref,
  id,
) {
  final p = ref.watch(_paymentProvider(id));
  if (!p.hasValue) return p.hasError ? AsyncError(p.error!, p.stackTrace!) : const AsyncLoading();
  final payment = p.value;
  if (payment == null) return const AsyncData(null);
  final uid = ref.watch(currentUserIdProvider);
  return ref
      .watch(_allMembersProvider(payment.groupId))
      .whenData((m) => paymentViews([payment], m, uid).first);
});

/// Delete (soft, with undo) and restore (rule 9).
class PaymentActions {
  PaymentActions(this._ref);

  final Ref _ref;

  Future<void> delete(LocalPayment p) =>
      _ref.read(paymentsRepositoryProvider).delete(p.id, p.groupId);

  Future<void> restore(LocalPayment p) =>
      _ref.read(paymentsRepositoryProvider).restore(p.id, p.groupId);
}

final paymentActionsProvider = Provider<PaymentActions>(PaymentActions.new);
