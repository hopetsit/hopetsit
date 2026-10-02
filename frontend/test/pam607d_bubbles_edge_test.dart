// 607 (PAM, 02/10/2026) — « les bulles apparaissent toujours mal, fais un vrai
// travail de fond » (Daniel). Test qui ÉCHOUE si un seul pixel non
// transparent touche le bord d'une image d'épingle : c'est exactement ce
// qu'on voit quand une bulle, un prénom ou un rond est « coupé net ».
// Rendu à la densité d'un iPhone (3×), textes longs dans les 9 langues,
// prix longs (« dès 1 200 zł/tydz. »), duo gardien/promeneur, devises.
// Et la passe de mise en page unique (pawmap_layout607.dart).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_layout607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

const double kDpr = 3;
Map<String, int> lastSides = {};

// Prénoms + notes sous le rond (le plus long possible : plafond 160 px).
const List<String> kNames = <String>[
  'Christine H.', 'Maximilian-Alexander W.', 'Đặng Thị Bảo Ngọc', 'Wojciech Szczęsny-Brzęczyszczykiewicz',
  '아름다운 이름의 고양이 돌보미', 'こんにちは長い名前のペットシッターさん', 'Ana-Luísa C.', 'Jean-Baptiste É.', 'Ötzi Ü.',
];
// Bulles de prix (simple et duo « gardien|promeneur »).
const List<String> kBubbles = <String>[
  '35 €', 'dès 1 200 zł/tydz.', '1 450 €/sem', '¥12,000', '₩150,000/주', '\$1,250/wk', '20 €|12 €',
  'dès 100 €/sem|dès 18 €/h', 'R\$ 2.500/mês',
];
// Étiquettes « Vu il y a » (9 langues, formes longues).
const List<String> kSeen = <String>[
  'Vu il y a 23 h', 'Seen 23 h ago', 'Visto hace 23 h', 'Vor 23 Std. gesehen', 'Visto 23 h fa',
  'Visto há 23 h', 'Widziano 23 godz. temu', '23時間前に確認', '23시간 전에 봄',
];

Future<Uint8List> _rgba(double w, double h, void Function(Canvas) paint) async {
  final img = await renderPinImage(w, h, paint, scale: kDpr);
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final out = bd!.buffer.asUint8List();
  img.dispose();
  return out;
}

/// Pixels opaques (alpha > 8) sur le bord de l'image : 0 attendu.
Future<int> _edgeHits(double w, double h, void Function(Canvas) paint) async {
  final W = (w * kDpr).ceil(), H = (h * kDpr).ceil();
  final px = await _rgba(w, h, paint);
  var hits = 0;
  final sides = <String, int>{};
  bool opaque(int x, int y) => px[(y * W + x) * 4 + 3] > 8;
  void hit(String s) {
    hits++;
    sides[s] = (sides[s] ?? 0) + 1;
  }
  for (var x = 0; x < W; x++) {
    if (opaque(x, 0)) hit('haut');
    if (opaque(x, H - 1)) hit('bas');
  }
  for (var y = 0; y < H; y++) {
    if (opaque(0, y)) hit('gauche');
    if (opaque(W - 1, y)) hit('droite');
  }
  if (hits > 0) lastSides = sides;
  return hits;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('rond de membre : prénom long + note, jamais coupé (9 langues)', (t) async {
    for (final name in kNames) {
      const size = PawMapLegend.memberSize;
      final w = PawMapPinPainter.memberBitmapWidth(size, priceLabel: name, rating: 4.9);
      final dx = (w - PawMapPinPainter.memberBitmapSize(size)) / 2;
      final h = PawMapPinPainter.memberBitmapSize(size, withLabel: true);
      final hits = await t.runAsync(() => _edgeHits(w, h, (c) {
            c.save();
            c.translate(dx, 0);
            PawMapPinPainter.paintMemberDot(c, role: 'sitter', priceLabel: name, rating: 4.9, crown: true);
            c.restore();
          }));
      expect(hits, 0, reason: 'prénom « $name » coupé ($hits px au bord)');
    }
  });

  testWidgets('rond de membre à MARGE ADAPTÉE (11 / 17 / 22) : couronne, sélection, PawBoost, vérifié, en ligne', (t) async {
    for (final boosted in [false, true]) {
      for (final crown in [false, true]) {
        for (final selected in [false, true]) {
          for (final lab in [null, 'Maximilian-Alexander W.']) {
            for (final b in [null, 'dès 100 €/sem|dès 18 €/h']) {
              const size = PawMapLegend.memberSize;
              final m = PawMapPinPainter.memberMarginFor(boosted: boosted, crown: crown, selected: selected);
              final w = PawMapPinPainter.memberBitmapWidth(size, priceBubble: b, priceLabel: lab, rating: 4.5, margin: m);
              final dx = (w - PawMapPinPainter.memberBitmapSize(size, margin: m)) / 2;
              final h = PawMapPinPainter.memberBitmapSize(size, withLabel: lab != null, withBubble: b != null, margin: m);
              final hits = await t.runAsync(() => _edgeHits(w, h, (c) {
                    c.save();
                    c.translate(dx, 0);
                    PawMapPinPainter.paintMemberDot(c,
                        role: 'walker', crown: crown, selected: selected, verified: !boosted, online: true,
                        boostPhase: boosted ? 0.5 : null, priceLabel: lab, rating: 4.5, priceBubble: b, margin: m);
                    c.restore();
                  }));
              expect(hits, 0, reason: 'marge $m boost=$boosted couronne=$crown sel=$selected lab=$lab bulle=$b : $hits px $lastSides');
            }
          }
        }
      }
    }
  });

  testWidgets('rond de membre : bulle de prix longue / duo + prénom, jamais coupé', (t) async {
    for (final b in kBubbles) {
      for (final role in ['owner', 'sitter', 'walker']) {
        const size = PawMapLegend.memberSize;
        const name = 'Maximilian-Alexander W.';
        final w = PawMapPinPainter.memberBitmapWidth(size, priceBubble: b, priceLabel: name, rating: 5);
        final dx = (w - PawMapPinPainter.memberBitmapSize(size)) / 2;
        final h = PawMapPinPainter.memberBitmapSize(size, withLabel: true, withBubble: true);
        final hits = await t.runAsync(() => _edgeHits(w, h, (c) {
              c.save();
              c.translate(dx, 0);
              PawMapPinPainter.paintMemberDot(c, role: role, priceBubble: b, priceLabel: name, rating: 5, boostPhase: 0.5);
              c.restore();
            }));
        expect(hits, 0, reason: 'bulle « $b » ($role) coupée ($hits px $lastSides)');
      }
    }
  });

  testWidgets('rond photo (ami / Moi) : « Vu il y a » 9 langues, dessous ET dessus, bulle', (t) async {
    for (final label in kSeen) {
      for (final above in [false, true]) {
        for (final bubble in [null, 'dès 1 200 zł/tydz.']) {
          const size = PawMapLegend.friendSize;
          const m = PawMapPinPainter.photoMarginGlow;
          final baseW = PawMapPinPainter.photoBitmapSize(size, margin: m);
          final bubbleW = bubble == null ? 0.0 : PawMapPinPainter.priceBubbleBitmapWidth(bubble);
          final labelW = PawMapPinPainter.photoLabelWidth(label);
          final w = [baseW, bubbleW, labelW].reduce((a, b) => a > b ? a : b);
          final dx = (w - baseW) / 2;
          final h = PawMapPinPainter.photoBitmapSize(size, withLabel: true, margin: m) +
              (bubble != null ? PawMapPinPainter.priceBubbleZone : 0);
          final hits = await t.runAsync(() => _edgeHits(w, h, (c) {
                c.save();
                c.translate(dx, 0);
                PawMapPinPainter.paintPhotoDot(c,
                    avatar: null,
                    ringColor: PawMapLegend.friend,
                    size: size,
                    label: label,
                    crown: true,
                    online: true,
                    priceBubble: bubble,
                    margin: m,
                    labelAbove: above);
                c.restore();
              }));
          expect(hits, 0, reason: '« $label » (dessus=$above, bulle=$bubble) coupé ($hits px $lastSides)');
        }
      }
    }
  });

  testWidgets('rond photo à marge 11 (sans couronne) : en ligne, pointillés, étiquette, bulle', (t) async {
    for (final dashed in [false, true]) {
      for (final lab in [null, 'Thibault', 'Vor 23 Std. gesehen']) {
        for (final b in [null, '35 €', '20 €|12 €']) {
          const size = PawMapLegend.memberSize;
          const m = PawMapPinPainter.photoMarginBare;
          final baseW = PawMapPinPainter.photoBitmapSize(size, margin: m);
          final bw = b == null ? 0.0 : PawMapPinPainter.priceBubbleBitmapWidth(b);
          final lw = lab == null ? 0.0 : PawMapPinPainter.photoLabelWidth(lab);
          final w = [baseW, bw, lw].reduce((a, c) => a > c ? a : c);
          final h = PawMapPinPainter.photoBitmapSize(size, withLabel: lab != null, margin: m) +
              (b != null ? PawMapPinPainter.priceBubbleZone : 0);
          final hits = await t.runAsync(() => _edgeHits(w, h, (c) {
                c.save();
                c.translate((w - baseW) / 2, 0);
                PawMapPinPainter.paintPhotoDot(c, avatar: null, ringColor: PawMapLegend.sitter, size: size,
                    label: lab, online: true, dashedRing: dashed, priceBubble: b, margin: m);
                c.restore();
              }));
          expect(hits, 0, reason: 'photo marge 11 lab=$lab bulle=$b pointillés=$dashed : $hits px $lastSides');
        }
      }
    }
  });

  testWidgets('groupes : pastille membres « 99+ », carrés lieux / PawSpots « 99+ »', (t) async {
    for (final n in [2, 35, 100]) {
      final w = PawMapPinPainter.memberClusterWidth(n) + 12;
      final h = PawMapLegend.memberClusterHeight + 12;
      expect(await t.runAsync(() => _edgeHits(w, h, (c) => PawMapPinPainter.paintMemberCluster(c, n,
          roleCounts: const {'owner': 1, 'sitter': 1, 'walker': 0}, hasFriend: true))), 0, reason: 'mcluster $n');
      final s = PawMapPinPainter.squareClusterBitmapSize();
      expect(await t.runAsync(() => _edgeHits(s, s, (c) => PawMapPinPainter.paintSquareCluster(c, n, tone: PawMapLegend.sitter))), 0, reason: 'pcluster $n');
      expect(await t.runAsync(() => _edgeHits(s, s, (c) => PawMapPinPainter.paintSquareCluster(c, n, tone: PawMapLegend.gold, black: true))), 0, reason: 'scluster $n');
    }
  });

  testWidgets('PawSpot : nom long sous la goutte ; Moi : couronne, œil barré, étiquette', (t) async {
    for (final name in ['Parc', 'Square du Temple – Elie Wiesel (espace canin)', 'Hundewiese am Volkspark Friedrichshain']) {
      const size = PawMapLegend.spotGoldSize;
      final baseW = PawMapPinPainter.dropBitmapWidth(size);
      final w = [baseW, PawMapPinPainter.spotLabelWidth(name)].reduce((a, b) => a > b ? a : b);
      final dx = (w - baseW) / 2;
      final h = PawMapPinPainter.dropHeight(size) + PawMapPinPainter.spotLabelZone;
      final hits = await t.runAsync(() => _edgeHits(w, h, (c) {
            c.save();
            c.translate(dx, 0);
            PawMapPinPainter.paintPawSpotDrop(c, type: 'park', golden: true);
            c.restore();
            PawMapPinPainter.paintPawSpotLabel(c, label: name, cx: w / 2,
                top: PawMapPinPainter.dropMargin + size * 1.32 + 2);
          }));
      expect(hits, 0, reason: 'PawSpot « $name » coupé ($hits px $lastSides)');
    }
    for (final label in ['Moi', 'Me', 'Ja', '나', '自分']) {
      const size = PawMapLegend.meSize;
      const m = PawMapPinPainter.photoMarginGlow;
      final baseW = PawMapPinPainter.photoBitmapSize(size, margin: m);
      final w = [baseW, PawMapPinPainter.photoLabelWidth(label)].reduce((a, b) => a > b ? a : b);
      final h = PawMapPinPainter.photoBitmapSize(size, withLabel: true, margin: m);
      final hits = await t.runAsync(() => _edgeHits(w, h, (c) {
            c.save();
            c.translate((w - baseW) / 2, 0);
            PawMapPinPainter.paintPhotoDot(c, avatar: null, ringColor: PawMapLegend.owner, size: size,
                label: label, crown: true, crownSize: PawMapLegend.crownMe, eyeOff: true, boostPhase: 0.7, margin: m);
            c.restore();
          }));
      expect(hits, 0, reason: 'Moi « $label » coupé ($hits px $lastSides)');
    }
  });

  testWidgets('demande : bulle de budget longue, « Ma demande »', (t) async {
    for (final p in ['35 €', 'dès 1 200 zł/tydz.', '₩150,000/주']) {
      final w = PawMapPinPainter.requestBubbleBitmapWidth(priceLabel: p, mineLabel: 'Ma demande');
      final h = PawMapPinPainter.requestBubbleBitmapHeight();
      expect(await t.runAsync(() => _edgeHits(w, h, (c) => PawMapPinPainter.paintRequestBubble(c,
          priceLabel: p, walking: true, mineLabel: 'Ma demande'))), 0, reason: 'demande $p');
    }
  });

  group('passe de mise en page unique', () {
    PawPlaced at(String id, double x, double y, {double w = 56, double h = 56}) =>
        PawPlaced(id: id, at: Offset(x, y), size: Size(w, h));

    test('un carré de lieux posé sur une pastille de membres n\'est pas posé', () {
      final hide = pawResolveCollisions([
        at('mcluster_a', 100, 100, w: 64, h: 64), // pastille « 2 »
        at('pcluster_b', 112, 118), // carré « 5 » dessous (vu à Bondy)
        at('pcluster_c', 300, 300),
      ]);
      expect(hide, {'pcluster_b'});
    });

    test('jamais une personne retirée, même empilée', () {
      final hide = pawResolveCollisions([
        at('me', 100, 100),
        at('friend_x', 102, 100),
        at('nearby_y', 104, 100),
        at('mcluster_z', 106, 100, w: 64, h: 64),
        at('req_1', 100, 104, w: 100, h: 60),
      ]);
      expect(hide, isEmpty);
    });

    test('priorités : signalement > PawSpot > lieu > groupe de lieux', () {
      final hide = pawResolveCollisions([
        at('pcluster_1', 100, 100),
        at('poi_1', 102, 100, w: 54, h: 64),
        at('pawspot_1', 101, 100, w: 64, h: 77),
        at('report_1', 100, 101, w: 40, h: 40),
      ]);
      expect(hide, {'pcluster_1', 'poi_1', 'pawspot_1'});
    });

    test('déterministe : même résultat quel que soit l\'ordre d\'entrée', () {
      final items = [
        at('poi_a', 100, 100, w: 54, h: 64),
        at('poi_b', 104, 100, w: 54, h: 64),
        at('nearby_c', 300, 100),
        at('pcluster_d', 120, 100),
      ];
      final a = pawResolveCollisions(items);
      final b = pawResolveCollisions(items.reversed);
      expect(a, b);
      expect(a, {'poi_b', 'pcluster_d'});
    });

    test('la bulle de prix d\'un membre compte : un carré posé dessus part', () {
      // rond photo avec bulle (image 110 × 140, ancre au centre du rond)
      final hide = pawResolveCollisions([
        const PawPlaced(id: 'nearby_x', at: Offset(200, 200), size: Size(110, 140), anchor: Offset(0.5, 0.62)),
        at('pcluster_5', 200, 128), // sur la bulle, au-dessus du rond
      ]);
      expect(hide, {'pcluster_5'});
    });

    test('marges transparentes ignorées : deux images qui se frôlent restent', () {
      // Deux carrés de lieux (image 56, carré visible 32) à 40 px : les images
      // se chevauchent, pas les carrés.
      expect(pawResolveCollisions([at('pcluster_1', 100, 100), at('pcluster_2', 140, 100)]), isEmpty);
    });
  });
}
