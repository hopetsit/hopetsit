// 610 (PAM, 04/10/2026) — Daniel : « vérifier les PawSpots : l'ajout et
// l'affichage marchent ». Le spot créé entre tout de suite dans la couche.
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' show Offset;

import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart'
    show pawPlushOffsetFromMe, pawSpotShiftedAnchor610, pawSpotShiftFromPeople610;

Map<String, dynamic> _resp(String id, {double lat = -35, double lng = -30}) => {
      'spot': {
        'id': id,
        'type': 'path_walk',
        'name': 'Bois test',
        'photoUrl': 'https://cdn/p.jpg',
        'lat': lat,
        'lng': lng,
        'isMine': true,
      },
      'pointsEarned': 30,
    };

void main() {
  group('spot créé visible tout de suite sur ma carte', () {
    test('la réponse du serveur ajoute le spot en tête (nom, photo, position)', () {
      final c = PawSpotController();
      c.addCreatedSpot610(_resp('a1'));
      expect(c.spots, hasLength(1));
      final s = c.spots.first;
      expect(s.id, 'a1');
      expect(s.name, 'Bois test');
      expect(s.photoUrl, 'https://cdn/p.jpg');
      expect(s.lat, -35);
      expect(s.lng, -30);
      expect(s.isMine, isTrue);
    });
    test('jamais en double (rechargement déjà passé)', () {
      final c = PawSpotController();
      c.addCreatedSpot610(_resp('a1'));
      c.addCreatedSpot610(_resp('a1'));
      expect(c.spots, hasLength(1));
    });
    test('réponse vide ou sans position : rien n\'est ajouté', () {
      final c = PawSpotController();
      c.addCreatedSpot610(const {});
      c.addCreatedSpot610(_resp('a2', lat: 0, lng: 0));
      c.addCreatedSpot610({'spot': {'id': ''}});
      expect(c.spots, isEmpty);
    });
  });

  group('spot jamais caché sous « Moi » (mesuré au simulateur, zoom ville)', () {
    test('spot à 2 px de Moi : dessiné sur le côté, à 54 px', () {
      final off = pawPlushOffsetFromMe(const Offset(2, 1));
      expect((const Offset(2, 1) + off).dx.abs(), 54);
      final a = pawSpotShiftedAnchor610(const Offset(0.5, 0.8), off, width: 64, height: 80);
      expect(a.dx, isNot(0.5));
      expect(a.dy, closeTo(0.8, 0.02));
    });
    test('spot loin de Moi : ancre inchangée', () {
      final off = pawPlushOffsetFromMe(const Offset(120, 0));
      expect(off, Offset.zero);
      expect(pawSpotShiftedAnchor610(const Offset(0.5, 0.8), off, width: 64, height: 80),
          const Offset(0.5, 0.8));
    });
  });

  test('spot sous un ami (rond + étiquette) : posé à 88 px du plus proche', () {
    const at = Offset(100, 100);
    final off = pawSpotShiftFromPeople610(at, const [Offset(300, 300), Offset(98, 101)]);
    expect((at + off - const Offset(98, 101)).dx.abs(), 88);
    expect(pawSpotShiftFromPeople610(at, const [Offset(300, 300)]), Offset.zero);
  });
}
