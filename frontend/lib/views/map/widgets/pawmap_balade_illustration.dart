// v599 (29/09/2026) — ILLUSTRATION « LA BALADE » de « Comprendre la PawMap ».
//
// Daniel : « une image montrant ce que voit la personne en balade et ce que
// voient les autres ». SANS AUCUN MOT (retour de LEO, 29/09 : la même image
// sert au site dans 9 langues) : les textes sont à côté, traduits. Dessinée
// avec les VRAIS peintres des épingles (`PawMapPinPainter`) et la vraie
// patte du menu (`PawGlyph` au contour vert, v604) : fidèle à la carte, nette à 2×
// et 3×, en clair comme en nuit. Le même widget exporte les PNG donnés à LEO
// (test `balade599_illustration_test.dart`).
//
//   ┌──────────────┐  ┌──────────────┐
//   │          ⏱👁 │  │      ●👁     │   gauche : ce que je vois (rond « Moi »
//   │      ╱‾‾╲ 🚶 │  │  ╱‾‾╲        │   à ma couleur, courte traîne ; v601 :
//   │              │  │              │   drapeau vert au-dessus du bouton
//   │              │  │              │   Balade, barre de droite)
//   │ ────╯  (Moi) │  │ ─╯   (photo) │   droite : ce que voient les autres
//   └──────────────┘  └──────────────┘   (rond photo, halo violet, bulle)
//                     🐾• (point vert du menu)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/paw_pattern_background.dart';
import '../../../widgets/paw_tab_bar.dart';
import 'pawmap_pins.dart';

class PawMapBaladeIllustration extends StatelessWidget {
  const PawMapBaladeIllustration({
    super.key,
    required this.dark,
    this.role = 'walker',
  });

  final bool dark;
  final String role;

  static const Color _dayBg = Color(0xFFF6F1EE);
  static const Color _nightBg = Color(0xFF1D1B18);
  static const double _pad = 10;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final Color roleColor = PawMapLegend.roleColor(role);
    final Color line = dark ? const Color(0xFF3A2A25) : const Color(0xFFEADBD2);
    return LayoutBuilder(builder: (context, c) {
      // Largeur utile = largeur donnée − marges intérieures (jamais plus large
      // que l'écran : vérifié à 320 et 360 dp par test).
      final double outer = c.maxWidth.isFinite ? c.maxWidth : 340;
      final double w = math.max(120, outer - 2 * _pad);
      final double panelW = ((w - _gap) / 2).floorToDouble();
      final double panelH = math.max(96, (panelW * 0.78).floorToDouble());
      Widget panel({required bool mine}) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: panelW,
            height: panelH,
            child: CustomPaint(
              painter: _BaladePanelPainter(
                dark: dark,
                mine: mine,
                roleColor: roleColor,
              ),
              // v601 — plus de pilule en haut : le drapeau vert est posé
              // au-dessus du bouton Balade, dans la barre de DROITE.
              child: mine
                  ? const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.only(top: 6, right: 5),
                        child: _RightBarBalade(),
                      ),
                    )
                  : null,
            ),
          ),
        );
      }

      return DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? _nightBg : _dayBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  panel(mine: true),
                  const SizedBox(width: _gap),
                  panel(mine: false),
                ],
              ),
              const SizedBox(height: 8),
              // v604 — la patte du menu avec son CONTOUR VERT (un ami en
              // direct) : plus de point vert (Daniel, 30/09 : « le contour
              // blanc devient vert, pas le pin entier »).
              const SizedBox(
                width: 54,
                height: 60,
                child: PawGlyph(size: 54, rimColor: PawLiveDot.green),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// v601 — morceau de la barre de DROITE, sans mot : le drapeau vert
/// (horloge = durée, œil = ceux qui me suivent) juste au-dessus du bouton
/// Balade vert en direct — même palette que le vrai bouton (`kJewelWalkOn`).
class _RightBarBalade extends StatelessWidget {
  const _RightBarBalade();

  static const List<Color> _walkOn = <Color>[
    Color(0xFF7FE39A),
    Color(0xFF2E9E48),
    Color(0xFF1D7A34),
  ];

  @override
  Widget build(BuildContext context) {
    const LinearGradient g = LinearGradient(
      begin: Alignment(-0.17, -1),
      end: Alignment(0.17, 1),
      colors: _walkOn,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            gradient: g,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _walkOn.last.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.schedule_rounded, size: 10, color: Colors.white),
              SizedBox(width: 2),
              Icon(Icons.visibility_rounded, size: 10, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: g,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.4),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _walkOn.last.withValues(alpha: 0.4),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.directions_walk_rounded,
              size: 16, color: Colors.white),
        ),
      ],
    );
  }
}

class _BaladePanelPainter extends CustomPainter {
  const _BaladePanelPainter({
    required this.dark,
    required this.mine,
    required this.roleColor,
  });

  final bool dark;
  final bool mine;
  final Color roleColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Fond de carte : beige / brun nuit + quelques « rues » douces.
    final Color base = dark ? const Color(0xFF2A2019) : const Color(0xFFF0EBE1);
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final Paint street = Paint()
      ..color = dark ? const Color(0xFF3E2E28) : Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height * 0.62),
        Offset(size.width, size.height * 0.48), street);
    canvas.drawLine(Offset(size.width * 0.3, 0),
        Offset(size.width * 0.42, size.height), street);
    final Paint park = Paint()
      ..color = (dark ? const Color(0xFF1F3A26) : const Color(0xFFDCEBD8));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.58, size.height * 0.08,
                size.width * 0.36, size.height * 0.3),
            const Radius.circular(10)),
        park);
    // Pattes discrètes (identité PawMap).
    PawPatternPainter(
      color: dark ? Colors.white : roleColor,
      opacity: 0.05,
      cell: 48,
    ).paint(canvas, size);

    // 612 — COURTE TRAÎNE violette derrière le rond (plus de tracé complet) :
    // fine (3), 5 morceaux qui s'estompent vers l'arrière (0,12 → 1), elle
    // finit sous le rond — comme sur la carte.
    final Offset end = Offset(size.width * 0.64, size.height * 0.64);
    final Path trail = Path()
      ..moveTo(size.width * 0.3, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.42, size.height * 0.6,
          end.dx, end.dy);
    for (final m in trail.computeMetrics()) {
      const int parts = 5;
      for (var k = 0; k < parts; k++) {
        final double a = 0.12 + 0.88 * (k / (parts - 1));
        canvas.drawPath(
            m.extractPath(m.length * k / parts, m.length * (k + 1) / parts),
            Paint()
              ..color = PawMapLegend.pawFollow.withValues(alpha: a)
              ..strokeWidth = 3
              ..strokeCap = k == 0 ? StrokeCap.round : StrokeCap.butt
              ..style = PaintingStyle.stroke);
      }
    }

    // Le rond : « Moi » (ma couleur) ou l'ami (halo violet discret, 612).
    // Aucune étiquette : l'image est sans mot.
    final double dot = mine ? 40 : 38;
    const double margin = PawMapPinPainter.photoMarginGlow;
    canvas.save();
    canvas.translate(end.dx - margin - dot / 2, end.dy - margin - dot / 2);
    PawMapPinPainter.paintPhotoDot(
      canvas,
      avatar: null,
      ringColor: mine ? roleColor : PawMapLegend.friend,
      size: dot,
      online: true,
      followPhase: mine ? null : 0.55,
      fallbackTint: roleColor,
      margin: margin,
    );
    canvas.restore();

    // Chez les autres : bulle « en direct » sans mot (point vert + œil).
    if (!mine) {
      final double bx = end.dx - 34;
      final double by = end.dy - dot / 2 - 30;
      final RRect bubble = RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, 68, 22), const Radius.circular(11));
      canvas.drawRRect(
          bubble,
          Paint()
            ..color = PawMapLegend.pawFollow.withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawRRect(bubble, Paint()..color = Colors.white);
      canvas.drawRRect(
          bubble,
          Paint()
            ..color = PawMapLegend.pawFollow.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      canvas.drawCircle(Offset(bx + 14, by + 11), 4, Paint()..color = PawLiveDot.green);
      // Œil : deux arcs + pupille.
      final Paint eye = Paint()
        ..color = PawMapLegend.pawFollow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      final Offset ec = Offset(bx + 44, by + 11);
      final Path eyePath = Path()
        ..moveTo(ec.dx - 9, ec.dy)
        ..quadraticBezierTo(ec.dx, ec.dy - 8, ec.dx + 9, ec.dy)
        ..quadraticBezierTo(ec.dx, ec.dy + 8, ec.dx - 9, ec.dy);
      canvas.drawPath(eyePath, eye);
      canvas.drawCircle(ec, 2.6, Paint()..color = PawMapLegend.pawFollow);
    }
  }

  @override
  bool shouldRepaint(covariant _BaladePanelPainter old) =>
      old.dark != dark || old.mine != mine || old.roleColor != roleColor;
}
