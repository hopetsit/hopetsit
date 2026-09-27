// v597 — Daniel (27/09) : « les PawSpots et les PawSpots dorés, bien beaux
// avec le nom ». Planche 3× : goutte noire et goutte dorée, sans et avec nom
// (court, long tronqué), comme le site (étiquette noire, contour or, texte or).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

void main() {
  testWidgets('PawSpot + PawSpot doré, avec leur nom', (tester) async {
    ui.Image? board;
    await tester.runAsync(() async {
      await ensurePawPinFonts();
      const cells = <(bool, String?)>[
        (false, null),
        (false, 'perros'),
        (true, null),
        (true, 'perros'),
        (true, 'Parc canin des Buttes-Chaumont très long nom'),
      ];
      const cellW = 170.0, cellH = 110.0;
      board = await renderPinImage(cellW * cells.length, cellH, (c) {
        c.drawRect(const Rect.fromLTWH(0, 0, cellW * 5, cellH),
            Paint()..color = const Color(0xFFEFE7DC));
        for (var i = 0; i < cells.length; i++) {
          final (golden, label) = cells[i];
          final size = golden ? PawMapLegend.spotGoldSize : PawMapLegend.spotSize;
          final baseW = PawMapPinPainter.dropBitmapWidth(size);
          final w = label == null
              ? baseW
              : (PawMapPinPainter.spotLabelWidth(label) > baseW
                  ? PawMapPinPainter.spotLabelWidth(label)
                  : baseW);
          final x0 = i * cellW + (cellW - w) / 2;
          c.save();
          c.translate(x0 + (w - baseW) / 2, 6);
          PawMapPinPainter.paintPawSpotDrop(c, type: 'dog_park', golden: golden);
          c.restore();
          if (label != null) {
            PawMapPinPainter.paintPawSpotLabel(c,
                label: label,
                cx: x0 + w / 2,
                top: 6 + PawMapPinPainter.dropMargin + size * 1.32 + 2);
          }
        }
      }, scale: 3);
    });
    expect(board, isNotNull);
    await expectLater(board!, matchesGoldenFile('goldens/pawspot597/pawspots_nom_3x.png'));
  });
}
