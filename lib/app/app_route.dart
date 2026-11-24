import 'package:flutter/material.dart' show MaterialPage;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Every app page as a Flutter [MaterialPage] (S-288), so the theme's [PageTransitionsTheme] runs on every
/// push and pop: the shared-axis move (280 ms in, 240 ms back; none when animations are removed, S-262),
/// Hero flights (group card → group page, expense icon → detail) and the back gesture.
///
/// go_router 18 decides its default page by looking for package `material_ui`'s `MaterialApp`; the app uses
/// Flutter's, so plain `builder:` routes would be `NoTransitionPage`s that appear without any motion.
Page<void> appPage(GoRouterState state, Widget child) => MaterialPage<void>(
  key: state.pageKey,
  name: state.name ?? state.path,
  restorationId: state.pageKey.value,
  child: child,
);

/// A [GoRoute] whose [builder] is shown in an [appPage]. Use it for every route in the app
/// (`test/app/app_route_test.dart` checks the router).
class AppRoute extends GoRoute {
  AppRoute({
    required super.path,
    super.name,
    GoRouterWidgetBuilder? builder,
    super.parentNavigatorKey,
    super.redirect,
    super.onExit,
    super.routes,
  }) : super(
         pageBuilder: builder == null
             ? null
             : (context, state) => appPage(state, builder(context, state)),
       );
}
