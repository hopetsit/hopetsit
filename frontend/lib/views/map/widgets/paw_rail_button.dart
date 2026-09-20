// v565 — Daniel (18/09) : « les boutons de la barre de gauche plus beaux et
// design, la barre de droite aussi, en gardant les mêmes couleurs ».
//
// Deux briques purement visuelles (mêmes couleurs, mêmes actions) :
//   - [PawRailButton] : bouton rond du rail GAUCHE — dégradé doux de la
//     couleur vers sa version foncée, liseré blanc translucide, ombre colorée
//     douce, glyphe blanc centré, appui = scale + retour haptique.
//   - [PawGlassCapsule] / [PawCapsuleButton] : capsule DROITE — une seule
//     capsule « verre dépoli », coins 22, séparateurs fins, icônes
//     noires `#1D1D1F` / grises `#6E6E73`, bouton actif teinté.
//
// v573 (20/09) — « peaufine les boutons de la PawMap » (Daniel). Tailles,
// rayons, épaisseurs de bord, dégradés et ombres viennent TOUS de
// `PawMapTheme` (railButtonSize / railGap / railIconRatio / minTapTarget /
// pill* / railGradient / railShadow / pillShadowOn) : c'est ce qui rend les
// huit boutons du rail rigoureusement identiques et aligne la capsule et les
// trois pilules du haut sur le même langage. Détail du peaufinage :
//   · rail : liseré 1,4 px (2,6 px + halo coloré quand le calque est actif),
//     zone tactile ≥ 44 dp même sur un écran étroit, appui 0,92 puis retour
//     ÉLASTIQUE court, `HapticFeedback.selectionClick`, glyphe (icône Material
//     arrondie OU SVG de marque) dans une boîte de taille identique ;
//   · capsule : surface/filet/ombre thémés, onde d'appui découpée en ROND,
//     état actif cerclé à la couleur de marque (éclaircie en sombre) ;
//   · pilules : bord et rayon communs, ombre `PawMapTheme.pillShadow`, liseré
//     éclairci en sombre.
// Aucune action, aucun `onTap`, aucune couleur de rôle n'a changé.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/pawmap_theme.dart';

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
    this.size = PawMapTheme.railButtonSize,
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
    // v573 — « peaufine les boutons » : le dégradé, l'ombre colorée et les
    // tailles viennent maintenant de PawMapTheme, donc les huit boutons du
    // rail sont rigoureusement identiques. gradientTop / gradientBottom
    // restent prioritaires : ce sont les teintes validées par Daniel.
    final LinearGradient grad = PawMapTheme.railGradient(
      widget.color,
      top: widget.gradientTop,
      bottom: widget.gradientBottom,
    );
    final Color tone = widget.gradientBottom ?? widget.color;
    final double s = widget.size.w;
    // Zone tactile : jamais moins de 44 dp, même quand ScreenUtil rétrécit le
    // rond sur un écran étroit. Le visuel, lui, ne bouge pas.
    // ⚠️ 44 est une valeur en pixels logiques : PAS de `.w` ici, sinon le
    // minimum rétrécirait avec l'écran — exactement ce qu'on veut éviter.
    final double tap = math.max(s, PawMapTheme.minTapTarget);
    // État actif : anneau blanc plus épais + halo coloré (cf. railShadow).
    final double ring = widget.active ? 2.6 : 1.4;
    final double glyph = s * PawMapTheme.railIconRatio;
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
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: SizedBox(
            width: tap,
            height: tap,
            child: Center(
              child: AnimatedScale(
                // Appui : 0,92 sec et court. Relâchement : retour élastique
                // bref (le bouton « rebondit » une fois, sans ballotter).
                scale: _pressed ? 0.92 : 1.0,
                duration: Duration(milliseconds: _pressed ? 90 : 320),
                curve: _pressed ? Curves.easeOut : Curves.elasticOut,
                child: Container(
                  width: s,
                  height: s,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: grad,
                    // Fin liseré blanc translucide.
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: widget.active ? 0.98 : 0.78),
                      width: ring,
                    ),
                    boxShadow: PawMapTheme.railShadow(
                      tone,
                      pressed: _pressed,
                      active: widget.active,
                    ),
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
                        // Même boîte de glyphe pour l'icône ET le SVG : c'est
                        // ce qui donne le même poids optique d'un bouton à
                        // l'autre.
                        widget.child ??
                            SizedBox.square(
                              dimension: glyph,
                              child: widget.svg != null
                                  ? SvgPicture.string(widget.svg!,
                                      width: glyph, height: glyph)
                                  : Icon(widget.icon ?? Icons.circle,
                                      size: glyph, color: Colors.white),
                            ),
                      ],
                    ),
                  ),
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
    // v571 — lisibilité sombre : la capsule blanche gardait ses icônes
    // anthracite ; en sombre elle devient anthracite (icônes claires, cf.
    // [PawCapsuleButton]) pour s'accorder aux panneaux de la PawMap. Le rendu
    // clair est strictement inchangé.
    // v573 — la capsule tire sa surface, son filet et son ombre des jetons
    // communs (panelOn / borderOn / pillShadowOn) : même « verre dépoli » que
    // les panneaux et les pilules du haut, clair comme sombre.
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Container(
          height: 1,
          margin: EdgeInsets.symmetric(horizontal: 9.w),
          color: PawMapTheme.borderOn(context),
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
            color: PawMapTheme.panelOn(context).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: PawMapTheme.borderOn(context),
              width: PawMapTheme.pillBorderWidth,
            ),
            boxShadow: PawMapTheme.pillShadowOn(context),
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
    final bool isDark = PawMapTheme.isDark(context);
    // v571 — sur capsule anthracite, l'encre #1D1D1F disparaît.
    final Color baseInk = isDark ? const Color(0xFFF2F2F2) : ink;
    final Color baseGrey = isDark ? const Color(0xFFB0B0B0) : grey;
    final Color t = tint ?? baseInk;
    // v573 — l'état actif prend la couleur de marque, éclaircie en sombre
    // (AppColors.accentOn) pour rester lisible sur l'anthracite.
    final Color toneOn = AppColors.accentOn(context, t);
    final Color iconColor =
        active ? toneOn : (secondary ? baseGrey : baseInk);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        selected: active,
        child: Material(
          color: Colors.transparent,
          // v573 — l'onde d'appui était RECTANGULAIRE dans une capsule à coins
          // pleins : elle débordait visuellement des séparateurs. Découpée en
          // rond, au diamètre de la pastille.
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            customBorder: const CircleBorder(),
            splashColor: toneOn.withValues(alpha: 0.16),
            highlightColor: toneOn.withValues(alpha: 0.08),
            child: SizedBox(
              width: size.w,
              height: size.w,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: (size - 10).w,
                  height: (size - 10).w,
                  decoration: BoxDecoration(
                    color: active
                        ? toneOn.withValues(alpha: isDark ? 0.22 : 0.12)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: active
                        ? Border.all(
                            color: toneOn.withValues(alpha: 0.45),
                            width: 1,
                          )
                        : null,
                  ),
                  // Toutes les icônes de la capsule au même poids optique.
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
    this.radius = PawMapTheme.pillRadius,
    this.borderWidth = PawMapTheme.pillBorderWidth,
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
    // v571 — lisibilité sombre : pilule anthracite au lieu de blanche quand
    // elle n'est pas « pleine ». Le liseré et le contenu gardent leur couleur.
    final bool isDark = PawMapTheme.isDark(context);
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
                : PawMapTheme.panelOn(context).withValues(alpha: 0.96),
            gradient: filled ? gradient : null,
            borderRadius: r,
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: 0.55)
                  // v573 — en sombre, le liseré de couleur pure manquait de
                  // contraste sur l'anthracite : on l'éclaircit comme partout.
                  : (isDark ? PawMapTheme.lighten(color, 0.2) : color),
              width: borderWidth,
            ),
            // v573 — pleine : halo à sa couleur ; vide : l'ombre commune des
            // pilules flottantes (PawMapTheme.pillShadow), thémée.
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : PawMapTheme.pillShadowOn(context),
          ),
          child: child,
        ),
      ),
    );
  }
}
