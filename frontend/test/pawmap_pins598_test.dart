// v598 (28/09) — « Vu il y a … » d'un ami collé à « Moi » n'est plus masquée
// mais DÉCALÉE au-dessus du rond (Daniel : la mère à côté de lui). Ce test
// prouve, avec le VRAI peintre des épingles :
//   1. l'ancre reste le centre du rond quand l'étiquette est au-dessus ;
//   2. la pastille est dessinée AU-DESSUS de l'anneau (pixels blancs opaques
//      au-dessus, aucun en dessous) et entière dans le bitmap ;
//   3. la largeur de l'image suit l'étiquette (jamais coupée) ;
//   4. un golden côte à côte (dessous / dessus).
// Régénérer après un changement VOULU :
//   flutter test test/pawmap_pins598_test.dart --update-goldens
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

Future<void> _loadSdkFonts() async {
  Directory? dir;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final d = Directory('$root/bin/cache/artifacts/material_fonts');
    if (d.existsSync()) dir = d;
  }
  var cur = File(Platform.resolvedExecutable).parent;
  while (dir == null && cur.path != cur.parent.path) {
    final d = Directory('${cur.path}/artifacts/material_fonts');
    if (d.existsSync()) dir = d;
    cur = cur.parent;
  }
  if (dir == null) return;
  for (final e in {
    'MaterialIcons': '${dir.path}/MaterialIcons-Regular.otf',
    'Roboto': '${dir.path}/Roboto-Bold.ttf',
  }.entries) {
    final f = File(e.value);
    if (!f.existsSync()) continue;
    final bytes = await f.readAsBytes();
    await (FontLoader(e.key)
          ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer))))
        .load();
  }
}

const double fs = PawMapLegend.friendSize;
const double m = PawMapPinPainter.photoMarginGlow;
const String caption = 'Vu il y a 5 j';

void _friend(Canvas c, {required bool above}) => PawMapPinPainter.paintPhotoDot(
      c,
      avatar: null,
      ringColor: PawMapLegend.friend,
      size: fs,
      label: caption,
      labelColor: PawMapLegend.darken(PawMapLegend.friend, 0.25),
      fallbackTint: PawMapLegend.sitter,
      margin: m,
      labelAbove: above,
    );

/// Lignes (en dp) qui contiennent au moins [minRun] pixels blancs opaques
/// consécutifs = la pastille de l'étiquette.
Future<Set<int>> _whiteRows(ui.Image img, {double scale = 1, int minRun = 20}) async {
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = bd!.buffer.asUint8List();
  final w = img.width, h = img.height;
  final rows = <int>{};
  for (var y = 0; y < h; y++) {
    var run = 0;
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final white = px[i] > 250 && px[i + 1] > 250 && px[i + 2] > 250 && px[i + 3] > 250;
      run = white ? run + 1 : 0;
      if (run >= minRun) {
        rows.add((y / scale).floor());
        break;
      }
    }
  }
  return rows;
}

void main() {
  setUpAll(_loadSdkFonts);

  test('ancre : centre du rond, étiquette dessous OU dessus', () {
    final h = PawMapPinPainter.photoBitmapSize(fs, withLabel: true, margin: m);
    // Dessous : le rond est en haut du bitmap.
    expect(PawMapPinPainter.photoAnchorY(fs, withLabel: true, margin: m),
        closeTo((m + fs / 2) / h, 1e-9));
    // Dessus : le rond est descendu de photoLabelExtra.
    expect(
        PawMapPinPainter.photoAnchorY(fs, withLabel: true, margin: m, labelAbove: true),
        closeTo((PawMapPinPainter.photoLabelExtra + m + fs / 2) / h, 1e-9));
    // Sans étiquette, labelAbove ne change rien.
    expect(PawMapPinPainter.photoAnchorY(fs, margin: m, labelAbove: true),
        closeTo(0.5, 1e-9));
    // La largeur suit l'étiquette : « Vu il y a 5 j » est plus large que le rond nu ?
    expect(PawMapPinPainter.photoLabelWidth(caption), greaterThan(0));
  });

  testWidgets('la pastille est dessinée au-dessus de l’anneau, entière',
      (tester) async {
    late ui.Image below, above;
    final w = PawMapPinPainter.photoBitmapSize(fs, margin: m);
    final h = PawMapPinPainter.photoBitmapSize(fs, withLabel: true, margin: m);
    await tester.runAsync(() async {
      await ensurePawPinFonts();
      below = await renderPinImage(w, h, (c) => _friend(c, above: false), scale: 1);
      above = await renderPinImage(w, h, (c) => _friend(c, above: true), scale: 1);
    });
    final rowsBelow = await tester.runAsync(() => _whiteRows(below));
    final rowsAbove = await tester.runAsync(() => _whiteRows(above));
    // Centre du rond (dp) dans chaque cas.
    final cyBelow = m + fs / 2;
    final cyAbove = PawMapPinPainter.photoLabelExtra + m + fs / 2;
    // Dessous : la pastille commence sous l'anneau (rayon 25 + 3).
    expect(rowsBelow!.where((y) => y > cyBelow + fs / 2), isNotEmpty);
    expect(rowsBelow.where((y) => y < cyBelow - fs / 2), isEmpty);
    // Dessus : la pastille est ENTIÈREMENT au-dessus de l'anneau, et dans le
    // bitmap (aucune ligne blanche hors [0, h[ — trivial — mais surtout aucune
    // ligne blanche sous le rond).
    expect(rowsAbove!.where((y) => y < cyAbove - fs / 2), isNotEmpty,
        reason: 'pastille attendue au-dessus du rond');
    expect(rowsAbove.where((y) => y > cyAbove + fs / 2), isEmpty,
        reason: 'aucune pastille sous le rond quand labelAbove');
    // La pastille (19,3 dp) tient au-dessus : sa 1re ligne n'est pas la ligne 0.
    expect(rowsAbove.reduce((a, b) => a < b ? a : b), greaterThan(0));
    // Sans étiquette et avec, le rond garde le même centre relatif à l'ancre.
    final anchorBelow = PawMapPinPainter.photoAnchorY(fs, withLabel: true, margin: m) * h;
    final anchorAbove =
        PawMapPinPainter.photoAnchorY(fs, withLabel: true, margin: m, labelAbove: true) * h;
    expect(anchorBelow, closeTo(cyBelow, 1e-9));
    expect(anchorAbove, closeTo(cyAbove, 1e-9));
  });

  testWidgets('marge serrée (16 dp) : couronne, point en ligne et prénom tiennent dans le bitmap',
      (tester) async {
    const ms = PawMapLegend.memberSize, me = PawMapLegend.meSize;
    const mt = PawMapPinPainter.photoMarginTight;
    final cases = <(String, double, double, void Function(Canvas))>[
      ('membre couronne + en ligne + prénom', PawMapPinPainter.photoBitmapSize(ms, margin: mt),
          PawMapPinPainter.photoBitmapSize(ms, withLabel: true, margin: mt),
          (c) => PawMapPinPainter.paintPhotoDot(c, avatar: null, ringColor: PawMapLegend.sitter,
              size: ms, crown: true, crownSize: PawMapLegend.crownMember, online: true,
              label: 'Sasha', margin: mt)),
      ('moi couronne + Moi', PawMapPinPainter.photoBitmapSize(me, margin: mt),
          PawMapPinPainter.photoBitmapSize(me, withLabel: true, margin: mt),
          (c) => PawMapPinPainter.paintPhotoDot(c, avatar: null, ringColor: PawMapLegend.owner,
              size: me, crown: true, crownSize: PawMapLegend.crownMe, label: 'Moi',
              dashedRing: true, eyeOff: true, margin: mt)),
    ];
    for (final (name, w, h, paint) in cases) {
      final img = await tester.runAsync(() => renderPinImage(w, h, paint, scale: 3));
      final bd = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.rawRgba));
      final px = bd!.buffer.asUint8List();
      final W = img!.width, H = img.height;
      var borderMax = 0;
      for (var y = 0; y < H; y++) {
        for (var x = 0; x < W; x++) {
          if (x < 2 || y < 2 || x >= W - 2 || y >= H - 2) {
            final a = px[(y * W + x) * 4 + 3];
            if (a > borderMax) borderMax = a;
          }
        }
      }
      // Rien de visible sur le bord du bitmap : ≤ 8/255 (3 %), c'est la
      // queue de l'ombre floue de la pastille, invisible ; un anneau, une
      // couronne ou un texte coupé donnerait des dizaines à 255.
      expect(borderMax, lessThanOrEqualTo(8), reason: '$name : contenu coupé au bord');
    }
  });

  testWidgets('golden : ami « Vu il y a » dessous / dessus (3×)', (tester) async {
    ui.Image? board;
    final labelW = PawMapPinPainter.photoLabelWidth(caption);
    final baseW = PawMapPinPainter.photoBitmapSize(fs, margin: m);
    final w = labelW > baseW ? labelW : baseW;
    final h = PawMapPinPainter.photoBitmapSize(fs, withLabel: true, margin: m);
    const gap = 16.0, pad = 12.0;
    await tester.runAsync(() async {
      await ensurePawPinFonts();
      board = await renderPinImage(2 * w + gap + 2 * pad, h + 2 * pad, (c) {
        c.drawRect(Rect.fromLTWH(0, 0, 2 * w + gap + 2 * pad, h + 2 * pad),
            Paint()..color = const Color(0xFFF0EBE1));
        c.save();
        c.translate(pad + (w - baseW) / 2, pad);
        _friend(c, above: false);
        c.restore();
        c.save();
        c.translate(pad + w + gap + (w - baseW) / 2, pad);
        _friend(c, above: true);
        c.restore();
      }, scale: 3);
    });
    expect(board, isNotNull);
    await expectLater(
        board!, matchesGoldenFile('goldens/pawmap598/ami_vu_dessous_dessus_3x.png'));
  });
}
