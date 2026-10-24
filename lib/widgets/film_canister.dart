import 'package:flutter/material.dart';

import '../core/film_stocks.dart';

/// Painted film can, or a small camera for instant / 110 stocks.
/// Original labels only — no third-party logos.
class FilmCanister extends StatelessWidget {
  final FilmStock stock;
  final bool selected;

  const FilmCanister({super.key, required this.stock, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CanisterPainter(stock: stock, selected: selected),
      child: const SizedBox.expand(),
    );
  }
}

class _CanisterPainter extends CustomPainter {
  final FilmStock stock;
  final bool selected;

  _CanisterPainter({required this.stock, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    if (stock.id == 'polaroid_600' || stock.id == 'pocket_110' || stock.id == 'disposable_flash_800') {
      _camera(canvas, size);
    } else {
      _can(canvas, size);
    }
    if (selected) {
      final ring = RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFE7B15A),
      );
    }
  }

  void _can(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = _ink(stock.badgeColor);
    final paper = _paper(stock.badgeColor);

    canvas.drawOval(
      Rect.fromLTWH(w * 0.22, h * 0.9, w * 0.56, h * 0.07),
      Paint()..color = const Color(0x55000000),
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.18, w * 0.68, h * 0.74),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF161616));

    final label = Rect.fromLTWH(w * 0.22, h * 0.3, w * 0.56, h * 0.52);
    final style = stock.id.hashCode.abs() % 3;
    if (style == 0) {
      canvas.drawRect(label, Paint()..color = ink);
      canvas.drawRect(
        Rect.fromLTWH(label.left, label.top, label.width * 0.22, label.height),
        Paint()..color = paper,
      );
      _texts(canvas, label.shift(Offset(label.width * 0.18, 0)), _on(ink), isoBig: true);
    } else if (style == 1) {
      canvas.drawRect(label, Paint()..color = paper);
      canvas.drawRect(
        Rect.fromLTWH(label.left, label.top, label.width * 0.18, label.height),
        Paint()..color = ink,
      );
      _texts(canvas, label.shift(Offset(label.width * 0.14, 0)), _on(paper), isoBig: true);
    } else {
      canvas.drawRect(label, Paint()..color = const Color(0xFF111111));
      canvas.drawRect(
        Rect.fromLTWH(label.left, label.top + label.height * 0.42, label.width, label.height * 0.28),
        Paint()..color = ink,
      );
      _texts(canvas, label, Colors.white, isoBig: false);
    }

    final cap = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.14, w * 0.64, h * 0.11),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(cap, Paint()..color = const Color(0xFF101010));
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.08),
      w * 0.09,
      Paint()..color = const Color(0xFF2C2C2C),
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.075),
      w * 0.035,
      Paint()..color = const Color(0xFF4A4A4A),
    );
  }

  void _camera(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyColor = stock.id == 'pocket_110'
        ? const Color(0xFFD5D8DE)
        : stock.id == 'disposable_flash_800'
            ? const Color(0xFFF0C84A)
            : const Color(0xFF3E86D6);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.84, h * 0.62),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(body, Paint()..color = bodyColor);
    canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.16, Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.08, Paint()..color = const Color(0xFF4C6E8A));
    if (stock.id == 'polaroid_600') {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.22, h * 0.3, w * 0.56, h * 0.06),
        Paint()..color = const Color(0xFFE23B32),
      );
      canvas.drawRect(
        Rect.fromLTWH(w * 0.22, h * 0.36, w * 0.56, h * 0.045),
        Paint()..color = const Color(0xFFF2C14E),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.62, h * 0.3, w * 0.16, h * 0.1),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF222222),
      );
    }
    _line(canvas, stock.shortName, Offset(w * 0.5, h * 0.78), 7, const Color(0xFF1A1814), centered: true);
  }

  void _texts(Canvas canvas, Rect label, Color color, {required bool isoBig}) {
    final iso = '${stock.iso}';
    _line(
      canvas,
      iso,
      Offset(label.center.dx, label.top + label.height * (isoBig ? 0.38 : 0.28)),
      isoBig ? label.width * 0.28 : label.width * 0.2,
      color,
      centered: true,
    );
    _line(
      canvas,
      stock.shortName,
      Offset(label.center.dx, label.top + label.height * 0.72),
      label.width * 0.13,
      color,
      centered: true,
    );
  }

  void _line(
    Canvas canvas,
    String text,
    Offset at,
    double size,
    Color color, {
    bool centered = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size.clamp(6, 16),
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 80);
    final dx = at.dx - (centered ? painter.width / 2 : 0);
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  Color _ink(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness > 0.82) return const Color(0xFF3E86D6);
    return hsl.withLightness(hsl.lightness.clamp(0.28, 0.62)).toColor();
  }

  Color _paper(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(0.92).withSaturation(0.25).toColor();
  }

  Color _on(Color background) {
    return background.computeLuminance() > 0.55 ? const Color(0xFF1A1814) : Colors.white;
  }

  @override
  bool shouldRepaint(covariant _CanisterPainter oldDelegate) {
    return oldDelegate.stock.id != stock.id || oldDelegate.selected != selected;
  }
}
