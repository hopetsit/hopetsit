// v599 (29/09/2026) — FOND DE REMPLACEMENT SOUS LA CARTE.
//
// Mesuré par BOB sur l'Oppo A40 du frère de Daniel : 5,25 s de zone vide
// (couleur de fond de l'écran) avant les premières tuiles ; < 1 s sur
// Samsung. Sur Android, la vue Google Maps n'existe pas encore pendant ce
// temps : ce qui est SOUS elle dans la pile se voit. On y pose donc un fond
// joli — beige clair `#F6F1EE`, motif de pattes discret, « Carte en
// préparation… » centré — et rien par-dessus la carte : dès que les tuiles
// arrivent, elles le recouvrent d'elles-mêmes. Aucune minuterie, aucun
// voile. Mode nuit : brun de la carte de nuit (`#1D1B18`, même ton que le
// style de nuit) et texte clair.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../widgets/paw_pattern_background.dart';
import 'pawmap_pins.dart';

class PawMapPlaceholder extends StatelessWidget {
  const PawMapPlaceholder({
    super.key,
    required this.night,
    this.roleColor = PawMapLegend.owner,
  });

  final bool night;
  final Color roleColor;

  /// Beige clair validé (clair) / brun du style de nuit (nuit).
  static const Color day = Color(0xFFF6F1EE);
  static const Color darkNight = Color(0xFF1D1B18);

  @override
  Widget build(BuildContext context) {
    final Color base = night ? darkNight : day;
    final Color ink = night ? const Color(0xFFD9CFC4) : const Color(0xFF6B5A52);
    final Color motif = night
        ? Color.lerp(roleColor, Colors.white, 0.45)!
        : Color.lerp(roleColor, const Color(0xFF8A6A5C), 0.35)!;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: PawPatternPainter(
            color: motif,
            opacity: night ? 0.07 : 0.06,
            motifs: const <PawMotif>{PawMotif.paw},
            base: base,
          ),
          isComplex: true,
          willChange: false,
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Text(
                'pawmap599_map_preparing'.tr,
                key: const ValueKey<String>('pawmap_placeholder_text'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: ink,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
