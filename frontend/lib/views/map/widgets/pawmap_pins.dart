// v584 — lot C du chantier du 24/09 : LES ÉPINGLES DE LA PAWMAP.
//
// Source de vérité : ~/hopetsit-social/LEGENDE_PAWMAP.md (validée point par
// point par Daniel le 23/09/2026, partagée avec le site). Une FORME par
// famille, la couleur ne fait que préciser :
//   · rond   = une personne (Moi = ma photo 56 px + « Moi » ; ami = sa photo +
//              anneau rose ; membre = patte / maison / marcheur blanc sur la
//              couleur de son rôle, À TOUS LES ZOOMS) ;
//   · goutte = un lieu (entièrement à la couleur du type, icône blanche) ;
//   · carré  = un groupe de lieux (blanc, bord à la couleur dominante) ;
//   · noir & or = PawSpot (goutte noire liserée du type ; doré = goutte OR
//              plus grande, patte noire ; groupe = carré noir, chiffre or) ;
//   · pilule blanche = un groupe de membres (icône « personnes » + nombre) ;
//   · bulle orange foncé = une demande de propriétaire (prix dedans, sinon
//              l'icône du service).
// Repères en plus, jamais à la place de la couleur du rôle :
//   · Paw Premium = petite couronne OR contour noir, en haut à droite ;
//   · PawBoost   = lueur TURQUOISE qui respire + petite fusée (jamais l'or) ;
//   · amis        = anneau ROSE, point vert si en ligne ;
//   · mode « amis seulement » (sur MON rond) = anneau POINTILLÉ + œil barré.
//
// Tout est dessiné sur un Canvas à 2× (net sur écrans 3×) puis affiché à la
// taille logique via `BitmapDescriptor.bytes(width: …)`. Les fonctions de
// dessin sont PURES (canvas + paramètres) : les tests « golden » les
// rendent dans un widget et comparent l'image de référence, sans carte.
//
// Zéro gris (saturation), zéro emoji : icônes Material peintes comme glyphes.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Couleurs et tailles de la légende (LEGENDE_PAWMAP.md). NE JAMAIS les
/// réutiliser pour autre chose sur la carte.
class PawMapLegend {
  PawMapLegend._();

  static const Color owner = Color(0xFFC92A12);
  static const Color sitter = Color(0xFF2563EB);
  static const Color walker = Color(0xFF16A34A);
  static const Color pawFollow = Color(0xFF7C3AED);
  static const Color boost = Color(0xFF06B6D4);
  static const Color gold = Color(0xFFF4C04A);
  static const Color friend = Color(0xFFF06AA0);
  static const Color ink = Color(0xFF17141F);
  static const Color online = Color(0xFF22C55E);

  // Tailles logiques (px) de la légende.
  // v584 (25/09, Daniel : « mets plus en valeur les utilisateurs et les
  // PawSpots ») : les MEMBRES sont les plus visibles (48-56), les PawSpots
  // ressortent (36 / 44 doré), les lieux ordinaires restent discrets (30).
  static const double meSize = 56;
  static const double friendSize = 50;
  static const double memberSize = 46;
  static const double memberClusterHeight = 36;
  static const double placeSize = 30;
  static const double placeClusterSize = 34;
  static const double spotSize = 36;
  static const double spotGoldSize = 44;
  static const double spotClusterSize = 36;
  static const double requestBubbleHeight = 34;

  static const double crownMember = 20;
  static const double crownFriend = 22;
  static const double crownMe = 24;

  static Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'sitter':
        return sitter;
      case 'walker':
        return walker;
      default:
        return owner;
    }
  }

  /// Icône blanche par rôle (daltoniens, idée 5 validée) : propriétaire =
  /// patte, gardien = maison, promeneur = personnage qui marche.
  static IconData roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'sitter':
        return Icons.home_rounded;
      case 'walker':
        return Icons.directions_walk_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  /// Couleur PLEINE d'un type de lieu (OSM). Palette écartée des couleurs
  /// réservées (rôles, PawFollow, PawBoost, or, rose) : parc et eau prennent
  /// un vert / bleu-vert plus SOMBRE et plein (légende), jamais une lueur.
  static Color placeColor(String category) {
    switch (category) {
      case 'vet':
        return const Color(0xFF9F1239); // framboise sombre
      case 'park':
        return const Color(0xFF166534); // vert forêt (plus sombre que promeneur)
      case 'water':
        return const Color(0xFF0E7490); // bleu-vert sombre (plus sombre que boost)
      case 'shop':
        return const Color(0xFFB45309); // ambre brûlé
      case 'groomer':
        return const Color(0xFFC026D3); // fuchsia
      case 'beach':
        return const Color(0xFF7C2D12); // rouille
      case 'trainer':
        return const Color(0xFF65A30D); // citron vert
      case 'hotel':
        return const Color(0xFF3F6212); // olive
      case 'restaurant':
        return const Color(0xFF92400E); // brun chaud
      default:
        return const Color(0xFF6B4F3A); // brun (teinte chaude, jamais gris)
    }
  }

  static IconData placeIcon(String category) {
    switch (category) {
      case 'vet':
        return Icons.medical_services_rounded;
      case 'park':
        return Icons.park_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'shop':
        return Icons.storefront_rounded;
      case 'groomer':
        return Icons.content_cut_rounded;
      case 'beach':
        return Icons.beach_access_rounded;
      case 'trainer':
        return Icons.school_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  static IconData spotIcon(String type) {
    switch (type) {
      case 'path_walk':
        return Icons.directions_walk_rounded;
      case 'chill':
        return Icons.self_improvement_rounded;
      case 'playground':
        return Icons.sports_soccer_rounded;
      case 'swimming':
        return Icons.pool_rounded;
      case 'food_cafe':
        return Icons.local_cafe_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  static Color darken(Color c, [double amount = 0.22]) =>
      Color.lerp(c, Colors.black, amount)!;
  static Color lighten(Color c, [double amount = 0.22]) =>
      Color.lerp(c, Colors.white, amount)!;
}

/// Nombre de phases de la respiration PawBoost (4 bitmaps par épingle
/// boostée, mis en cache : la carte ne redessine que ces marqueurs-là).
const int kBoostPhases = 4;

/// Peintres purs. Toutes les coordonnées sont en pixels LOGIQUES : l'appelant
/// applique `canvas.scale(2, 2)` avant et alloue une image 2× après.
class PawMapPinPainter {
  PawMapPinPainter._();

  // ── briques ────────────────────────────────────────────────────────────

  static void drawIcon(Canvas canvas, IconData icon, Offset center,
      double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  static void drawText(Canvas canvas, String text, Offset center, double size,
      Color color,
      {FontWeight weight = FontWeight.w800}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: color,
            height: 1.0,
            // Roboto (embarquée par Flutter sur Android, présente dans le SDK
            // pour les tests) ; iOS retombe sur sa police système.
            fontFamily: 'Roboto'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  static void drawShadow(Canvas canvas, Path shape, {double blur = 3}) {
    canvas.drawPath(
      shape.shift(const Offset(0, 1.6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  /// Lueur TURQUOISE qui respire (PawBoost). [phase] 0..1 → sinus doux.
  static void drawBoostGlow(Canvas canvas, Offset center, double radius,
      double phase) =>
      drawGlow(canvas, center, radius, phase, PawMapLegend.boost);

  /// Lueur qui respire (PawBoost turquoise, PawFollow violet pour la
  /// personne suivie en direct — v584 25/09).
  static void drawGlow(Canvas canvas, Offset center, double radius,
      double phase, Color color) {
    final s = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);
    final r = radius + 5 + 6 * s;
    canvas.drawCircle(
      center,
      r + 6,
      Paint()
        ..color = color.withValues(alpha: 0.28 + 0.22 * s)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.55 + 0.35 * s)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  /// Petite fusée blanche sur pastille turquoise (même icône que le bouton
  /// Boost de l'accueil), en bas à gauche du rond.
  static void drawRocketBadge(Canvas canvas, Offset center, double size) {
    canvas.drawCircle(center, size / 2 + 1.5, Paint()..color = Colors.white);
    canvas.drawCircle(center, size / 2, Paint()..color = PawMapLegend.boost);
    drawIcon(canvas, Icons.rocket_launch_rounded, center, size * 0.64,
        Colors.white);
  }

  /// Couronne Paw Premium : or, contour noir, en haut à droite du rond.
  static void drawCrown(Canvas canvas, Offset center, double size) {
    final w = size, h = size * 0.78;
    final l = center.dx - w / 2, t = center.dy - h / 2;
    final path = Path()
      ..moveTo(l + w * 0.08, t + h * 0.92)
      ..lineTo(l + w * 0.02, t + h * 0.30)
      ..lineTo(l + w * 0.30, t + h * 0.55)
      ..lineTo(l + w * 0.50, t + h * 0.08)
      ..lineTo(l + w * 0.70, t + h * 0.55)
      ..lineTo(l + w * 0.98, t + h * 0.30)
      ..lineTo(l + w * 0.92, t + h * 0.92)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = PawMapLegend.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = PawMapLegend.gold);
    // Trois perles sur les pointes.
    for (final x in [0.02, 0.50, 0.98]) {
      canvas.drawCircle(
        Offset(l + w * x, t + h * (x == 0.50 ? 0.08 : 0.30)),
        w * 0.07,
        Paint()..color = PawMapLegend.ink,
      );
    }
  }

  /// Œil barré noir (mode « visible par mes amis seulement »), bas droite.
  static void drawEyeOffBadge(Canvas canvas, Offset center, double size) {
    canvas.drawCircle(center, size / 2 + 1.5, Paint()..color = Colors.white);
    canvas.drawCircle(center, size / 2, Paint()..color = PawMapLegend.ink);
    drawIcon(canvas, Icons.visibility_off_rounded, center, size * 0.62,
        Colors.white);
  }

  static void drawOnlineDot(Canvas canvas, Offset center, double size) {
    canvas.drawCircle(center, size / 2 + 1.5, Paint()..color = Colors.white);
    canvas.drawCircle(center, size / 2, Paint()..color = PawMapLegend.online);
  }

  static void drawDashedRing(Canvas canvas, Offset center, double radius,
      Color color, double width) {
    const dash = 5.0, gap = 3.5;
    final circumference = 2 * math.pi * radius;
    final n = (circumference / (dash + gap)).floor();
    final sweep = (circumference / n - gap) / radius;
    final step = 2 * math.pi / n;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, i * step, sweep, false, paint);
    }
  }

  /// Goutte (épingle) : pointe en bas = position exacte.
  static Path dropPath(double cx, double cy, double r, double tipY) {
    final p = Path();
    p.moveTo(cx, tipY);
    p.cubicTo(cx - r * 0.30, tipY - r * 0.62, cx - r * 1.02, cy + r * 0.78,
        cx - r, cy);
    p.arcToPoint(Offset(cx + r, cy), radius: Radius.circular(r), clockwise: true);
    p.cubicTo(cx + r * 1.02, cy + r * 0.78, cx + r * 0.30, tipY - r * 0.62,
        cx, tipY);
    p.close();
    return p;
  }

  // ── PERSONNES (ronds) ──────────────────────────────────────────────────

  /// Rond de MEMBRE : couleur du rôle à tous les zooms, icône blanche du
  /// rôle. [size] = diamètre logique (36). Bitmap carré `size + 2 * marge`.
  static void paintMemberDot(
    Canvas canvas, {
    required String role,
    double size = PawMapLegend.memberSize,
    bool crown = false,
    bool verified = false,
    bool online = false,
    bool selected = false,
    double? boostPhase,
    String? priceLabel,
    double rating = 0,
  }) {
    final margin = memberMargin;
    final r = size / 2;
    final c = Offset(margin + r, margin + r);
    final color = PawMapLegend.roleColor(role);
    if (boostPhase != null) drawBoostGlow(canvas, c, r, boostPhase);
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    drawShadow(canvas, circle);
    if (selected) {
      canvas.drawCircle(
        c,
        r + 3.5,
        Paint()
          ..color = PawMapLegend.darken(color).withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r, c.dy - r),
          Offset(c.dx + r, c.dy + r),
          [PawMapLegend.lighten(color, 0.14), PawMapLegend.darken(color, 0.16)],
        ),
    );
    // Liseré blanc (lisible en mode nuit aussi).
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    // Reflet doux (relief, sans effet bille).
    canvas.save();
    canvas.clipPath(circle);
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(0, -r * 0.45), width: r * 1.3, height: r * 0.6),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.restore();
    drawIcon(canvas, PawMapLegend.roleIcon(role), c, r * 1.1, Colors.white);
    if (online) {
      drawOnlineDot(canvas, Offset(c.dx + r * 0.68, c.dy + r * 0.68), r * 0.42);
    }
    if (verified) {
      final vc = Offset(c.dx - r * 0.72, c.dy + r * 0.66);
      canvas.drawCircle(vc, r * 0.30 + 1.5, Paint()..color = Colors.white);
      canvas.drawCircle(vc, r * 0.30, Paint()..color = PawMapLegend.sitter);
      drawIcon(canvas, Icons.check_rounded, vc, r * 0.42, Colors.white);
    }
    if (boostPhase != null) {
      drawRocketBadge(canvas, Offset(c.dx - r * 0.72, c.dy + r * 0.66),
          r * 0.62);
    }
    if (crown) {
      drawCrown(canvas, Offset(c.dx + r * 0.72, c.dy - r * 0.72),
          PawMapLegend.crownMember);
    }
    if (priceLabel != null && priceLabel.isNotEmpty) {
      _paintLabel(canvas, priceLabel, Offset(c.dx, c.dy + r + 9),
          textColor: PawMapLegend.darken(color, 0.30), rating: rating);
    }
  }

  /// Marge autour du rond de membre (couronne, lueur, étiquette de prix).
  static const double memberMargin = 14;

  /// Hauteur totale d'un bitmap de membre (avec la marge basse pour le prix).
  static double memberBitmapSize(double size, {bool withLabel = false}) =>
      size + 2 * memberMargin + (withLabel ? 12 : 0);

  /// Étiquette blanche sous une épingle : « 25 € », et, si une note est
  /// fournie (idée 2, zoom rue), une petite étoile or + « 4,8 ».
  static void _paintLabel(Canvas canvas, String text, Offset topCenter,
      {required Color textColor, double rating = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: textColor,
            fontFamily: 'Roboto'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    TextPainter? rp;
    const double star = 9;
    if (rating > 0) {
      rp = TextPainter(
        text: TextSpan(
          text: rating.toStringAsFixed(1),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: PawMapLegend.darken(PawMapLegend.gold, 0.35),
              fontFamily: 'Roboto'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final extra = rp == null ? 0.0 : 6 + star + 1 + rp.width;
    final w = tp.width + 10 + extra;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: topCenter.translate(0, tp.height / 2 + 2),
        width: w,
        height: tp.height + 5,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    final left = topCenter.dx - w / 2 + 5;
    tp.paint(canvas, Offset(left, topCenter.dy + 2));
    if (rp != null) {
      final sx = left + tp.width + 6;
      drawIcon(canvas, Icons.star_rounded,
          Offset(sx + star / 2, topCenter.dy + 2 + tp.height / 2), star + 2,
          PawMapLegend.gold);
      rp.paint(canvas, Offset(sx + star + 1, topCenter.dy + 2));
    }
  }

  /// Rond PHOTO : Moi (56, anneau à la couleur de mon rôle, étiquette « Moi »)
  /// ou un ami (44, anneau rose). [avatar] null → patte blanche sur la teinte.
  static void paintPhotoDot(
    Canvas canvas, {
    required ui.Image? avatar,
    required Color ringColor,
    required double size,
    String? label,
    Color? labelColor,
    bool crown = false,
    double crownSize = PawMapLegend.crownFriend,
    bool online = false,
    bool dashedRing = false,
    bool eyeOff = false,
    double? boostPhase,
    // v584 (25/09) — auréole VIOLETTE qui respire : la personne que je suis
    // en direct (PawFollow). Un seul halo par rond : PawBoost > PawFollow.
    double? followPhase,
    // v584 (25/09) — « signal perdu » : rond éteint à la couleur du rôle
    // (anneau plus clair, photo voilée), jamais gris.
    bool dimmed = false,
    // v584 (25/09) — icône du rôle quand il n'y a pas de photo.
    IconData fallbackIcon = Icons.pets_rounded,
    Color fallbackTint = PawMapLegend.owner,
  }) {
    final margin = photoMargin;
    final r = size / 2;
    final c = Offset(margin + r, margin + r);
    if (boostPhase != null) {
      drawBoostGlow(canvas, c, r, boostPhase);
    } else if (followPhase != null) {
      drawGlow(canvas, c, r, followPhase, PawMapLegend.pawFollow);
    }
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    drawShadow(canvas, circle, blur: 3.5);
    // Anneau (plein ou pointillé) puis liseré blanc, puis la photo.
    const ring = 3.2;
    const white = 2.0;
    final Color ringPaint = dimmed
        ? Color.lerp(ringColor, Colors.white, 0.45)!
        : ringColor;
    if (dashedRing) {
      canvas.drawCircle(c, r, Paint()..color = Colors.white);
      drawDashedRing(canvas, c, r - ring / 2, ringPaint, ring);
    } else {
      canvas.drawCircle(c, r, Paint()..color = ringPaint);
    }
    canvas.drawCircle(c, r - ring, Paint()..color = Colors.white);
    final photoR = r - ring - white;
    final photoRect = Rect.fromCircle(center: c, radius: photoR);
    canvas.save();
    canvas.clipPath(Path()..addOval(photoRect));
    if (avatar != null) {
      canvas.drawImageRect(
        avatar,
        Rect.fromLTWH(0, 0, avatar.width.toDouble(), avatar.height.toDouble()),
        photoRect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      canvas.drawRect(photoRect, Paint()..color = fallbackTint);
      drawIcon(canvas, fallbackIcon, c, photoR * 1.05, Colors.white);
    }
    if (dimmed) {
      // Voile chaud à la couleur du rôle (jamais gris) : « signal perdu ».
      canvas.drawRect(photoRect,
          Paint()..color = Color.lerp(ringColor, Colors.white, 0.35)!.withValues(alpha: 0.55));
    }
    // Reflet médaillon.
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(0, -photoR * 0.7),
          width: photoR * 1.7,
          height: photoR * 0.8),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();
    if (online) {
      drawOnlineDot(canvas, Offset(c.dx + r * 0.70, c.dy + r * 0.70), r * 0.40);
    }
    if (eyeOff) {
      drawEyeOffBadge(
          canvas, Offset(c.dx + r * 0.70, c.dy + r * 0.70), r * 0.56);
    }
    if (boostPhase != null) {
      drawRocketBadge(
          canvas, Offset(c.dx - r * 0.70, c.dy + r * 0.70), r * 0.56);
    }
    if (crown) {
      drawCrown(canvas, Offset(c.dx + r * 0.70, c.dy - r * 0.70), crownSize);
    }
    if (label != null && label.isNotEmpty) {
      _paintLabel(canvas, label, Offset(c.dx, c.dy + r + 6),
          textColor: labelColor ?? ringColor);
    }
  }

  static const double photoMargin = 16;
  static double photoBitmapSize(double size, {bool withLabel = false}) =>
      size + 2 * photoMargin + (withLabel ? 10 : 0);

  /// Pilule blanche d'un groupe de MEMBRES : icône « personnes » + nombre,
  /// bord et texte encre. Largeur adaptée au nombre.
  static void paintMemberCluster(Canvas canvas, int count,
      {Map<String, int>? roleCounts}) {
    final label = count > 99 ? '99+' : '$count';
    final h = PawMapLegend.memberClusterHeight;
    final w = memberClusterWidth(count);
    const m = 6.0;
    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(m, m, w, h), Radius.circular(h / 2));
    drawShadow(canvas, Path()..addRRect(rect));
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = PawMapLegend.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    // Petit arc de composition sous la pilule : une couleur par rôle présent
    // (proportionnel), pour dire d'un coup d'œil qui est dans le groupe.
    if (roleCounts != null) {
      final present = ['owner', 'sitter', 'walker']
          .where((k) => (roleCounts[k] ?? 0) > 0)
          .toList();
      if (present.isNotEmpty) {
        final total = present.fold<int>(0, (s, k) => s + roleCounts[k]!);
        double x = m + 10;
        final span = w - 20;
        for (final k in present) {
          final len = span * roleCounts[k]! / total;
          canvas.drawLine(
            Offset(x, m + h - 4),
            Offset(x + len - 2, m + h - 4),
            Paint()
              ..color = PawMapLegend.roleColor(k)
              ..strokeWidth = 2.6
              ..strokeCap = StrokeCap.round,
          );
          x += len;
        }
      }
    }
    drawIcon(canvas, Icons.people_alt_rounded, Offset(m + 15, m + h / 2 - 1),
        16, PawMapLegend.ink);
    drawText(canvas, label, Offset(m + 15 + 10 + (w - 34) / 2, m + h / 2 - 1),
        14, PawMapLegend.ink);
  }

  static double memberClusterWidth(int count) =>
      44 + (count > 99 ? 3 : (count > 9 ? 2 : 1)) * 9.0;

  // ── LIEUX (gouttes, carrés) ───────────────────────────────────────────

  /// Goutte de LIEU : entièrement à la couleur du type, icône blanche.
  /// [size] = largeur logique (30) ; hauteur = size * 1.32.
  static void paintPlaceDrop(Canvas canvas,
      {required String category, double size = PawMapLegend.placeSize}) {
    _paintDrop(
      canvas,
      width: size,
      body: PawMapLegend.placeColor(category),
      rim: Colors.white,
      icon: PawMapLegend.placeIcon(category),
      iconColor: Colors.white,
      disc: null,
    );
  }

  /// Goutte PawSpot : NOIRE, liseré à la couleur du type, icône blanche.
  /// Doré : goutte OR plus grande, patte noire, bord noir.
  static void paintPawSpotDrop(Canvas canvas,
      {required String type, bool golden = false}) {
    if (golden) {
      _paintDrop(
        canvas,
        width: PawMapLegend.spotGoldSize,
        body: PawMapLegend.gold,
        rim: PawMapLegend.ink,
        icon: Icons.pets_rounded,
        iconColor: PawMapLegend.ink,
        disc: null,
        sparkle: true,
      );
      return;
    }
    _paintDrop(
      canvas,
      width: PawMapLegend.spotSize,
      body: PawMapLegend.ink,
      rim: _spotTypeColor(type),
      icon: PawMapLegend.spotIcon(type),
      iconColor: Colors.white,
      disc: null,
    );
  }

  static Color _spotTypeColor(String t) {
    switch (t) {
      case 'path_walk':
        return const Color(0xFF16A34A);
      case 'chill':
        return const Color(0xFF2563EB);
      case 'playground':
        return const Color(0xFFEF4444);
      case 'swimming':
        return const Color(0xFF14B8A6);
      case 'food_cafe':
        return const Color(0xFFE8A00A);
      default:
        return const Color(0xFFEC4899);
    }
  }

  static double dropHeight(double width) => width * 1.32 + 2 * dropMargin;
  static double dropBitmapWidth(double width) => width + 2 * dropMargin;
  static const double dropMargin = 6;

  static void _paintDrop(
    Canvas canvas, {
    required double width,
    required Color body,
    required Color rim,
    required IconData icon,
    required Color iconColor,
    required Color? disc,
    bool sparkle = false,
  }) {
    const m = dropMargin;
    final r = width / 2;
    final cx = m + r;
    final cy = m + r;
    final tipY = m + width * 1.32;
    final path = dropPath(cx, cy, r, tipY);
    // Ombre au sol sous la pointe + ombre portée.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, tipY + 1), width: r, height: r * 0.28),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    drawShadow(canvas, path);
    canvas.drawPath(dropPath(cx, cy, r + 1.8, tipY + 2), Paint()..color = rim);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - r, cy - r),
          Offset(cx + r, tipY),
          [PawMapLegend.lighten(body, 0.16), PawMapLegend.darken(body, 0.14)],
        ),
    );
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - r * 0.3, cy - r * 0.55),
          width: r * 1.3,
          height: r * 0.7),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.restore();
    if (disc != null) {
      canvas.drawCircle(Offset(cx, cy), r * 0.68, Paint()..color = disc);
    }
    drawIcon(canvas, icon, Offset(cx, cy), r * 1.05, iconColor);
    if (sparkle) {
      final p = Paint()..color = Colors.white;
      Path star(Offset c, double s) => Path()
        ..moveTo(c.dx, c.dy - s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
        ..close();
      canvas.drawPath(star(Offset(cx + r * 0.72, cy - r * 0.72), 3.6), p);
      canvas.drawPath(star(Offset(cx - r * 0.82, cy - r * 0.45), 2.2), p);
    }
  }

  /// Carré arrondi BLANC d'un groupe de lieux : bord à la couleur du type
  /// dominant, nombre dans le foncé de ce type. Groupe de PawSpots : carré
  /// NOIR, nombre OR.
  static void paintSquareCluster(Canvas canvas, int count,
      {required Color tone, bool black = false}) {
    final label = count > 99 ? '99+' : '$count';
    const s = PawMapLegend.placeClusterSize;
    const m = 6.0;
    final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(m, m, s, s), const Radius.circular(10));
    drawShadow(canvas, Path()..addRRect(rect));
    canvas.drawRRect(
        rect, Paint()..color = black ? PawMapLegend.ink : Colors.white);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = black ? PawMapLegend.gold : tone
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    drawText(
      canvas,
      label,
      const Offset(m + s / 2, m + s / 2 - 0.5),
      label.length > 2 ? 12 : 15,
      black ? PawMapLegend.gold : PawMapLegend.darken(tone, 0.25),
    );
  }

  static double squareClusterBitmapSize() => PawMapLegend.placeClusterSize + 12;

  // ── DEMANDES (bulles orange foncé) ────────────────────────────────────

  /// Bulle de dialogue ORANGE FONCÉ (couleur propriétaire), petite pointe
  /// vers le bas, prix en blanc dedans ; sans budget : l'icône du service.
  /// [mine] → « Ma demande » (le propriétaire voit les siennes).
  static void paintRequestBubble(Canvas canvas,
      {String? priceLabel,
      required bool walking,
      double? boostPhase,
      String? mineLabel}) {
    const h = PawMapLegend.requestBubbleHeight;
    final text = mineLabel ?? priceLabel;
    final w = requestBubbleWidth(priceLabel: priceLabel, mineLabel: mineLabel);
    const m = 8.0;
    const tip = 7.0;
    final cx = m + w / 2;
    if (boostPhase != null) {
      drawBoostGlow(canvas, Offset(cx, m + h / 2), math.max(w, h) / 2 - 2,
          boostPhase);
    }
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(m, m, w, h), const Radius.circular(12));
    final tipPath = Path()
      ..moveTo(cx - tip, m + h - 1)
      ..lineTo(cx, m + h + tip)
      ..lineTo(cx + tip, m + h - 1)
      ..close();
    final shape = Path()
      ..addRRect(body)
      ..addPath(tipPath, Offset.zero);
    drawShadow(canvas, shape);
    canvas.drawPath(
      shape,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(m, m),
          Offset(m + w, m + h),
          [PawMapLegend.lighten(PawMapLegend.owner, 0.10), PawMapLegend.owner],
        ),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final icon = walking ? Icons.directions_walk_rounded : Icons.home_rounded;
    if (text == null || text.isEmpty) {
      drawIcon(canvas, icon, Offset(cx, m + h / 2), 18, Colors.white);
    } else {
      drawIcon(canvas, icon, Offset(m + 14, m + h / 2), 15, Colors.white);
      drawText(canvas, text, Offset(m + 14 + 8 + (w - 30) / 2, m + h / 2), 12.5,
          Colors.white);
    }
  }

  static double requestBubbleWidth({String? priceLabel, String? mineLabel}) {
    final t = mineLabel ?? priceLabel;
    if (t == null || t.isEmpty) return 40;
    return 34 + t.length * 7.4;
  }

  static double requestBubbleBitmapWidth(
          {String? priceLabel, String? mineLabel}) =>
      requestBubbleWidth(priceLabel: priceLabel, mineLabel: mineLabel) + 16;
  static double requestBubbleBitmapHeight() =>
      PawMapLegend.requestBubbleHeight + 8 + 7 + 8;
}

/// Rendu d'un peintre en image PNG (2×) — partagé par la carte (BitmapDescriptor)
/// et par la légende « ? » / les tests (Image.memory).
Future<Uint8List> renderPinPng(
  double logicalW,
  double logicalH,
  void Function(Canvas canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(2, 2);
  paint(canvas);
  final img = await recorder
      .endRecording()
      .toImage((logicalW * 2).ceil(), (logicalH * 2).ceil());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

/// Décode une photo (bytes) en `ui.Image` carrée redimensionnée.
Future<ui.Image?> decodeAvatar(Uint8List? bytes, {int target = 128}) async {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: target);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

/// Cache des épingles de la carte (idée 10 : chaque épingle dessinée UNE fois
/// puis réutilisée). Clé = description complète de l'épingle. Les photos
/// (Moi, amis) sont téléchargées une fois et gardées en mémoire.
class PawMapPinCache extends GetxService {
  final Map<String, BitmapDescriptor> _cache = {};
  final Set<String> _building = {};
  final Map<String, ui.Image?> _avatars = {};
  final Map<String, int> _avatarFails = {};

  /// Incrémenté à chaque épingle prête → l'écran reconstruit ses marqueurs.
  final RxInt rev = 0.obs;

  BitmapDescriptor? peek(String key) => _cache[key];

  /// Renvoie l'épingle en cache, sinon lance sa construction et renvoie null
  /// (l'appelant pose un repli et sera prévenu par [rev]).
  BitmapDescriptor? getOrBuild(
    String key,
    double logicalW,
    double logicalH,
    void Function(Canvas canvas) paint,
  ) {
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_building.add(key)) {
      unawaited(_build(key, logicalW, logicalH, paint));
    }
    return null;
  }

  Future<void> _build(String key, double w, double h,
      void Function(Canvas canvas) paint) async {
    try {
      final png = await renderPinPng(w, h, paint);
      _cache[key] = BitmapDescriptor.bytes(png, width: w);
      rev.value++;
    } catch (e) {
      debugPrint('[PawMapPinCache] $key : $e');
    } finally {
      _building.remove(key);
    }
  }

  /// Photo décodée d'un membre, ou null si pas (encore) disponible. Un
  /// téléchargement est lancé au premier appel ; [rev] bouge quand elle
  /// arrive. Trois échecs → on reste sur la patte blanche.
  ui.Image? avatarFor(String url) {
    if (url.isEmpty || !url.startsWith('http')) return null;
    if (_avatars.containsKey(url)) return _avatars[url];
    if ((_avatarFails[url] ?? 0) >= 3) return null;
    if (_building.add('avatar:$url')) {
      unawaited(_downloadAvatar(url));
    }
    return null;
  }

  Future<void> _downloadAvatar(String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: const {'User-Agent': 'Mozilla/5.0 (HoPetSit)'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        _avatars[url] = await decodeAvatar(resp.bodyBytes);
        rev.value++;
        return;
      }
      _avatarFails[url] = (_avatarFails[url] ?? 0) + 1;
    } catch (_) {
      _avatarFails[url] = (_avatarFails[url] ?? 0) + 1;
    } finally {
      _building.remove('avatar:$url');
    }
  }

  /// Vide les épingles (pas les photos) — après un changement de langue ou
  /// de thème, les libellés doivent être redessinés.
  void invalidatePins() {
    _cache.clear();
    rev.value++;
  }
}
