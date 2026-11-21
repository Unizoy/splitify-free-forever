import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/l10n/app_localizations.dart';

/// App router. Phase 02 replaces the placeholder with the tab shell.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => const PlaceholderHome())],
  );
});

/// Temporary home screen.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          AppLocalizations.of(context).homePlaceholder,
          key: const Key('placeholder-home'),
        ),
      ),
    );
  }
}
