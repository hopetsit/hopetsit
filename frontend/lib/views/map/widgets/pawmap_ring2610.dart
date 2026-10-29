// 623 (PAM, 26/10/2026) — maquette de Daniel « Améliorer boutons et profil
// PawMap » (~/hopetsit-social/design_pawmap_2610/, README + pawmap-markers.tsx).
//
// Valeurs reprises À L'IDENTIQUE de la maquette (pt = px logiques Flutter) :
//   · rond de profil style « A · Anneau » : 50, fond blanc, liseré
//     rgba(0,0,0,.16) 1, ombre 0 2 3 .25 + halo du rôle 0 4 10 -2 (.5),
//     anneau 5 centré à 5,5 du bord, centre 32 plein + icône blanche 20 ;
//     multi-rôle : anneau découpé (écart 6°), centre en camembert, icône
//     `pets`, pastilles de rôles 17 (contour blanc 2) sous le rond ;
//     couronne 17 (#f6b400, contour blanc 1,5, couronne #7a4500 7,5) en haut
//     à droite ; point « en direct » 10 (#e8452f, contour blanc 1,5) pulsé
//     (0 → 7 px, .55 → 0, 1,8 s) en bas à droite ;
//   · groupe : 48, fond blanc (#262123 en sombre), contour blanc 2,5 +
//     rgba(0,0,0,.18) 1, ombre 0 3 3 .25, anneau 7 segmenté (écart 5°),
//     nombre 15,5 extra-gras ; « dès X » seulement quand le groupe est ouvert ;
//   · bulle de prix : pilule blanche (padding 2, écart 2), un segment plein
//     par rôle (hauteur 24, 3/10), icône 12 dans un rond blanc 18, montant
//     12,5 gras + unité 9,5 medium blanc 88 %, pointe blanche 12 × 7 ;
//   · éclatement : 6 profils sur un cercle de 72, le reste sur 132 (× 0,95
//     en hauteur), aucun trait.
// Fonctions de dessin PURES (aucun état) — testées dans test/pam623_test.dart.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../widgets/paw_tab_bar.dart' show PawNavRole, kPawTabBarPalettes;
import 'pawmap_jewel.dart' show PawSymbols;
import 'pawmap_pins.dart' show PawSvgPath, PawMapPinPainter, PawMapLegend, kPawPinPoppins;

/// Variante « extras » (demande de LEO/BOB du 26/10, en attente de Daniel) :
/// halo PawBoost (option payante) et coche « identité vérifiée » gardés,
/// discrets, sur le rond Anneau. false = maquette stricte.
const bool kPawRingExtras2610 = true;

/// Prix posés sur les épingles par défaut : NON (maquette 26/10).
const bool kShowPinPrices2610 = false;

/// Couleurs des rôles de la maquette (pleines, vives — README §Couleurs).
class PawRole2610 {
  PawRole2610._();
  static const Color owner = Color(0xFFF23B16);
  static const Color sitter = Color(0xFF1A6CFF);
  static const Color walker = Color(0xFF12B350);
  static const Color gold = Color(0xFFF6B400);
  static const Color goldInk = Color(0xFF7A4500);
  static const Color live = Color(0xFFE8452F);
  static const Color clusterDark = Color(0xFF262123);
  static const Color inkLight = Color(0xFF1D1719);
  static const Color inkDark = Color(0xFFF6EFEC);
  static const Color mutedLight = Color(0xFF7A6F71);
  static const Color mutedDark = Color(0xFFA99C9E);

  static Color color(String role) {
    switch (role.trim().toLowerCase()) {
      case 'sitter':
        return sitter;
      case 'walker':
        return walker;
      default:
        return owner;
    }
  }

  /// Halo du rôle : la couleur à 50 % (`rgba(…, 0.5)`).
  static Color glow(String role) => color(role).withValues(alpha: 0.5);

  /// Icônes Material de la maquette : pets / home / directions_walk.
  static IconData icon(String role) {
    switch (role.trim().toLowerCase()) {
      case 'sitter':
        return PawSymbols.home;
      case 'walker':
        return PawSymbols.walk;
      default:
        return kPawPets2610;
    }
  }
}

/// `pets` (Material Symbols Rounded, même police figée que les boutons).
const IconData kPawPets2610 = IconData(0xe91d, fontFamily: 'PawSymbols');

/// Un segment de la bulle de prix.
class PawPriceSeg2610 {
  const PawPriceSeg2610(this.role, this.amount, this.unit);
  final String role;
  final String amount; // « 25 € »
  final String unit; // « /jour » (peut être vide)
  @override
  String toString() => '$role:$amount$unit';
}

/// Règle `visiblePrices()` de la maquette : propriétaire → prix des gardiens
/// et promeneurs ; gardien / promeneur → budget des propriétaires seulement ;
/// jamais son propre rôle ; multi-rôle = rôle ACTIF ([viewerRole]).
/// [personRoles] : rôles de la personne touchée ; [priceOf] : prix connu d'un
/// de ses rôles (null = pas de prix → pas de segment). Ordre fixe
/// propriétaire → gardien → promeneur. Pure.
List<PawPriceSeg2610> pawVisiblePrices2610(
  String viewerRole,
  Iterable<String> personRoles,
  ({String amount, String unit})? Function(String role) priceOf,
) {
  final v = viewerRole.trim().toLowerCase();
  final allowed = v == 'owner' || v.isEmpty
      ? const <String>{'sitter', 'walker'}
      : const <String>{'owner'};
  final has = personRoles.map((r) => r.trim().toLowerCase()).toSet();
  final out = <PawPriceSeg2610>[];
  for (final r in const ['owner', 'sitter', 'walker']) {
    if (!allowed.contains(r) || !has.contains(r) || r == v) continue;
    final p = priceOf(r);
    if (p == null || p.amount.isEmpty) continue;
    out.add(PawPriceSeg2610(r, p.amount, p.unit));
  }
  return out;
}

/// Sépare « 25 €/jour » en montant + unité (« 25 € », « /jour »).
({String amount, String unit}) pawSplitPrice2610(String text) {
  final t = text.trim();
  final i = t.indexOf('/');
  if (i <= 0) return (amount: t, unit: '');
  return (amount: t.substring(0, i).trim(), unit: t.substring(i));
}

/// Éclatement d'un groupe (spiderfy de la maquette) : décalages ÉCRAN (pt)
/// autour du centre. 6 profils sur 72, le reste sur 132 (× 0,95 en y). Pure.
List<Offset> pawSpiderfy2610(int n) {
  // Maquette : 6 sur 72, le reste sur 132. Au-delà de 21 profils (les ronds
  // de 50 se toucheraient sur 132), 15 sur 132 puis le reste sur 192.
  final inner = math.min(n, 6);
  final second = n > 21 ? 15 : n - inner;
  return List<Offset>.generate(n, (j) {
    final ring = j < inner ? 0 : (j < inner + second ? 1 : 2);
    final cnt = ring == 0 ? inner : (ring == 1 ? second : n - inner - second);
    final idx = ring == 0 ? j : (ring == 1 ? j - inner : j - inner - second);
    final rad = ring == 0 ? 72.0 : (ring == 1 ? 132.0 : 192.0);
    final a = (idx / cnt) * math.pi * 2 -
        math.pi / 2 +
        (ring >= 1 ? math.pi / cnt : 0);
    return Offset(math.cos(a) * rad, math.sin(a) * rad * (ring >= 1 ? 0.95 : 1));
  });
}

/// Nombre maximal de profils éclatés (3 cercles : 6 + 15 + 24).
const int kSpiderMax2610 = 45;

/// Rayon (pt) occupé par un éclatement de [n] profils (rond 25 + halo).
double pawSpiderRadius2610(int n) => (n > 21 ? 192.0 : (n > 6 ? 132.0 : 72.0)) + 25 + 14;

/// Échelle du rond SÉLECTIONNÉ au temps [ms] : ressort de la maquette
/// (Animated.spring friction 5 · tension 160 → raideur 664,6, amortissement
/// 16, masse 1), de 1 vers 1,18. Pure.
double pawSpringScale2610(double ms, {double from = 1, double to = 1.18}) {
  const double k = 664.6, c = 16, m = 1;
  final w0 = math.sqrt(k / m);
  final zeta = c / (2 * math.sqrt(k * m));
  final wd = w0 * math.sqrt(1 - zeta * zeta);
  final t = ms / 1000;
  final x0 = from - to;
  final e = math.exp(-zeta * w0 * t);
  final x = e * (x0 * math.cos(wd * t) + (zeta * w0 * x0 / wd) * math.sin(wd * t));
  return to + x;
}

/// Pas d'animation du ressort (ms) : 0, 40, … 480 ; au-delà : 1,18.
const List<int> kPawSpringSteps2610 = <int>[0, 40, 80, 120, 160, 200, 240, 300, 360, 420, 480];

// ── géométrie des images ─────────────────────────────────────────────────

/// Marge autour du rond (halo 0 4 10 -2 et couronne). 630 (Daniel : « les
/// halos ne sont pas assez voyants ») : 14 → 22 pour loger le liseré blanc
/// 3 + l'anneau plein 8 + la lueur large de PawBoost / PawFollow (site).
const double kRingMargin2610 = 22;

/// Taille de l'image d'un rond à l'échelle [s] (multi = pastilles dessous).
Size pawRingBitmap2610(double s, {required bool multi}) {
  final top = (25 + kRingMargin2610) * s;
  final bottom = (multi ? 25 + 17 + 3 + 6 : 25 + kRingMargin2610) * s;
  return Size(2 * (25 + kRingMargin2610) * s, top + math.max(bottom, (25 + kRingMargin2610) * s));
}

/// Ancre (centre du rond) dans l'image.
Offset pawRingAnchor2610(double s, {required bool multi}) {
  final sz = pawRingBitmap2610(s, multi: multi);
  return Offset(0.5, ((25 + kRingMargin2610) * s) / sz.height);
}

/// Boîte VISIBLE (relative au centre) d'un rond, pour le placement.
Rect pawRingBox2610({required bool multi, bool premium = false}) =>
    Rect.fromLTRB(-25, premium ? -29.5 : -25, premium ? 29.5 : 25, multi ? 34 : 25);

// ── dessin ───────────────────────────────────────────────────────────────

Path _circle(Offset c, double r) => Path()..addOval(Rect.fromCircle(center: c, radius: r));

/// Arc de [a0] à [a1] degrés, 0 = en haut, sens horaire (helper `arc`).
Rect _ringRect(Offset c, double r) => Rect.fromCircle(center: c, radius: r);
double _rad(double deg) => (deg - 90) * math.pi / 180;

/// FontAwesome 6 « crown » (solide, CC BY 4.0) — boîte 576 × 512.
const String _faCrown =
    'M309 106c11.4-7 19-19.7 19-34c0-22.1-17.9-40-40-40s-40 17.9-40 40c0 14.4 7.6 27 19 34L209.7 220.6c-9.1 18.2-32.7 23.4-48.6 10.7L72 160c5-6.7 8-15 8-24c0-22.1-17.9-40-40-40S0 113.9 0 136s17.9 40 40 40c.2 0 .5 0 .7 0L86.4 427.4c5.5 30.4 32 52.6 63 52.6H426.6c30.9 0 57.4-22.1 63-52.6L535.3 176c.2 0 .5 0 .7 0c22.1 0 40-17.9 40-40s-17.9-40-40-40s-40 17.9-40 40c0 9 3 17.3 8 24l-89.1 71.3c-15.9 12.7-39.5 7.5-48.6-10.7L309 106z';
Path? _crownPath;

void _drawFaCrown(Canvas canvas, Offset c, double fontSize, Color color) {
  final p = _crownPath ??= PawSvgPath.parse(_faCrown);
  // FontAwesome : 1 em = 512 unités ; la couronne fait 576 × 448 (32 → 480).
  final k = fontSize / 512;
  canvas.save();
  canvas.translate(c.dx - 288 * k, c.dy - 256 * k);
  canvas.scale(k, k);
  canvas.drawPath(p, Paint()..color = color);
  canvas.restore();
}

/// Rond de profil « A · Anneau » centré en [c] (échelle déjà appliquée au
/// canvas par l'appelant). [livePhase] 0..1 (null = pas de point en direct).
void paintRing2610(
  Canvas canvas,
  Offset c, {
  required List<String> roles,
  bool premium = false,
  double? livePhase,
  double? boostPhase,
  bool verified = false,
  bool? status,
  int pin618 = 0,
  bool pawFollow = false,
}) {
  final rs = roles.isEmpty ? const <String>['owner'] : roles;
  final n = rs.length;
  final main = rs.first;
  final disc = _circle(c, 25);
  // 630 (Daniel, 30/10 : « les halos bleu, turquoise et violet ne sont pas
  // assez voyants ») — mêmes valeurs que le site de LEO (`boostGlowStyle`,
  // `hps-breathe`, halo PawFollow) : liseré BLANC 3 pt, anneau PLEIN 8 pt,
  // lueur large (24-32 pt) qui respire, lisible sur carte claire et sombre.
  if (kPawRingExtras2610 && boostPhase != null) {
    final k = 0.5 + 0.5 * math.sin(boostPhase * 2 * math.pi);
    PawMapPinPainter.drawCssGlow(canvas, c, 25, 25 + kRingMargin2610 - 0.5, PawMapLegend.boost, [
      (8 + k, 0, 0.98),
      (8 + 4 * k, 24 + 8 * k, 0.8 + 0.1 * k),
    ]);
  }
  // PawFollow : halo violet net (un seul halo : PawBoost passe devant).
  if (kPawRingExtras2610 && boostPhase == null && pawFollow) {
    PawMapPinPainter.drawCssGlow(canvas, c, 25, 25 + kRingMargin2610 - 0.5, PawMapLegend.pawFollow, [
      (8, 0, 0.95),
      (10, 30, 0.85),
    ]);
  }
  final bool halo630 = kPawRingExtras2610 && (boostPhase != null || pawFollow);
  // box-shadow (CSS : le 1er listé est dessus → on peint à l'envers).
  PawMapPinPainter.cssShadow(canvas, disc,
      dy: 4, blur: 10, spread: -2, color: PawRole2610.glow(main));
  PawMapPinPainter.cssShadow(canvas, disc,
      dy: 2, blur: 3, color: const Color(0x40000000));
  if (halo630) {
    // 630 — liseré BLANC 3 pt entre le rond et l'anneau plein (site : `0 0 0 3px #fff`),
    // posé APRÈS les ombres pour rester blanc ; le filet gris .16 du rond saute.
    canvas.drawCircle(c, 28, Paint()..color = Colors.white);
  } else {
    canvas.drawCircle(c, 26, Paint()..color = const Color(0x29000000)); // .16
  }
  canvas.drawCircle(c, 25, Paint()..color = Colors.white);
  // Anneau 5 pt, centré à 5,5 du bord (r 19,5).
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..isAntiAlias = true;
  if (n == 1) {
    canvas.drawCircle(c, 19.5, ring..color = PawRole2610.color(main));
  } else {
    for (var i = 0; i < n; i++) {
      final a0 = i / n * 360 + 6, a1 = (i + 1) / n * 360;
      canvas.drawArc(_ringRect(c, 19.5), _rad(a0), (a1 - a0) * math.pi / 180,
          false, ring..color = PawRole2610.color(rs[i]));
    }
  }
  // Centre 32 pt plein (camembert si multi-rôle).
  if (n == 1) {
    canvas.drawCircle(c, 16, Paint()..color = PawRole2610.color(main));
  } else {
    for (var i = 0; i < n; i++) {
      final a0 = i / n * 360, a1 = (i + 1) / n * 360;
      canvas.drawArc(_ringRect(c, 16), _rad(a0), (a1 - a0) * math.pi / 180,
          true, Paint()..color = PawRole2610.color(rs[i]));
    }
  }
  PawMapPinPainter.drawIcon(canvas, n > 1 ? kPawPets2610 : PawRole2610.icon(main),
      c, 20, Colors.white);
  // Pastilles de rôles 17 (contour blanc 2) sous le rond, écart 4, top +17.
  if (n > 1) {
    const double d = 17, gap = 4;
    final total = n * d + (n - 1) * gap;
    for (var i = 0; i < n; i++) {
      final cc = Offset(c.dx - total / 2 + d / 2 + i * (d + gap), c.dy + 17 + d / 2);
      PawMapPinPainter.cssShadow(canvas, _circle(cc, d / 2), dy: 2, blur: 3,
          color: const Color(0x4D000000));
      canvas.drawCircle(cc, d / 2 + 3, Paint()..color = const Color(0x1F000000));
      canvas.drawCircle(cc, d / 2 + 2, Paint()..color = Colors.white);
      canvas.drawCircle(cc, d / 2, Paint()..color = PawRole2610.color(rs[i]));
      PawMapPinPainter.drawIcon(canvas, PawRole2610.icon(rs[i]), cc, 10.5, Colors.white);
    }
  }
  // Couronne premium 17, haut-droite (right −4, top −4).
  if (premium) {
    final cc = Offset(c.dx + 25 + 4 - 8.5, c.dy - 25 - 4 + 8.5);
    PawMapPinPainter.cssShadow(canvas, _circle(cc, 8.5), dy: 1, blur: 3,
        color: const Color(0x40000000));
    canvas.drawCircle(cc, 10, Paint()..color = Colors.white);
    canvas.drawCircle(cc, 8.5, Paint()..color = PawRole2610.gold);
    _drawFaCrown(canvas, cc, 7.5, PawRole2610.goldInk);
  }
  // Signes existants gardés (Daniel 26/10 : « pawboost pawspot etc faut
  // laisser »), mêmes places que le site de LEO (pawmap2610.ts) :
  //  · coche « identité vérifiée » 15 en bas à gauche (multi-rôle : milieu
  //    du bord droit, le bas est aux pastilles) ;
  //  · fusée PawBoost 15 au milieu du bord gauche ;
  //  · pin du podium 16 en haut à gauche ;
  //  · point en ligne (vert) / hors ligne (orange) 10 en bas à droite, à la
  //    place du point « en direct », qui passe devant.
  if (kPawRingExtras2610 && verified) {
    final cc = n > 1 ? Offset(c.dx + 23.5, c.dy - 3.5) : Offset(c.dx - 18.5, c.dy + 18.5);
    PawMapPinPainter.cssShadow(canvas, _circle(cc, 7.5), dy: 1, blur: 3,
        color: const Color(0x40000000));
    canvas.drawCircle(cc, 9, Paint()..color = Colors.white);
    PawMapPinPainter.drawVerifiedBadge(canvas, cc, 15);
  }
  if (kPawRingExtras2610 && boostPhase != null) {
    final cc = Offset(c.dx - 23.5, c.dy);
    PawMapPinPainter.drawRocketBadge(canvas, cc, 15);
  }
  if (kPawRingExtras2610 && pin618 > 0) {
    PawMapPinPainter.drawPin618(canvas, Offset(c.dx - 20.5, c.dy - 20.5), pin618, 16);
  }
  final dot = Offset(c.dx + 20, c.dy + (n > 1 ? 11 : 20));
  if (livePhase != null) {
    // Point « en direct » 10, bas-droite, pulsé (0 → 7 px, .55 → 0 à 70 %).
    final p = livePhase % 1;
    if (p < 0.7) {
      final k = p / 0.7;
      canvas.drawCircle(dot, 5 + 7 * k,
          Paint()..color = PawRole2610.live.withValues(alpha: 0.55 * (1 - k)));
    }
    canvas.drawCircle(dot, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(dot, 5, Paint()..color = PawRole2610.live);
  } else if (kPawRingExtras2610 && status != null) {
    canvas.drawCircle(dot, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(dot, 5,
        Paint()..color = status ? const Color(0xFF16A34A) : const Color(0xFFC2410C));
  }
}

/// Image complète d'un rond (échelle [s]).
void paintRingBitmap2610(
  Canvas canvas, {
  required List<String> roles,
  bool premium = false,
  double? livePhase,
  double? boostPhase,
  bool verified = false,
  bool? status,
  int pin618 = 0,
  bool pawFollow = false,
  double s = 1,
}) {
  final top = (25 + kRingMargin2610) * s;
  final cx = (25 + kRingMargin2610) * s;
  canvas.save();
  canvas.translate(cx, top);
  canvas.scale(s, s);
  paintRing2610(canvas, Offset.zero,
      roles: roles,
      premium: premium,
      livePhase: livePhase,
      boostPhase: boostPhase,
      verified: verified,
      status: status,
      pin618: pin618,
      pawFollow: pawFollow);
  canvas.restore();
}

// ── groupe ───────────────────────────────────────────────────────────────

const double kClusterMargin2610 = 8;

TextPainter _tp(String t, double size, FontWeight w, Color color,
    {double letterSpacing = 0}) =>
    TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontFamily: kPawPinPoppins,
          fontFamilyFallback: const ['Roboto'],
          fontSize: size,
          fontWeight: w,
          color: color,
          height: 1.0,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

/// Étiquette « dès X » sous un groupe ouvert : (préfixe, prix).
Size pawClusterLabelSize2610(String prefix, String price) {
  final a = _tp(prefix, 10, FontWeight.w600, Colors.black);
  final b = _tp(price, 12, FontWeight.w800, Colors.black);
  return Size(10 + a.width + (prefix.isEmpty ? 0 : 3) + b.width + 10, 22);
}

Size pawClusterBitmap2610({String? labelPrefix, String? labelPrice}) {
  double w = 48 + 2 * kClusterMargin2610;
  double h = 48 + 2 * kClusterMargin2610;
  if (labelPrice != null && labelPrice.isNotEmpty) {
    final l = pawClusterLabelSize2610(labelPrefix ?? '', labelPrice);
    w = math.max(w, l.width + 2 * kClusterMargin2610);
    h = kClusterMargin2610 + 24 + 27 + 22 + kClusterMargin2610;
  }
  return Size(w, h);
}

Offset pawClusterAnchor2610({String? labelPrefix, String? labelPrice}) {
  final sz = pawClusterBitmap2610(labelPrefix: labelPrefix, labelPrice: labelPrice);
  return Offset(0.5, (kClusterMargin2610 + 24) / sz.height);
}

/// Groupe : [counts] par rôle principal (ordre walker → owner → sitter).
void paintCluster2610(
  Canvas canvas, {
  required int count,
  required Map<String, int> counts,
  bool dark = false,
  String? labelPrefix,
  String? labelPrice,
  String labelRole = 'sitter',
}) {
  final sz = pawClusterBitmap2610(labelPrefix: labelPrefix, labelPrice: labelPrice);
  final c = Offset(sz.width / 2, kClusterMargin2610 + 24);
  final disc = _circle(c, 24);
  PawMapPinPainter.cssShadow(canvas, disc, dy: 3, blur: 3, color: const Color(0x40000000));
  canvas.drawCircle(c, 27.5, Paint()..color = const Color(0x2E000000)); // .18
  canvas.drawCircle(c, 26.5, Paint()..color = Colors.white);
  canvas.drawCircle(c, 24, Paint()..color = dark ? PawRole2610.clusterDark : Colors.white);
  final parts = <(String, int)>[
    for (final r in const ['walker', 'owner', 'sitter'])
      if ((counts[r] ?? 0) > 0) (r, counts[r]!),
  ];
  final tot = parts.fold<int>(0, (s, p) => s + p.$2);
  if (tot > 0) {
    var acc = 0;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..isAntiAlias = true;
    for (final (r, v) in parts) {
      final a0 = acc / tot * 360 + 5;
      acc += v;
      final a1 = acc / tot * 360;
      canvas.drawArc(_ringRect(c, 19), _rad(a0), (a1 - a0) * math.pi / 180, false,
          ring..color = PawRole2610.color(r));
    }
  }
  final t = _tp('${count > 99 ? '99+' : count}', 15.5, FontWeight.w800,
      dark ? PawRole2610.inkDark : PawRole2610.inkLight,
      letterSpacing: -0.5);
  t.paint(canvas, Offset(c.dx - t.width / 2, c.dy - t.height / 2));
  if (labelPrice != null && labelPrice.isNotEmpty) {
    final pre = labelPrefix ?? '';
    final l = pawClusterLabelSize2610(pre, labelPrice);
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - l.width / 2, c.dy + 27, l.width, 22),
        const Radius.circular(11));
    final path = Path()..addRRect(r);
    PawMapPinPainter.cssShadow(canvas, path,
        dy: 4, blur: 10, spread: -4, color: const Color(0x4D000000));
    canvas.drawRRect(r, Paint()..color = dark ? PawRole2610.clusterDark : Colors.white);
    canvas.drawRRect(
        r.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = PawRole2610.color(labelRole).withValues(alpha: 0x55 / 255));
    final a = _tp(pre, 10, FontWeight.w600, dark ? PawRole2610.mutedDark : PawRole2610.mutedLight);
    final b = _tp(labelPrice, 12, FontWeight.w800, PawRole2610.color(labelRole));
    var x = r.left + 10;
    final cy = r.center.dy;
    if (pre.isNotEmpty) {
      a.paint(canvas, Offset(x, cy - a.height / 2 + 1));
      x += a.width + 3;
    }
    b.paint(canvas, Offset(x, cy - b.height / 2));
  }
}

// ── bulle de prix ────────────────────────────────────────────────────────

const double kBubbleMargin2610 = 6;
/// La pointe est 31 pt au-dessus du centre du rond (6 sous la bulle + 25).
const double kBubbleLift2610 = 31;

double _segW(PawPriceSeg2610 s) {
  final a = _tp(s.amount, 12.5, FontWeight.w700, Colors.white, letterSpacing: -0.125);
  final u = s.unit.isEmpty ? 0.0 : _tp(s.unit, 9.5, FontWeight.w500, Colors.white).width + 1;
  return 3 + 18 + 6 + a.width + u + 10;
}

/// Largeur du corps de la bulle (pilule blanche).
double pawBubbleBodyW2610(List<PawPriceSeg2610> segs) =>
    4 + segs.fold<double>(0, (s, x) => s + _segW(x)) + 2 * (segs.length - 1);

Size pawBubbleBitmap2610(List<PawPriceSeg2610> segs, {double lift = kBubbleLift2610}) => Size(
    pawBubbleBodyW2610(segs) + 2 * kBubbleMargin2610,
    kBubbleMargin2610 + 28 - 1 + 7 + lift);

/// Décalage horizontal de la pointe par rapport au centre de la bulle pour
/// que la bulle reste à [margin] des bords d'un écran de largeur [screenW],
/// le rond étant à l'abscisse [markerX]. Pure (règle de la maquette).
double pawBubbleTailDx2610(double bodyW, double markerX, double screenW,
    {double margin = 12, double? left, double? right}) {
  final half = bodyW / 2;
  // [left] / [right] : bords utiles (barre de gauche, capsule de droite à la
  // hauteur de la bulle) ; sinon les bords de l'écran à [margin].
  final double l = math.max(margin, left ?? 0);
  final double r = math.min(screenW - margin, right ?? screenW);
  final lo = l + half - markerX; // décalage du CORPS
  final hi = r - half - markerX;
  double bodyDx = 0;
  if (lo > hi) {
    bodyDx = (l + r) / 2 - markerX;
  } else {
    bodyDx = math.max(lo, math.min(hi, 0));
  }
  // La bulle reste dans l'écran ; la pointe reste sous la pilule.
  final maxTail = math.max(0.0, half - 6);
  return (-bodyDx).clamp(-maxTail, maxTail);
}

/// Ancre de la bulle : la pointe, 31 pt sous laquelle se trouve le rond.
Offset pawBubbleAnchor2610(List<PawPriceSeg2610> segs, double tailDx,
    {double lift = kBubbleLift2610}) {
  final sz = pawBubbleBitmap2610(segs, lift: lift);
  return Offset((sz.width / 2 + tailDx) / sz.width, 1.0);
}

void paintBubble2610(Canvas canvas, List<PawPriceSeg2610> segs, {double tailDx = 0}) {
  if (segs.isEmpty) return;
  final bodyW = pawBubbleBodyW2610(segs);
  final left = kBubbleMargin2610;
  final top = kBubbleMargin2610;
  final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, bodyW, 28), const Radius.circular(14));
  final tipX = left + bodyW / 2 + tailDx;
  final tail = Path()
    ..moveTo(tipX - 6, top + 27)
    ..lineTo(tipX + 6, top + 27)
    ..lineTo(tipX, top + 34)
    ..close();
  final shape = Path()
    ..addRRect(body)
    ..addPath(tail, Offset.zero);
  // drop-shadow(0 0 .6px rgba(0,0,0,.4)) + drop-shadow(0 2px 2px rgba(0,0,0,.22)).
  PawMapPinPainter.cssShadow(canvas, shape, dy: 2, blur: 2, color: const Color(0x38000000));
  PawMapPinPainter.cssShadow(canvas, shape, blur: 1.2, color: const Color(0x66000000));
  canvas.drawPath(shape, Paint()..color = Colors.white);
  var x = left + 2;
  for (final s in segs) {
    final w = _segW(s);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, top + 2, w, 24), const Radius.circular(12));
    final col = PawRole2610.color(s.role);
    canvas.drawRRect(r, Paint()..color = col);
    final ic = Offset(x + 3 + 9, top + 2 + 12);
    canvas.drawCircle(ic, 9, Paint()..color = Colors.white);
    PawMapPinPainter.drawIcon(canvas, PawRole2610.icon(s.role), ic, 12, col);
    final a = _tp(s.amount, 12.5, FontWeight.w700, Colors.white, letterSpacing: -0.125);
    final tx = x + 3 + 18 + 6;
    // Ligne de base commune (montant 12,5 / unité 9,5).
    final base = top + 2 + 12 + 12.5 * 0.36;
    a.paint(canvas, Offset(tx, base - a.computeDistanceToActualBaseline(ui.TextBaseline.alphabetic)));
    if (s.unit.isNotEmpty) {
      final u = _tp(s.unit, 9.5, FontWeight.w500, const Color(0xE0FFFFFF));
      u.paint(canvas, Offset(tx + a.width + 1,
          base - u.computeDistanceToActualBaseline(ui.TextBaseline.alphabetic)));
    }
    x += w + 2;
  }
}

// ── 4 boutons du haut à droite ───────────────────────────────────────────

/// Bouton rond 38, fond PLEIN couleur du rôle actif, contour blanc 1,5 +
/// filet rgba(0,0,0,.12), ombre teintée 0 3 8 −2, icône blanche 19,
/// pression → échelle .94 (README §4).
class PawRoleButton2610 extends StatefulWidget {
  const PawRoleButton2610({
    super.key,
    required this.role,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.busy = false,
  });
  final String role;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? badge;
  final bool busy;

  @override
  State<PawRoleButton2610> createState() => _PawRoleButton2610State();
}

class _PawRoleButton2610State extends State<PawRoleButton2610> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    // Daniel (26/10) : en propriétaire, EXACTEMENT l'orange du menu du bas
    // (même constante, même dégradé haut → bas) ; gardien / promeneur :
    // couleurs pleines de la maquette.
    final bool owner = widget.role.trim().toLowerCase() != 'sitter' &&
        widget.role.trim().toLowerCase() != 'walker';
    final menu = kPawTabBarPalettes[PawNavRole.owner]!;
    final col = owner ? menu.top : PawRole2610.color(widget.role);
    final glow = owner ? menu.top.withValues(alpha: 0.5) : PawRole2610.glow(widget.role);
    final disc = AnimatedScale(
      scale: _down ? 0.94 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: owner ? null : col,
          gradient: owner
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [menu.top, menu.bottom])
              : null,
          shape: BoxShape.circle,
          // CSS : 0 3 8 −2 halo, 0 0 0 1.5 #fff, 0 0 0 2.5 rgba(0,0,0,.12)
          // (Flutter peint la liste dans l'ordre : le dernier est dessus).
          boxShadow: [
            const BoxShadow(color: Color(0x1F000000), spreadRadius: 2.5),
            const BoxShadow(color: Colors.white, spreadRadius: 1.5),
            BoxShadow(
                color: glow,
                offset: const Offset(0, 3),
                blurRadius: 8,
                spreadRadius: -2),
          ],
        ),
        child: widget.busy
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(widget.icon, size: 19, color: Colors.white),
      ),
    );
    return Semantics(
      button: true,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.busy ? null : widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                disc,
                if (widget.badge != null)
                  Positioned(right: -2, top: -2, child: widget.badge!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 625 — groupe de LIEUX au style « Anneau » ───────────────────────────
// Captures de l'Oppo (26/10) : « affichage ancien », des carrés blancs
// « 39 », « 10 », « 99+ », « 20 ». MESURÉ (sonde Android) : ce sont les
// groupes de LIEUX (vétos, parcs… couche « Lieux », marqueurs `pcluster_`),
// seul groupe encore dessiné en carré blanc (`paintSquareCluster`). Ils
// prennent le gabarit des groupes de membres 2610 : rond 48, liseré blanc,
// anneau plein de 7 à la couleur du type dominant, nombre 15,5.
void paintPlaceCluster625(Canvas canvas,
    {required int count, required Color tone, bool dark = false}) {
  final sz = pawClusterBitmap2610();
  final c = Offset(sz.width / 2, kClusterMargin2610 + 24);
  PawMapPinPainter.cssShadow(canvas, _circle(c, 24),
      dy: 3, blur: 3, color: const Color(0x40000000));
  canvas.drawCircle(c, 27.5, Paint()..color = const Color(0x2E000000));
  canvas.drawCircle(c, 26.5, Paint()..color = Colors.white);
  canvas.drawCircle(c, 24, Paint()..color = dark ? PawRole2610.clusterDark : Colors.white);
  canvas.drawCircle(
      c,
      19,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..isAntiAlias = true
        ..color = tone);
  final t = _tp('${count > 99 ? '99+' : count}', 15.5, FontWeight.w800,
      dark ? PawRole2610.inkDark : PawRole2610.inkLight,
      letterSpacing: -0.5);
  t.paint(canvas, Offset(c.dx - t.width / 2, c.dy - t.height / 2));
}
