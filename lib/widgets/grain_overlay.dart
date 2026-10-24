/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Grain Overlay Widget
///
/// Static semi-transparent film grain overlay that sits on top of any screen.
/// Painted once and cached: the noise is decorative (2–5% opacity) and the
/// camera's real grain comes from FilmPreview, not from here.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:math';

import 'package:flutter/material.dart';

class GrainOverlay extends StatelessWidget {
  final double opacity;

  const GrainOverlay({super.key, this.opacity = 0.06});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GrainPainter(opacity: opacity),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final double opacity;

  const _GrainPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    // Stable seed: the same screen always gets the same grain, so the layer
    // can be cached by the RepaintBoundary above instead of redrawn.
    final random = Random(opacity.hashCode);
    final paint = Paint();

    // Draw sparse noise points for performance
    final density = (size.width * size.height / 60).round();
    for (int i = 0; i < density; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final brightness = random.nextInt(256);
      paint.color = Color.fromRGBO(brightness, brightness, brightness, opacity);

      canvas.drawRect(Rect.fromLTWH(x, y, 1.5, 1.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
