import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Shared layout of the sign-in pages (532): back arrow, the mark, a centred
/// serif question, a short hint, then the page's options.
class AuthPage extends StatelessWidget {
  const AuthPage({
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
    this.leading,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;

  /// Replaces the brand mark above the title (e.g. an avatar).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        leading: onBack == null
            ? null
            : IconButton(tooltip: l.back, icon: const Icon(AppIcons.back), onPressed: onBack),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s2,
            AppSpacing.screen,
            AppSpacing.s8,
          ),
          children: [
            Center(child: leading ?? const BrandMark(size: 44, tile: true)),
            const SizedBox(height: AppSpacing.s6),
            Semantics(
              header: true,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: AppText.maxSerifScale,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.text.heroDisplay.copyWith(
                    color: c.textPrimary,
                    fontSize: 38,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Inline error / info line under a field or button.
class AuthMessage extends StatelessWidget {
  const AuthMessage(this.text, {this.error = true, super.key});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s3),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.text.bodySmall.copyWith(color: error ? c.oweText : c.textSecondary),
        ),
      ),
    );
  }
}
