import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';

/// Default split editor state (#35), with the default payer (W2-X P-10; null = whoever adds it).
final class DefaultSplitState {
  const DefaultSplitState({
    required this.groupName,
    required this.members,
    required this.split,
    this.payer,
  });

  final String groupName;
  final List<EditorMember> members;
  final SplitDraft split;
  final String? payer;

  /// Checked against 100.00 units: percent must reach 100 %, shares need someone.
  SplitCheck get check => split.check(10000);

  bool get canSave => check is SplitReady;

  DefaultSplitState withSplit(SplitDraft s) =>
      DefaultSplitState(groupName: groupName, members: members, split: s, payer: payer);

  DefaultSplitState withPayer(String? id) =>
      DefaultSplitState(groupName: groupName, members: members, split: split, payer: id);
}

/// The group default an expense draft can become ("Save as group default" in the paid/split sheet, W2-X
/// P-10): its one payer and its split when that is equal between everyone, percentages or shares; null when the
/// split can't be a default (exact amounts, adjustments, items, equal between only some) or several paid.
DefaultSplit? defaultFromDraft(ExpenseDraft d) {
  if (d.multiplePayers || d.split.isItems || !DefaultSplit.kinds.contains(d.split.kind))
    return null;
  final payer = d.payerId;
  if (payer == null) return null;
  final active = [for (final m in d.members) m.id];
  final split = d.split;
  final DefaultSplit out;
  if (split.kind == SplitKind.equal) {
    if (!active.every(split.included.contains)) return null;
    out = DefaultSplit(SplitKind.equal, const {}, payer);
  } else {
    final values = split.values;
    if (values == null) return null;
    out = DefaultSplit(split.kind, {for (final id in active) id: values[id] ?? 0}, payer);
  }
  return out.resolve(active) == null ? null : out;
}

/// Saves [d]'s payer and split as its group's default (outbox); false when it can't be one.
Future<bool> saveDraftAsDefault(Ref ref, ExpenseDraft d) async {
  final def = defaultFromDraft(d);
  if (def == null || !d.hasGroup) return false;
  await ref.read(groupsRepositoryProvider).update(d.groupId, {'default_split': def.toJson()});
  return true;
}

/// [saveDraftAsDefault] for widgets.
final saveDraftAsDefaultProvider = Provider<Future<bool> Function(ExpenseDraft d)>(
  (ref) =>
      (d) => saveDraftAsDefault(ref, d),
);

final defaultSplitProvider = AsyncNotifierProvider.autoDispose
    .family<DefaultSplitController, DefaultSplitState, String>(
      DefaultSplitController.new,
      retry: (retryCount, error) => null,
    );

/// Group settings → Default split: choose equal, percent or shares; new expenses start from it (#35).
class DefaultSplitController extends AsyncNotifier<DefaultSplitState> {
  DefaultSplitController(this.groupId);

  final String groupId;

  @override
  Future<DefaultSplitState> build() async {
    final group = await ref.read(groupsRepositoryProvider).watchOne(groupId).first;
    if (group == null) throw const ExpenseNotFound();
    final members = await ref.read(membersRepositoryProvider).watchForGroup(groupId).first;
    final sorted = [...members]
      ..sort((a, b) {
        final p = a.position.compareTo(b.position);
        return p != 0 ? p : a.id.compareTo(b.id);
      });
    final ids = [for (final m in sorted) m.id];
    final uid = ref.read(currentUserIdProvider);
    final stored = DefaultSplit.decode(group.defaultSplit);
    final preset = stored?.resolve(ids);
    return DefaultSplitState(
      payer: stored?.payerIn(ids),
      groupName: group.name,
      members: [
        for (final m in sorted)
          (id: m.id, name: m.displayName, isMe: uid != null && m.userId == uid),
      ],
      split: SplitDraft.initial(ids, 2, preset: preset),
    );
  }

  void select(SplitKind kind) => _set((s) => s.switchTo(kind, total: 10000));

  /// The default payer (null = whoever adds the expense).
  void setPayer(String? id) {
    final s = state.value;
    if (s != null) state = AsyncData(s.withPayer(id));
  }

  void edit(SplitDraft Function(SplitDraft s) change) => _set(change);

  void _set(SplitDraft Function(SplitDraft s) change) {
    final s = state.value;
    if (s != null) state = AsyncData(s.withSplit(change(s.split)));
  }

  /// Saves through the groups repository (outbox); equal with no default payer clears the default. False
  /// when not valid.
  Future<bool> save() async {
    final s = state.value;
    if (s == null || !s.canSave) return false;
    final split = s.split;
    final def = DefaultSplit(
      split.kind,
      split.kind == SplitKind.equal ? const {} : split.values!,
      s.payer,
    );
    final value = def.isPlain ? null : def.toJson();
    await ref.read(groupsRepositoryProvider).update(groupId, {'default_split': value});
    return true;
  }
}
