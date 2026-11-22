import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/groups/application/groups_providers.dart' show syncNowProvider;
import 'package:splitify/ui/theme/theme.dart';

/// Pull to refresh on the main lists (Groups, a group, Friends, Activity; final QA S-259): pulling down sends
/// waiting changes and fetches what the others changed, like returning to the app does. Without network the
/// indicator just closes; the offline note and "not synced yet" markers already say why. The scroll view
/// inside needs [AlwaysScrollableScrollPhysics] so short pages can be pulled too.
class SyncRefresh extends ConsumerWidget {
  const SyncRefresh({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return RefreshIndicator(
      key: const Key('sync-refresh'),
      edgeOffset: MediaQuery.paddingOf(context).top,
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: () => ref.read(syncNowProvider)().catchError((Object _) {}),
      child: child,
    );
  }
}
