import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/device/capture_bridge.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart'
    show currentUserIdProvider;

/// Wraps the signed-in shell (phase 18b): imports what the bubble caught at start and on every resume, and
/// keeps the bubble's recent group/friend chips and theme in step with the app (like the home widget, X3).
class CaptureBinding extends ConsumerStatefulWidget {
  const CaptureBinding({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CaptureBinding> createState() => _CaptureBindingState();
}

class _CaptureBindingState extends ConsumerState<CaptureBinding> {
  late final AppLifecycleListener _life;
  StreamSubscription<Object?>? _writes;
  Timer? _chips;
  List<CaptureChip>? _lastChips;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _refresh);
    if (!ref.read(captureBridgeProvider).supported) return;
    _refresh();
    // Recent chips follow every write to the phone's database (debounced).
    _writes = ref.read(appDatabaseProvider).tableUpdates().listen((_) => _scheduleChips());
    _scheduleChips();
  }

  void _refresh() {
    if (!ref.read(captureBridgeProvider).supported) return;
    unawaited(ref.read(captureRepositoryProvider).importNow().catchError((Object _) => 0));
    ref.invalidate(capturePermissionsProvider);
  }

  void _scheduleChips() {
    _chips?.cancel();
    _chips = Timer(const Duration(milliseconds: 800), () async {
      final repo = ref.read(captureRepositoryProvider);
      final chips = await repo.recentChips(myUserId: ref.read(currentUserIdProvider));
      if (_same(chips, _lastChips)) return;
      _lastChips = chips;
      await repo.bridge.setRecents(chips);
    });
  }

  static bool _same(List<CaptureChip> a, List<CaptureChip>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _life.dispose();
    _chips?.cancel();
    unawaited(_writes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ThemeMode>(themeModeControllerProvider, (_, mode) {
      if (ref.read(captureBridgeProvider).supported) {
        unawaited(ref.read(captureSettingsProvider.notifier).theme(mode));
      }
    });
    return widget.child;
  }
}
