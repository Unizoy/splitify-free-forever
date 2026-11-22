import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/add_friend_sheet.dart';
import 'package:splitify/features/friends/presentation/friend_widgets.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show SectionLabel;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Friends tab (`/friends`, 438 list + 646 rows, #2/#16): a search pill in the hero, amber "Add friend
/// expense", and everyone I share a group with, each with the total with them per currency (positive =
/// they owe me). Local and instant; "not synced yet" while anything is pending (rule 3).
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final async = ref.watch(friendsProvider);
    final all = async.value;
    final unsynced = ref.watch(anyUnsyncedProvider).value ?? false;
    final first = ref.watch(profileProvider).value?.defaultCurrency ?? 'INR';
    final query = _search.text;
    final shown = all == null ? null : searchFriends(all, query);

    final Widget content;
    if (all == null && async.hasError) {
      content = EmptyState(icon: AppIcons.warning, title: l.balLoadError);
    } else if (shown == null) {
      content = const FriendsSkeleton();
    } else if (all!.isEmpty) {
      content = EmptyState(
        icon: AppIcons.friends,
        title: l.emptyFriendsTitle,
        message: l.emptyFriendsBody,
      );
    } else if (shown.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
        child: Text(
          l.friendsNoMatch(query.trim()),
          key: const Key('friends-no-match'),
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: c.textSecondary),
        ),
      );
    } else {
      content = Column(
        key: const Key('friends-list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shown.length; i++)
            FriendRow(friend: shown[i], firstCurrency: first, showDivider: i < shown.length - 1),
        ],
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: HeroHeader(
            title: l.friendsHero,
            art: (seed: 'friends-home', family: CoverFamily.couple),
            child: _SearchPill(controller: _search, onChanged: (_) => setState(() {})),
          ),
          bottom: OverlapSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(
                  all == null ? l.friendsSection : '${l.friendsSection}\u00A0· ${all.length}',
                  trailing: unsynced ? const SyncMarker() : null,
                ),
                const SizedBox(height: AppSpacing.s4),
                PillButton(
                  key: const Key('friends-add-expense'),
                  label: l.addFriendExpense,
                  icon: AppIcons.add,
                  variant: PillVariant.money,
                  onPressed: () => unawaited(showAddFriendExpense(context, ref)),
                ),
                const SizedBox(height: AppSpacing.s4),
                content,
                const SizedBox(height: AppSpacing.navReserve),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill with a search field (438 search pill).
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
          child: Row(
            children: [
              Icon(AppIcons.search, color: c.textSecondary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: TextField(
                  key: const Key('friends-search'),
                  controller: controller,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: context.text.body.w(500).copyWith(color: c.textPrimary),
                  decoration: pillInputDecoration(
                    context: context,
                    hint: l.friendsSearchHint,
                    style: context.text.body,
                    hintStyle: context.text.body.w(500).copyWith(color: c.textSecondary),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  key: const Key('friends-search-clear'),
                  tooltip: l.cancelLabel,
                  icon: Icon(AppIcons.close, color: c.textSecondary, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
