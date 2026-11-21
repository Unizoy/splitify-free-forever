import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/money_tone.dart';
import 'package:splitify/ui/components/sync_marker.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Group card for the 2-column grid (438): generated cover (or photo) with a
/// dark bottom gradient, centred type icon, serif UPPERCASE name, thin
/// divider, and a footer with the balance label and amount.
class GroupCoverCard extends StatelessWidget {
  const GroupCoverCard({
    required this.seed,
    required this.family,
    required this.name,
    required this.statusLabel,
    this.amountText,
    this.tone = MoneyTone.settled,
    this.photo,
    this.unsynced = false,
    this.onTap,
    super.key,
  });

  /// Group id: picks the cover art.
  final String seed;
  final CoverFamily family;
  final String name;

  /// "YOU ARE OWED" / "YOU OWE" / "SETTLED".
  final String statusLabel;

  /// Formatted amount; null when settled.
  final String? amountText;
  final MoneyTone tone;

  /// User-uploaded cover instead of the generated art.
  final ImageProvider? photo;
  final bool unsynced;
  final VoidCallback? onTap;

  /// Grid aspect ratio (width / height): 0.62, taller at large text sizes.
  static double aspectRatioFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (scale >= 1.8) return 0.44;
    if (scale >= 1.3) return 0.52;
    return 0.62;
  }

  static IconData iconFor(CoverFamily family) => switch (family) {
    CoverFamily.trip => AppIcons.typeTrip,
    CoverFamily.home => AppIcons.typeHome,
    CoverFamily.couple => AppIcons.typeCouple,
    CoverFamily.other => AppIcons.typeOther,
    CoverFamily.direct => AppIcons.typeDirect,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amountColor = tone.onDarkColor(c);
    return Semantics(
      button: onTap != null,
      label: [
        name,
        statusLabel,
        ?amountText,
        if (unsynced) AppLocalizations.of(context).notSyncedYet,
      ].join(', '),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadii.all28,
        child: Material(
          color: AppPalette.clear,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo != null) ...[
                  Image(image: photo!, fit: BoxFit.cover),
                  const _BottomShade(),
                ] else
                  CoverArt(seed: seed, family: family),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    AppSpacing.s4,
                    AppSpacing.s4,
                    AppSpacing.s4,
                  ),
                  child: Column(
                    children: [
                      if (unsynced)
                        const Align(alignment: AlignmentDirectional.topEnd, child: _UnsyncedDot()),
                      const Spacer(),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c.onHero.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconFor(family), size: 16, color: AppPalette.black),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        name.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.cardTitle.copyWith(color: c.onHero),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      Divider(height: 1, thickness: 1, color: c.onHero.withValues(alpha: 0.22)),
                      const SizedBox(height: AppSpacing.s3),
                      _Footer(
                        label: Text(
                          statusLabel.toUpperCase(),
                          maxLines: 1,
                          style: context.text.labelCaps.copyWith(
                            color: c.onHero.withValues(alpha: 0.7),
                            letterSpacing: 1.2,
                            fontSize: 11,
                          ),
                        ),
                        amount: amountText == null
                            ? null
                            : Text(
                                amountText!,
                                style: context.text.amount.w(700).copyWith(color: amountColor),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomShade extends StatelessWidget {
  const _BottomShade();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppPalette.black.withValues(alpha: 0), AppPalette.black.withValues(alpha: 0.6)],
        stops: const [0.35, 1],
      ),
    ),
  );
}

class _UnsyncedDot extends StatelessWidget {
  const _UnsyncedDot();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
    decoration: BoxDecoration(color: context.colors.bg, borderRadius: AppRadii.allPill),
    child: const SyncMarker(compact: true),
  );
}

/// Balance label + amount: side by side, stacked when the text is large.
class _Footer extends StatelessWidget {
  const _Footer({required this.label, required this.amount});

  final Widget label;
  final Widget? amount;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          if (amount != null) ...[
            const SizedBox(height: AppSpacing.s1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: amount,
            ),
          ],
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: label,
          ),
        ),
        if (amount != null) ...[
          const SizedBox(width: AppSpacing.s2),
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: amount,
            ),
          ),
        ],
      ],
    );
  }
}
