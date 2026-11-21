import 'package:flutter/material.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// One card in a [StackedCardsLoader].
typedef LoaderCard = ({String seed, CoverFamily family, String caption});

/// Playful busy state (505/528): tilted white photo cards with generated
/// covers and captions; the top card flies off and slides to the back, again
/// and again. Static stack when the user removed animations.
/// Used for create group, import and first sync.
class StackedCardsLoader extends StatefulWidget {
  const StackedCardsLoader({required this.cards, this.title, this.message, super.key});

  final List<LoaderCard> cards;
  final String? title;
  final String? message;

  @override
  State<StackedCardsLoader> createState() => _StackedCardsLoaderState();
}

class _StackedCardsLoaderState extends State<StackedCardsLoader>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..addStatusListener(_onStatus);
  int _top = 0;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _top = (_top + 1) % widget.cards.length);
    _c.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motion.reduced) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _tilts = [-0.16, 0.1, -0.05, 0.18, -0.22];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = widget.cards.length;
    return Semantics(
      liveRegion: true,
      label: [?widget.title, ?widget.message].join('. '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                // Fly out (0–0.55) then tuck behind (0.55–1).
                final out = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
                final back = Curves.easeInOutCubic.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));
                final children = <Widget>[];
                // Paint from the back of the stack to the front.
                for (var depth = n - 1; depth >= 0; depth--) {
                  final index = (_top + depth) % n;
                  final isTop = depth == 0;
                  var angle = _tilts[depth % _tilts.length];
                  var offset = Offset(depth * 3.0, depth * 4.0);
                  if (isTop && !context.motion.reduced) {
                    angle = angle + 0.45 * out - 0.45 * back;
                    offset = Offset(110 * out - 110 * back, -120 * out + 120 * back);
                  }
                  final card = Transform.translate(
                    offset: offset,
                    child: Transform.rotate(
                      angle: angle,
                      child: _PhotoCard(card: widget.cards[index]),
                    ),
                  );
                  if (isTop && t > 0.55) {
                    children.insert(0, card); // tucked behind the others
                  } else {
                    children.add(card);
                  }
                }
                return Stack(alignment: Alignment.center, children: children);
              },
            ),
          ),
          if (widget.title != null) ...[
            const SizedBox(height: AppSpacing.s6),
            Text(widget.title!, textAlign: TextAlign.center, style: context.text.title.w(700)),
          ],
          if (widget.message != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.card});

  final LoaderCard card;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 150,
      height: 196,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: AppRadii.all16,
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 146,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(AppRadii.r12)),
              child: CoverArt(seed: card.seed, family: card.family, legibilityScrim: false),
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: MediaQuery.withNoTextScaling(
                  child: Text(
                    card.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall.w(700).copyWith(color: AppPalette.black),
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
