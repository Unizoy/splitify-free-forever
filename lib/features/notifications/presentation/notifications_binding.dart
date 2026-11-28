import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/app/app_route.dart';
import 'package:splitify/core/platform/startup_gate.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/notifications/presentation/notification_settings_screen.dart';
import 'package:splitify/features/notifications/presentation/notifications_screen.dart';
import 'package:splitify/features/notifications/presentation/push_pre_prompt.dart';

/// Notification routes (07 §1): the bell list and its settings page; spread into the app router.
List<RouteBase> notificationRoutes() => [
  AppRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
  AppRoute(
    path: '/account/notifications',
    builder: (context, state) => const NotificationSettingsScreen(),
  ),
];

/// Wraps the signed-in tab shell: refreshes the bell now and after every sync, registers this phone's push
/// token, shows pushes that arrive while the app is open and opens the target of a tapped push.
class NotificationsBinding extends ConsumerStatefulWidget {
  const NotificationsBinding({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationsBinding> createState() => _NotificationsBindingState();
}

class _NotificationsBindingState extends ConsumerState<NotificationsBinding> {
  final _subs = <StreamSubscription<PushMessage>>[];

  @override
  void initState() {
    super.initState();
    final actions = ref.read(notificationActionsProvider);
    // The bell refresh and push wait for the first frame (S-456).
    StartupGate.run(() async {
      if (mounted) await actions.refresh();
    });
    // A request made while the shell was not on screen (joining from an invite link replaces the whole
    // stack, so this binding was gone): show the pre-prompt now (final QA; shown only once anyway).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(pushPrePromptRequestsProvider) > 0) {
        unawaited(maybeShowPushPrePrompt(context, ref));
      }
    });
    unawaited(_startPush());
  }

  Future<void> _startPush() async {
    final push = ref.read(pushMessagingProvider);
    await whenPushReady(push);
    if (!mounted || !push.available) return;
    final actions = ref.read(notificationActionsProvider);
    unawaited(ref.read(pushRegistrationProvider).register());
    _subs
      ..add(
        push.foreground.listen((m) {
          unawaited(push.show(m));
          unawaited(actions.refresh());
          // The push is about something new on the server: pull it now.
          unawaited(ref.read(syncRepositoryProvider).syncNow());
        }),
      )
      ..add(push.opened.listen(_open));
    unawaited(push.launchMessage().then((m) => m == null ? null : _open(m)));
  }

  void _open(PushMessage m) {
    final id = m.notificationId;
    final actions = ref.read(notificationActionsProvider);
    if (id != null) unawaited(actions.open(id));
    final route = notificationRoute(m.data);
    if (route != null && mounted) unawaited(GoRouter.of(context).push(route));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(notificationsAutoRefreshProvider)
      ..listen(
        pushPrePromptRequestsProvider,
        (_, _) => unawaited(maybeShowPushPrePrompt(context, ref)),
      );
    return widget.child;
  }
}
