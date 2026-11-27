import 'package:go_router/go_router.dart';
import 'package:splitify/app/app_route.dart';
import 'package:splitify/features/app_lock/presentation/security_screen.dart';

/// Account → Security page (X2 app lock), on the root navigator. The home-screen widget (X3) is a sheet
/// from the Account list since D-033; its old page link lands on Account.
abstract final class SecurityRoutes {
  static const security = '/account/security';
  static const widget = '/account/widget';
}

List<RouteBase> securityRoutes() => [
  AppRoute(path: SecurityRoutes.security, builder: (context, state) => const SecurityScreen()),
  AppRoute(path: SecurityRoutes.widget, redirect: (context, state) => '/account'),
];
