// 625 (PAM, 27/10/2026) — « les marqueurs ne sont pas à leur place ».
// Mesure, à Europe / France / Espagne / Paris, l'ÉCART entre la position
// AFFICHÉE d'un rond ou d'un groupe et une VRAIE position :
//   · après (règle 625, parité site) : groupe posé sur son membre le plus
//     central + glissement ≤ 12 pt → écart = distance au membre d'ancrage ;
//   · avant (règle 622) : groupe posé sur la MOYENNE + glissement jusqu'à
//     90/180 pt → écart = distance au membre RÉEL le plus proche du groupe.
// Mêmes données (points autour de vraies villes, dont des paires de côtes
// séparées par la mer), même écran (393 × 852 pt, en-tête, menu, rails).
// Et toujours : 0 chevauchement entre bulles visibles.
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:hopetsit/views/map/pawmap_camera_memory.dart';
import 'package:hopetsit/views/map/widgets/pawmap_anchor625.dart';
import 'package:hopetsit/views/map/widgets/pawmap_layout622.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_ring2610.dart';

import 'legacy624/layout622_624.dart' as old;
import 'legacy624/overlap607_624.dart' as old7;

class P {
  const P(this.id, this.lat, this.lng);
  final int id;
  final double lat, lng;
}

/// Villes réelles (lat, lng, nombre de membres) — densités proches de la
/// carte de production (Paris très dense, Espagne du Sud-Est, Benelux…).
const _cities = <(double, double, int)>[
  (48.8566, 2.3522, 70), (48.90, 2.25, 14), (48.80, 2.45, 12), // Paris + couronne
  (45.764, 4.835, 10), (43.296, 5.370, 9), (43.604, 1.444, 6), (47.218, -1.553, 5),
  (48.390, -4.486, 3), (49.494, 0.107, 4), (50.951, 1.858, 3), // Brest, Le Havre, Calais
  (51.128, 1.308, 3), (51.507, -0.128, 12), // Douvres, Londres
  (40.416, -3.703, 12), (41.385, 2.173, 10), (39.470, -0.376, 6), (37.983, -1.130, 8), // Murcie
  (37.851, -1.425, 5), (37.389, -5.984, 5), (36.721, -4.421, 6), (35.889, -5.321, 2), // Alhama, Ceuta
  (35.759, -5.834, 2), (38.345, -0.481, 5), (38.840, 0.106, 4), (39.569, 2.650, 3), // Tanger, Dénia, Palma
  (50.850, 4.352, 9), (52.370, 4.895, 8), (50.110, 8.682, 5), (52.520, 13.405, 8),
  (45.464, 9.190, 6), (41.903, 12.496, 5), (38.722, -9.139, 5), (41.149, -8.611, 3),
];

List<P> _data() {
  var seed = 625;
  double rnd() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  }

  final out = <P>[];
  var id = 0;
  for (final c in _cities) {
    for (var k = 0; k < c.$3; k++) {
      // Dispersion ~0-12 km autour du centre (floutage ~1 km compris).
      final r = 0.11 * math.sqrt(rnd());
      final a = rnd() * 2 * math.pi;
      out.add(P(id++, c.$1 + r * math.sin(a), c.$2 + r * math.cos(a) * 1.4));
    }
  }
  return out;
}

/// Cases de 44 pt (comme `_clusterize` de l'écran).
List<List<P>> _cells(List<P> pts, double zoom, double cell) {
  final m = <String, List<P>>{};
  for (final p in pts) {
    final q = pawMercatorPx(p.lat, p.lng, zoom);
    (m['${(q.dx / cell).floor()}:${(q.dy / cell).floor()}'] ??= <P>[]).add(p);
  }
  return m.values.toList();
}

class _Res {
  _Res(this.maxGap, this.overlaps, this.visible, this.hidden, this.atSea);
  final double maxGap;
  final int overlaps, visible, hidden;
  final int atSea; // groupe affiché à > 25 pt de tout membre réel
}

const _w = 393.0, _h = 852.0;
// En-tête + pilule (≈ 128 pt), menu du bas (≈ 110 pt), 6 pt des bords.
final Rect _bounds = Rect.fromLTRB(-_w / 2 + 6, -_h / 2 + 134, _w / 2 - 6, _h / 2 - 116);
final Rect _screen = Rect.fromCenter(center: Offset.zero, width: _w, height: _h);
// Rail gauche et capsule droite (boîtes mesurées au simulateur, 623).
final List<PawPlacedBox> _rails = <PawPlacedBox>[
  PawPlacedBox(const Offset(-_w / 2 + 30, 150), Rect.fromCenter(center: Offset.zero, width: 48, height: 200)),
  PawPlacedBox(const Offset(_w / 2 - 30, 150), Rect.fromCenter(center: Offset.zero, width: 48, height: 200)),
];

_Res _run(List<P> pts, double lat, double lng, double zoom, {required bool after}) {
  final cam = pawMercatorPx(lat, lng, zoom);
  Offset px(P p) => pawMercatorPx(p.lat, p.lng, zoom) - cam;
  final cells = _cells(pts, zoom, 44);
  Rect boxOf(List<P> g) => g.length > 1 ? pawPinBox(27.5) : pawRingBox2610(multi: false);
  final PawPlacement622<P> pl;
  if (after) {
    pl = pawPlace622<P>(
        pawMergeAnchored625<P>(cells, (p) => pawMercatorPx(p.lat, p.lng, zoom)), px,
        boxOf: boxOf, fixed: _rails, bounds: _bounds, screen: _screen, anchored: (_) => true);
  } else {
    // Code du build 624 tel quel (copie figée de 1acd43e3).
    final o = old.pawPlace622<P>(
        old7.pawMergeCloseGroups<P>(cells, (p) => pawMercatorPx(p.lat, p.lng, zoom)), px,
        boxOf: boxOf,
        fixed: [for (final r in _rails) old7.PawPlacedBox(r.at, r.box)],
        bounds: _bounds,
        screen: _screen);
    pl = PawPlacement622<P>(o.groups, o.shifts, o.compact);
  }
  var maxGap = 0.0;
  var visible = 0, hidden = 0, atSea = 0;
  final drawn = <Rect>[];
  for (var i = 0; i < pl.groups.length; i++) {
    final g = pl.groups[i];
    if (pl.isHidden(i)) {
      hidden++;
      continue;
    }
    // Position affichée : avant = moyenne (622) ; après = membre central.
    Offset shown;
    if (after) {
      shown = pawAnchorPx625(g, px);
    } else {
      var x = 0.0, y = 0.0;
      for (final p in g) {
        x += px(p).dx;
        y += px(p).dy;
      }
      shown = Offset(x / g.length, y / g.length);
    }
    shown += pl.shifts[i];
    final box = boxOf(g).shift(shown);
    if (!box.overlaps(_screen)) continue;
    visible++;
    drawn.add(box);
    // Écart à la vraie position la plus proche (un membre réel).
    var best = double.infinity;
    for (final p in g) {
      best = math.min(best, (px(p) - shown).distance);
    }
    if (after) best = (pawAnchorPx625(g, px) - shown).distance;
    maxGap = math.max(maxGap, best);
    if (g.length > 1) {
      var near = double.infinity;
      for (final p in g) {
        near = math.min(near, (px(p) - shown).distance);
      }
      if (near > 25) atSea++;
    }
  }
  var overlaps = 0;
  for (var i = 0; i < drawn.length; i++) {
    for (var j = i + 1; j < drawn.length; j++) {
      final x = drawn[i].intersect(drawn[j]);
      if (x.width > 0.5 && x.height > 0.5) overlaps++;
    }
  }
  return _Res(maxGap, overlaps, visible, hidden, atSea);
}

void main() {
  final pts = _data();
  final views = <(String, double, double, double)>[
    ('europe', 47.5, 3.0, 4.2),
    ('france', 46.7, 2.6, 5.6),
    ('espagne', 39.6, -2.5, 6.0),
    ('paris', 48.8566, 2.3522, 11.0),
  ];

  group('625 — fusion ancrée', () {
    test('aucune paire de positions affichées à moins de 56 pt', () {
      for (final z in <double>[4.2, 5.6, 6.0, 11.0]) {
        Offset q(P p) => pawMercatorPx(p.lat, p.lng, z);
        final gs = pawMergeAnchored625<P>(_cells(pts, z, 44), q);
        final at = [for (final g in gs) pawAnchorPx625(g, q)];
        for (var i = 0; i < at.length; i++) {
          for (var j = i + 1; j < at.length; j++) {
            expect((at[i] - at[j]).distance, greaterThanOrEqualTo(56), reason: 'z=$z');
          }
        }
        // Rien de perdu ni de doublé.
        expect(gs.fold<int>(0, (n, g) => n + g.length), pts.length);
      }
    });

    test('un groupe est posé sur un membre réel, jamais sur la moyenne', () {
      // Deux côtes face à face (Tarifa / Tanger) : la moyenne est en mer.
      const a = <Offset>[Offset(0, 0), Offset(2, 1), Offset(1, 3)];
      const b = <Offset>[Offset(40, 30), Offset(42, 31)];
      final pts2 = [...a, ...b];
      final g = pawMergeAnchored625<Offset>([pts2.sublist(0, 3), pts2.sublist(3)], (o) => o);
      expect(g.length, 1);
      final anchor = pawAnchorPx625(g.first, (o) => o);
      expect(pts2.contains(anchor), isTrue);
    });

    test('médoïde = le membre le plus proche du centre', () {
      expect(pawMedoidIndex625(const [Offset(0, 0), Offset(10, 0), Offset(4, 0)]), 2);
      expect(pawMedoidIndex625(const [Offset(5, 5)]), 0);
    });
  });

  group('625 — écart affiché / réel (Europe, France, Espagne, Paris)', () {
    for (final v in views) {
      test('${v.$1} : écart ≤ 12 pt, 0 chevauchement, aucun groupe en mer', () {
        final before = _run(pts, v.$2, v.$3, v.$4, after: false);
        final after = _run(pts, v.$2, v.$3, v.$4, after: true);
        // ignore: avoid_print
        print('MESURE625 ${v.$1} z=${v.$4} AVANT ecart_max=${before.maxGap.toStringAsFixed(1)} '
            'chev=${before.overlaps} visibles=${before.visible} en_mer=${before.atSea} | '
            'APRES ecart_max=${after.maxGap.toStringAsFixed(1)} chev=${after.overlaps} '
            'visibles=${after.visible} masques=${after.hidden} en_mer=${after.atSea}');
        expect(after.maxGap, lessThanOrEqualTo(12.0 + 1e-6));
        expect(after.overlaps, 0);
        expect(after.atSea, 0);
        expect(after.visible, greaterThan(0));
      });
    }
  });

  group('625 — règles de la passe', () {
    test('un rond ancré sur un obstacle fixe (Moi) est masqué, pas déplacé loin', () {
      final pl = pawPlace622<Offset>(
        [
          [const Offset(0, 0)],
        ],
        (o) => o,
        boxOf: (_) => pawRingBox2610(multi: false),
        fixed: [PawPlacedBox(const Offset(4, 4), pawPinBox(30))],
        anchored: (_) => true,
      );
      expect(pl.isHidden(0), isTrue);
    });

    test('un ami (immobile) n\'est jamais masqué', () {
      final pl = pawPlace622<Offset>(
        [
          [const Offset(0, 0)],
          [const Offset(10, 0)],
        ],
        (o) => o,
        boxOf: (_) => pawRingBox2610(multi: false),
        movable: (g) => g.first != const Offset(0, 0),
        canMerge: (a, b) => false,
        anchored: (_) => true,
      );
      expect(pl.isHidden(0), isFalse);
      expect(pl.isHidden(1), isTrue);
    });

    test('une demande s\'écarte, le rond de personne reste sur sa position', () {
      const member = Offset(0, 0);
      const req = Offset(8, 0);
      final pl = pawPlace622<Offset>(
        [
          [member],
          [req],
        ],
        (o) => o,
        boxOf: (g) => g.first == req
            ? const Rect.fromLTRB(-30, -35, 30, 1)
            : pawRingBox2610(multi: false),
        canMerge: (a, b) => false,
        anchored: (g) => g.first == member,
      );
      final mi = pl.groups.indexWhere((g) => g.first == member);
      final ri = pl.groups.indexWhere((g) => g.first == req);
      expect(pl.isHidden(mi), isFalse);
      expect(pl.shifts[mi].distance, lessThanOrEqualTo(12));
      expect(pl.isHidden(ri) || pl.shifts[ri].distance > 12, isTrue);
    });
  });

  group('625 — centrage initial : GPS → profil → Paris', () {
    const prof = <String, dynamic>{
      'location': {
        'coordinates': [-1.425, 37.851]
      }
    };
    test('la caméra mémorisée = repli Paris ne compte pas', () {
      final paris = PawMapCameraMemory.encode(PawMapCameraMemory.fallbackCenter, 10);
      expect(PawMapCameraMemory.savedCenter(paris), isNull);
      final c = PawMapCameraMemory.centerFrom(paris, prof);
      expect(c.latitude, closeTo(37.851, 1e-9));
      expect(c.longitude, closeTo(-1.425, 1e-9));
    });
    test('un vrai dernier endroit regardé reste prioritaire', () {
      final mem = PawMapCameraMemory.encode(const LatLng(37.99, -1.13), 12);
      expect(PawMapCameraMemory.centerFrom(mem, prof).latitude, closeTo(37.99, 1e-9));
      expect(PawMapCameraMemory.noGpsCenter(trustedMemory: true, profile: const LatLng(1, 1)), isNull);
    });
    test('sans GPS ni mémoire : la position du profil, Paris seulement sans profil', () {
      expect(PawMapCameraMemory.noGpsCenter(trustedMemory: false, profile: const LatLng(37.851, -1.425))!.latitude,
          closeTo(37.851, 1e-9));
      expect(PawMapCameraMemory.centerFrom(null, null), PawMapCameraMemory.fallbackCenter);
      expect(PawMapCameraMemory.isFallback(const LatLng(48.85661, 2.35221)), isTrue);
      expect(PawMapCameraMemory.isFallback(const LatLng(48.86, 2.35)), isFalse);
    });
  });
}
