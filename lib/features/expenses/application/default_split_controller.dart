import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';

/// Default split editor state (#35).
final class DefaultSplitState {
  const DefaultSplitState({required this.groupName, required this.members, required this.split});

  final String groupName;
  final List<EditorMember> members;
  final SplitDraft split;

  /// Checked against 100.00 units: percent must reach 100 %, shares need someone.
  SplitCheck get check => split.check(10000);

  bool get canSave => check is SplitReady;

  DefaultSplitState withSplit(SplitDraft s) =>
      DefaultSplitState(groupName: groupName, members: members, split: s);
}

final defaultSplitProvider = AsyncNotifierProvider.autoDispose
    .family<DefaultSplitController, DefaultSplitState, String>(DefaultSplitController.new);

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
    final preset = DefaultSplit.decode(group.defaultSplit)?.resolve(ids);
    return DefaultSplitState(
      groupName: group.name,
      members: [
        for (final m in sorted)
          (id: m.id, name: m.displayName, isMe: uid != null && m.userId == uid),
      ],
      split: SplitDraft.initial(ids, 2, preset: preset),
    );
  }

  void select(SplitKind kind) => _set((s) => s.switchTo(kind, total: 10000));

  void edit(SplitDraft Function(SplitDraft s) change) => _set(change);

  void _set(SplitDraft Function(SplitDraft s) change) {
    final s = state.value;
    if (s != null) state = AsyncData(s.withSplit(change(s.split)));
  }

  /// Saves through the groups repository (outbox); equal clears the default. False when not valid.
  Future<bool> save() async {
    final s = state.value;
    if (s == null || !s.canSave) return false;
    final split = s.split;
    final value = split.kind == SplitKind.equal
        ? null
        : DefaultSplit(split.kind, split.values!).toJson();
    await ref.read(groupsRepositoryProvider).update(groupId, {'default_split': value});
    return true;
  }
}
