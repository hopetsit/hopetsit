// v23.1.362 — l'emoji PawSpot DORÉ officiel (visuel fourni par Daniel) en
// WIDGET réutilisable : médaille or (anneau brillant + fond bronze), patte
// dorée en relief avec la POINTE-PIN découpée dans le coussinet, étincelles.
// Même dessin que le marqueur carte (_buildGoldenCoinBitmap) mais en
// CustomPaint vectoriel → net à toutes les tailles (boutique, sheets...).

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GoldenPawCoin extends StatelessWidget {
  const GoldenPawCoin({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoldenPawCoinPainter(),
    );
  }
}

class _GoldenPawCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dessin calibré sur un canevas 64×64 → on met à l'échelle.
    final s = size.width / 64.0;
    canvas.scale(s, s);
    const c = Offset(32, 32);

    // Anneau extérieur brillant (dégradé or clair → or).
    canvas.drawCircle(
      c,
      29,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(10, 8),
          const Offset(54, 58),
          [const Color(0xFFFFE989), const Color(0xFFD99800)],
        ),
    );
    // Fond intérieur bronze doré + liseré clair.
    canvas.drawCircle(c, 24.5, Paint()..color = const Color(0xFF9A6B00));
    canvas.drawCircle(
      c,
      24.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFFE989).withValues(alpha: 0.7),
    );

    // Patte dorée en relief (4 doigts + coussinet).
    final pawPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(18, 14),
        const Offset(46, 52),
        [const Color(0xFFFFE066), const Color(0xFFE8A00A)],
      );
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(20.5, 22), width: 9, height: 12),
        pawPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(28.5, 17.5), width: 9.5, height: 13),
        pawPaint);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(38, 18.5), width: 9.5, height: 13),
        pawPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(45.5, 24.5), width: 9, height: 11.5),
        pawPaint);
    final pad = Path()
      ..moveTo(20, 38)
      ..cubicTo(20, 29, 26, 26, 32.5, 26)
      ..cubicTo(39, 26, 45, 29, 45, 38)
      ..cubicTo(45, 44, 40, 48.5, 32.5, 48.5)
      ..cubicTo(25, 48.5, 20, 44, 20, 38)
      ..close();
    canvas.drawPath(pad, pawPaint);

    // Pointe-PIN découpée dans le coussinet.
    final hole = Paint()..color = const Color(0xFF9A6B00);
    canvas.drawCircle(const Offset(32.5, 36), 4.2, hole);
    final tip = Path()
      ..moveTo(27.8, 38.5)
      ..lineTo(37.2, 38.5)
      ..lineTo(32.5, 47)
      ..close();
    canvas.drawPath(tip, hole);
    canvas.drawCircle(const Offset(32.5, 36), 1.8,
        Paint()..color = const Color(0xFFFFE066));

    // Étincelles ✨.
    void sparkle(Offset p, double r) {
      final sp = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(p.dx - r, p.dy), Offset(p.dx + r, p.dy), sp);
      canvas.drawLine(Offset(p.dx, p.dy - r), Offset(p.dx, p.dy + r), sp);
    }

    sparkle(const Offset(50, 13), 4);
    sparkle(const Offset(13, 49), 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
