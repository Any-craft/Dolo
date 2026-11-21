import 'package:flutter/material.dart';

/// Hand-drawn style money stack: four tilted green notes held by a gold band.
/// Drawn in code so it stays sharp at any size and needs no image asset.
class MoneyStackPainter extends CustomPainter {
  const MoneyStackPainter();

  static const _fills = [
    Color(0xFF2E9E50),
    Color(0xFF39B05C),
    Color(0xFF45C168),
    Color(0xFF55D277),
  ];
  static const _outline = Color(0xFF1C7038);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final noteW = size.width * 0.86;
    final noteH = size.height * 0.58;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.42);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.016
      ..strokeJoin = StrokeJoin.round
      ..color = _outline;

    // Notes, bottom to top. Each lower note peeks out down-left.
    for (var i = 0; i < 4; i++) {
      final depth = 3 - i;
      final rect = Rect.fromCenter(
        center: Offset(-depth * noteW * 0.018, depth * noteH * 0.09),
        width: noteW,
        height: noteH,
      );
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(noteH * 0.12));
      canvas.drawRRect(rr, Paint()..color = _fills[i]);
      canvas.drawRRect(rr, stroke);
    }

    // Details on the top note: inner border and corner marks.
    final top = Rect.fromCenter(center: Offset.zero, width: noteW, height: noteH);
    final inner = RRect.fromRectAndRadius(
      top.deflate(noteH * 0.11),
      Radius.circular(noteH * 0.07),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.009
        ..color = _outline.withValues(alpha: 0.35),
    );
    // Soft highlight along the top edge of the top note.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(top.left + noteH * 0.14, top.top + noteH * 0.14,
            noteW * 0.55, noteH * 0.12),
        Radius.circular(noteH * 0.06),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    // Gold band across the middle.
    final band = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(-noteW * 0.02, noteH * 0.12),
        width: noteW * 0.3,
        height: noteH * 1.36,
      ),
      Radius.circular(noteH * 0.05),
    );
    canvas.drawRRect(band, Paint()..color = const Color(0xFFC9A24D));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(band.left + band.width * 0.12, band.top + 4,
            band.width * 0.22, band.height - 8),
        Radius.circular(noteH * 0.04),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.014
        ..color = const Color(0xFF8A6A22),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(MoneyStackPainter oldDelegate) => false;
}

/// A soft feathered wing. The root (where it joins the money) is at the
/// bottom-right of the canvas; feathers fan out up and to the left.
/// Set [mirror] for the opposite wing.
class WingPainter extends CustomPainter {
  const WingPainter({this.mirror = false});
  final bool mirror;

  static const _fill = Color(0xFFFFFFFF);
  static const _shade = Color(0xFFF2E6E9);
  static const _outline = Color(0xFFB7A0A6);

  @override
  void paint(Canvas canvas, Size size) {
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final root = Offset(size.width * 0.86, size.height * 0.84);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03
      ..strokeJoin = StrokeJoin.round
      ..color = _outline;

    // Tapered feathers fanning out from the root. Long ones first (behind).
    final feathers = <(double angle, double length)>[
      (-2.80, 0.98),
      (-2.50, 0.95),
      (-2.20, 0.86),
      (-1.90, 0.72),
      (-1.62, 0.54),
    ];
    final h = size.height * 0.27;
    for (final (angle, length) in feathers) {
      final len = size.width * length;
      canvas.save();
      canvas.translate(root.dx, root.dy);
      canvas.rotate(angle);
      // Teardrop: wide near the root, rounded tip at the far end.
      final feather = Path()
        ..moveTo(0, -h * 0.32)
        ..cubicTo(len * 0.35, -h * 0.62, len * 0.82, -h * 0.58, len, -h * 0.05)
        ..cubicTo(len * 1.02, h * 0.2, len * 0.9, h * 0.45, len * 0.7, h * 0.45)
        ..cubicTo(len * 0.4, h * 0.5, len * 0.15, h * 0.42, 0, h * 0.32)
        ..close();
      canvas.drawPath(feather, Paint()..color = _fill);
      // Shading along the lower edge of each feather.
      final shade = Path()
        ..moveTo(len * 0.2, h * 0.18)
        ..cubicTo(len * 0.5, h * 0.3, len * 0.8, h * 0.3, len * 0.92, h * 0.12)
        ..cubicTo(len * 0.85, h * 0.4, len * 0.45, h * 0.44, len * 0.2, h * 0.3)
        ..close();
      canvas.drawPath(shade, Paint()..color = _shade);
      canvas.drawPath(feather, stroke);
      canvas.restore();
    }

    // Rounded covert over the root.
    final covert = Rect.fromCenter(
      center: root + Offset(-size.width * 0.16, -size.height * 0.16),
      width: size.width * 0.5,
      height: size.height * 0.42,
    );
    canvas.drawOval(covert, Paint()..color = _fill);
    canvas.drawOval(
      Rect.fromLTWH(covert.left + covert.width * 0.2, covert.center.dy,
          covert.width * 0.6, covert.height * 0.3),
      Paint()..color = _shade,
    );
    canvas.drawOval(covert, stroke);
  }

  @override
  bool shouldRepaint(WingPainter oldDelegate) => oldDelegate.mirror != mirror;
}
