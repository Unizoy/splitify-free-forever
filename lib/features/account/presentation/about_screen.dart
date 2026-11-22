import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/config/app_info.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a web link in the browser; false when nothing could open it.
typedef LinkOpener = Future<bool> Function(Uri uri);

Future<bool> _openInBrowser(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    return false;
  }
}

/// How the About screen opens links (tests replace it).
final linkOpenerProvider = Provider<LinkOpener>((ref) => _openInBrowser);

/// About & licences (`/account/about`, phase 19 T7): generated cover hero with the brand tile, app name
/// and version; the project links (source code, privacy policy, report a problem, open-source licences)
/// and the credits for the bundled fonts, icons and exchange rates.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    Future<void> open(String url) async {
      final messenger = ScaffoldMessenger.of(context);
      final failed = l.aboutLinkFailed(url);
      final ok = await ref.read(linkOpenerProvider)(Uri.parse(url));
      if (!ok) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failed)));
      }
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: HeroHeader(
            art: (seed: 'splitify-about', family: CoverFamily.other),
            title: l.aboutHeroTitle,
            leading: HeroIconButton(
              icon: AppIcons.back,
              tooltip: l.back,
              onPressed: () => context.canPop() ? context.pop() : context.go('/account'),
            ),
            child: GlassCard(
              child: Row(
                children: [
                  const BrandMark(size: 48, tile: true),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.appTitle, style: context.text.title.copyWith(color: c.onHero)),
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          l.version(appVersion),
                          style: context.text.bodySmall.copyWith(color: c.onHeroMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottom: OverlapSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.aboutTagline, style: context.text.body.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpacing.s8),
                _Caps(l.aboutSectionProject),
                DashedListRow(
                  key: const Key('about-source'),
                  icon: AppIcons.link,
                  label: l.aboutSourceCode,
                  value: l.aboutSourceValue,
                  onTap: () => unawaited(open(repoUrl)),
                ),
                DashedListRow(
                  key: const Key('about-privacy'),
                  icon: AppIcons.shieldCheck,
                  label: l.aboutPrivacy,
                  onTap: () => unawaited(open(privacyUrl)),
                ),
                DashedListRow(
                  key: const Key('about-report'),
                  icon: AppIcons.chat,
                  label: l.aboutReport,
                  onTap: () => unawaited(open(issuesUrl)),
                ),
                DashedListRow(
                  key: const Key('about-licences'),
                  icon: AppIcons.licence,
                  label: l.aboutLicencesRow,
                  showDivider: false,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: l.appTitle,
                    applicationVersion: appVersion,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                _Caps(l.aboutSectionCredits),
                for (final line in [l.aboutCreditFonts, l.aboutCreditIcons, l.aboutCreditRates])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                    child: Text(line, style: context.text.body),
                  ),
                const SizedBox(height: AppSpacing.s5),
                Text(
                  l.aboutCopyright,
                  style: context.text.bodySmall.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Caps extends StatelessWidget {
  const _Caps(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s2),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
      ),
    ),
  );
}
