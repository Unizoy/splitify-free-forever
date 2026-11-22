import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/sync/background_sync.dart';
import 'package:splitify/data/sync/sync_triggers.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';

final _log = Logger('sync');

/// The user's live groups, for the Realtime topics (`group:<id>`).
final _groupIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref
      .watch(groupsRepositoryProvider)
      .watchAll()
      .map((gs) => {for (final LocalGroup g in gs) g.id}),
);

/// Wraps the signed-in shell (04 §1, §8; S-046/S-160): syncs at start, when the network comes back, when the
/// app returns to the foreground and on a Realtime nudge for the user's groups; keeps the WorkManager jobs
/// scheduled (one-off when the app goes to the background with changes waiting) and answers WorkManager
/// runs in this process; shows the one-time "newer edit was kept" snackbar (04 §3, T4).
class SyncBinding extends ConsumerStatefulWidget {
  const SyncBinding({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncBinding> createState() => _SyncBindingState();
}

class _SyncBindingState extends ConsumerState<SyncBinding> {
  late final SyncTriggers _triggers;
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<int> _lost;
  ForegroundSyncPort? _port;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(syncEngineProvider);
    _triggers = SyncTriggers(
      sync: engine.sync,
      online: ref.read(networkStatusProvider).watch(),
      nudges: ref.read(changeNudgesProvider).nudges,
    );
    _lifecycle = AppLifecycleListener(onResume: _triggers.onResume, onPause: _paused);
    _lost = engine.superseded.listen(_showLost);
    final background = ref.read(backgroundSyncProvider);
    if (background is WorkmanagerBackgroundSync) _port = ForegroundSyncPort(engine.sync);
    ref.listenManual(_groupIdsProvider, (_, next) {
      final ids = next.value;
      if (ids == null) return;
      unawaited(
        ref
            .read(changeNudgesProvider)
            .watchGroups(ids)
            .catchError((Object e) => _log.warning('realtime topics: $e')),
      );
    }, fireImmediately: true);
    unawaited(_start());
  }

  Future<void> _start() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.id;
    try {
      if (uid != null && await ref.read(syncRepositoryProvider).adoptOwner(uid)) {
        await ref.read(mediaFilesProvider).wipe();
      }
    } on Object catch (e) {
      _log.warning('owner check failed: $e');
    }
    if (!mounted) return;
    unawaited(ref.read(backgroundSyncProvider).start());
    unawaited(ref.read(syncEngineProvider).sync());
  }

  /// Going to the background with changes waiting: let WorkManager send them once a network is there.
  void _paused() {
    final repo = ref.read(syncRepositoryProvider);
    final background = ref.read(backgroundSyncProvider);
    unawaited(
      repo
          .hasWaiting()
          .then((waiting) => waiting ? background.syncWhenOnline() : null)
          .catchError((Object e) => _log.warning('pause check failed: $e')),
    );
  }

  void _showLost(int count) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(key: const Key('sync-superseded'), content: Text(l.syncSuperseded(count))),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _port?.close();
    unawaited(_lost.cancel());
    unawaited(_triggers.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
