// 630 (PAM, 30/10/2026) — Daniel : « les halos bleu, turquoise et violet ne
// sont pas assez voyants ». Mesure en pixels des halos PawBoost (turquoise)
// et PawFollow (violet) sur le rond « Anneau 2610 » et sur un rond photo :
// liseré blanc, anneau plein ≥ 4 pt, lueur encore nette à 12 pt du bord.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_ring2610.dart';

Future<Uint8List> _render(void Function(Canvas) paint, double w, double h) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
}

(int, int, int, int) _px(Uint8List b, int w, double x, double y) {
  final i = (y.round() * w + x.round()) * 4;
  return (b[i], b[i + 1], b[i + 2], b[i + 3]);
}

void main() {
  group('rond Anneau 2610', () {
    Future<Uint8List> ring({double? boost, bool follow = false}) {
      final sz = pawRingBitmap2610(1, multi: false);
      return _render(
          (c) => paintRingBitmap2610(c, roles: const ['sitter'], boostPhase: boost, pawFollow: follow),
          sz.width, sz.height);
    }

    test('PawBoost : liseré blanc, anneau turquoise plein 8 pt, lueur à 12 pt', () async {
      final sz = pawRingBitmap2610(1, multi: false);
      final w = sz.width.toInt();
      final b = await ring(boost: 0.25);
      const cx = 25 + kRingMargin2610, cy = 25 + kRingMargin2610;
      final white = _px(b, w, cx, cy - 27);
      expect(white.$1 > 235 && white.$2 > 235 && white.$3 > 235, isTrue, reason: 'liseré $white');
      for (final d in [29.0, 31.0, 33.0]) {
        final p = _px(b, w, cx, cy - d);
        expect(p.$4, greaterThan(240), reason: 'anneau plein à $d : $p');
        expect(p.$1 < 60 && p.$3 > 180, isTrue, reason: 'turquoise à $d : $p');
      }
      final glow = _px(b, w, cx, cy - 37);
      expect(glow.$4, greaterThan(100), reason: 'lueur à 12 pt du bord : $glow');
    });

    test('PawFollow : liseré blanc, anneau violet plein, lueur', () async {
      final sz = pawRingBitmap2610(1, multi: false);
      final w = sz.width.toInt();
      final b = await ring(follow: true);
      const cx = 25 + kRingMargin2610, cy = 25 + kRingMargin2610;
      final white = _px(b, w, cx, cy - 27);
      expect(white.$1 > 235 && white.$2 > 235 && white.$3 > 235, isTrue, reason: 'liseré $white');
      final p = _px(b, w, cx, cy - 31);
      expect(p.$4, greaterThan(240), reason: 'anneau plein $p');
      expect(p.$3 > 180 && p.$1 > 90 && p.$2 < 110, isTrue, reason: 'violet $p');
      expect(_px(b, w, cx, cy - 37).$4, greaterThan(80), reason: 'lueur');
    });

    test('rond normal : rien autour (pas de halo parasite)', () async {
      final sz = pawRingBitmap2610(1, multi: false);
      final w = sz.width.toInt();
      final b = await ring();
      const cx = 25 + kRingMargin2610, cy = 25 + kRingMargin2610;
      expect(_px(b, w, cx, cy - 33).$4, lessThan(90));
    });
  });

  group('rond photo', () {
    test('PawFollow (personne suivie) : anneau violet plein + liseré blanc', () async {
      const size = PawMapLegend.friendSize;
      const margin = PawMapPinPainter.photoMarginGlow;
      final w = PawMapPinPainter.photoBitmapSize(size, margin: margin);
      final b = await _render(
          (c) => PawMapPinPainter.paintPhotoDot(c,
              avatar: null, ringColor: PawMapLegend.sitter, size: size, margin: margin, followPhase: 0.25),
          w, w);
      const cx = margin + size / 2, cy = margin + size / 2, r = size / 2;
      final white = _px(b, w.toInt(), cx, cy - r - 1.5);
      expect(white.$1 > 235 && white.$2 > 235 && white.$3 > 235, isTrue, reason: 'liseré $white');
      final p = _px(b, w.toInt(), cx, cy - r - 6);
      expect(p.$4, greaterThan(240), reason: 'anneau plein $p');
      expect(p.$3 > 180 && p.$2 < 110, isTrue, reason: 'violet $p');
      expect(_px(b, w.toInt(), cx, cy - r - 14).$4, greaterThan(60), reason: 'lueur');
    });
  });
}
