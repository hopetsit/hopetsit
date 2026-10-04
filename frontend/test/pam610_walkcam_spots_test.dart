// 610 (PAM, 04/10/2026) — retours de Daniel en Balade à Alhama de Murcia.
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/widgets/pawmap_spots610.dart';
import 'package:hopetsit/views/map/widgets/pawmap_walkcam610.dart';

void main() {
  group('couche PawSpot allumée par défaut (Cam ne voyait aucun spot)', () {
    test('compte neuf (rien en mémoire) : allumée', () {
      expect(pawSpotLayerDefault610(null), isTrue);
    });
    test('allumée à la main : allumée', () {
      expect(pawSpotLayerDefault610(true), isTrue);
    });
    test('éteinte à la main : reste éteinte', () {
      expect(pawSpotLayerDefault610(false), isFalse);
    });
    test('sans GetStorage (test) : allumée, jamais d\'erreur', () {
      expect(pawSpotLayerInitial610(), isTrue);
    });
  });

  group('caméra de Balade « vue rue »', () {
    const laIsla = LatLng(37.7322, -1.3471);
    test('départ dézoomé (Daniel à 13) : zoom de rue 17,5', () {
      expect(pawWalkZoomFor(13), kPawWalkZoom);
      expect(pawWalkZoomFor(null), kPawWalkZoom);
    });
    test('déjà zoomé (18) : on garde son zoom', () {
      expect(pawWalkZoomFor(18), 18);
      expect(pawWalkZoomFor(21), 19.5);
    });
    test('caméra penchée et centrée sur moi', () {
      final c = pawWalkCamera(me: laIsla, currentZoom: 12);
      expect(c.target, laIsla);
      expect(c.zoom, kPawWalkZoom);
      expect(c.tilt, kPawWalkTilt);
      expect(c.bearing, 0);
    });
    test('cap : vers l\'est = 90°, vers le nord = 0°', () {
      final est = pawWalkBearing(laIsla, const LatLng(37.7322, -1.3461))!;
      final nord = pawWalkBearing(laIsla, const LatLng(37.7332, -1.3471))!;
      expect(est, closeTo(90, 1));
      expect(nord, closeTo(0, 1));
    });
    test('bruit GPS (< 8 m) : pas de cap, on garde le dernier', () {
      const pas = LatLng(37.73223, -1.3471); // ~3 m
      expect(pawWalkBearing(laIsla, pas), isNull);
      final c = pawWalkCamera(me: pas, currentZoom: 18, bearing: null, lastBearing: 120);
      expect(c.bearing, 120);
    });
    test('fin de Balade : carte remise à plat', () {
      final c = pawWalkFlatCamera(laIsla, 17.5);
      expect(c.tilt, 0);
      expect(c.bearing, 0);
      expect(c.zoom, 17.5);
    });
  });
}
