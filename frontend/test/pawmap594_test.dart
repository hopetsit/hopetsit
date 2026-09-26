// v594 — retours de Daniel et de son frère sur le 593 (26/09).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_jewel.dart';

String fmt(String cur, double p) => '${p.toStringAsFixed(0)} €';

void main() {
  group('bulle de prix d\'une personne', () {
    final saray = <Map<String, dynamic>>[
      {'id': 's1', '_role': 'sitter', 'priceFrom': 20},
      {'id': 'w1', '_role': 'walker', 'priceFrom': 12},
    ];

    test('propriétaire qui regarde : bulle DUO gardien|promeneur', () {
      final b = pawMapPersonPriceBubble(saray,
          shows: (r) => pawMapShowsPriceBubble('owner', r),
          shownRoles: const {'owner', 'sitter', 'walker'},
          format: fmt);
      expect(b, isNotNull);
      expect(b!.role, 'duo');
      expect(b.text, '20 €|12 €');
    });

    test('filtre promeneurs seulement : le prix promeneur, en vert', () {
      final b = pawMapPersonPriceBubble(saray,
          shows: (r) => pawMapShowsPriceBubble('owner', r),
          shownRoles: const {'walker'},
          format: fmt);
      expect(b!.role, 'walker');
      expect(b.text, '12 €');
    });

    test('un gardien qui regarde : aucun prix (concurrents)', () {
      final b = pawMapPersonPriceBubble(saray,
          shows: (r) => pawMapShowsPriceBubble('sitter', r),
          shownRoles: const {},
          format: fmt);
      expect(b, isNull);
    });

    test('3 rôles : le rôle propriétaire n\'a jamais de prix', () {
      final b = pawMapPersonPriceBubble([
        {'id': 'o', '_role': 'owner', 'priceFrom': 0},
        ...saray,
      ],
          shows: (r) => pawMapShowsPriceBubble('owner', r),
          shownRoles: const {},
          format: fmt);
      expect(b!.text, '20 €|12 €');
    });

    test('sans prix renseigné : pas de bulle', () {
      final b = pawMapPersonPriceBubble([
        {'id': 's', '_role': 'sitter', 'priceFrom': 0},
      ],
          shows: (_) => true, shownRoles: const {}, format: fmt);
      expect(b, isNull);
    });
  });

  test('rôles dans l\'ordre FIXE orange → bleu → vert', () {
    expect(pawMapOrderedRoles(['walker', 'owner', 'sitter', 'walker']),
        ['owner', 'sitter', 'walker']);
    expect(
        pawMapPersonRoles({
          'roles': [
            {'id': 'a', 'role': 'walker'},
            {'id': 'b', 'role': 'sitter'},
          ]
        }),
        ['sitter', 'walker']);
    expect(pawMapPersonRoles({'_role': 'owner'}), ['owner']);
  });

  test('bouton Profil : 1 rôle = son dégradé, 2 = bleu puis vert', () {
    final one = pawRolesGradient(['walker']);
    expect(one.colors, kJewelWalker.gradient.colors);
    final two = pawRolesGradient(['walker', 'sitter']);
    expect(two.colors, [kJewelSitter.mid, kJewelWalker.mid]);
    final three = pawRolesGradient(['walker', 'sitter', 'owner']);
    expect(three.colors, [kJewelOwner.mid, kJewelSitter.mid, kJewelWalker.mid]);
    expect(three.begin, Alignment.centerLeft);
  });

  test('distance à vol d\'oiseau', () {
    final d = pawMapDistanceKm(const LatLng(37.85, -1.42), const LatLng(37.85, -1.42));
    expect(d, 0);
    final paris = pawMapDistanceKm(
        const LatLng(48.8566, 2.3522), const LatLng(48.8606, 2.3376));
    expect(paris, closeTo(1.15, 0.1));
  });
}
