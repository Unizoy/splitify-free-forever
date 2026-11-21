import 'package:flutter/material.dart';
import 'package:splitify/core/utils/stable_hash.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Avatar sizes (§6): 32, 40, 56, 96 dp.
enum AvatarSize {
  s32(32),
  s40(40),
  s56(56),
  s96(96);

  const AvatarSize(this.dp);

  final double dp;
}

/// Initials ("AK") on a tint pair picked by `stableHash(seed) % 5`, or a photo.
class Avatar extends StatelessWidget {
  const Avatar({
    required this.name,
    required this.seed,
    this.size = AvatarSize.s40,
    this.image,
    this.ring = false,
    super.key,
  });

  final String name;

  /// Stable id (member id) that picks the colour.
  final String seed;
  final AvatarSize size;
  final ImageProvider? image;

  /// White ring, used when avatars overlap.
  final bool ring;

  /// Up to two initials from [name].
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts.last.characters.first : '';
    return (first + second).toUpperCase();
  }

  /// Tint pair for [seed] in the current mode.
  static AvatarTint tintFor(BuildContext context, String seed) {
    final tints = context.isDark ? AppPalette.avatarDark : AppPalette.avatarLight;
    return tints[stableHash(seed) % tints.length];
  }

  @override
  Widget build(BuildContext context) {
    final tint = tintFor(context, seed);
    final d = size.dp;
    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: tint.bg,
          shape: BoxShape.circle,
          border: ring ? Border.all(color: context.colors.bg, width: 2) : null,
          image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: image != null
            ? null
            : ExcludeSemantics(
                child: MediaQuery.withNoTextScaling(
                  child: Text(
                    initials(name),
                    style: context.text.body
                        .w(700)
                        .copyWith(color: tint.fg, fontSize: d * 0.38, height: 1, letterSpacing: 0),
                  ),
                ),
              ),
      ),
    );
  }
}

/// One person in an [AvatarStack].
typedef AvatarPerson = ({String name, String seed});

/// Overlapping avatars with a "+N" bubble after [max] people (438).
class AvatarStack extends StatelessWidget {
  const AvatarStack({required this.people, this.max = 3, this.size = AvatarSize.s32, super.key});

  final List<AvatarPerson> people;
  final int max;
  final AvatarSize size;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    final extra = people.length - shown.length;
    final d = size.dp;
    final step = d * 0.68;
    final count = shown.length + (extra > 0 ? 1 : 0);
    final l = AppLocalizations.of(context);
    return SizedBox(
      width: count == 0 ? 0 : d + step * (count - 1),
      height: d,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(
              start: step * i,
              child: Avatar(name: shown[i].name, seed: shown[i].seed, size: size, ring: true),
            ),
          if (extra > 0)
            PositionedDirectional(
              start: step * shown.length,
              child: Semantics(
                label: l.moreMembers(extra),
                excludeSemantics: true,
                child: Container(
                  width: d,
                  height: d,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.chip,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.bg, width: 2),
                  ),
                  child: MediaQuery.withNoTextScaling(
                    child: Text(
                      l.moreCount(extra),
                      style: context.text.caption
                          .w(700)
                          .copyWith(color: context.colors.textPrimary, fontSize: d * 0.34),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
