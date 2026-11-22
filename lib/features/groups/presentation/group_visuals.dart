import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The group's photo cover (S-073), decoded about [width] px wide; null for generated covers and while
/// the photo is loading or not reachable (the generated art shows instead).
ImageProvider? groupCoverImage(WidgetRef ref, LocalGroup g, {int? width}) {
  final path = g.coverPath;
  if (g.coverKind != 'photo' || path == null) return null;
  final file = ref
      .watch(storedPhotoProvider((bucket: MediaBuckets.groupCovers, path: path, thumb: false)))
      .value;
  if (file == null) return null;
  final image = FileImage(file);
  return width == null ? image : ResizeImage(image, width: width);
}

/// Cover family for a group `type` (trip/home/couple/other/direct).
CoverFamily coverFamilyFor(String type) => switch (type) {
  'trip' => CoverFamily.trip,
  'home' => CoverFamily.home,
  'couple' => CoverFamily.couple,
  'direct' => CoverFamily.direct,
  _ => CoverFamily.other,
};

String groupTypeLabel(AppLocalizations l, String type) => switch (type) {
  'trip' => l.groupTypeTrip,
  'home' => l.groupTypeHome,
  'couple' => l.groupTypeCouple,
  _ => l.groupTypeOther,
};

/// Friendly copy for an online-only group action that failed (08 cross-cutting "Errors").
String groupFailureText(AppLocalizations l, GroupFailureCode code) => switch (code) {
  GroupFailureCode.offline => l.needsInternet,
  GroupFailureCode.invalidCode => l.joinInvalidCode,
  GroupFailureCode.rateLimited => l.joinRateLimited,
  GroupFailureCode.alreadyClaimed => l.groupErrorAlreadyClaimed,
  GroupFailureCode.memberNotFound => l.groupErrorMemberNotFound,
  GroupFailureCode.nonzeroBalance => l.groupErrorNonzeroBalance,
  GroupFailureCode.notMember => l.groupErrorNotMember,
  GroupFailureCode.notClaimed => l.groupErrorNotClaimed,
  GroupFailureCode.groupFull => l.groupErrorGroupFull,
  GroupFailureCode.claimRequired => l.groupErrorClaimRequired,
  GroupFailureCode.unknown => l.authErrorUnknown,
};

/// Shows [message] in a snackbar.
void showGroupMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Display name of a member, "You" when it is the viewer's own spot with no name yet.
String memberName(AppLocalizations l, LocalMember m, String? me) =>
    m.displayName.trim().isEmpty && m.userId != null && m.userId == me ? l.you : m.displayName;

AvatarPerson memberPerson(AppLocalizations l, LocalMember m, String? me) =>
    (name: memberName(l, m, me), seed: m.id, tint: m.tint);

/// Serif page title with an optional subtitle, used by the group pages.
class PageTitle extends StatelessWidget {
  const PageTitle({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: AppText.maxSerifScale,
            child: Text(title, style: context.text.sheetTitle),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(subtitle!, style: context.text.body.copyWith(color: c.textSecondary)),
        ],
      ],
    );
  }
}

/// Section label in letter-spaced caps.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
    );
    if (trailing == null) return Semantics(header: true, child: label);
    // Wraps as a whole at large text sizes so the label never breaks inside a word.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s2,
        runSpacing: AppSpacing.s2,
        children: [
          Semantics(header: true, child: label),
          trailing!,
        ],
      ),
    );
  }
}

/// Wide generated cover with the type icon and the group name (create/edit preview, join preview).
class CoverBanner extends StatelessWidget {
  const CoverBanner({
    required this.seed,
    required this.type,
    required this.name,
    this.caption,
    this.height = 168,
    this.showName = true,
    this.photo,
    super.key,
  });

  final String seed;
  final String type;
  final String name;
  final String? caption;
  final double height;

  /// False when the page title already shows the name (join preview).
  final bool showName;

  /// A photo cover instead of the generated art.
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final family = coverFamilyFor(type);
    return Semantics(
      container: true,
      label: [name, ?caption].join(', '),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadii.all28,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Stack(
            children: [
              Positioned.fill(
                child: photo == null
                    ? CoverArt(seed: seed, family: family)
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(image: photo!, fit: BoxFit.cover, gaplessPlayback: true),
                          ColoredBox(color: AppPalette.black.withValues(alpha: 0.32)),
                        ],
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: height * 0.18),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.onHero.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        GroupCoverCard.iconFor(family),
                        size: 18,
                        color: AppPalette.black,
                      ),
                    ),
                    if (showName) ...[
                      const SizedBox(height: AppSpacing.s3),
                      Center(
                        child: Text(
                          name.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.cardTitle.copyWith(color: c.onHero),
                        ),
                      ),
                    ],
                    if (caption != null) ...[
                      SizedBox(height: showName ? AppSpacing.s1 : AppSpacing.s3),
                      Text(
                        caption!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: context.text.labelCaps.copyWith(
                          color: c.onHero.withValues(alpha: 0.78),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirm sheet (same pattern as sign-out); true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  IconData? icon,
}) async {
  final l = AppLocalizations.of(context);
  final yes = await showAppSheet<bool>(
    context,
    title: title,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(body, style: context.text.body.copyWith(color: context.colors.textSecondary)),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('confirm-action'),
          label: confirm,
          icon: icon,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.s2),
        PillButton(
          label: l.cancelLabel,
          variant: PillVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return yes ?? false;
}
