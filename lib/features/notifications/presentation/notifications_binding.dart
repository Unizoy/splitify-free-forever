import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/notifications/presentation/notification_settings_screen.dart';
import 'package:splitify/features/notifications/presentation/notifications_screen.dart';
import 'package:splitify/features/notifications/presentation/push_pre_prompt.dart';

/// Notification routes (07 §1): the bell list and its settings page; spread into the app router.
List<RouteBase> notificationRoutes() => [
  GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
  GoRoute(
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
    unawaited(actions.refresh());
    final push = ref.read(pushMessagingProvider);
    if (!push.available) return;
    unawaited(ref.read(pushRegistrationProvider).register());
    _subs
      ..add(
        push.foreground.listen((m) {
          unawaited(push.show(m));
          unawaited(actions.refresh());
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
