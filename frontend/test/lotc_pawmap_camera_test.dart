// v584 — lot C du chantier du 24/09 : mémoire de la caméra de la PawMap
// (LEGENDE_PAWMAP.md, « Ouverture de la carte », validé par Daniel le 23/09).
//   · centre : dernier endroit regardé → sinon la ville du profil → sinon le
//     repli (jamais « Paris » pour un compte de Dallas) ;
//   · le zoom est retenu et borné ; le zoom d'atterrissage reste entre la
//     ville et la rue ;
//   · l'encodage écrit bien lat / lng / zoom.
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/pawmap_camera_memory.dart';

void main() {
  group('PawMapCameraMemory.centerFrom', () {
    test('mémoire présente → dernier endroit regardé', () {
      final c = PawMapCameraMemory.centerFrom(
        {'lat': 45.76, 'lng': 4.84, 'zoom': 15},
        {'location': {'coordinates': [-96.797, 32.7767]}},
      );
      expect(c, const LatLng(45.76, 4.84));
    });

    test('sans mémoire → ville du profil (GeoJSON [lng, lat])', () {
      final c = PawMapCameraMemory.centerFrom(
        null,
        {'location': {'coordinates': [-96.797, 32.7767]}},
      );
      expect(c.latitude, closeTo(32.7767, 1e-9));
      expect(c.longitude, closeTo(-96.797, 1e-9));
    });

    test('profil avec lat / lng à plat', () {
      final c = PawMapCameraMemory.centerFrom(
        null,
        {'location': {'lat': 48.87, 'lng': 2.3}},
      );
      expect(c, const LatLng(48.87, 2.3));
    });

    test('rien de connu → repli, jamais (0, 0)', () {
      expect(PawMapCameraMemory.centerFrom(null, null),
          PawMapCameraMemory.fallbackCenter);
      expect(
        PawMapCameraMemory.centerFrom(
            {'lat': 0, 'lng': 0}, {'location': {'coordinates': [0, 0]}}),
        PawMapCameraMemory.fallbackCenter,
      );
    });

    test('valeurs hors bornes ignorées', () {
      expect(
        PawMapCameraMemory.centerFrom({'lat': 120, 'lng': 4}, null),
        PawMapCameraMemory.fallbackCenter,
      );
    });
  });

  group('PawMapCameraMemory.zoomFrom / launchZoom / encode', () {
    test('zoom retenu, sinon défaut quartier', () {
      expect(PawMapCameraMemory.zoomFrom({'zoom': 16.5}), 16.5);
      expect(PawMapCameraMemory.zoomFrom({'lat': 1, 'lng': 1}),
          PawMapCameraMemory.defaultZoom);
      expect(PawMapCameraMemory.zoomFrom(null), PawMapCameraMemory.defaultZoom);
      expect(PawMapCameraMemory.zoomFrom({'zoom': 40}),
          PawMapCameraMemory.defaultZoom);
    });

    test("zoom d'atterrissage borné entre la ville et la rue", () {
      expect(PawMapCameraMemory.launchZoom(3), 11);
      expect(PawMapCameraMemory.launchZoom(15), 15);
      expect(PawMapCameraMemory.launchZoom(20), 18);
    });

    test('encode écrit lat / lng / zoom borné', () {
      final m = PawMapCameraMemory.encode(const LatLng(48.8566, 2.3522), 25);
      expect(m['lat'], 48.8566);
      expect(m['lng'], 2.3522);
      expect(m['zoom'], PawMapCameraMemory.maxZoom);
      // Ce que l'on écrit se relit tel quel.
      expect(PawMapCameraMemory.centerFrom(m, null),
          const LatLng(48.8566, 2.3522));
    });
  });
}
