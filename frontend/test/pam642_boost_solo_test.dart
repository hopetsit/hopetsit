// 642 (PAM) — PawBoost visible à tous les zooms : un profil boosté ne rentre
// jamais dans un groupe et se pose À CÔTÉ du rond le plus proche (jumeau de
// website/src/lib/pawmapBoost1111.ts). Positions de test : pixels d'écran
// d'une zone fictive (lat −35 / lng −30), jamais une vraie ville.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_boost642.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';

void main() {
  group('642 · un boosté ne rentre jamais dans un groupe', () {
    test('coupe-circuit allumé par défaut ; écart : 36 sur le site, 44 dans l\'app',
        () {
      expect(kPawBoostSolo642, isTrue);
      expect(kPawBoostGapWeb1111, 36);
      // pastille boostée de l'app = anneau net de 43 pt → 44 (rien ne se touche)
      expect(kPawBoostGap642, 44);
      expect(pawBoostSolo642(true), isTrue);
      expect(pawBoostSolo642(false), isFalse);
      expect(pawBoostSolo642(true, enabled: false), isFalse);
    });

    test('à tous les zooms : le boosté reste seul, les autres se groupent', () {
      // 6 profils dans la même ville fictive (−35 / −30), dont 2 boostés.
      final people = <({String id, bool boost, double lat, double lng})>[
        for (var i = 0; i < 6; i++)
          (id: 'p$i', boost: i == 1 || i == 4, lat: -35 + i * 0.0004, lng: -30 + i * 0.0003),
      ];
      for (var zoom = 2; zoom <= 18; zoom++) {
        // regroupement « tout ce qui est à moins de 44 px » au zoom donné
        List<List<({String id, bool boost, double lat, double lng})>> cluster(
            List<({String id, bool boost, double lat, double lng})> others) {
          final out = <List<({String id, bool boost, double lat, double lng})>>[];
          for (final p in others) {
            final px = pawMercatorPx(p.lat, p.lng, zoom.toDouble());
            final g = out.where((g) =>
                (pawMercatorPx(g.first.lat, g.first.lng, zoom.toDouble()) - px).distance < 44);
            if (g.isEmpty) {
              out.add([p]);
            } else {
              g.first.add(p);
            }
          }
          return out;
        }

        final groups = pawGroupKeepingFriends(
            people, (p) => pawBoostSolo642(p.boost), cluster);
        for (final g in groups) {
          if (g.any((p) => p.boost)) {
            expect(g.length, 1, reason: 'zoom $zoom : un boosté est toujours seul');
          }
        }
        expect(groups.where((g) => g.length == 1 && g.first.boost).length, 2,
            reason: 'zoom $zoom : les 2 boostés ont chacun leur pastille');
        // coupe-circuit coupé : comme au 641, ils se fondent dans le groupe
        final off = pawGroupKeepingFriends(
            people, (p) => pawBoostSolo642(p.boost, enabled: false), cluster);
        if (zoom <= 8) expect(off.length, 1, reason: 'zoom $zoom : un seul groupe');
      }
    });
  });

  group('642 · placement à côté des groupes (jumeau du site)', () {
    test('place libre : aucun décalage', () {
      final off = pawBoostOffsets642(
          [(id: 'a', px: const Offset(100, 100))], [const Offset(200, 100)]);
      expect(off, isEmpty);
    });

    test('piège de ZOE : boosté SUR le rond du groupe de sa ville → à côté', () {
      const group = Offset(300, 300);
      final off = pawBoostOffsets642([(id: 'a', px: group)], [group]);
      expect(off.containsKey('a'), isTrue);
      final at = group + off['a']!;
      // au moins 36 px du rond du groupe : son compteur reste lisible
      expect((at - group).distance, greaterThanOrEqualTo(kPawBoostGap642));
      // exactement au-dessus (direction −π/2, cercle 1 = écart + 2)
      expect(off['a'], const Offset(0, -46));
      // avec l'écart du site : la place du site (38 px au-dessus)
      expect(pawBoostOffsets642([(id: 'a', px: group)], [group], gap: kPawBoostGapWeb1111)['a'],
          const Offset(0, -38));
    });

    test('part de la direction du boosté, sur le 1er cercle', () {
      const group = Offset(300, 300);
      final off = pawBoostOffsets642(
          [(id: 'a', px: const Offset(310, 300))], [group]); // 10 px à droite
      expect(off['a'], const Offset(36, 0)); // 346 − 310
      expect(
          pawBoostOffsets642([(id: 'a', px: const Offset(310, 300))], [group],
              gap: kPawBoostGapWeb1111)['a'],
          const Offset(28, 0)); // site : 338 − 310
    });

    test('plusieurs boostés dans la même ville : aucun empilement', () {
      const group = Offset(300, 300);
      final boosted = [
        for (var i = 0; i < 12; i++)
          (id: 'b${i.toString().padLeft(2, '0')}', px: Offset(300 + i * 0.5, 300 - i * 0.3)),
      ];
      final obstacles = [group, const Offset(330, 300)];
      // calcul du site (4 cercles, sans plafond de déplacement)
      final off = pawBoostOffsets642(boosted, obstacles, maxShift: double.infinity);
      expect(off.length, 12);
      final at = [for (final b in boosted) b.px + (off[b.id] ?? Offset.zero)];
      for (var i = 0; i < at.length; i++) {
        for (final o in obstacles) {
          expect((at[i] - o).distance, greaterThanOrEqualTo(kPawBoostGap642 - 0.75),
              reason: 'b$i ne touche aucun groupe (arrondi au px)');
        }
        for (var j = i + 1; j < at.length; j++) {
          expect((at[i] - at[j]).distance, greaterThanOrEqualTo(kPawBoostGap642 - 1.5),
              reason: 'b$i et b$j ne se recouvrent pas');
        }
      }
    });

    test('ordre stable : mêmes données dans le désordre = mêmes places', () {
      const group = Offset(300, 300);
      final a = [
        (id: 'zed', px: const Offset(301, 300)),
        (id: 'amy', px: const Offset(299, 301)),
        (id: 'kim', px: const Offset(300, 299)),
      ];
      final r1 = pawBoostOffsets642(a, [group], maxShift: double.infinity);
      final r2 = pawBoostOffsets642(a.reversed.toList(), [group], maxShift: double.infinity);
      expect(r1, r2);
      expect(r1.length, 3);
    });

    test('aucun obstacle : rien ne bouge, sauf deux boostés au même endroit', () {
      expect(pawBoostOffsets642([(id: 'a', px: const Offset(10, 10))], const []), isEmpty);
      final off = pawBoostOffsets642([
        (id: 'a', px: const Offset(10, 10)),
        (id: 'b', px: const Offset(10, 10)),
      ], const []);
      expect(off.containsKey('a'), isFalse); // le 1er (ordre des ids) garde sa place
      expect(off['b'], const Offset(0, -46));
    });

    test('rien ne se touche dans l\'app : groupe 32, ami 41, « Moi » 44, boosté 43',
        () {
      // un boosté décalé est à ≥ 44 de tout : son anneau (21,5) ne mord ni le
      // rond d'un groupe (16), ni un ami (20,5), ni « Moi » (22).
      const town = Offset(200, 200);
      final off = pawBoostOffsets642([
        (id: 'a', px: town),
        (id: 'b', px: town),
        (id: 'c', px: town),
      ], [town]);
      final at = [for (final id in ['a', 'b', 'c']) town + off[id]!];
      for (final p in at) {
        expect((p - town).distance >= 21.5 + 22, isTrue);
      }
      for (var i = 0; i < 3; i++) {
        for (var j = i + 1; j < 3; j++) {
          expect((at[i] - at[j]).distance >= 43, isTrue,
              reason: 'deux anneaux PawBoost ne se recouvrent pas');
        }
      }
    });

    test('zone saturée (4 cercles pleins) : il reste à sa vraie position', () {
      // un mur d'obstacles tous les 20 px sur 600 × 600
      final wall = [
        for (var x = 0.0; x <= 600; x += 20)
          for (var y = 0.0; y <= 600; y += 20) Offset(x, y),
      ];
      final off = pawBoostOffsets642([(id: 'a', px: const Offset(300, 300))], wall);
      expect(off, isEmpty);
    });

    test('même calcul que le site sur un cas chiffré (4e essai : à droite)', () {
      // groupe en (0,0), un obstacle juste au-dessus : la place du haut est
      // prise, les deux diagonales (±45°) sont à 29 px de l'obstacle → le
      // 4e essai (+2 pas = plein est) est le premier libre.
      final off = pawBoostOffsets642(
          [(id: 'a', px: Offset.zero)], [Offset.zero, const Offset(0, -38)],
          gap: kPawBoostGapWeb1111);
      expect(off['a'], const Offset(38, 0));
    });
  });

  // ── Bornes demandées par le contrôle de ZOE ──────────────────────────────
  group('642 · bornes (a) déplacement ≤ 60 pt', () {
    test('constantes', () {
      expect(kPawBoostMaxShift642, 60);
      expect(kPawBoostSoloMax642, 24);
    });
    test('30 boostés empilés sur un groupe : aucun ne bouge de plus de 60 pt', () {
      const town = Offset(0, 0);
      final boosted = [
        for (var i = 0; i < 30; i++)
          (id: 'b${i.toString().padLeft(2, '0')}', px: Offset(i * 0.7 - 10, i * 0.4 - 6)),
      ];
      final off = pawBoostOffsets642(boosted, [town]);
      var maxD = 0.0;
      for (final o in off.values) {
        if (o.distance > maxD) maxD = o.distance;
      }
      // ignore: avoid_print
      print('642 bornes · 30 boostés sur un groupe : ${off.length} décalés, '
          'déplacement max ${maxD.toStringAsFixed(1)} pt, '
          '${30 - off.length} restés à leur vraie position');
      expect(maxD <= 60.75, isTrue, reason: 'max $maxD'); // arrondi au px
      expect(off.isNotEmpty, isTrue);
      expect(off.length < 30, isTrue,
          reason: 'sans place à 60 pt : vraie position (cas rare, accepté)');
      // sans le plafond (le site) : on retrouve les grands sauts relevés
      final far = pawBoostOffsets642(boosted, [town], maxShift: double.infinity);
      expect(far.values.any((o) => o.distance > 100), isTrue);
    });
    test('pas de place à 60 pt : il reste à sa vraie position', () {
      // tout le 1er cercle (46 pt) est pris par des pastilles
      final ring = [
        for (var k = 0; k < 16; k++)
          Offset(46 * math.cos(k * math.pi / 8), 46 * math.sin(k * math.pi / 8)),
      ];
      final off = pawBoostOffsets642(
          [(id: 'a', px: Offset.zero)], [Offset.zero, ...ring]);
      expect(off, isEmpty);
    });
  });

  group('642 · bornes (b) 24 boostés solo au plus', () {
    test('40 boostés : les 24 plus proches du centre, ordre stable', () {
      final all = [
        for (var i = 0; i < 40; i++)
          (id: 'p${i.toString().padLeft(2, '0')}', dist2: ((i * 7) % 40).toDouble()),
      ];
      final pick = pawBoostSoloPick642(all);
      expect(pick.length, 24);
      for (final b in all) {
        expect(pick.contains(b.id), b.dist2 < 24, reason: b.id);
      }
      expect(pawBoostSoloPick642(all.reversed.toList()), pick);
    });
    test('à distance égale : départagés par l\'identifiant', () {
      final pick = pawBoostSoloPick642([
        (id: 'c', dist2: 1.0),
        (id: 'a', dist2: 1.0),
        (id: 'b', dist2: 1.0),
      ], max: 2);
      expect(pick, {'a', 'b'});
    });
    test('les autres retournent dans les groupes (comme au 641)', () {
      // 30 boostés dans la même ville fictive : 24 pastilles + 1 groupe de 6
      final people = [for (var i = 0; i < 30; i++) 'p${i.toString().padLeft(2, '0')}'];
      final pick = pawBoostSoloPick642(
          [for (var i = 0; i < 30; i++) (id: people[i], dist2: i.toDouble())]);
      final groups = pawGroupKeepingFriends<String>(
          people, pick.contains, (others) => [if (others.isNotEmpty) others]);
      expect(groups.where((g) => g.length == 1).length, 24);
      expect(groups.last.length, 6);
    });
    test('moins de 24 : tous gardés ; aucun : ensemble vide', () {
      expect(pawBoostSoloPick642([(id: 'x', dist2: 9.0)]), {'x'});
      expect(pawBoostSoloPick642(const []), isEmpty);
    });
  });

  group('642 · bornes (c) jamais hors de la zone visible', () {
    // zone visible fictive : 360 × 600 centrée, en-tête 100, menu 90, 6 de bord
    const bounds = Rect.fromLTRB(-174, -194, 174, 204);
    test('pawBoostAllowed642 : la pastille tient entière, hors rails', () {
      final ok = pawBoostAllowed642(bounds, [const Rect.fromLTWH(-174, -60, 48, 200)]);
      expect(ok(Offset.zero), isTrue);
      expect(ok(const Offset(160, 0)), isFalse); // bord droit
      expect(ok(const Offset(0, -180)), isFalse); // sous l'en-tête
      expect(ok(const Offset(0, 190)), isFalse); // dans le menu
      expect(ok(const Offset(-140, 0)), isFalse); // sur le rail gauche
      expect(pawBoostAllowed642(null, const [])(const Offset(9999, 0)), isTrue);
    });
    test('groupe collé au bord droit : le boosté part vers l\'intérieur', () {
      const town = Offset(150, 0); // à 24 pt du bord
      final off = pawBoostOffsets642([(id: 'a', px: const Offset(152, 0))], [town],
          allowed: pawBoostAllowed642(bounds, const []));
      final at = const Offset(152, 0) + off['a']!;
      expect(at.dx + kPawBoostPinR642 <= bounds.right, isTrue, reason: '$at');
      expect((at - town).distance >= kPawBoostGap642 - 0.75, isTrue);
      // sans la règle : il sortait de l'écran (1re place = vers la droite)
      final raw = pawBoostOffsets642([(id: 'a', px: const Offset(152, 0))], [town]);
      expect(152 + raw['a']!.dx + kPawBoostPinR642 > bounds.right, isTrue);
    });
    test('groupe dans un coin, aucune place visible à 60 pt : vraie position', () {
      const town = Offset(170, 200); // coin bas-droit, déjà à moitié dehors
      final off = pawBoostOffsets642([(id: 'a', px: town)], [town],
          allowed: pawBoostAllowed642(const Rect.fromLTRB(150, 180, 174, 204), const []));
      expect(off, isEmpty);
    });
    test('groupe sous le rail : la place sur le rail est sautée', () {
      const rail = Rect.fromLTWH(-174, -100, 48, 220);
      const town = Offset(-100, 0);
      final off = pawBoostOffsets642([(id: 'a', px: const Offset(-104, 0))], [town],
          allowed: pawBoostAllowed642(bounds, const [rail]));
      final at = const Offset(-104, 0) + off['a']!;
      expect(rail.overlaps(Rect.fromCircle(center: at, radius: kPawBoostPinR642)), isFalse);
    });
  });

  // ── Coût : identifiants boostés relevés UNE fois par reconstruction ──────
  group('642 · coût du test « boosté ? »', () {
    List<Map<String, dynamic>> layer(int n, int boosted) => [
          for (var i = 0; i < n; i++)
            {
              'id': 'u$i',
              'personIds': ['u$i', 'u${i}s', 'u${i}w'],
              if (i < boosted && i.isEven) 'isBoosted': true,
              // boost porté par un AUTRE rôle de la personne (cas v597)
            },
          for (var i = 1; i < boosted; i += 2)
            {'id': 'u${i}w', 'personIds': ['u$i', 'u${i}w'], 'isBoosted': true},
        ];

    // l'ancien test (parcours de toute la couche à chaque question)
    bool oldBoosted(Map p, List<Map<String, dynamic>> world) {
      if (p['isBoosted'] == true) return true;
      for (final id in pawMapPersonIds(p)) {
        final k = id.trim().toLowerCase();
        if (world.any((q) =>
            q['isBoosted'] == true &&
            pawMapPersonIds(q).any((x) => x.trim().toLowerCase() == k))) {
          return true;
        }
      }
      return false;
    }

    test('même réponse que l\'ancien parcours, pour chaque profil', () {
      final w = layer(400, 30);
      final ids = pawBoostedIds642([w]);
      var n = 0;
      for (final p in w) {
        expect(pawIsBoosted642(p, ids), oldBoosted(p, w), reason: '${p['id']}');
        if (pawIsBoosted642(p, ids)) n++;
      }
      expect(n, 45); // 30 personnes, dont 15 comptées par leurs 2 points
      expect(pawBoostedIds642(const []), isEmpty);
      expect(pawIsBoosted642({'id': 'x'}, const {}), isFalse);
    });

    test('mesure avant / après pour 400, 1 000 et 2 000 membres (30 boostés)', () {
      for (final n in [400, 1000, 2000]) {
        final w = layer(n, 30);
        // avant : 3 questions par membre et par reconstruction
        final sw = Stopwatch()..start();
        var a = 0;
        for (var r = 0; r < 3; r++) {
          for (final p in w) {
            if (oldBoosted(p, w)) a++;
          }
        }
        final before = sw.elapsedMicroseconds;
        // après : l'ensemble une fois, puis les mêmes 3 questions
        sw
          ..reset()
          ..start();
        final ids = pawBoostedIds642([w]);
        var b = 0;
        for (var r = 0; r < 3; r++) {
          for (final p in w) {
            if (pawIsBoosted642(p, ids)) b++;
          }
        }
        final after = sw.elapsedMicroseconds;
        // ignore: avoid_print
        print('642 coût · $n membres : avant ${(before / 1000).toStringAsFixed(1)} ms, '
            'après ${(after / 1000).toStringAsFixed(2)} ms');
        expect(a, b);
        expect(after * 5 < before, isTrue, reason: '$n : $before → $after µs');
      }
    });
  });
}
