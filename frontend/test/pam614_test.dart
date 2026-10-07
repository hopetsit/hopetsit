// 614 (PAM, 07/10/2026) — PawSpot « Los Guardianes » et position des amis.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';

void main() {
  group('PawSpot écarté par sa POSITION (dessin = zone d’appui)', () {
    // Valeurs MESURÉES au simulateur (scène de la capture de Daniel, zoom 11,6) :
    // spot « perros » 37.72384,-1.36058 à 30 px de Cam → écarté de 88 px à gauche.
    const spot = LatLng(37.72384080318378, -1.3605810329318047);
    for (final z in [9.0, 11.6, 14.0, 17.5]) {
      for (final off in const [Offset(-88, -18), Offset(88, 12), Offset(-61, 0)]) {
        test('zoom $z, décalage $off : le point dessiné est à $off px du vrai', () {
          final drawn = pawSpotDisplayLatLng614(spot, off, z);
          final a = pawMercatorPx(spot.latitude, spot.longitude, z);
          final b = pawMercatorPx(drawn.latitude, drawn.longitude, z);
          expect((b - a - off).distance, lessThan(0.01));
        });
      }
    }
    test('sans décalage : la vraie position, inchangée', () {
      expect(pawSpotDisplayLatLng614(spot, Offset.zero, 12), spot);
    });
    test('écart de la scène réelle : 88 px à gauche de la personne la plus proche', () {
      final at = pawMercatorPx(spot.latitude, spot.longitude, 11.6);
      final cam = pawMercatorPx(37.73215424383419, -1.3471085487286405, 11.6);
      final off = pawSpotShiftFromPeople610(at, [cam]);
      expect(off, isNot(Offset.zero));
      expect(((at + off) - cam).dx, closeTo(-88, 0.5));
    });
  });

  group('position renvoyée au retour de l’app (batterie)', () {
    final t0 = DateTime(2026, 10, 7, 4, 0);
    test('jamais envoyée → envoi', () => expect(pawPresenceDue614(null, t0), isTrue));
    test('il y a 3 min → rien', () =>
        expect(pawPresenceDue614(t0, t0.add(const Duration(minutes: 3))), isFalse));
    test('il y a 10 min → envoi', () =>
        expect(pawPresenceDue614(t0, t0.add(const Duration(minutes: 10))), isTrue));
  });
}
