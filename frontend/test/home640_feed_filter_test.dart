// 640 — Lot 3 : annonces SANS coordonnées dans le fil « Autour de moi »
// (Daniel, en Espagne avec un rayon de 90 km, voyait une demande du Brésil).
// Le correctif est au SERVEUR (backend/tests/feedNoCoords640.test.js). Côté
// app le filtre local est éteint par défaut : dans le doute on garde.
//
//   1. règle PURE `keepPostForAnchor640` + `normalizeCity640` (filtre local
//      allumé à la main : n'écarte que deux villes connues et différentes) ;
//   2. le VRAI écran d'accueil gardien, avec le faux serveur du harnais lot D
//      (aucun réseau, données fictives) : une annonce sans coordonnées que le
//      serveur a laissée passer reste affichée ; le rayon continue de trier
//      celles qui ont des coordonnées.
//
// Centre fictif (-35.2, -30.4 : pleine mer, aucune vraie ville).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/shared/widgets/home640_kit.dart';
import 'package:hopetsit/views/shared/widgets/home_empty_kit.dart';

import 'lotd_harness.dart';

const double kLat = -35.2;
const double kLng = -30.4;

({double lat, double lng}) eastKm(double km) =>
    (lat: kLat, lng: kLng + km / (111.32 * math.cos(kLat * math.pi / 180)));

Map<String, dynamic> _post(String id, {double? km, required String city}) {
  final Map<String, dynamic> loc = <String, dynamic>{'city': city};
  if (km != null) {
    final p = eastKm(km);
    loc['lat'] = p.lat;
    loc['lng'] = p.lng;
  }
  return <String, dynamic>{
    'id': id,
    'postType': 'text',
    'body': 'Annonce $id',
    'startDate': '2026-12-10T09:00:00.000Z',
    'endDate': '2026-12-12T18:00:00.000Z',
    'serviceTypes': <String>['pet_sitting'],
    'location': loc,
    'createdAt': '2026-11-09T08:00:00.000Z',
    'owner': <String, dynamic>{'id': 'o-$id', 'name': 'Proprio $id', 'email': '', 'avatar': ''},
  };
}

Future<void> _profile({String city = 'Zone test'}) async {
  await GetStorage().write(StorageKeys.userProfile, <String, dynamic>{
    'id': 'u-test',
    '_id': 'u-test',
    'name': 'Camille Durand',
    'email': 'camille@example.test',
    'role': 'sitter',
    'city': city,
    'location': <String, dynamic>{'city': city, 'country': city.isEmpty ? '' : 'Test', 'lat': kLat, 'lng': kLng},
  });
}

void _serve(List<Map<String, dynamic>> posts) {
  lotdResponder = (req) {
    if (req.url.path.endsWith('/posts/requests')) {
      return <String, dynamic>{'posts': posts};
    }
    return <String, dynamic>{};
  };
}

Finder _results(int n) => find.text(n == 1
    ? 'home635_results_found_one'.tr
    : 'home_results_found'.trParams({'count': '$n'}));

void main() {
  group('règle pure keepPostForAnchor640', () {
    bool keep({
      double? aLat = kLat,
      double? aLng = kLng,
      double? pLat,
      double? pLng,
      String? postCity,
      String? providerCity,
      double radius = 90,
      bool strict = true,
    }) =>
        keepPostForAnchor640(
          anchorLat: aLat,
          anchorLng: aLng,
          postLat: pLat,
          postLng: pLng,
          postCity: postCity,
          providerCity: providerCity,
          radiusKm: radius,
          strict: strict,
        );

    test('le filtre local est ÉTEINT par défaut (le serveur décide)', () {
      expect(kFeedNoCoordsStrict640, isFalse);
    });

    test('sans coordonnées + autre ville → écartée', () {
      expect(keep(postCity: 'São Paulo', providerCity: 'Alhama de Murcia'), isFalse);
      expect(keep(postCity: 'Brasília, Brasil', providerCity: 'Alhama de Murcia, Espagne'), isFalse);
    });

    test('sans coordonnées + ville de l\'annonce inconnue → gardée (doute)', () {
      expect(keep(postCity: '', providerCity: 'Alhama de Murcia'), isTrue);
      expect(keep(postCity: null, providerCity: 'Alhama de Murcia'), isTrue);
    });

    test('sans coordonnées + même ville (casse, accents, espaces) → gardée', () {
      expect(keep(postCity: 'São Paulo', providerCity: 'sao paulo'), isTrue);
      expect(keep(postCity: '  SAO   PAULO ', providerCity: 'São Paulo, Brasil'), isTrue);
      expect(keep(postCity: 'Saint-Étienne', providerCity: 'saint etienne'), isTrue);
      expect(keep(postCity: 'Alhama de Murcia, Murcia', providerCity: 'Alhama de Murcia, Espagne'), isTrue);
    });

    test('sans coordonnées + ville du prestataire inconnue → gardée (doute)', () {
      // Recherche « autour de ma position » : l'écran ne connaît pas de ville.
      expect(keep(postCity: 'Paris', providerCity: ''), isTrue);
      expect(keep(postCity: 'Paris', providerCity: null), isTrue);
      expect(keep(postCity: 'Paris', providerCity: '   '), isTrue);
      expect(keep(postCity: '', providerCity: ''), isTrue);
    });

    test('avec coordonnées : dans le rayon gardée, hors rayon écartée (inchangé)', () {
      final near = eastKm(40);
      final far = eastKm(120);
      // La ville ne joue AUCUN rôle quand les coordonnées existent.
      expect(keep(pLat: near.lat, pLng: near.lng, postCity: 'Ailleurs', providerCity: 'Ici'), isTrue);
      expect(keep(pLat: far.lat, pLng: far.lng, postCity: 'Ici', providerCity: 'Ici'), isFalse);
      // Borne inclusive (même règle que le serveur).
      final edge = eastKm(90);
      expect(keep(pLat: edge.lat, pLng: edge.lng), isTrue);
      // Une seule coordonnée = pas de coordonnées.
      expect(keep(pLat: near.lat, postCity: 'Ailleurs', providerCity: 'Ici'), isFalse);
    });

    test('pas d\'ancre → tout est gardé', () {
      expect(keep(aLat: null, aLng: null, postCity: 'São Paulo', providerCity: 'Madrid'), isTrue);
      expect(keep(aLat: null, aLng: null), isTrue);
      expect(keep(aLat: kLat, aLng: null, postCity: 'x', providerCity: 'y'), isTrue);
      final far = eastKm(5000);
      expect(keep(aLat: null, aLng: null, pLat: far.lat, pLng: far.lng), isTrue);
    });

    test('strict: false → tolérance d\'avant (coupe-circuit)', () {
      expect(keep(postCity: 'São Paulo', providerCity: 'Madrid', strict: false), isTrue);
      expect(keep(postCity: '', providerCity: '', strict: false), isTrue);
      final far = eastKm(120);
      expect(keep(pLat: far.lat, pLng: far.lng, strict: false), isFalse);
    });

    test('normalizeCity640', () {
      expect(normalizeCity640('São Paulo'), 'saopaulo');
      expect(normalizeCity640('sao  paulo'), 'saopaulo');
      // Forme décomposée (a + tilde combinant).
      expect(normalizeCity640('São Paulo'), 'saopaulo');
      expect(normalizeCity640('Madrid, Espagne'), 'madrid');
      expect(normalizeCity640("L'Haÿ-les-Roses"), 'lhaylesroses');
      expect(normalizeCity640('Düsseldorf'), 'dusseldorf');
      expect(normalizeCity640('Łódź'), 'lodz');
      expect(normalizeCity640('서울'), '서울');
      expect(normalizeCity640(null), '');
      expect(normalizeCity640('  ,France'), '');
    });
  });

  group('vrai accueil gardien — annonces sans coordonnées', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
    });

    testWidgets('le serveur décide : sans coordonnées gardées, avec coordonnées triées par le rayon',
        (tester) async {
      await _profile();
      _serve(<Map<String, dynamic>>[
        _post('p40', km: 40, city: 'Zone test'),
        _post('p60', km: 60, city: 'Zone test'),
        _post('voisine', city: 'Commune voisine'),
        _post('sansville', city: ''),
        _post('ici', city: 'ZONE  Tést'),
      ]);
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const SitterHomescreen()));
      await lotdSettle(tester, frames: 8);
      expect(tester.takeException(), isNull);
      // Rayon 50 km : p40 + les 3 annonces sans coordonnées = 4 ; p60 hors rayon.
      expect(_results(4), findsOneWidget);
      expect(find.textContaining('Annonce p60', skipOffstage: false), findsNothing);
    });

    testWidgets('recherche sans ville connue : une annonce sans coordonnées reste affichée',
        (tester) async {
      await _profile(city: '');
      _serve(<Map<String, dynamic>>[
        _post('p40', km: 40, city: 'Zone test'),
        _post('floue', city: 'Zone test'),
      ]);
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const SitterHomescreen()));
      await lotdSettle(tester, frames: 8);
      expect(tester.takeException(), isNull);
      expect(_results(2), findsOneWidget);
    });
  });
}
