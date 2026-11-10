// BUILD 640 (PAM) — habillage des accueils d'après les 3 maquettes de Daniel
// (« améliorer les deux boutons de l'accueil owner comme sur la photo » ; « les
// deux accueils walker et sitter dans ce style, c'est juste amélioré »).
//
// APPARENCE SEULEMENT : mêmes contenus, mêmes actions, mêmes clés de test,
// mêmes zones tactiles. Tout est derrière trois coupe-circuits : à `false`,
// l'écran retombe sur le rendu d'avant le 640, resté intact dans le code.
//
// Ce fichier ne connaît ni l'API ni les contrôleurs : il reçoit des libellés
// déjà traduits et des callbacks.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hopetsit/utils/search_radius.dart';
import 'package:hopetsit/views/shared/widgets/home_hero3110.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

// ─────────────────────────── Coupe-circuits ───────────────────────────────

/// Lot 1 — accueil PROPRIÉTAIRE : les deux grandes cartes « Garde » /
/// « Promenade » au dessin 640 (silhouettes, ombre de la couleur de la carte).
/// `false` → `ServiceCards3110` (rendu du 31/10).
const bool kOwnerHomeCards640 = true;

/// Lot 2 — accueils GARDIEN et PROMENEUR : filigranes de l'en-tête, bouton
/// « Partager » en dégradé, carte d'annonce (liseré, panneau de l'animal,
/// pastille contour), carte « rien à moins de 200 km ».
/// `false` → rendu du 31/10.
const bool kProviderHome640 = true;

/// Lot 3 — fil des annonces : filtre CÔTÉ APP des annonces SANS coordonnées
/// (Daniel, en Espagne à 90 km, voyait une demande du Brésil).
///
/// ÉTEINT par défaut (BOB, 10/11) : c'est le SERVEUR qui décide
/// (`backend/src/utils/feedNoCoords640.js` — il situe la ville de l'annonce et
/// ne la retire que si elle est vraiment loin ; dans le doute il la garde).
/// L'app ne sait pas situer une ville : comparer deux NOMS de ville écarterait
/// une vraie demande de la commune voisine, et toutes les annonces sans
/// coordonnées dès que le prestataire cherche « autour de ma position » (pas de
/// ville connue). `true` → règle locale ci-dessous, en plus de celle du serveur.
const bool kFeedNoCoordsStrict640 = false;

// ───────────────────── Lot 3 — décision pure du filtre ────────────────────

const Map<String, String> _kFold640 = <String, String>{
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'ď': 'd',
  'đ': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ğ': 'g',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ı': 'i',
  'ł': 'l',
  'ľ': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ő': 'o',
  'ř': 'r',
  'ś': 's',
  'š': 's',
  'ş': 's',
  'ș': 's',
  'ß': 'ss',
  'ť': 't',
  'ț': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ű': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
  'æ': 'ae',
  'œ': 'oe',
};

final RegExp _kNoise640 = RegExp(r'[\s\p{P}\p{S}]', unicode: true);

/// Ville ramenée à une forme comparable : premier segment (avant la virgule :
/// « Madrid, Espagne » → « madrid »), minuscules, sans accents, sans espaces ni
/// ponctuation. « São Paulo » et « sao  paulo » donnent la même chaîne.
/// Chaîne vide = ville inconnue.
String normalizeCity640(String? raw) {
  if (raw == null) return '';
  final String first = raw.split(',').first.trim().toLowerCase();
  if (first.isEmpty) return '';
  final StringBuffer out = StringBuffer();
  for (final int rune in first.runes) {
    final String ch = String.fromCharCode(rune);
    out.write(_kFold640[ch] ?? ch);
  }
  // Accents « combinants » (forme décomposée : o + U+0303).
  return out
      .toString()
      .replaceAll(RegExp(r'[̀-ͯ]'), '')
      .replaceAll(_kNoise640, '');
}

/// Faut-il garder cette annonce dans le fil « Autour de moi » ?
///
///  • pas d'ancre ([anchorLat]/[anchorLng] nuls) → gardée (aucun filtre) ;
///  • annonce AVEC coordonnées → dans le rayon ou non (haversine, borne
///    inclusive — inchangé) ;
///  • annonce SANS coordonnées → avec [strict] à `false` (défaut) : gardée, le
///    serveur a déjà retiré celles dont la ville est vraiment loin. Avec
///    [strict] à `true` : écartée seulement si sa ville ET celle du prestataire
///    ([providerCity]) sont connues et différentes (comparaison insensible à
///    la casse, aux accents et aux espaces) ; une ville inconnue → gardée.
bool keepPostForAnchor640({
  required double? anchorLat,
  required double? anchorLng,
  required double? postLat,
  required double? postLng,
  required String? postCity,
  required String? providerCity,
  required double radiusKm,
  bool strict = kFeedNoCoordsStrict640,
}) {
  if (anchorLat == null || anchorLng == null) return true;
  if (postLat == null || postLng == null) {
    if (!strict) return true;
    // Dans le doute on GARDE (même règle que le serveur) : on n'écarte que
    // si les deux villes sont connues ET différentes.
    final String mine = normalizeCity640(providerCity);
    final String theirs = normalizeCity640(postCity);
    if (mine.isEmpty || theirs.isEmpty) return true;
    return theirs == mine;
  }
  return withinRadiusKm(
    haversineKm(anchorLat, anchorLng, postLat, postLng),
    radiusKm,
  );
}

// ─────────────────────────── Décors (non tactiles) ────────────────────────

/// Quel dessin poser en bas à droite d'une carte.
enum HomeDeco640 {
  /// Un chien et un chat assis côte à côte (carte « Garde »).
  dogAndCat,

  /// Un chien tenu en laisse (carte « Promenade », bandeau promeneur).
  dogOnLeash,
}

/// Silhouette décorative PLEINE en blanc translucide, dessinée à la main
/// (aucun asset, aucun paquet). Jamais tactile, jamais lue par les lecteurs
/// d'écran. Toutes les formes sont peintes opaques dans un calque unique, puis
/// le calque est rendu translucide : aucune surépaisseur là où deux formes se
/// recouvrent.
class HomeSilhouette640 extends StatelessWidget {
  const HomeSilhouette640({
    super.key,
    required this.deco,
    this.height = 58,
    this.color = Colors.white,
    this.opacity = 0.20,
  });

  final HomeDeco640 deco;
  final double height;
  final Color color;
  final double opacity;

  /// Largeur du dessin pour une hauteur donnée.
  static double widthFor(HomeDeco640 deco, double height) =>
      height * (deco == HomeDeco640.dogAndCat ? 1.50 : 1.48);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: widthFor(deco, height),
          height: height,
          child: CustomPaint(
            painter: _SilhouettePainter640(deco, color, opacity),
          ),
        ),
      ),
    );
  }
}

/// Dessin dans une grille de 100 de haut (150 ou 148 de large).
class _SilhouettePainter640 extends CustomPainter {
  const _SilhouettePainter640(this.deco, this.color, this.opacity);
  final HomeDeco640 deco;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.height / 100;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
    );
    canvas.scale(k);
    final Paint fill = Paint()
      ..color = color.withValues(alpha: 1)
      ..isAntiAlias = true;
    Paint stroke(double w) => Paint()
      ..color = color.withValues(alpha: 1)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w
      ..isAntiAlias = true;
    void oval(double cx, double cy, double rx, double ry, [double deg = 0]) {
      canvas.save();
      canvas.translate(cx, cy);
      if (deg != 0) canvas.rotate(deg * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        fill,
      );
      canvas.restore();
    }

    void pill(double l, double t, double r, double b, double rad) {
      canvas.drawRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)), fill);
    }

    switch (deco) {
      case HomeDeco640.dogAndCat:
        _sittingDog(canvas, fill, stroke, oval, pill);
        _sittingCat(canvas, fill, stroke, oval, pill);
      case HomeDeco640.dogOnLeash:
        _walkingDog(canvas, fill, stroke, oval, pill);
    }
    canvas.restore();
  }

  // Chien assis, de profil, museau vers la droite (x 2..88).
  void _sittingDog(
    Canvas canvas,
    Paint fill,
    Paint Function(double) stroke,
    void Function(double, double, double, double, [double]) oval,
    void Function(double, double, double, double, double) pill,
  ) {
    // queue
    canvas.drawPath(
      Path()
        ..moveTo(16, 90)
        ..quadraticBezierTo(2, 86, 5, 68),
      stroke(7),
    );
    oval(31, 77, 23, 22); // arrière-train
    oval(44, 62, 17, 30, 20); // dos / poitrail
    pill(53, 58, 64, 98, 5.5); // patte avant
    pill(53, 89, 75, 99, 5); // pied avant
    pill(20, 89, 54, 99, 5); // pied arrière
    oval(56, 46, 11, 16, 12); // cou
    oval(62, 30, 15, 14.5); // tête
    pill(64, 28, 88, 41, 6.5); // museau
    oval(50, 33, 6.5, 13.5, 14); // oreille tombante
  }

  // Chat assis, de dos / face (x 96..148), plus petit que le chien.
  void _sittingCat(
    Canvas canvas,
    Paint fill,
    Paint Function(double) stroke,
    void Function(double, double, double, double, [double]) oval,
    void Function(double, double, double, double, double) pill,
  ) {
    canvas.drawPath(
      Path()
        ..moveTo(132, 94)
        ..quadraticBezierTo(149, 94, 145, 72),
      stroke(6),
    );
    oval(119, 76, 18, 23); // corps
    pill(102, 90, 136, 99, 4.5); // assise
    oval(119, 47, 14, 12.5); // tête
    canvas.drawPath(
      Path()
        ..moveTo(105.5, 46)
        ..lineTo(107, 27)
        ..lineTo(119, 37)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(132.5, 46)
        ..lineTo(131, 27)
        ..lineTo(119, 37)
        ..close(),
      fill,
    );
  }

  // Chien qui marche vers la droite, tenu par une laisse qui remonte à gauche.
  void _walkingDog(
    Canvas canvas,
    Paint fill,
    Paint Function(double) stroke,
    void Function(double, double, double, double, [double]) oval,
    void Function(double, double, double, double, double) pill,
  ) {
    // laisse + poignée
    canvas.drawPath(
      Path()
        ..moveTo(112, 50)
        ..cubicTo(88, 44, 52, 40, 20, 14),
      stroke(2.6),
    );
    canvas.drawCircle(const Offset(14, 9), 6.5, stroke(2.6));
    // queue
    canvas.drawPath(
      Path()
        ..moveTo(62, 60)
        ..quadraticBezierTo(50, 56, 48, 42),
      stroke(6.5),
    );
    pill(58, 52, 118, 77, 12.5); // corps
    oval(110, 63, 13, 14); // poitrail
    oval(116, 52, 9, 14, 28); // cou
    oval(123, 40, 12.5, 12); // tête
    pill(125, 38, 146, 49, 5.5); // museau
    oval(113.5, 42, 5.2, 11.5, 16); // oreille
    // pattes (en marche)
    final Paint leg = stroke(8.5);
    canvas.drawLine(const Offset(68, 72), const Offset(64, 95), leg);
    canvas.drawLine(const Offset(79, 72), const Offset(82, 95), leg);
    canvas.drawLine(const Offset(102, 72), const Offset(99, 95), leg);
    canvas.drawLine(const Offset(111, 72), const Offset(115, 95), leg);
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter640 old) =>
      old.deco != deco || old.color != color || old.opacity != opacity;
}

/// Patte en filigrane (en-tête du promeneur, photo de l'animal).
class PawWatermark640 extends StatelessWidget {
  const PawWatermark640({
    super.key,
    this.size = 96,
    this.color = Colors.white,
    this.opacity = 0.14,
    this.angle = -0.35,
  });

  final double size;
  final Color color;
  final double opacity;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final Color c = color.withValues(alpha: opacity);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: angle,
          child: PawIconWidget(PawIcon.paw, size: size, color: c, fill: c),
        ),
      ),
    );
  }
}

// ───────────── Lot 2 — en-tête des accueils gardien / promeneur ────────────

/// Bandeau d'état du hero, dessin 640. MÊME clé (`home_hero_status`), mêmes
/// titre et sous-texte que `HeroStatusBlock3110` : seul l'habillage change
/// (liseré clair, rond blanc ombré, et — pour le promeneur — une silhouette de
/// chien en laisse à droite). La silhouette n'apparaît que si le bandeau est
/// assez large (≥ 320 dp) : sur un petit écran le texte garde toute sa place.
class HeroStatusBlock640 extends StatelessWidget {
  const HeroStatusBlock640({
    super.key,
    required this.primary,
    required this.title,
    required this.subtitle,
    this.deco,
  });

  final Color primary;
  final String title;
  final String subtitle;

  /// Décor de droite (null = aucun).
  final HomeDeco640? deco;

  /// Largeur à partir de laquelle le décor est dessiné.
  static const double decoMinWidth = 320;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool showDeco = deco != null && c.maxWidth >= decoMinWidth;
        return Container(
          key: const ValueKey<String>('home_hero_status'),
          margin: const EdgeInsets.only(top: 14),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Stack(
            children: <Widget>[
              if (showDeco)
                Positioned(
                  right: 10,
                  bottom: 4,
                  child: HomeSilhouette640(
                    key: const ValueKey<String>('home640_status_deco'),
                    deco: deco!,
                    height: 46,
                    opacity: 0.30,
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(14, 12, showDeco ? 84 : 14, 12),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 21,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: pop3110(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: pop3110(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.86),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pose une patte en filigrane sur le hero (promeneur), SANS toucher au hero
/// lui-même : le hero reste l'enfant, la patte est peinte par-dessus, rognée
/// aux coins du bas, jamais tactile. `show: false` → l'enfant seul.
class HeroPawOverlay640 extends StatelessWidget {
  const HeroPawOverlay640({
    super.key,
    required this.child,
    this.show = true,
    this.bottomRadius = 32,
  });

  final Widget child;
  final bool show;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    final double top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(bottomRadius),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  Positioned(
                    // Dans le cercle clair du coin, derrière la fusée et la
                    // cloche, et AU-DESSUS du bandeau d'état (qui commence à
                    // ~120 dp sous la zone sûre) : jamais à cheval dessus.
                    top: top + 12,
                    right: -18,
                    child: const PawWatermark640(
                      key: ValueKey<String>('home640_hero_paw'),
                      size: 92,
                      opacity: 0.10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────── Lot 1 — cartes de l'accueil propriétaire ───────────────

/// Au-delà de ×1,5 le texte des cartes ne grossit plus (il resterait lisible
/// mais ferait déborder une carte de 144 dp de large).
const double kOwnerCardMaxTextScale640 = 1.5;

/// Hauteur de la carte compacte (dès la première annonce) — inchangée.
const double kOwnerCardCompactHeight640 = 76;

/// Plus grande taille de police (≤ [start], ≥ [floor], par pas de 0,5) à
/// laquelle TOUS les [texts] tiennent en [maxLines] lignes dans [width].
/// Les deux cartes partagent ainsi la même taille : jamais un titre plus gros
/// que l'autre. Si rien ne tient, [floor] (le `Text` finit alors par « … »).
double fitFontSize640(
  List<String> texts, {
  required double width,
  required double start,
  required double floor,
  required int maxLines,
  required FontWeight weight,
  required double lineHeight,
  TextStyle? base,
  TextDirection direction = TextDirection.ltr,
}) {
  if (!width.isFinite || width <= 1) return floor;
  for (double s = start; s > floor; s -= 0.5) {
    // Même style que le `Text` rendu : le style par défaut du thème (qui
    // porte un interlettrage) fusionné avec le nôtre.
    final TextStyle own = pop3110(
      fontSize: s,
      fontWeight: weight,
      height: lineHeight,
    );
    final TextStyle style = base == null ? own : base.merge(own);
    bool ok = true;
    for (final String t in texts) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: t, style: style),
        maxLines: maxLines,
        textDirection: direction,
      )..layout(maxWidth: width - 1);
      final bool over = tp.didExceedMaxLines;
      tp.dispose();
      if (over) {
        ok = false;
        break;
      }
    }
    if (ok) return s;
  }
  return floor;
}

/// Les deux grandes cartes « Garde » (bleu) et « Promenade » (vert) de
/// l'accueil propriétaire, dessin 640. Mêmes clés (`owner_card_sitting`,
/// `owner_card_walking`), mêmes callbacks et même règle compact / grand que
/// `ServiceCards3110`.
class OwnerServiceCards640 extends StatelessWidget {
  const OwnerServiceCards640({
    super.key,
    required this.compact,
    required this.sittingTitle,
    required this.walkingTitle,
    required this.sittingSubtitle,
    required this.walkingSubtitle,
    required this.onSitting,
    required this.onWalking,
  });

  final bool compact;
  final String sittingTitle;
  final String walkingTitle;
  final String sittingSubtitle;
  final String walkingSubtitle;
  final VoidCallback onSitting;
  final VoidCallback onWalking;

  static const double _gap = 12;

  static TextScaler _scaler(BuildContext context) => MediaQuery.textScalerOf(
    context,
  ).clamp(maxScaleFactor: kOwnerCardMaxTextScale640);

  /// Hauteur commune des deux grandes cartes : elle suit la taille du texte
  /// (jusqu'à ×1,5) pour que titre + sous-titre sur 2 lignes tiennent
  /// toujours, sans `IntrinsicHeight` ni `stretch` (règles du projet).
  static double largeHeightFor(BuildContext context) {
    final TextScaler s = _scaler(context);
    return 100 +
        math.max(18.0, s.scale(18)) * 1.2 +
        math.max(12.0, s.scale(12)) * 1.4 * 2;
  }

  @override
  Widget build(BuildContext context) {
    final TextScaler s = _scaler(context);
    final TextDirection dir = Directionality.of(context);
    final TextStyle base = DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double cardW = (c.maxWidth - _gap) / 2;
        final double padH = cardW < 150 ? 14 : 16;
        final double titleSize;
        double subtitleSize = 0;
        // Carte étroite (écran de 360 dp et moins) : en version basse, la flèche
        // décorative s'efface pour laisser le titre lisible (toute la carte
        // reste tactile, l'action ne change pas).
        final bool dense = compact && cardW < 165;
        if (compact) {
          // 12 + pavé 36 + 8 + [titre] + 6 + flèche 24 + 12
          // étroit : 10 + pavé 32 + 6 + [titre] + 10
          titleSize = fitFontSize640(
            <String>[sittingTitle, walkingTitle],
            width: dense ? cardW - 58 : cardW - 98,
            start: s.scale(15),
            floor: 10.5,
            maxLines: 1,
            weight: FontWeight.w700,
            lineHeight: 1.15,
            base: base,
            direction: dir,
          );
        } else {
          titleSize = fitFontSize640(
            <String>[sittingTitle, walkingTitle],
            width: cardW - padH * 2,
            start: s.scale(18),
            floor: 13,
            maxLines: 1,
            weight: FontWeight.w700,
            lineHeight: 1.15,
            base: base,
            direction: dir,
          );
          subtitleSize = fitFontSize640(
            <String>[sittingSubtitle, walkingSubtitle],
            width: cardW - padH * 2,
            start: s.scale(12),
            floor: 10.5,
            maxLines: 2,
            weight: FontWeight.w500,
            lineHeight: 1.35,
            base: base,
            direction: dir,
          );
        }
        final double? height = compact ? null : largeHeightFor(context);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: OwnerServiceCard640(
                key: const ValueKey<String>('owner_card_sitting'),
                compact: compact,
                height: height,
                padH: padH,
                dense: dense,
                titleSize: titleSize,
                subtitleSize: subtitleSize,
                title: sittingTitle,
                subtitle: sittingSubtitle,
                icon: PawIcon.house,
                deco: HomeDeco640.dogAndCat,
                start: const Color(0xFF4C82F0),
                end: const Color(0xFF1F4FBF),
                arrow: const Color(0xFF2457C5),
                shadow: const Color(0x522457C5),
                onTap: onSitting,
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: OwnerServiceCard640(
                key: const ValueKey<String>('owner_card_walking'),
                compact: compact,
                height: height,
                padH: padH,
                dense: dense,
                titleSize: titleSize,
                subtitleSize: subtitleSize,
                title: walkingTitle,
                subtitle: walkingSubtitle,
                icon: PawIcon.walker,
                deco: HomeDeco640.dogOnLeash,
                start: const Color(0xFF34C26B),
                end: const Color(0xFF16893F),
                arrow: const Color(0xFF1F9A4B),
                shadow: const Color(0x521F9A4B),
                onTap: onWalking,
              ),
            ),
          ],
        );
      },
    );
  }
}

class OwnerServiceCard640 extends StatelessWidget {
  const OwnerServiceCard640({
    super.key,
    required this.compact,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.deco,
    required this.start,
    required this.end,
    required this.arrow,
    required this.shadow,
    required this.onTap,
    this.height,
    this.padH = 16,
    this.dense = false,
    this.titleSize = 18,
    this.subtitleSize = 12,
  });

  final bool compact;
  final double? height;
  final double padH;

  /// Version basse sur une carte de moins de 165 dp : pavé plus petit, pas de
  /// flèche (décor), pour garder le titre lisible.
  final bool dense;

  /// Tailles DÉJÀ mises à l'échelle (le texte est rendu sans rééchelonnage).
  final double titleSize;
  final double subtitleSize;
  final String title;
  final String subtitle;
  final PawIcon icon;
  final HomeDeco640 deco;
  final Color start;
  final Color end;
  final Color arrow;
  final Color shadow;
  final VoidCallback onTap;

  static const double _radius = 24;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(_radius);
    return Semantics(
      button: true,
      label: subtitle,
      child: DecoratedBox(
        // L'ombre vit HORS du Material rogné : douce, de la couleur de la
        // carte, portée vers le bas.
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shadow,
              blurRadius: 26,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[start, end],
              ),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              splashColor: Colors.white.withValues(alpha: 0.16),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              child: compact ? _compact(context) : _large(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(double size, double r, double iconSize) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(r),
      ),
      child: PawIconWidget(
        icon,
        size: iconSize,
        color: Colors.white,
        fill: Colors.white.withValues(alpha: 0.30),
      ),
    );
  }

  Widget _arrow(double size, double iconSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: end.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.north_east_rounded, size: iconSize, color: arrow),
    );
  }

  Widget _halo(double size, double top, double right) {
    return Positioned(
      top: top,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.13),
          ),
        ),
      ),
    );
  }

  Widget _large(BuildContext context) {
    return SizedBox(
      height: height ?? 156,
      child: Stack(
        children: <Widget>[
          _halo(132, -52, -44),
          // Filigrane : sous le texte, en bas à droite.
          Positioned(
            right: 8,
            bottom: 7,
            child: HomeSilhouette640(deco: deco, height: 56, opacity: 0.17),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padH, 16, padH, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[_tile(48, 16, 26), _arrow(32, 17)],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: pop3110(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: pop3110(
                      fontSize: subtitleSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.94),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compact(BuildContext context) {
    return SizedBox(
      height: kOwnerCardCompactHeight640,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _halo(96, -44, -30),
          Padding(
            padding: EdgeInsets.all(dense ? 10 : 12),
            child: Row(
              children: <Widget>[
                if (dense) _tile(32, 11, 18) else _tile(36, 12, 20),
                SizedBox(width: dense ? 6 : 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: pop3110(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                ),
                if (!dense) ...<Widget>[
                  const SizedBox(width: 6),
                  _arrow(24, 13),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
