// 613 (PAM, 06/10/2026) — épingle de SIGNALEMENT sans jamais de « rond blanc
// vide » (PROCHAIN_BUILD_613 §4a, capture 6_icone_blanche.jpg).
//
// Mesuré : à La Isla le 06/10 à 22:38, les 3 ronds à droite de john sont,
// d'après leurs coordonnées (API admin, écarts lng/lat → px cohérents à 1 %),
// « animal mort » 🪦, « circulation » 🚗 et — le rond VIDE — « danger » ⚠️
// (posé à 22:35). L'emoji est dessiné par un TextPainter dans une image ; si
// le glyphe ne sort pas (police d'emoji non résolue pour ce caractère), il ne
// restait que le disque blanc et son anneau.
//
// Règle : on dessine l'emoji, on VÉRIFIE qu'il y a de l'encre au centre ; sinon
// on redessine avec une icône Material du même sens (police embarquée dans
// l'app, toujours disponible). Jamais de rond vide.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Taille du dessin (px) — identique à l'ancien `_buildEmojiBitmap`.
const double kPawReportPinPx613 = 56;

/// Icône de secours par type de signalement (même sens que l'emoji).
IconData pawReportFallbackIcon613(String type) => switch (type) {
      'poop' => Icons.pets_rounded,
      'pee' => Icons.water_drop_rounded,
      'water_active' => Icons.water_drop_rounded,
      'water_broken' => Icons.format_color_reset_rounded,
      'hazard' => Icons.warning_rounded,
      'aggressive_dog' => Icons.report_rounded,
      'lost_pet' => Icons.search_rounded,
      'found_pet' => Icons.volunteer_activism_rounded,
      'dead_animal' => Icons.sentiment_very_dissatisfied_rounded,
      'trap' => Icons.dangerous_rounded,
      'poison' => Icons.science_rounded,
      'stray_pet' => Icons.pets_rounded,
      'construction' => Icons.construction_rounded,
      'busy_traffic' => Icons.directions_car_rounded,
      'fire_smoke' => Icons.local_fire_department_rounded,
      'flood' => Icons.waves_rounded,
      'fallen_tree' => Icons.park_rounded,
      'chemical' => Icons.science_rounded,
      'wildlife' => Icons.cruelty_free_rounded,
      'no_dogs_zone' => Icons.block_rounded,
      'food' => Icons.restaurant_rounded,
      'trash' => Icons.delete_rounded,
      'vet_open' => Icons.local_hospital_rounded,
      'leash_required' => Icons.link_rounded,
      'heat_hot_ground' => Icons.thermostat_rounded,
      'tick_zone' => Icons.bug_report_rounded,
      _ => Icons.place_rounded,
    };

/// Couleur de l'icône de secours (lisible sur blanc, jamais grise).
const Color kPawReportFallbackInk613 = Color(0xFFC92A12);

/// Y a-t-il de l'ENCRE au centre de l'image (RGBA brut) ? « Encre » = pixel
/// opaque nettement plus sombre ou plus coloré que le blanc du disque.
/// Le centre = carré de [box] px (hors anneau).
bool pawPinHasInk613(ByteData rgba, int w, int h, {int box = 26, int minPixels = 14}) {
  final x0 = (w - box) ~/ 2, y0 = (h - box) ~/ 2;
  var n = 0;
  for (var y = y0; y < y0 + box; y++) {
    for (var x = x0; x < x0 + box; x++) {
      final i = (y * w + x) * 4;
      final r = rgba.getUint8(i), g = rgba.getUint8(i + 1), b = rgba.getUint8(i + 2), a = rgba.getUint8(i + 3);
      if (a < 128) continue;
      final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
      if (mn < 205 || mx - mn > 40) n++;
      if (n >= minPixels) return true;
    }
  }
  return false;
}

/// Dessine le rond (blanc + anneau) avec [emoji], ou avec [icon] si fourni.
/// 613 §4b — [fresh] (< 2 h) : auréole de la couleur de l'anneau autour d'un
/// disque un peu plus petit (même taille d'image : aucune ancre ne bouge).
Future<ui.Image> pawPaintReportPin613({
  String? emoji,
  IconData? icon,
  Color ringColor = const Color(0xFFC92A12),
  double ringWidth = 3.0,
  bool fresh = false,
}) async {
  const size = kPawReportPinPx613;
  const c = Offset(size / 2, size / 2);
  final double rDisk = fresh ? size / 2 - 6 : size / 2 - 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (fresh) {
    canvas.drawCircle(
        c,
        size / 2 - 1.5,
        Paint()
          ..color = ringColor.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    canvas.drawCircle(
        c,
        size / 2 - 3,
        Paint()
          ..color = ringColor.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  } else {
    canvas.drawCircle(
        const Offset(size / 2, size / 2 + 1.5),
        rDisk,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }
  canvas.drawCircle(c, rDisk, Paint()..color = Colors.white);
  canvas.drawCircle(
      c,
      rDisk - ringWidth / 2,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth);
  final double fs = fresh ? 24 : 27;
  final TextSpan span = icon != null
      ? TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: fs,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: ringColor,
          ))
      : TextSpan(text: emoji ?? '', style: TextStyle(fontSize: fs));
  final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
  tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
  return recorder.endRecording().toImage(size.toInt(), size.toInt());
}

/// Résultat : PNG prêt pour `BitmapDescriptor.bytes` + la voie retenue.
class PawReportPin613 {
  const PawReportPin613(this.png, {required this.usedFallback});
  final Uint8List png;
  final bool usedFallback;
}

/// L'épingle d'un signalement : l'emoji s'il se dessine, sinon l'icône ;
/// anneau à la couleur de la gravité ([ringColor]), auréole si [fresh].
Future<PawReportPin613> pawBuildReportPin613(String type, String emoji,
    {Color ringColor = const Color(0xFFC92A12), bool fresh = false}) async {
  final img = await pawPaintReportPin613(emoji: emoji, ringColor: ringColor, fresh: fresh);
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final useFallback = raw == null || !pawPinHasInk613(raw, img.width, img.height);
  ui.Image out = img;
  if (useFallback) {
    out = await pawPaintReportPin613(
        icon: pawReportFallbackIcon613(type), ringColor: ringColor, fresh: fresh);
  }
  final png = await out.toByteData(format: ui.ImageByteFormat.png);
  return PawReportPin613(png!.buffer.asUint8List(), usedFallback: useFallback);
}
