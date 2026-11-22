import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/app_lock/application/app_lock_controller.dart';
import 'package:splitify/features/app_lock/presentation/lock_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';

/// Wraps the whole app (MaterialApp.router `builder`): feeds lifecycle changes to the lock, shows
/// the cover in the background and the lock screen above everything, asks for the phone's lock
/// as soon as the lock screen appears in the foreground, and swallows Back while locked.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  late final AppLifecycleListener _life;
  bool _prompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _life = AppLifecycleListener(
      onStateChange: (s) => ref.read(appLockProvider.notifier).onLifecycle(s),
    );
  }

  @override
  void dispose() {
    _life.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Registered before the router's back dispatcher, so Back can't pop pages under the lock screen.
  @override
  Future<bool> didPopRoute() async => ref.read(appLockProvider).locked;

  void _unlock() {
    final reason = AppLocalizations.of(context).lockReason;
    unawaited(ref.read(appLockProvider.notifier).unlock(reason));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appLockProvider);
    final foreground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden;
    if (!s.locked) {
      _prompted = false;
    } else if (!_prompted && !s.covered && foreground) {
      // Once per lock: a cancelled prompt leaves the Unlock button, it doesn't nag.
      _prompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(appLockProvider).locked) _unlock();
      });
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: s.locked,
          child: TickerMode(enabled: !s.locked, child: widget.child),
        ),
        if (s.locked) LockScreen(state: s, onUnlock: _unlock) else if (s.covered) const LockCover(),
      ],
    );
  }
}
