// v565 — Daniel (18/09) : « les boutons de la barre de gauche plus beaux et
// design, la barre de droite aussi, en gardant les mêmes couleurs ».
//
// Deux briques purement visuelles (mêmes couleurs, mêmes actions) :
//   - [PawRailButton] : bouton rond du rail GAUCHE — dégradé doux de la
//     couleur vers sa version foncée, anneau blanc fin (1,5 px ; plus épais
//     quand `active`), ombre colorée douce, icône blanche centrée, appui =
//     scale 0,94 + retour haptique.
//   - [PawGlassCapsule] / [PawCapsuleButton] : capsule DROITE — une seule
//     capsule blanche translucide (blur), coins 22, séparateurs fins, icônes
//     noires `#1D1D1F` / grises `#6E6E73`, bouton actif teinté.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PawRailButton extends StatefulWidget {
  const PawRailButton({
    super.key,
    required this.color,
    required this.label,
    required this.onTap,
    this.icon,
    this.svg,
    this.child,
    this.gradientTop,
    this.gradientBottom,
    this.active = false,
    this.size = 46,
  });

  final Color color;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? svg;
  final Widget? child;
  final Color? gradientTop;
  final Color? gradientBottom;
  final bool active;
  final double size;

  @override
  State<PawRailButton> createState() => _PawRailButtonState();
}

class _PawRailButtonState extends State<PawRailButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final Color top =
        widget.gradientTop ?? Color.lerp(widget.color, Colors.white, 0.16)!;
    final Color bottom =
        widget.gradientBottom ?? Color.lerp(widget.color, Colors.black, 0.18)!;
    final double s = widget.size.w;
    final double ring = widget.active ? 3.0 : 1.5;
    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        label: widget.label,
        selected: widget.active,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Container(
              width: s,
              height: s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [top, bottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: widget.active ? 1 : 0.92),
                  width: ring,
                ),
                boxShadow: [
                  // Ombre colorée douce sous le bouton.
                  BoxShadow(
                    color: bottom.withValues(alpha: _pressed ? 0.22 : 0.38),
                    blurRadius: 14,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                  // Assise très légère (lisibilité sur carte claire).
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Reflet doux en haut (relief, sans effet « bille »).
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: s * 0.48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    widget.child ??
                        (widget.svg != null
                            ? SvgPicture.string(widget.svg!,
                                width: s * 0.5, height: s * 0.5)
                            : Icon(widget.icon ?? Icons.circle,
                                size: s * 0.5, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Capsule blanche translucide (blur) du rail droit.
class PawGlassCapsule extends StatelessWidget {
  const PawGlassCapsule({super.key, required this.children, this.width = 42});

  /// Boutons ([PawCapsuleButton]) — les séparateurs fins sont insérés ici.
  final List<Widget> children;
  final double width;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Container(
          height: 1,
          margin: EdgeInsets.symmetric(horizontal: 9.w),
          color: const Color(0xFF1D1D1F).withValues(alpha: 0.08),
        ));
      }
      items.add(children[i]);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      // v566 — fluidité : plus de flou (BackdropFilter) au-dessus de la carte
      // (une vue native) : il force un calque par image pendant le déplacement.
      // Blanc translucide sans flou = même rendu, zéro coût.
      child: RepaintBoundary(
        child: Container(
          width: width.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}

/// Bouton de la capsule droite : icône noire (primaire) ou grise
/// (secondaire) ; `active` = icône ET pastille teintées de [tint].
class PawCapsuleButton extends StatelessWidget {
  const PawCapsuleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.secondary = false,
    this.active = false,
    this.tint,
    this.size = 42,
  });

  static const Color ink = Color(0xFF1D1D1F);
  static const Color grey = Color(0xFF6E6E73);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool secondary;
  final bool active;
  final Color? tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color t = tint ?? ink;
    final Color iconColor = active ? t : (secondary ? grey : ink);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        selected: active,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: SizedBox(
              width: size.w,
              height: size.w,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: (size - 10).w,
                  height: (size - 10).w,
                  decoration: BoxDecoration(
                    color: active ? t.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, color: iconColor, size: 20.sp),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// v565 (18/09) — appui animé partagé : scale [scale] + retour haptique.
class PawPressable extends StatefulWidget {
  const PawPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.label,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;
  final String? label;

  @override
  State<PawPressable> createState() => _PawPressableState();
}

class _PawPressableState extends State<PawPressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
    final label = widget.label;
    if (label == null || label.isEmpty) return child;
    return Tooltip(
      message: label,
      child: Semantics(button: true, label: label, child: child),
    );
  }
}

/// v565 (18/09) — pilule « verre » : fond blanc translucide (blur), coins
/// pleins (999), liseré fin de sa couleur, ombre douce. [filled] = fond de la
/// couleur (ou [gradient]) avec contenu blanc — l'état « actif ».
class PawGlassPill extends StatelessWidget {
  const PawGlassPill({
    super.key,
    required this.color,
    required this.child,
    this.filled = false,
    this.gradient,
    this.height,
    this.width,
    this.padding,
    this.radius = 999,
    this.borderWidth = 1.4,
  });

  final Color color;
  final Widget child;
  final bool filled;
  final Gradient? gradient;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      // v566 — fluidité : plus de flou (BackdropFilter) au-dessus de la carte
      // (une vue native) : il force un calque par image pendant le déplacement.
      // Blanc translucide sans flou = même rendu, zéro coût.
      child: RepaintBoundary(
        child: Container(
          height: height,
          width: width,
          padding: padding ?? EdgeInsets.symmetric(horizontal: 12.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? (gradient == null ? color : null)
                : Colors.white.withValues(alpha: 0.94),
            gradient: filled ? gradient : null,
            borderRadius: r,
            border: Border.all(
              color: filled ? Colors.white.withValues(alpha: 0.55) : color,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: (filled ? color : Colors.black)
                    .withValues(alpha: filled ? 0.32 : 0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
