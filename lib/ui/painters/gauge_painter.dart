import 'dart:math';

import 'package:flutter/rendering.dart';

/// 240° arc gauge (646): track, progress arc and a round knob at the end.
class GaugePainter extends CustomPainter {
  const GaugePainter({
    required this.progress,
    required this.track,
    required this.fill,
    required this.knob,
    this.stroke = 18,
  });

  /// 0–1.
  final double progress;
  final Color track;
  final Color fill;
  final Color knob;
  final double stroke;

  static const sweep = 240 * pi / 180;
  static const start = pi / 2 + (2 * pi - sweep) / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & Size.square(size.shortestSide)).deflate(stroke / 2 + 4);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, base..color = track);
    final p = progress.clamp(0.0, 1.0);
    if (p > 0) {
      canvas.drawArc(rect, start, sweep * p, false, base..color = fill);
    }
    // Knob: a round dot centred on the arc end, a little wider than the stroke (06 §6).
    final angle = start + sweep * p;
    final c = rect.center;
    final r = rect.width / 2;
    final dir = Offset(cos(angle), sin(angle));
    canvas
      ..drawCircle(c + dir * r, stroke * 0.72, Paint()..color = track)
      ..drawCircle(c + dir * r, stroke * 0.58, Paint()..color = knob);
  }

  @override
  bool shouldRepaint(GaugePainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.fill != fill ||
      old.knob != knob ||
      old.stroke != stroke;
}
