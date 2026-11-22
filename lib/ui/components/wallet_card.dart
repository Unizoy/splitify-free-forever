import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:splitify/ui/components/overlap_sheet.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/painters/brand_mark_painter.dart';
import 'package:splitify/ui/painters/wallet_painter.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Wallet showpiece (542 "INFINITY" wallet): a gold card peeking out of a
/// stitched leather sleeve. The card shows the overall balance (first
/// currency big, others below); the sleeve carries an amber status pill and
/// a caption. Tap opens the balance breakdown.
class WalletCard extends StatelessWidget {
  const WalletCard({
    required this.brandLabel,
    required this.amounts,
    required this.statusLabel,
    this.caption,
    this.onTap,
    super.key,
  });

  /// Small caps label on the card ("SPLITIFY").
  final String brandLabel;

  /// Formatted overall balance per currency, most important first.
  final List<String> amounts;

  /// "YOU ARE OWED" / "YOU OWE" / "ALL SETTLED".
  final String statusLabel;
  final String? caption;
  final VoidCallback? onTap;

  static const _ear = 34.0;
  static const _hidden = 64.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = [statusLabel, ...amounts, ?caption].join(', ');
    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        highlight: false,
        child: OverlapColumn(
          overlap: _hidden + _ear,
          top: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
            child: _GoldCard(brandLabel: brandLabel, amounts: amounts, chevron: onTap != null),
          ),
          bottom: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadii.all32,
              boxShadow: AppShadows.lifted(c),
            ),
            child: CustomPaint(
              painter: SleevePainter(
                top: c.leatherTop,
                bottom: c.leatherBottom,
                stitch: c.stitch,
                lip: c.metalHighlight,
                earHeight: _ear,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s6,
                  _ear + AppSpacing.s6,
                  AppSpacing.s6,
                  AppSpacing.s8,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
                      decoration: BoxDecoration(color: c.money, borderRadius: AppRadii.allPill),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(color: c.onMoney, shape: BoxShape.circle),
                            child: Icon(AppIcons.wallet, size: 13, color: c.money),
                          ),
                          const SizedBox(width: AppSpacing.s2),
                          Flexible(
                            child: Text(
                              statusLabel.toUpperCase(),
                              style: context.text.labelCaps.copyWith(
                                color: c.onMoney,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: AppSpacing.s3),
                      Text(
                        caption!,
                        textAlign: TextAlign.center,
                        style: context.text.body
                            .w(600)
                            .copyWith(color: c.onHero.withValues(alpha: 0.72)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldCard extends StatelessWidget {
  const _GoldCard({required this.brandLabel, required this.amounts, required this.chevron});

  final String brandLabel;
  final List<String> amounts;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CustomPaint(
      painter: _GoldPainter(light: c.goldLight, mid: c.goldMid, dark: c.goldDark, ink: c.onGold),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6,
          AppSpacing.s5,
          AppSpacing.s5,
          WalletCard._hidden + AppSpacing.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    brandLabel,
                    style: context.text.labelCaps.copyWith(
                      color: c.onGold,
                      fontSize: 14,
                      letterSpacing: 2.4,
                    ),
                  ),
                ),
                if (chevron) Icon(AppIcons.chevronRight, size: 18, color: c.onGold),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            if (amounts.isNotEmpty)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  amounts.first,
                  style: context.text.amountHero.copyWith(color: c.onGold),
                ),
              ),
            if (amounts.length > 1)
              Text(
                amounts.skip(1).join('  ·  '),
                style: context.text.amount.copyWith(color: c.onGold),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoldPainter extends CustomPainter {
  const _GoldPainter({
    required this.light,
    required this.mid,
    required this.dark,
    required this.ink,
  });

  final Color light;
  final Color mid;
  final Color dark;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AppRadii.r24));
    canvas
      ..drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(size.width, size.height),
            [dark, mid, light, mid],
            const [0, 0.35, 0.62, 1],
          ),
      )
      // Sheen spot, upper right.
      ..drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width * 0.78, size.height * 0.1),
            size.width * 0.45,
            [light.withValues(alpha: 0.9), light.withValues(alpha: 0)],
          ),
      )
      // Engraved inner border.
      ..drawRRect(
        rrect.deflate(10),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = light.withValues(alpha: 0.7),
      )
      ..drawRRect(
        rrect.deflate(11.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = dark.withValues(alpha: 0.35),
      );
    // Embossed brand mark watermark.
    final markSize = Size.square(size.height * 0.9);
    canvas
      ..save()
      ..translate(size.width * 0.62 - markSize.width / 2, size.height * 0.02);
    BrandMarkPainter(color: ink.withValues(alpha: 0.12)).paint(canvas, markSize);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoldPainter old) =>
      old.light != light || old.mid != mid || old.dark != dark || old.ink != ink;
}
