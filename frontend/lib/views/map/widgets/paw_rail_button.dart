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
    this.onLongPress,
  });

  final Color color;
  final String label;
  final VoidCallback onTap;

  /// v584 — appui LONG = l'explication du bouton (Daniel : « que les gens
  /// comprennent à quoi ça sert »). Optionnel : sans lui, rien ne change.
  final VoidCallback? onLongPress;
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
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  _setPressed(false);
                  HapticFeedback.mediumImpact();
                  widget.onLongPress!();
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
/// v587 (point 7) — Daniel : « la barre de droite de l'app n'est pas aussi
/// belle que celle du site ». La MATIÈRE du site (`glassStyle` de /map) :
/// verre chaud en dégradé (crème → pêche), liseré blanc net, reflet blanc en
/// haut, ombre TEINTÉE ambre (et non plus brun neutre). Partagée par la
/// capsule droite ET le rail gauche : mêmes coins, même matière.
BoxDecoration pawSiteGlass(BuildContext context, {double radius = 25}) {
  // v590 — handoff design §3.3 : verre des barres (clair / sombre), liseré
  // intérieur 1 px, ombre 0 14 30 −14 rgba(0,0,0,.45). Les deux barres sont
  // symétriques (même matière, même rayon 25).
  final bool dark = PawMapTheme.isDark(context);
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xEB2E2826), Color(0xE61A171D)]
          : const [Color(0xF2FFFFFF), Color(0xE0FCF4F0)],
    ),
    borderRadius: BorderRadius.circular(radius.r),
    border: Border.all(
      color: dark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFF78281E).withValues(alpha: 0.08),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.45),
        blurRadius: 30,
        spreadRadius: -14,
        offset: const Offset(0, 14),
      ),
    ],
  );
}

/// Séparateur du site : trait court (24 px) à la teinte chaude pleine.
class PawSiteSeparator extends StatelessWidget {
  const PawSiteSeparator({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 24.w,
        height: 1,
        margin: EdgeInsets.symmetric(vertical: 3.h),
        color: PawMapTheme.isDark(context)
            ? const Color(0xFF4A3530)
            : const Color(0xFFEBD7CC),
      );
}

class PawGlassCapsule extends StatelessWidget {
  const PawGlassCapsule({
    super.key,
    required this.children,
    this.width = 42,
    this.footer,
  });

  /// Boutons ([PawCapsuleButton]) — les séparateurs fins sont insérés ici.
  final List<Widget> children;
  final double width;

  /// v586 — l'action du rôle (Publier / Direct), sous un trait plus marqué.
  /// Hors de la découpe : sa lueur qui respire n'est jamais rognée.
  final Widget? footer;

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
    // v590 — handoff §3.3 : boutons outils ronds espacés, sans filet.
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(height: 3.h));
      items.add(children[i]);
    }
    // v585 (bug 8) — même verre TEINTÉ que le rail gauche (PawRailGlass) :
    // blanc chaud translucide, liseré blanc fin, ombre à l'encre chaude hors
    // de la découpe (elle était rognée), coins 28.
    return Container(
      width: width.w,
      decoration: pawSiteGlass(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25.r),
            child: RepaintBoundary(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 5.h),
                child: Column(mainAxisSize: MainAxisSize.min, children: items),
              ),
            ),
          ),
          if (footer != null) ...[
            Container(
              key: const ValueKey<String>('pawmap_capsule_trait'),
              height: 2,
              margin: EdgeInsets.symmetric(horizontal: 9.w),
              decoration: BoxDecoration(
                color: PawMapTheme.borderOn(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: footer!,
            ),
          ],
        ],
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

  // v587 (point 7) — l'encre chaude du site (#3B2A26), la même pour tous
  // les boutons (le site n'a pas de « secondaire » plus pâle).
  static const Color ink = Color(0xFF3B2A26);
  static const Color grey = Color(0xFF3B2A26);

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
    final Color baseInk = isDark ? const Color(0xFFFBEFE6) : ink;
    final Color baseGrey = isDark ? const Color(0xFFFBEFE6) : grey;
    final Color t = tint ?? baseInk;
    // v573 — l'état actif prend la couleur de marque, éclaircie en sombre
    // (AppColors.accentOn) pour rester lisible sur l'anthracite.
    final Color toneOn = AppColors.accentOn(context, t);
    // v585 (bug 8) — un bouton principal teinté (« ma position ») prend
    // l'accent du rôle ; le reste reste à l'encre chaude.
    final Color iconColor = active
        ? toneOn
        : (secondary ? baseGrey : (tint != null ? toneOn : baseInk));
    final Color fill = active
        ? (isDark
            ? toneOn.withValues(alpha: 0.28)
            : Color.alphaBlend(toneOn.withValues(alpha: 0.20), Colors.white))
        : (isDark
            ? t.withValues(alpha: 0.16)
            : Color.alphaBlend(t.withValues(alpha: 0.11), Colors.white));
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
                  // v590 — handoff §3.3 : rond 38, fond teinté doux
                  // (couleur à 10–12 %), liseré intérieur 1 px, reflet blanc
                  // en haut ; actif = teinte plus marquée + anneau blanc.
                  width: (size - 4).w,
                  height: (size - 4).w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        isDark
                            ? fill
                            : Color.alphaBlend(
                                Colors.white.withValues(alpha: 0.6), fill),
                        fill,
                        fill,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                    border: Border.all(
                      color: active
                          ? Colors.white
                          : t.withValues(alpha: isDark ? 0.26 : 0.16),
                      width: active ? 1.5 : 1,
                    ),
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
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;
  final String? label;

  /// v584 — appui long (explication d'un bouton du dock).
  final VoidCallback? onLongPress;

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
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _set(false);
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
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
    // v585 (bug 13, Daniel : « barre des boutons du haut : ronds coupés ») —
    // l'ombre était dessinée DANS un ClipRRect qui la rognait : bord dur, rond
    // qui paraît coupé. L'ombre vit maintenant autour, la découpe seulement
    // sur le contenu.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
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
      child: ClipRRect(
        borderRadius: r,
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
                    : (isDark ? PawMapTheme.lighten(color, 0.2) : color),
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
