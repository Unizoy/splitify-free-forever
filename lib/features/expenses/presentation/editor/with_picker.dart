import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/groups_remote.dart' show GroupFailure, GroupFailureCode;
import 'package:splitify/features/balances/application/balances_providers.dart'
    show allLedgersProvider;
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show currentUserIdProvider;
import 'package:splitify/features/groups/presentation/group_visuals.dart'
    show GroupThumb, SectionLabel, showGroupMessage;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// One place a new expense can go (D-033 "With you and"): a group, or a friend through our direct group.
class WithTarget {
  const WithTarget({
    required this.group,
    required this.name,
    required this.lastUsed,
    this.friendSeed,
    this.friendTint,
  });

  final LocalGroup group;

  /// The group's name, or the friend's name for our direct group.
  final String name;

  /// Newest expense, payment or the group's own change: recent ones come first.
  final DateTime lastUsed;

  /// The friend's member id (avatar colour) when this is our direct group.
  final String? friendSeed;
  final int? friendTint;

  String get groupId => group.id;

  bool get isFriend => group.type == 'direct';
}

DateTime _at(String? iso) => (iso == null ? null : DateTime.tryParse(iso)) ?? DateTime(2000);

/// Every open group I am in, newest use first (D-033). Direct groups carry the friend's name and avatar.
final withTargetsProvider = Provider.autoDispose<List<WithTarget>?>((ref) {
  final ledgers = ref.watch(allLedgersProvider).value;
  if (ledgers == null) return null;
  final uid = ref.watch(currentUserIdProvider);
  final profiles = ref.watch(profilesProvider).value ?? const <String, LocalProfile>{};
  final out = <WithTarget>[];
  for (final ledger in ledgers) {
    final g = ledger.group;
    if (g.archivedAt != null || g.deletedAt != null) continue;
    final active = [
      for (final m in ledger.members)
        if (m.deletedAt == null && m.status == 'active') m,
    ];
    if (uid != null && !active.any((m) => m.userId == uid)) continue;
    var last = _at(g.updatedAt ?? g.createdAt);
    for (final e in ledger.expenses.take(20)) {
      final t = _at(e.createdAt);
      if (t.isAfter(last)) last = t;
    }
    for (final p in ledger.payments.take(20)) {
      final t = _at(p.createdAt);
      if (t.isAfter(last)) last = t;
    }
    final friend = g.type == 'direct'
        ? active.where((m) => uid == null || m.userId != uid).firstOrNull
        : null;
    out.add(
      WithTarget(
        group: g,
        name: friend == null
            ? g.name
            : (profiles[friend.userId]?.displayName ?? friend.displayName),
        lastUsed: last,
        friendSeed: friend?.id,
        friendTint: friend?.tint,
      ),
    );
  }
  out.sort((a, b) {
    final byTime = b.lastUsed.compareTo(a.lastUsed);
    return byTime != 0 ? byTime : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
});

/// The round picture of a target: the group's cover, or the friend's avatar.
class WithThumb extends ConsumerWidget {
  const WithThumb({required this.target, this.size = 40, super.key});

  final WithTarget target;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = target;
    if (t.isFriend && t.friendSeed != null) {
      return Avatar(
        name: t.name,
        seed: t.friendSeed!,
        tint: t.friendTint,
        size: size >= 40 ? AvatarSize.s40 : AvatarSize.s32,
      );
    }
    return GroupThumb(group: t.group, size: size);
  }
}

/// Opens the "With you and" picker (D-033): a search field, recent groups (with covers) and friends, and
/// "Add <name> as a friend" for a new name. Returns the group the expense goes to, or null.
Future<String?> showWithPicker(BuildContext context, {String? selected}) {
  final l = AppLocalizations.of(context);
  final container = ProviderScope.containerOf(context);
  return showAppSheet<String>(
    context,
    title: l.expWithPickTitle,
    // The sheet lives on the root navigator: it reads the editor's (maybe overridden) providers.
    builder: (sheet) => UncontrolledProviderScope(
      container: container,
      child: WithPicker(selected: selected, onPicked: (id) => Navigator.of(sheet).pop(id)),
    ),
  );
}

/// The picker's content (also used by goldens inside an [AppSheet]).
class WithPicker extends ConsumerStatefulWidget {
  const WithPicker({required this.onPicked, this.selected, super.key});

  final String? selected;
  final ValueChanged<String> onPicked;

  @override
  ConsumerState<WithPicker> createState() => _WithPickerState();
}

class _WithPickerState extends ConsumerState<WithPicker> {
  final _query = TextEditingController();

  /// A friend's group is being found or made (S-120: once online for a linked friend).
  String? _busy;

  /// Without a search: this many recent targets.
  static const _recent = 6;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _friend(Friend f) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = f.key);
    try {
      final id = await ref.read(friendActionsProvider).expenseGroupFor(f);
      if (mounted) widget.onPicked(id);
    } on GroupFailure catch (e) {
      if (!mounted) return;
      setState(() => _busy = null);
      showGroupMessage(
        context,
        e.code == GroupFailureCode.offline
            ? l.friendNeedsInternet(f.name)
            : l.friendStartFailed(f.name),
      );
    }
  }

  Future<void> _newFriend(String name) async {
    setState(() => _busy = 'new');
    final made = await ref.read(friendActionsProvider).addNameOnlyFriend(name);
    if (mounted) widget.onPicked(made.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final q = _query.text.trim().toLowerCase();
    final targets = ref.watch(withTargetsProvider);
    final friends = ref.watch(friendsProvider).value ?? const <Friend>[];
    final direct = {for (final t in targets ?? const <WithTarget>[]) t.groupId};
    final matches = [
      for (final t in targets ?? const <WithTarget>[])
        if (q.isEmpty || t.name.toLowerCase().contains(q)) t,
    ];
    final shown = q.isEmpty ? matches.take(_recent).toList() : matches;
    // Friends we share only a normal group with (no direct group yet): picking one finds or makes it.
    final others = [
      for (final f in searchFriends(friends, q))
        if (f.directGroupId == null || !direct.contains(f.directGroupId)) f,
    ];
    final exact =
        matches.any((t) => t.name.toLowerCase() == q) ||
        others.any((f) => f.name.toLowerCase() == q);
    final typed = _query.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        key: const Key('with-picker'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchBox(controller: _query, onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.s4),
          if (targets == null)
            const Shimmer(child: Column(children: [SkeletonRow(), SkeletonRow(lineWidth: 0.4)]))
          else ...[
            if (shown.isNotEmpty) ...[
              SectionLabel(q.isEmpty ? l.expWithRecent : l.expWithGroups),
              for (final t in shown)
                _Row(
                  key: Key('with-target-${t.groupId}'),
                  leading: WithThumb(target: t),
                  title: t.name,
                  subtitle: t.isFriend ? l.expWithFriendLabel : null,
                  selected: t.groupId == widget.selected,
                  onTap: _busy == null ? () => widget.onPicked(t.groupId) : null,
                ),
            ],
            if (others.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s3),
              SectionLabel(l.expWithFriends),
              for (final f in others)
                _Row(
                  key: Key('with-friend-${f.key}'),
                  leading: Avatar(name: f.name, seed: f.seed, tint: f.tint),
                  title: f.name,
                  busy: _busy == f.key,
                  onTap: _busy == null ? () => unawaited(_friend(f)) : null,
                ),
            ],
            if (typed.isNotEmpty && !exact) ...[
              const SizedBox(height: AppSpacing.s3),
              _Row(
                key: const Key('with-add-friend'),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                  child: Icon(AppIcons.userPlus, size: 20, color: c.onPrimaryContainer),
                ),
                title: l.expWithAddFriend(typed),
                subtitle: l.expWithAddFriendHint,
                busy: _busy == 'new',
                onTap: _busy == null ? () => unawaited(_newFriend(typed)) : null,
              ),
            ],
            if (shown.isEmpty && others.isEmpty && typed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                child: Text(
                  l.expWithNothingYet,
                  key: const Key('with-empty'),
                  style: context.text.body.copyWith(color: c.textSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      decoration: BoxDecoration(
        color: c.bgSubtle,
        borderRadius: AppRadii.allPill,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(AppIcons.search, size: 20, color: c.textSecondary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: TextField(
              key: const Key('with-search'),
              controller: controller,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
              style: context.text.body,
              cursorColor: c.primary,
              decoration: pillInputDecoration(
                context: context,
                hint: l.expWithSearchHint,
                style: context.text.body,
                hintStyle: context.text.body.copyWith(color: c.textTertiary),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact picker row: picture, name (+ a short caption), a check when it is the current choice.
class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.busy = false,
    super.key,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: [title, ?subtitle].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.all16,
        scale: AppMotion.rowPressScale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: Row(
              children: [
                leading,
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: context.text.body.w(600)),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: context.text.bodySmall.copyWith(color: c.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (busy)
                  DotsPulse(color: c.primary)
                else if (selected)
                  Icon(AppIcons.check, size: 20, color: c.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
