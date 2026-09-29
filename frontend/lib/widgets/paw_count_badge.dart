// v602 (PAM, 29/09/2026) — UNE pastille de compteur pour toute l'app.
//
// Daniel (retour sur le 601, « et dans la cloche notification ») : les
// pastilles de la cloche et du Chat doivent être posées sur le bord de
// l'icône, jamais flottantes, à la même place sur iPhone et Android, lisibles
// de jour comme de nuit, « 99+ » au-delà.
//
// Ce qui n'allait pas :
//   · cloche de l'en-tête : `BoxShape.circle` + largeur minimale en `.w` →
//     « 99+ » débordait du rond rouge, et la taille changeait avec l'écran ;
//   · cloche du profil et Chat du menu : ancrées par la DROITE → plus le
//     nombre est long, plus la pastille s'étalait VERS l'icône et la
//     recouvrait (« 99+ » cachait la moitié de la bulle du Chat) ;
//   · tailles en `.w/.h/.sp` : la place relative changeait d'un téléphone à
//     l'autre.
//
// Règle : taille FIXE (dp, sans mise à l'échelle du texte du téléphone),
// ancrage par la GAUCHE sur le coin haut-droit de l'icône (le début de la
// pastille mord l'icône, un nombre plus long s'allonge vers l'extérieur),
// pilule (jamais un rond déformé), liseré blanc, rouge chaud saturé.

import 'package:flutter/material.dart';

/// Rouge des compteurs (chaud, saturé : jamais gris, lisible sur blanc et
/// sur les en-têtes colorés).
const Color kPawBadgeRed = Color(0xFFE5484D);

/// Texte d'un compteur : « 99+ » au-delà de [max].
String pawBadgeLabel(int count, {int max = 99}) =>
    count > max ? '$max+' : '$count';

/// Pastille compteur : 18 dp de haut, au moins 18 de large, chiffre blanc.
class PawCountBadge extends StatelessWidget {
  const PawCountBadge({
    super.key,
    required this.count,
    this.max = 99,
    this.color = kPawBadgeRed,
    this.textColor = Colors.white,
    this.borderColor = Colors.white,
  });

  final int count;
  final int max;
  final Color color;
  final Color textColor;
  final Color borderColor;

  static const double height = 18;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      height: height,
      constraints: const BoxConstraints(minWidth: height),
      padding: const EdgeInsets.symmetric(horizontal: 4.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x471E1513),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        pawBadgeLabel(count, max: max),
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// Pose [badge] sur le coin haut-droit d'une icône de [iconWidth] dp :
/// le début de la pastille (9 dp) mord l'icône, le reste s'allonge vers
/// l'extérieur ; le haut dépasse de [lift] dp. Même place partout.
class PawBadgeAnchor extends StatelessWidget {
  const PawBadgeAnchor({
    super.key,
    required this.child,
    required this.iconWidth,
    required this.badge,
    this.bite = 9,
    this.lift = 7,
  });

  final Widget child;
  final double iconWidth;
  final Widget? badge;
  final double bite;
  final double lift;

  @override
  Widget build(BuildContext context) {
    final b = badge;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        if (b != null)
          Positioned(
            left: iconWidth - bite,
            top: -lift,
            child: b,
          ),
      ],
    );
  }
}
