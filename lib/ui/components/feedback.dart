import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';

/// Short "Coming soon" snackbar for actions a later phase builds.
void showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).comingSoon),
        duration: const Duration(seconds: 2),
      ),
    );
}
