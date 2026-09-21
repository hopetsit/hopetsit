// v575 — Daniel : « la petite icône en haut à gauche de la PawMap : recentre la
// patte et fais-la animer, discrète ».
//
// Tuile orange (scène de l'écran d'ouverture) + patte-épingle. Le dessin de
// `PawGlyph` est ancré en bas de sa boîte (pointe de l'épingle) : posé tel quel
// il paraissait trop bas et touchait le bord. On le remonte et on le réduit un
// peu pour que la masse visuelle (doigts + coussinet) soit au centre.
// Animation : une seule boucle lente (6 s) — respiration de 3 % et, une fois par
// cycle, une petite vague qui passe d'un doigt à l'autre. Rien qui clignote.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart' show PawGlyph;

class PawMapHeaderBadge extends StatefulWidget {
  const PawMapHeaderBadge({super.key, required this.size});

  /// Côté de la tuile, en points logiques.
  final double size;

  @override
  State<PawMapHeaderBadge> createState() => _PawMapHeaderBadgeState();
}

class _PawMapHeaderBadgeState extends State<PawMapHeaderBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// Vague : chaque doigt se rétracte d'un rien (1 → 0,82 → 1) à son tour,
  /// entre 8 % et 40 % du cycle. Le reste du temps : immobile.
  static double _toe(double t, int i) {
    final double start = 0.08 + 0.06 * i;
    const double len = 0.14;
    if (t < start || t > start + len) return 1;
    final double u = (t - start) / len; // 0 → 1
    return 1 - 0.18 * math.sin(u * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    final bool still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(s * 0.32),
        gradient: const LinearGradient(
          begin: Alignment(-0.6, -1),
          end: Alignment(0.6, 1),
          colors: <Color>[
            Color(0xFFF26A46),
            Color(0xFFDD4430),
            Color(0xFFC7311F),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFDD4430).withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _loop,
          builder: (BuildContext context, Widget? _) {
            final double t = still ? 0.6 : _loop.value;
            final double breath =
                still ? 0 : 0.5 - 0.5 * math.cos(t * 2 * math.pi);
            final List<double> toes =
                List<double>.generate(4, (int i) => _toe(t, i));
            return Center(
              child: Transform.translate(
                // Recentrage optique : la boîte du glyphe est lourde en bas.
                offset: Offset(0, -s * 0.085),
                child: Transform.scale(
                  scale: 1.0 + 0.03 * breath,
                  child: PawGlyph(size: s * 0.70, toeProgress: toes),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
