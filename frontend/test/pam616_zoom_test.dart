// 616 (PAM) — recalcul des épingles PENDANT un zoom/dézoom rapide.
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/widgets/pawmap_zoom616.dart';

void main() {
  final t0 = DateTime(2026, 10, 15, 12, 0, 0);
  test('pas de recalcul sous un demi-niveau de zoom', () {
    expect(
        pawMapRecalcDuringMove616(
            zoom: 12.4, pinZoom: 12.0, lastAt: null, now: t0),
        isFalse);
  });
  test('recalcul dès 0,5 niveau, immédiat au premier coup', () {
    expect(
        pawMapRecalcDuringMove616(
            zoom: 12.5, pinZoom: 12.0, lastAt: null, now: t0),
        isTrue);
    expect(
        pawMapRecalcDuringMove616(
            zoom: 3.0, pinZoom: 12.0, lastAt: null, now: t0),
        isTrue);
  });
  test('au plus un recalcul toutes les 120 ms pendant le geste', () {
    expect(
        pawMapRecalcDuringMove616(
            zoom: 14.0,
            pinZoom: 12.0,
            lastAt: t0,
            now: t0.add(const Duration(milliseconds: 60))),
        isFalse);
    expect(
        pawMapRecalcDuringMove616(
            zoom: 14.0,
            pinZoom: 12.0,
            lastAt: t0,
            now: t0.add(const Duration(milliseconds: 120))),
        isTrue);
  });

  group('id stable des ronds de groupe (anti « dédoublement »)', () {
    test('le plus petit id du groupe, quel que soit l’ordre', () {
      expect(pawClusterKey616(['b2', 'a9', 'c1']), 'a9');
      expect(pawClusterKey616(['c1', 'a9', 'b2']), 'a9');
    });
    test('un membre de plus ou de moins ne change pas la clé si le plus petit reste', () {
      expect(pawClusterKey616(['a9', 'b2']), pawClusterKey616(['a9', 'b2', 'z5']));
    });
    test('ids vides ignorés, aucun id → chaîne vide', () {
      expect(pawClusterKey616(['', ' ', 'k']), 'k');
      expect(pawClusterKey616(const []), '');
    });
  });

  group('présence d’une personne (plusieurs ids de rôle)', () {
    final table = <String, bool>{'s1': true, 'o1': false, 'w2': false};
    bool? look(String id) => table[id];
    test('un profil en ligne → en ligne', () {
      expect(pawPersonPresence616(['o1', 's1'], look), isTrue);
    });
    test('tous connus hors ligne → hors ligne', () {
      expect(pawPersonPresence616(['o1', 'w2'], look), isFalse);
    });
    test('aucun id connu → null (on garde la valeur chargée)', () {
      expect(pawPersonPresence616(['x', 'y'], look), isNull);
    });
  });

  group('ids à sonder sur /friends/members/presence', () {
    test('position exacte seulement, tous les ids de la personne, dédoublonnés', () {
      final ids = pawPresenceIdsToPoll616([
        _m('a', ids: ['a', 'a_sitter']),
        _m('b', approx: true), // couche monde floutée : jamais de point
        _m('a_sitter'),
        _m('c'),
      ]);
      expect(ids, ['a', 'a_sitter', 'c']);
    });
    test('plafond respecté', () {
      final ids = pawPresenceIdsToPoll616(
          [for (var i = 0; i < 500; i++) _m('id$i')],
          max: 120);
      expect(ids.length, 120);
    });
  });

  group('application d’une réponse de présence', () {
    test('seules les entrées qui changent comptent', () {
      final table = <String, bool>{'a': true, 'b': false};
      expect(pawApplyPresence616(table, {'a': true, 'b': true, 'c': false}), 2);
      expect(table, {'a': true, 'b': true, 'c': false});
      expect(pawApplyPresence616(table, {'a': true}), 0);
    });
    test('valeurs non booléennes ignorées', () {
      final table = <String, bool>{};
      expect(pawApplyPresence616(table, {'a': 'oui', '': true}), 0);
      expect(table, isEmpty);
    });
  });

  group('personnes : la position ne bouge jamais entre deux images', () {
    test('rien n’a bougé → liste vide ; un rond de groupe peut bouger', () {
      final before = {
        'nearby_a': const LatLng(43.7, 7.26),
        'mcluster_x': const LatLng(45.0, 5.0),
      };
      final after = {
        'nearby_a': const LatLng(43.7, 7.26),
        'mcluster_x': const LatLng(46.0, 6.0),
      };
      expect(pawMovedPersonIds616(before, after), isEmpty);
    });
    test('une personne déplacée est signalée (Nice → Floride)', () {
      final before = {'nearby_nice': const LatLng(43.7, 7.26)};
      final after = {'nearby_nice': const LatLng(26.0, -80.0)};
      expect(pawMovedPersonIds616(before, after), ['nearby_nice']);
    });
  });
}

Map<String, dynamic> _m(String id, {bool approx = false, List<String>? ids}) =>
    {'id': id, 'approx': approx, if (ids != null) 'personIds': ids};
