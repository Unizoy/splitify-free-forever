import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/avatar.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Swipeable avatars inside a light ring (602): the centred avatar is full
/// size, neighbours shrink to 70 %; dots below show the position.
class AvatarCarousel extends StatefulWidget {
  const AvatarCarousel({
    required this.people,
    required this.onChanged,
    this.initialIndex = 0,
    this.ringSize = 220,
    super.key,
  });

  final List<AvatarPerson> people;
  final ValueChanged<int> onChanged;
  final int initialIndex;

  /// Outer diameter of the ring (spec: about 200 dp).
  final double ringSize;

  @override
  State<AvatarCarousel> createState() => _AvatarCarouselState();
}

class _AvatarCarouselState extends State<AvatarCarousel> {
  late final _controller = PageController(viewportFraction: 0.42, initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ring = widget.ringSize;
    final inner = ring * 0.66;
    final l = AppLocalizations.of(context);
    return SizedBox.square(
      dimension: ring,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring: thick light band, white inside.
          Container(
            decoration: BoxDecoration(color: c.surfaceMuted, shape: BoxShape.circle),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
          ),
          ClipOval(
            child: SizedBox.square(
              dimension: inner,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.people.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _index = i);
                  widget.onChanged(i);
                },
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final page = _controller.hasClients && _controller.position.haveDimensions
                        ? _controller.page ?? _index.toDouble()
                        : _index.toDouble();
                    final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
                    return Transform.scale(scale: 0.7 + 0.3 * t, child: child);
                  },
                  child: Center(
                    child: Avatar(
                      name: widget.people[i].name,
                      seed: widget.people[i].seed,
                      size: AvatarSize.s96,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: (ring - inner) / 2 + AppSpacing.s3,
            child: Semantics(
              label: l.pageDots(_index + 1, widget.people.length),
              excludeSemantics: true,
              child: Row(
                children: [
                  for (var i = 0; i < widget.people.length; i++)
                    AnimatedContainer(
                      duration: context.motion.fast,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index ? c.ink : c.divider,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
