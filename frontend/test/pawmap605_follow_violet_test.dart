// v605 (30/09) — Daniel : « t'es pas violet ». Sur la carte de celui qui
// SUIT, la personne suivie en direct doit porter le halo VIOLET, même si
// elle a un PawBoost (avant : la lueur turquoise du boost passait devant).
// Test sur les VRAIS pixels du peintre : on dessine l'ami boosté ET suivi,
// puis on lit la couleur du halo à mi-chemin entre le rond et le bord.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

const double fs = PawMapLegend.friendSize;
const double m = PawMapPinPainter.photoMarginGlow;

Future<(int, int, int, int)> _haloPixel(
    {required bool boosted, required bool followed}) async {
  final w = PawMapPinPainter.photoBitmapSize(fs, margin: m);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  PawMapPinPainter.paintPhotoDot(
    c,
    avatar: null,
    ringColor: PawMapLegend.friend,
    size: fs,
    boostPhase: boosted ? 0.5 : null,
    followPhase: followed ? 0.5 : null,
    fallbackTint: PawMapLegend.walker,
    margin: m,
  );
  final img = await rec.endRecording().toImage(w.ceil(), w.ceil());
  final bd = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  final bytes = bd.buffer.asUint8List();
  // À gauche du rond, dans le halo : x = marge − 6 px, y = centre.
  final int x = (m - 6).round();
  final int y = (m + fs / 2).round();
  final i = (y * w.ceil() + x) * 4;
  return (bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]);
}

bool _isViolet((int, int, int, int) p) =>
    p.$4 > 20 && p.$1 > p.$2 + 20 && p.$3 > p.$2 + 20; // R et B > G
bool _isTurquoise((int, int, int, int) p) =>
    p.$4 > 20 && p.$2 > p.$1 + 20 && p.$3 > p.$1 + 20; // G et B > R

void main() {
  test('règle pure : suivi > PawBoost > PawFollow > ami > moi', () {
    expect(pickPhotoHalo(boosted: true, followed: true), PawPhotoHalo.follow);
    expect(pickPhotoHalo(boosted: true, followed: false), PawPhotoHalo.boost);
    expect(pickPhotoHalo(boosted: false, followed: false, isFriend: true),
        PawPhotoHalo.friend);
    expect(
        pickPhotoHalo(
            boosted: false, followed: false, pawFollowGlow: true, isFriend: true),
        PawPhotoHalo.pawFollow);
  });

  test('ami boosté ET suivi en direct : halo VIOLET (pixels réels)', () async {
    final p = await _haloPixel(boosted: true, followed: true);
    expect(_isViolet(p), isTrue, reason: 'pixel halo = $p');
    expect(_isTurquoise(p), isFalse, reason: 'pixel halo = $p');
  });

  test('ami boosté NON suivi : lueur turquoise inchangée', () async {
    final p = await _haloPixel(boosted: true, followed: false);
    expect(_isTurquoise(p), isTrue, reason: 'pixel halo = $p');
  });

  test('ami suivi sans boost : violet', () async {
    final p = await _haloPixel(boosted: false, followed: true);
    expect(_isViolet(p), isTrue, reason: 'pixel halo = $p');
  });
}
