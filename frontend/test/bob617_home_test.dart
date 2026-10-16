// Lot D (25/09/2026) — CURSEUR DE DISTANCE (demande de Daniel : « mini-lags »
// sur les 3 profils).
//
// Ce que l'on prouve ici, avec le faux serveur du harnais (aucun réseau) :
//   1. FLUIDITÉ — pendant le glissement, seule la barre se redessine (la
//      valeur est locale au widget) ; le flux / la liste ne se recalcule
//      qu'au RELÂCHEMENT. Mesure : 40 pas de glissement sur un accueil
//      gardien de 40 annonces, chronométrés (Stopwatch) et nombre de
//      reconstructions du corps de l'écran.
//   2. AFFICHÉ = ENVOYÉ — la valeur écrite dans la barre (« 30 km ») est
//      exactement celle envoyée au serveur (`radiusInMeters=30000`) et celle
//      appliquée au filtre local.
//   3. COHÉRENCE — un prestataire à 40 km apparaît à 50 km et disparaît à
//      30 km (propriétaire, via /sitters/nearby) ; une annonce à 40 km
//      apparaît à 50 km et disparaît à 30 km (gardien, filtre local). Les
//      bornes fines (4 km visible à 5 km, absent à 3 km) sont prouvées sur la
//      règle pure `search_radius.dart`, identique à celle du serveur
//      (backend/tests/radius585.test.js).
//   4. RETENU — le rayon choisi est mémorisé par rôle (appareil) et poussé
//      au compte (`PATCH /users/me/map-prefs`, clé `homeRadiusKm`) ; un
//      nouvel accueil repart avec cette valeur.
//
// Distances : les annonces / prestataires sont placés à l'EST d'un centre
// fictif (-35.2, -30.4 : pleine mer, aucune vraie ville), 1° de longitude ≈
// 111,32·cos(lat) km.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/shared/widgets/around_me_search_bar.dart';
import 'package:hopetsit/views/shared/widgets/home_empty_kit.dart';

import 'package:hopetsit/utils/apply_distance617.dart';

import 'lotd_harness.dart';

const double kLat = -35.2;
const double kLng = -30.4;

({double lat, double lng}) eastKm(double km) =>
    (lat: kLat, lng: kLng + km / (111.32 * math.cos(kLat * math.pi / 180)));

Map<String, dynamic> _post(String id, double km, {String service = 'pet_sitting'}) {
  final p = eastKm(km);
  return <String, dynamic>{
    'id': id,
    'postType': 'text',
    'body': 'Annonce $id',
    'startDate': '2026-10-10T09:00:00.000Z',
    'endDate': '2026-10-12T18:00:00.000Z',
    'serviceTypes': <String>[service],
    'location': <String, dynamic>{'city': 'Zone test', 'lat': p.lat, 'lng': p.lng},
    'createdAt': '2026-09-25T08:00:00.000Z',
    'owner': <String, dynamic>{'id': 'o-$id', 'name': 'Proprio $id', 'email': '', 'avatar': ''},
  };
}

Future<void> _profileAtCenter(String role) async {
  final storage = GetStorage();
  await storage.write(StorageKeys.userProfile, <String, dynamic>{
    'id': 'u-test',
    '_id': 'u-test',
    'name': 'Camille Durand',
    'email': 'camille@example.test',
    'role': role,
    'city': 'Zone test',
    'location': <String, dynamic>{'city': 'Zone test', 'country': 'Test', 'lat': kLat, 'lng': kLng},
  });
}

/// Le curseur de la barre « Autour de moi ».
Slider _slider(WidgetTester tester) =>
    tester.widget<Slider>(find.descendant(of: find.byType(AroundMeSearchBar), matching: find.byType(Slider)));

void main() {
  group('accueil gardien — plafond de candidature 200 km', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
      await _profileAtCenter('sitter');
    });

    testWidgets('150 km proposée dans « les plus proches », 11 254 km jamais', (tester) async {
      lotdResponder = (req) {
        if (req.url.path.endsWith('/posts/requests')) {
          return <String, dynamic>{
            'posts': <Map<String, dynamic>>[_post('p150', 150), _post('busan', 11254)],
          };
        }
        return <String, dynamic>{};
      };
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const SitterHomescreen()));
      await lotdSettle(tester, frames: 8);
      expect(tester.takeException(), isNull);
      // Rien dans les 50 km → carte « Élargir » + la seule annonce honorable.
      expect(find.byType(HomeRadiusHintCard), findsOneWidget);
      expect(find.byType(HomeDistancePill), findsOneWidget); // 150 km seulement
      expect(find.textContaining('Annonce p150'), findsWidgets);
      expect(find.textContaining('Annonce busan'), findsNothing);
      expect(find.byKey(const ValueKey<String>('home617_too_far')), findsNothing);
      // Le curseur ne dépasse plus 200 km (même valeur que le serveur).
      expect(_slider(tester).max, kApplyMaxKm617);
    });

    testWidgets('toutes les demandes à plus de 200 km → carte « aucune demande à moins de 200 km »',
        (tester) async {
      lotdResponder = (req) {
        if (req.url.path.endsWith('/posts/requests')) {
          return <String, dynamic>{
            'posts': <Map<String, dynamic>>[_post('busan', 11254), _post('loin', 450)],
          };
        }
        return <String, dynamic>{};
      };
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const SitterHomescreen()));
      await lotdSettle(tester, frames: 8);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('home617_too_far')), findsOneWidget);
      expect(find.text('bob617_nothing_within_max'.tr.replaceAll('{max}', '200')), findsOneWidget);
      expect(find.byType(HomeRadiusHintCard), findsNothing);
      expect(find.byType(HomeDistancePill), findsNothing);
      expect(find.textContaining('Annonce busan'), findsNothing);
      expect(find.textContaining('Annonce loin'), findsNothing);
    });
  });
}
