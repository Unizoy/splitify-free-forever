import 'package:go_router/go_router.dart';
import 'package:splitify/features/app_lock/presentation/security_screen.dart';
import 'package:splitify/features/widget/presentation/widget_settings_screen.dart';

/// Account → Security pages (X2 app lock, X3 home-screen widget), on the root navigator.
abstract final class SecurityRoutes {
  static const security = '/account/security';
  static const widget = '/account/widget';
}

List<RouteBase> securityRoutes() => [
  GoRoute(path: SecurityRoutes.security, builder: (context, state) => const SecurityScreen()),
  GoRoute(path: SecurityRoutes.widget, builder: (context, state) => const WidgetSettingsScreen()),
];
