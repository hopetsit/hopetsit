// 626 (PAM, 27/10/2026) — bug de Daniel : « le zoom dézoom bug, des fois ça
// apparaît les groupes d'autres fois pas, après ça ouvre les gens dans l'eau ».
//   1. STABILITÉ : à un même zoom et une même zone, les mêmes groupes quel
//      que soit le chemin (zoom avant, arrière, déplacement, ordre de
//      chargement des données).
//   2. ÉCLATEMENT : toucher un groupe dézoomé → la carte zoome sur ses
//      membres ; chacun est affiché à ≤ 12 pt de sa vraie position, aucun
//      en mer. Mesure « avant » : l'anneau fixe 623 (72/132/192 pt).
// Données synthétiques (villes réelles du Nord-Est des USA et d'Europe, points
// dispersés de quelques km) — aucune donnée de membre.
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_cluster626.dart';
import 'package:hopetsit/views/map/widgets/pawmap_layout622.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_ring2610.dart';

class P {
  const P(this.id, this.lat, this.lng);
  final String id;
  final double lat, lng;
}

// Villes à terre (lat, lng, membres).
const _neUsa = <(double, double, int)>[
  (40.713, -74.006, 9), (40.735, -74.172, 3), (39.953, -75.165, 5), // NY, Newark, Philadelphie
  (42.360, -71.058, 5), (41.824, -71.413, 2), (41.765, -72.674, 2), // Boston, Providence, Hartford
  (42.652, -73.757, 3), (43.048, -76.147, 2), (39.290, -76.612, 4), // Albany, Syracuse, Baltimore
  (38.907, -77.037, 3), (40.441, -79.996, 2), (44.476, -73.212, 2), // Washington, Pittsburgh, Burlington
];
const _europe = <(double, double, int)>[
  (48.8566, 2.3522, 60), (52.370, 4.895, 14), (51.924, 4.478, 6), (50.850, 4.352, 9),
  (45.764, 4.835, 6), (43.296, 5.370, 4), (46.204, 6.143, 7), (50.110, 8.682, 5),
  (53.551, 9.993, 6), (43.710, 7.262, 3), (37.851, -1.425, 5), (51.507, -0.128, 8),
];

List<P> _gen(List<(double, double, int)> cities, int seed0, String pre) {
  var seed = seed0;
  double rnd() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  }

  final out = <P>[];
  var id = 0;
  for (final c in cities) {
    for (var k = 0; k < c.$3; k++) {
      final r = 0.06 * math.sqrt(rnd()); // ≤ ~7 km : reste à terre
      final a = rnd() * 2 * math.pi;
      out.add(P('$pre${(id++).toString().padLeft(4, '0')}', c.$1 + r * math.sin(a),
          c.$2 + r * math.cos(a) * 1.3));
    }
  }
  return out;
}

PawClusterIndex626<P> _index(List<P> pts) => PawClusterIndex626<P>(pts,
    idOf: (p) => p.id, posOf: (p) => (lat: p.lat, lng: p.lng));

/// Groupes visibles dans l'écran 393 × 852 centré sur (lat, lng) au zoom z,
/// en ensembles d'identifiants triés (comparables entre deux chemins).
Set<String> _view(PawClusterIndex626<P> idx, double lat, double lng, double z) {
  final cam = pawMercatorPx(lat, lng, z);
  final scr = Rect.fromCenter(center: Offset.zero, width: 393, height: 852);
  final out = <String>{};
  for (final c in idx.clustersAt(z)) {
    final a = c.anchor * math.pow(2.0, z).toDouble() - cam;
    if (!scr.inflate(30).contains(a)) continue;
    out.add((List<String>.of(c.ids)..sort()).join(','));
  }
  return out;
}

/// Les groupes affichés à l'écran (positions en pt), pour le contrôle visuel.
List<(Offset, int)> _shown(PawClusterIndex626<P> idx, double lat, double lng, double z) {
  final cam = pawMercatorPx(lat, lng, z);
  return [
    for (final c in idx.clustersAt(z)) (c.anchor * math.pow(2.0, z).toDouble() - cam, c.length),
  ];
}

void main() {
  final usa = _gen(_neUsa, 626, 'u');
  final eu = _gen(_europe, 2710, 'e');
  final all = [...usa, ...eu];

  group('626 — regroupement stable', () {
    test('même zoom + même zone = mêmes groupes, quel que soit le chemin', () {
      // Chemin A : données chargées dans un ordre, arrivée par zoom avant
      // (4,2 → 5,0 → 5,6). Chemin B : autre ordre de chargement, arrivée par
      // dézoom (8 → 6,1 → 5,6) et en passant par une autre zone.
      final idxA = _index(all);
      final idxB = _index(all.reversed.toList());
      var diffs = 0;
      for (final v in <(double, double, double)>[
        (41.5, -73.5, 5.6), (47.5, 4.0, 4.6), (48.8566, 2.3522, 10.2), (52.0, 5.0, 7.3),
      ]) {
        for (final dz in <double>[0, 0.31, 0.77]) {
          final z = v.$3.floorToDouble() + dz;
          final a = _view(idxA, v.$1, v.$2, z);
          final b = _view(idxB, v.$1, v.$2, z);
          if (a.length != b.length || !a.containsAll(b)) diffs++;
        }
      }
      // ignore: avoid_print
      print('MESURE626 stabilite : vues differentes entre 2 chemins = $diffs / 12');
      expect(diffs, 0);
    });

    test('entre deux niveaux entiers, les groupes ne bougent pas (5,02 = 5,48 = 5,97)', () {
      final idx = _index(all);
      Set<String> all0(double z) =>
          {for (final c in idx.clustersAt(z)) (List<String>.of(c.ids)..sort()).join(',')};
      final a = all0(5.02);
      expect(all0(5.48), a);
      expect(all0(5.97), a);
      expect(all0(6.01), isNot(a)); // au niveau suivant, ils se divisent
    });

    test('hiérarchie : un groupe se divise en ses enfants (jamais de membre qui saute ailleurs)', () {
      final idx = _index(all);
      for (var z = 1; z <= kPawClusterMaxZoom626; z++) {
        final parentOf = <String, int>{};
        final up = idx.clustersAt(z - 1.0);
        for (var i = 0; i < up.length; i++) {
          for (final id in up[i].ids) {
            parentOf[id] = i;
          }
        }
        for (final c in idx.clustersAt(z.toDouble())) {
          expect(c.ids.map((id) => parentOf[id]).toSet().length, 1, reason: 'z=$z');
        }
      }
    });

    test('≥ 56 pt entre deux groupes affichés, à tout zoom (rien ne se chevauche)', () {
      final idx = _index(all);
      for (final z in <double>[3.0, 4.6, 5.99, 8.5, 11.2, 14.0]) {
        final s = _shown(idx, 0, 0, z);
        for (var i = 0; i < s.length; i++) {
          for (var j = i + 1; j < s.length; j++) {
            expect((s[i].$1 - s[j].$1).distance, greaterThanOrEqualTo(56 - 1e-6), reason: 'z=$z');
          }
        }
      }
      // Rien de perdu ni de doublé.
      expect(idx.clustersAt(4.2).fold<int>(0, (n, c) => n + c.length), all.length);
    });

    test('un groupe est posé sur un vrai membre (jamais la moyenne)', () {
      final idx = _index(all);
      for (final z in <double>[3, 4, 5, 6]) {
        for (final c in idx.clustersAt(z)) {
          expect(c.pts.contains(c.anchor), isTrue);
        }
      }
    });

    test('100 recalculs en < 1 s pour 2 000 membres (la carte reste vive)', () {
      final big = <P>[
        for (var k = 0; k < 2000; k++)
          P('b$k', 40 + (k % 50) * 0.21 + (k * 7 % 13) * 0.01, -10 + (k ~/ 50) * 0.5),
      ];
      final sw = Stopwatch()..start();
      final idx = _index(big);
      final build = sw.elapsedMilliseconds;
      for (var i = 0; i < 100; i++) {
        idx.clustersAt(3 + i * 0.1);
      }
      // ignore: avoid_print
      print('MESURE626 perf : index 2000 points = $build ms, 100 lectures = ${sw.elapsedMilliseconds - build} ms');
      expect(sw.elapsedMilliseconds - build, lessThan(1000));
      expect(build, lessThan(5000));
    });
  });

  group('626 — toucher un groupe dézoomé (Nord-Est des USA)', () {
    test('la carte zoome sur ses membres : chacun à ≤ 12 pt de sa vraie position, aucun en mer', () {
      final idx = _index(all);
      const z0 = 4.6; // vue dézoomée du Nord-Est (capture daniel_1)
      final c = idx.clustersAt(z0).reduce((a, b) =>
          (a.ids.first.startsWith('u') && a.length >= b.length) ? a : (b.ids.first.startsWith('u') ? b : a));
      expect(c.length, greaterThanOrEqualTo(20));
      final exp = idx.expansionLevel(c.ids, fromZoom: z0);
      final t = pawClusterTapTarget626(
          pts: c.pts, w: 393 - 144, h: 852 - 310, currentZoom: z0, expansionLevel: exp)!;
      expect(t.zoom, greaterThan(z0));
      // À l'arrivée, chaque membre du groupe touché est dans un rond posé sur
      // un vrai membre : seul → sur lui-même (écart 0) ; dans un sous-groupe
      // → sur le membre le plus central du sous-groupe (vraie position, à terre).
      final byId = {for (final p in all) p.id: p};
      final want = c.ids.toSet();
      var maxSoloGap = 0.0;
      var shownAtSea = 0;
      var subGroups = 0;
      for (final g in idx.clustersAt(t.zoom)) {
        if (!g.ids.any(want.contains)) continue;
        subGroups++;
        final anchorItem = g.anchorItem;
        // « En mer » = posé ailleurs que sur un vrai membre.
        if (!g.pts.contains(g.anchor)) shownAtSea++;
        if (g.length == 1) {
          final p = byId[g.ids.first]!;
          final d = (pawMercatorPx(p.lat, p.lng, t.zoom) -
                  pawMercatorPx(anchorItem.lat, anchorItem.lng, t.zoom))
              .distance;
          maxSoloGap = math.max(maxSoloGap, d);
        }
      }
      // AVANT (623) : anneau fixe 72/132/192 pt autour du centre, au zoom +1,5.
      final fan = pawSpiderfy2610(math.min(c.length, kSpiderMax2610));
      final hub = c.anchor;
      final zOld = z0 + 1.5;
      var oldMax = 0.0;
      var oldKm = 0.0;
      for (var j = 0; j < fan.length; j++) {
        final p = byId[c.ids[j]]!;
        final real = pawMercatorPx(p.lat, p.lng, zOld);
        final shown = hub * math.pow(2.0, zOld).toDouble() + fan[j];
        final d = (real - shown).distance;
        oldMax = math.max(oldMax, d);
        // pt → km à cette latitude (1 pt = 40075 km·cos(lat) / (256·2^z)).
        oldKm = math.max(oldKm,
            d * 40075 * math.cos(p.lat * math.pi / 180) / (256 * math.pow(2.0, zOld)));
      }
      // ignore: avoid_print
      print('MESURE626 eclatement groupe=${c.length} z=$z0 -> ${t.zoom.toStringAsFixed(2)} '
          '(niveau de division $exp) | APRES : ${subGroups} ronds, ecart max seul = '
          '${maxSoloGap.toStringAsFixed(1)} pt, poses hors d un vrai membre = $shownAtSea | '
          'AVANT (anneau 623) : ecart max = ${oldMax.toStringAsFixed(0)} pt = ${oldKm.toStringAsFixed(0)} km');
      expect(subGroups, greaterThan(1)); // le groupe s'est divisé
      expect(maxSoloGap, lessThanOrEqualTo(12));
      expect(shownAtSea, 0);
      expect(oldMax, greaterThan(12)); // l'ancien anneau violait la règle
    });

    test('points superposés : pas de zoom, la liste (jamais d\'anneau)', () {
      final same = [const P('a', 40.7, -74.0), const P('b', 40.7, -74.0), const P('c', 40.7, -74.0)];
      final idx = _index(same);
      final c = idx.clustersAt(12).single;
      expect(idx.expansionLevel(c.ids, fromZoom: 12), isNull);
      expect(
          pawClusterTapTarget626(
              pts: c.pts, w: 250, h: 500, currentZoom: 12, expansionLevel: null),
          isNull);
    });
  });

  group('626 — passe de placement : un groupe de membres n\'est plus masqué', () {
    test('sous un rail / au bord : affiché (keepAnchored), ≤ 12 pt de glissement', () {
      final pl = pawPlace622<Offset>(
        [
          [const Offset(-170, 150)], // sous le rail gauche
          [const Offset(0, -400)], // coupé en haut
        ],
        (o) => o,
        boxOf: (_) => pawPinBox(27.5),
        fixed: [PawPlacedBox(const Offset(-166, 150), Rect.fromCenter(center: Offset.zero, width: 48, height: 200))],
        bounds: const Rect.fromLTRB(-190, -292, 190, 310),
        screen: Rect.fromCenter(center: Offset.zero, width: 393, height: 852),
        anchored: (_) => true,
        keepAnchored: true,
      );
      expect(pl.groups.length, 2);
      expect(pl.isHidden(0), isFalse);
      expect(pl.isHidden(1), isFalse);
      for (final s in pl.shifts) {
        expect(s.distance, lessThanOrEqualTo(12 + 1e-6));
      }
    });
  });
}
