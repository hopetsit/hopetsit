// 630 (PAM, 30/10/2026) — capture de Daniel : l'épingle d'Agnès D. (3 rôles,
// owner = sitter même id) n'avait que 2 couleurs d'anneau. Test du DESSIN :
// un rond photo avec ringColors = [owner, sitter, walker] doit montrer les
// 3 couleurs sur son contour (pixels mesurés), avec et sans bulle de prix.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'dart:math' as math;

Future<Uint8List> _render(void Function(Canvas) paint, double w, double h) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
}

String _hue(int r, int g, int b) {
  if (r > 150 && g < 110 && b < 110) return 'orange';
  if (b > 150 && r < 110) return 'bleu';
  if (g > 120 && r < 110 && b < 130) return 'vert';
  return 'autre';
}

void main() {
  final agnesRoles = pawMapPersonRoles({
    'id': '6adea6cd90a7ee40f6011b58', 'role': 'sitter',
    'roles': [
      {'id': '6adea6cd90a7ee40f6011b58', 'role': 'sitter'},
      {'id': '6adea6cd90a7ee40f6011b58', 'role': 'owner'},
      {'id': '6adea80390a7ee40f6012f15', 'role': 'walker'},
    ],
  });

  test('rôles de la personne (couche proche, doc gardien) : owner, sitter, walker', () {
    expect(agnesRoles, ['owner', 'sitter', 'walker']);
  });

  test('contour du rond photo : les 3 couleurs sont visibles (pixels)', () async {
    final rings = [for (final r in agnesRoles) PawMapLegend.roleColor(r)];
    const size = PawMapLegend.friendSize;
    const margin = PawMapPinPainter.photoMarginGlow;
    final w = PawMapPinPainter.photoBitmapSize(size, margin: margin);
    final b = await _render((c) => PawMapPinPainter.paintPhotoDot(c,
        avatar: null, ringColor: PawMapLegend.sitter, size: size, margin: margin, ringColors: rings), w, w);
    final cx = margin + size / 2, cy = margin + size / 2, r = size / 2;
    final seen = <String>{};
    for (var k = 0; k < 72; k++) {
      final a = k * math.pi / 36;
      final x = (cx + (r - 1.5) * math.cos(a)).round(), y = (cy + (r - 1.5) * math.sin(a)).round();
      final i = (y * w.toInt() + x) * 4;
      seen.add(_hue(b[i], b[i + 1], b[i + 2]));
    }
    expect(seen, containsAll(['orange', 'bleu', 'vert']), reason: 'couleurs vues : $seen');
  });
}
