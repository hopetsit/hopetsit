// v571 — fond à motif de pattes, réutilisable dans toute l'app.
//
// Daniel : « les pages Réservations […] et en fond une petite patte ou quelque
// chose ». Le motif doit se VOIR sans jamais gêner la lecture : un semis
// discret de petites pattes (coussinet + 4 doigts), teintées à la couleur
// d'accent du rôle, à ≈ 5 % d'opacité en clair et ≈ 6 % en sombre.
//
// Contraintes de rendu :
//   · disposition en QUINCONCE DÉTERMINISTE (aucun aléatoire re-tiré à chaque
//     frame : tailles, rotations et décalages viennent d'un hachage de la
//     cellule) — sinon le fond « scintille » à chaque rebuild ;
//   · `RepaintBoundary` autour du peintre, `shouldRepaint` faux tant que la
//     couleur et l'opacité ne changent pas ;
//   · `IgnorePointer` : le motif ne capte aucun tap, la liste par-dessus
//     garde tous ses gestes.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Empile un semis de pattes derrière [child].
///
/// ```dart
/// PawPatternBackground(
///   color: _ownerAccent,
///   child: Column(children: [...]),
/// )
/// ```
class PawPatternBackground extends StatelessWidget {
  /// Couleur d'accent du rôle (elle est fortement transparentisée).
  final Color color;

  /// Contenu affiché PAR-DESSUS le motif (les cartes restent opaques).
  final Widget child;

  /// Opacité forcée. Par défaut 0.09 en clair et 0.10 en sombre.
  final double? opacity;

  const PawPatternBackground({
    super.key,
    required this.color,
    required this.child,
    this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double alpha = (opacity ?? (dark ? 0.10 : 0.09)).clamp(0.0, 1.0);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PawPatternPainter(color: color, opacity: alpha),
                isComplex: true,
                willChange: false,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Peintre du semis. Public pour pouvoir être réutilisé seul (en-tête, carte…).
class PawPatternPainter extends CustomPainter {
  final Color color;
  final double opacity;

  /// Côté d'une cellule du semis, en pixels logiques.
  final double cell;

  const PawPatternPainter({
    required this.color,
    required this.opacity,
    this.cell = 96,
  });

  /// Hachage déterministe d'une cellule : mêmes tailles / rotations à chaque
  /// frame, donc aucun scintillement.
  static int _hash(int c, int r) {
    int h = (c * 73856093) ^ (r * 19349663) ^ 0x5bf03635;
    h ^= h >> 13;
    h *= 1274126177;
    h ^= h >> 16;
    return h & 0x7fffffff;
  }

  /// Une patte centrée sur l'origine, coussinet + 4 doigts.
  static void _paw(Canvas canvas, Paint paint) {
    // Coussinet.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 5.2), width: 17, height: 14),
      paint,
    );
    // 4 doigts : deux au centre (plus hauts), deux sur les côtés.
    const List<List<double>> toes = <List<double>>[
      // dx, dy, rx, ry, rotation (radians)
      <double>[-8.6, -3.6, 4.0, 5.2, -0.42],
      <double>[-3.0, -9.0, 4.0, 5.4, -0.14],
      <double>[3.0, -9.0, 4.0, 5.4, 0.14],
      <double>[8.6, -3.6, 4.0, 5.2, 0.42],
    ];
    for (final List<double> t in toes) {
      canvas.save();
      canvas.translate(t[0], t[1]);
      canvas.rotate(t[4]);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: t[2] * 2, height: t[3] * 2),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || opacity <= 0) return;
    final Paint paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final int cols = (size.width / cell).ceil() + 1;
    final int rows = (size.height / cell).ceil() + 1;

    for (int r = -1; r <= rows; r++) {
      for (int c = -1; c <= cols; c++) {
        final int h = _hash(c, r);
        // Quinconce : une ligne sur deux décalée d'une demi-cellule.
        final double baseX = c * cell + (r.isEven ? 0.0 : cell / 2);
        final double dx = baseX + (((h & 0x0F) - 7.5) * 1.6);
        final double dy = r * cell + ((((h >> 4) & 0x0F) - 7.5) * 1.6);
        if (dx < -cell || dy < -cell || dx > size.width + cell) continue;
        final double scale = 0.68 + ((h >> 8) & 0x07) * 0.08; // 0,68 → 1,24
        final double angle = (((h >> 11) & 0x1F) / 32.0) * 2 * math.pi;
        canvas.save();
        canvas.translate(dx, dy);
        canvas.rotate(angle);
        canvas.scale(scale);
        _paw(canvas, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant PawPatternPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity ||
      oldDelegate.cell != cell;

  @override
  bool shouldRebuildSemantics(covariant PawPatternPainter oldDelegate) => false;
}
