import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../utils/pawmap_theme.dart';
import '../views/map/widgets/paw_rail_button.dart';

/// v555 — poignée de repli du panneau PawMap.
///
/// Daniel : « la flèche pour réduire le menu est grise, fais un truc orange
/// pâle, animé léger et plus long horizontal ». Deux états :
///  - ouvert   : pilule orange pâle, large, chevron ▲ orange qui « respire »
///               (2 px de va-et-vient, 1,4 s) — assez pour qu'on la remarque,
///               pas assez pour distraire ;
///  - replié   : pilule orange pleine avec l'icône des filtres + ▼. Elle est
///               volontairement plus visible : le panneau contient les
///               interrupteurs d'abonnement, il ne doit pas se perdre.
///
/// Widget autonome avec son propre ticker : l'écran carte est déjà lourd, on
/// ne lui ajoute pas un AnimationController de plus.
class PawMapPanelHandle extends StatefulWidget {
  const PawMapPanelHandle({
    super.key,
    required this.collapsed,
    required this.onTap,
    this.fill = false,
    this.badge = 0,
  });

  final bool collapsed;
  final VoidCallback onTap;

  /// v565 (18/09) — nombre de filtres actifs (badge sur la pilule repliée).
  final int badge;

  /// v558 — replié dans la rangée à trois cases : la pilule remplit sa case
  /// (même largeur et même hauteur que « Partager en direct » et « Agrandir »),
  /// coins arrondis alignés sur ses voisines au lieu de la forme capsule.
  final bool fill;

  @override
  State<PawMapPanelHandle> createState() => _PawMapPanelHandleState();
}

class _PawMapPanelHandleState extends State<PawMapPanelHandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _bob =
      CurvedAnimation(parent: _ctl, curve: Curves.easeInOut);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    final fill = widget.fill && collapsed;
    // v565 (18/09) — Daniel : pilule repliée modernisée, mêmes couleurs :
    // verre blanc translucide, liseré orange fin, icône filtres + ▾ orange,
    // badge du nombre de filtres actifs, appui scale 0,96 + haptique.
    if (collapsed) {
      return Center(
        child: PawPressable(
          onTap: widget.onTap,
          child: PawGlassPill(
            color: PawMapTheme.accent,
            height: fill ? double.infinity : 44.h,
            width: fill ? double.infinity : 104.w,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.tune_rounded,
                        size: 19.sp, color: PawMapTheme.accent),
                    if (widget.badge > 0)
                      Positioned(
                        top: -6.h,
                        right: -8.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4.w, vertical: 1.h),
                          constraints: BoxConstraints(minWidth: 15.w),
                          decoration: BoxDecoration(
                            color: PawMapTheme.accent,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            widget.badge > 9 ? '9+' : '${widget.badge}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8.5.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 6.w),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20.sp, color: PawMapTheme.accent),
              ],
            ),
          ),
        ),
      );
    }
    return Center(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 120.w,
          height: 24.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Audit mode sombre — le panneau PawMap est passé en anthracite :
            // la pilule pêche en dur y formait une barre claire.
            color: PawMapTheme.isDark(context)
                ? PawMapTheme.accent.withValues(alpha: 0.18)
                : PawMapTheme.pastelPeach,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedBuilder(
            animation: _bob,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, -2.h * _bob.value),
              child: child,
            ),
            child: Icon(Icons.keyboard_arrow_up_rounded,
                size: 20.sp, color: PawMapTheme.accent),
          ),
        ),
      ),
    );
  }
}
