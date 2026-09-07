import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../utils/pawmap_theme.dart';

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
  });

  final bool collapsed;
  final VoidCallback onTap;

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
    return Center(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: collapsed ? 96.w : 120.w,
          height: collapsed ? 34.h : 24.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: collapsed ? PawMapTheme.accent : PawMapTheme.pastelPeach,
            borderRadius: BorderRadius.circular(999),
            boxShadow: collapsed ? PawMapTheme.pillShadow : null,
          ),
          child: collapsed
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 15.sp, color: Colors.white),
                    SizedBox(width: 5.w),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18.sp, color: Colors.white),
                  ],
                )
              : AnimatedBuilder(
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
