// v601 (PAM, 29/09) — photo de la carte : règles d'affichage (7 jours,
// ~20 km, nuit / satellite / compte / proportions), cadence (10 s), fiche
// enregistrée lisible, et place de la photo SOUS la vue Google.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/pawmap_snapshot.dart';

void main() {
  final now = DateTime(2026, 9, 29, 16);
  const paris = LatLng(48.8566, 2.3522);
  PawMapSnapshotMeta meta({
    LatLng at = paris,
    Duration age = const Duration(hours: 2),
    bool night = false,
    bool satellite = false,
    String uid = 'u1',
    double aspect = 0.46,
  }) =>
      PawMapSnapshotMeta(
        path: '/x/pawmap_snapshot.png',
        lat: at.latitude,
        lng: at.longitude,
        zoom: 14.5,
        savedAt: now.subtract(age),
        night: night,
        satellite: satellite,
        uid: uid,
        aspect: aspect,
      );
  bool ok(PawMapSnapshotMeta? m,
          {LatLng target = paris,
          bool night = false,
          bool satellite = false,
          String uid = 'u1',
          double aspect = 0.46}) =>
      PawMapSnapshotRules.usable(m,
          now: now,
          target: target,
          night: night,
          satellite: satellite,
          uid: uid,
          aspect: aspect);

  test('photo récente au même endroit : affichée', () {
    expect(ok(meta()), isTrue);
  });
  test('pas de photo : fond « Carte en préparation… »', () {
    expect(ok(null), isFalse);
  });
  test('plus de 7 jours : ignorée ; 6 jours : affichée', () {
    expect(ok(meta(age: const Duration(days: 7, minutes: 1))), isFalse);
    expect(ok(meta(age: const Duration(days: 6))), isTrue);
  });
  test('date dans le futur (horloge changée) : ignorée', () {
    expect(ok(meta(age: const Duration(hours: -3))), isFalse);
  });
  test('plus de ~20 km : ignorée (Versailles 17 km oui, Meaux 41 km non)', () {
    const versailles = LatLng(48.8049, 2.1204);
    const meaux = LatLng(48.9601, 2.8788);
    expect(PawMapSnapshotRules.distanceKm(paris, versailles), inInclusiveRange(15, 19));
    expect(ok(meta(), target: versailles), isTrue);
    expect(ok(meta(), target: meaux), isFalse);
  });
  test('mode nuit, satellite, autre compte, autres proportions : ignorée', () {
    expect(ok(meta(), night: true), isFalse);
    expect(ok(meta(), satellite: true), isFalse);
    expect(ok(meta(), uid: 'u2'), isFalse);
    expect(ok(meta(), aspect: 0.75), isFalse); // tablette / rotation
  });
  test('au plus une photo toutes les 10 s', () {
    expect(PawMapSnapshotRules.due(null, now), isTrue);
    expect(PawMapSnapshotRules.due(now.subtract(const Duration(seconds: 9)), now), isFalse);
    expect(PawMapSnapshotRules.due(now.subtract(const Duration(seconds: 10)), now), isTrue);
  });
  test('fiche : aller-retour JSON, fiche abîmée refusée', () {
    final m = meta();
    final back = PawMapSnapshotMeta.fromJson(m.toJson())!;
    expect(back.lat, m.lat);
    expect(back.zoom, 14.5);
    expect(back.savedAt, m.savedAt);
    expect(back.uid, 'u1');
    expect(PawMapSnapshotMeta.fromJson({'lat': 1}), isNull);
    expect(PawMapSnapshotMeta.fromJson('pas du json'), isNull);
    expect(PawMapSnapshotMeta.fromJson({...m.toJson(), 'zoom': 40}), isNull);
  });
  test('la photo est posée SOUS la vue Google, au-dessus du fond de repli', () {
    final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
    final ph = src.indexOf("ValueKey<String>('pawmap_placeholder')");
    final snap = src.indexOf("ValueKey<String>('pawmap_snapshot')");
    final map = src.indexOf("ValueKey<String>('pawmap_google_map')");
    expect(ph, greaterThan(0));
    expect(snap, greaterThan(ph));
    expect(map, greaterThan(snap));
    // Retirée au premier arrêt de caméra et au premier geste.
    expect(RegExp(r'void _scheduleReload\(\) \{[^}]*_snapshotShown\.value = false')
        .hasMatch(src), isTrue);
    expect(RegExp(r'void _onMapPointerDown\(PointerDownEvent e\) \{[^}]*_snapshotShown\.value = false')
        .hasMatch(src), isTrue);
  });
}
