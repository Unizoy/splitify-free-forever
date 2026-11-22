import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Router error page (final QA, S-250): an old, mistyped or foreign `splitify://` link no longer shows
/// go_router's red debug page with a dead "Go to home page" button; it explains and leads to the Groups tab
/// (signed out, the auth gate sends that on to the welcome screen).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: EmptyState(
              key: const Key('not-found'),
              icon: AppIcons.warning,
              title: l.linkNotFoundTitle,
              message: l.linkNotFoundBody,
              actions: [
                PillButton(
                  key: const Key('not-found-home'),
                  label: l.linkNotFoundAction,
                  icon: AppIcons.groups,
                  onPressed: () => context.go('/groups'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
