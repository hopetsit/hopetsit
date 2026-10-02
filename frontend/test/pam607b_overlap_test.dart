// 607b (PAM, 01/10/2026) — captures de Daniel sur l'iPhone (build 605/606) :
// pastilles de groupe qui se chevauchent au zoom pays, pastilles posées sur
// les photos des amis / « Moi », « Vu il y a 23 h » sur « Moi », œil barré
// empilé sur la fusée PawBoost du rond « Moi ».
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

// Positions (arrondies à 0,1°, sans aucune identité) de la couche « monde »
// en Europe telle que l'app l'avait en cache le 01/10/2026.
const List<List<double>> kEurope = [
  [47.1, -1.9], [48.4, 1.5], [48.9, 2.6], [48.9, 2.1], [48.9, 2.5], [48.9, 2.3],
  [50.6, 3.0], [49.0, 2.2], [48.8, 2.4], [48.9, 2.3], [50.8, 4.4], [52.4, 4.9],
  [48.9, 2.5], [52.4, 4.9], [48.7, 1.4], [48.9, 2.3], [48.8, 2.3], [50.3, 3.5],
  [48.9, 2.3], [44.4, 26.2], [47.7, 9.8], [48.9, 2.5], [47.4, 0.7], [49.0, 2.3],
  [48.8, 2.3], [45.1, 7.7], [49.0, 1.9], [40.0, -0.0], [48.9, 2.4], [54.3, 13.1],
  [38.3, -0.5], [41.4, 2.2], [45.9, 5.2], [51.5, 7.0], [45.4, 4.4], [48.8, 2.0],
  [36.8, -2.6], [48.9, 2.3], [48.9, 2.3], [43.8, -0.4], [48.9, 2.4], [50.7, 1.6],
  [48.8, 2.2], [40.8, 14.2], [48.9, 2.3], [49.2, 0.4], [45.8, 1.3], [48.4, 2.2],
  [49.1, 2.0], [43.1, 6.0], [48.8, 2.4], [48.9, 2.3], [47.0, 0.1], [48.6, 1.7],
  [48.9, 2.3], [49.0, 2.9], [43.3, 5.4], [46.5, 24.6], [48.9, 6.1], [48.7, 2.6],
  [48.7, 4.6], [48.5, 2.6], [48.9, 2.3], [48.9, 2.3], [43.5, -1.5],
];

/// Copie exacte de l'ancien regroupement de l'écran (cases de 44 px).
List<List<List<double>>> gridClusters(List<List<double>> pts, double zoom) {
  final cells = <String, List<List<double>>>{};
  for (final p in pts) {
    final o = pawMercatorPx(p[0], p[1], zoom);
    final key = '${(o.dx / 44).floor()}_${(o.dy / 44).floor()}';
    (cells[key] ??= []).add(p);
  }
  return cells.values.toList();
}

Offset centerPx(List<List<double>> g, double zoom) {
  var x = 0.0, y = 0.0;
  for (final p in g) {
    final o = pawMercatorPx(p[0], p[1], zoom);
    x += o.dx;
    y += o.dy;
  }
  return Offset(x / g.length, y / g.length);
}

int overlappingPairs(List<List<List<double>>> groups, double zoom) {
  final c = groups.map((g) => centerPx(g, zoom)).toList();
  var n = 0;
  for (var i = 0; i < c.length; i++) {
    for (var j = i + 1; j < c.length; j++) {
      if ((c[i] - c[j]).distance < kPawGroupMinPx) n++;
    }
  }
  return n;
}

void main() {
  group('pastilles de groupe — plus aucun chevauchement', () {
    for (final zoom in [3.6, 4.5, 5.5, 7.0, 9.5, 12.0]) {
      test('Europe, zoom $zoom', () {
        final before = gridClusters(kEurope, zoom);
        final after = pawMergeCloseGroups<List<double>>(
            before, (p) => pawMercatorPx(p[0], p[1], zoom));
        // Personne n'est perdu ni compté deux fois.
        expect(after.fold<int>(0, (s, g) => s + g.length), kEurope.length);
        expect(overlappingPairs(after, zoom), 0);
        if (zoom == 3.6) {
          // La capture de Daniel : l'ancien regroupement en laissait plusieurs.
          expect(overlappingPairs(before, zoom), greaterThan(0));
        }
      });
    }

    test('deux points à 1 px de part et d\'autre d\'une case = un seul groupe', () {
      final g = pawMergeCloseGroups<Offset>([
        [const Offset(43.5, 10)],
        [const Offset(44.5, 10)],
        [const Offset(300, 300)],
      ], (o) => o);
      expect(g.length, 2);
      expect(g.first.length, 2);
    });

    test('fusion en chaîne jusqu\'à ce que plus rien ne se touche', () {
      final g = pawMergeCloseGroups<Offset>([
        for (var i = 0; i < 6; i++) [Offset(i * 40.0, 0)],
      ], (o) => o);
      final centers = g.map((m) {
        final x = m.map((o) => o.dx).reduce((a, b) => a + b) / m.length;
        return Offset(x, 0);
      }).toList();
      for (var i = 0; i < centers.length; i++) {
        for (var j = i + 1; j < centers.length; j++) {
          expect((centers[i] - centers[j]).distance,
              greaterThanOrEqualTo(kPawGroupMinPx));
        }
      }
    });
  });

  group('pastille écartée de « Moi » et des amis', () {
    test('rien autour : aucun décalage', () {
      expect(pawRepelShift(const Offset(100, 100), [const Offset(400, 400)]),
          Offset.zero);
    });
    // 607 (02/10) — plafond relevé de 28 à 48 px (kPawRepelMaxPx).
    test('posée sur un ami : écartée, au plus 48 px', () {
      final s = pawRepelShift(const Offset(100, 100), [const Offset(110, 100)]);
      expect(s.dx, lessThan(0));
      expect(s.distance, closeTo(40, 0.001)); // 50 − 10 : sous le plafond
      expect(s.distance, lessThanOrEqualTo(kPawRepelMaxPx + 0.0001));
    });
    test('à 30 px de Moi : repoussée jusqu\'à 50 px', () {
      final s = pawRepelShift(const Offset(130, 100), [const Offset(100, 100)]);
      expect(((const Offset(130, 100) + s) - const Offset(100, 100)).distance,
          closeTo(kPawGroupMinPx, 0.01));
    });
  });

  group('étiquette « Vu il y a » : jamais sur un autre rond ni sur « Moi »', () {
    // Scène de la capture : Moi en (200, 200), un ami juste au-dessus, un ami
    // juste en dessous, une pastille « 2 » au-dessus.
    const me = Offset(200, 200);
    final meRects = [
      pawCircleRect(me, 30),
      pawLabelRect(me, 28, 34, PawLabelSide.below, height: 16.3),
    ];
    test('ami collé sous « Moi » : jamais sur « Moi »', () {
      const friend = Offset(205, 240);
      final side = pawPickLabelSide(
          center: friend, radius: 25, width: 100, obstacles: meRects);
      if (side != PawLabelSide.none) {
        final r = pawLabelRect(friend, 25, 100, side);
        for (final o in meRects) {
          expect(r.overlaps(o), isFalse, reason: 'étiquette sur Moi ($side)');
        }
      }
    });
    test('ami au-dessus avec une pastille au-dessus : dessous ou rien', () {
      const friend = Offset(195, 150);
      final obstacles = [...meRects, pawCircleRect(const Offset(190, 100), 24.5)];
      final side = pawPickLabelSide(
          center: friend, radius: 25, width: 100, obstacles: obstacles);
      expect(side, PawLabelSide.none);
    });
    test('ami isolé : dessous, comme avant', () {
      expect(
          pawPickLabelSide(
              center: const Offset(600, 600),
              radius: 25,
              width: 100,
              obstacles: meRects),
          PawLabelSide.below);
    });
    test('dessous pris : dessus, sauf si une bulle de prix y est', () {
      final below = [pawCircleRect(const Offset(600, 660), 24)];
      expect(
          pawPickLabelSide(
              center: const Offset(600, 600), radius: 25, width: 100, obstacles: below),
          PawLabelSide.above);
      expect(
          pawPickLabelSide(
              center: const Offset(600, 600),
              radius: 25,
              width: 100,
              obstacles: below,
              allowAbove: false),
          PawLabelSide.none);
    });
  });

  group('bulle de prix au zoom ville (Dallas)', () {
    test('épingle seule : la bulle a sa place', () {
      expect(pawBubbleHasRoom(const Offset(300, 300), 24, 70, [
        pawCircleRect(const Offset(420, 300), 24),
      ]), isTrue);
    });
    test('voisin juste au-dessus : pas de bulle', () {
      expect(pawBubbleHasRoom(const Offset(300, 300), 24, 70, [
        pawCircleRect(const Offset(310, 250), 24),
      ]), isFalse);
    });
  });

  group('rond « Moi » : couronne, œil barré, fusée séparés', () {
    const c = Offset(100, 100);
    const r = 28.0; // Moi = 56
    // Fusée (code de _paintPhotoDotBody, s = 20 pour Moi).
    const s = 20.0;
    final l = (s * 0.3).roundToDouble(), b = (s * 0.25).roundToDouble();
    final rocket = Offset(c.dx - (r + l - s / 2), c.dy + r + b - s / 2);
    final crown = PawMapPinPainter.crownCenter(c, r, 24);
    final eye = PawMapPinPainter.eyeOffBadgeCenter(c, r);
    test('œil barré ≠ fusée, ≠ couronne', () {
      expect((eye - rocket).distance, greaterThan(10 + 10));
      expect((eye - crown).distance, greaterThan(10 + 12));
    });
    test('œil barré au-dessus de l\'étiquette « Moi »', () {
      final moi = pawLabelRect(c, r, 34, PawLabelSide.below, height: 16.3);
      expect(Rect.fromCircle(center: eye, radius: 10).overlaps(moi), isFalse);
    });
    test('œil barré avec point en ligne : haut-gauche', () {
      final up = PawMapPinPainter.eyeOffBadgeCenter(c, r, online: true);
      expect(up.dx, lessThan(c.dx));
      expect(up.dy, lessThan(c.dy));
    });
  });

  group('rendu réel des images d\'épingle', () {
    testWidgets('pastille « 35 » : le rond tient entier dans son image',
        (tester) async {
      await tester.runAsync(() async {
        const side = 52.0 + 12; // _memberClusterIcon
        final img = await renderPinImage(side, side, (cv) {
          PawMapPinPainter.paintMemberCluster(cv, 35,
              roleCounts: const {'owner': 5, 'sitter': 25, 'walker': 5},
              hasFriend: true);
        }, scale: 2);
        final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        int alpha(int x, int y) => data.getUint8((y * img.width + x) * 4 + 3);
        // Le rond (rayon 22 + anneau 2,5) : bord opaque à l'intérieur, et
        // l'image ne coupe rien sur les côtés / le haut (alpha ~0).
        final cx = img.width ~/ 2;
        expect(alpha(cx, (32 - 23) * 2), greaterThan(200));
        expect(alpha(cx, (32 + 23) * 2), greaterThan(200));
        expect(alpha((32 + 23) * 2, cx), greaterThan(200));
        for (var i = 0; i < img.width; i++) {
          expect(alpha(i, 0), lessThan(40));
          expect(alpha(0, i), lessThan(40));
          expect(alpha(img.width - 1, i), lessThan(40));
        }
        img.dispose();
      });
    });

    testWidgets('« Moi » couronne + fusée + œil barré : dessin sans erreur',
        (tester) async {
      await tester.runAsync(() async {
        final img = await renderPinImage(56 + 60, 56 + 60 + 14, (cv) {
          PawMapPinPainter.paintPhotoDot(cv,
              avatar: null,
              ringColor: const Color(0xFFC92A12),
              size: 56,
              label: 'Moi',
              crown: true,
              crownSize: 24,
              dashedRing: true,
              eyeOff: true,
              boostPhase: 0.5,
              margin: 30);
        }, scale: 2);
        expect(img.width, greaterThan(0));
        img.dispose();
      });
    });
  });

  test('pixels Mercator : 256 px pour le monde au zoom 0', () {
    final a = pawMercatorPx(0, -180, 0);
    final b = pawMercatorPx(0, 180, 0);
    expect((b.dx - a.dx), closeTo(256, 1e-6));
    expect(pawMercatorPx(0, 0, 1).dy, closeTo(256, 1e-6));
    expect(math.pow(2, 3), 8);
  });
}
