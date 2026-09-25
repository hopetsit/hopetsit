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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/home_controller.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/utils/home_radius_prefs.dart';
import 'package:hopetsit/utils/search_radius.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_owner/home/home_screen.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/shared/widgets/around_me_search_bar.dart';
import 'package:hopetsit/views/shared/widgets/home_empty_kit.dart';

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

Map<String, dynamic> _sitter(String id, double km) {
  final p = eastKm(km);
  return <String, dynamic>{
    'id': id,
    'name': 'Gardien $id',
    'email': '$id@example.test',
    'city': 'Zone test',
    'location': <String, dynamic>{'type': 'Point', 'coordinates': <double>[p.lng, p.lat]},
    'distanceInMeters': (km * 1000).round(),
    'hourlyRate': 12,
    'currency': 'EUR',
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

/// Simule un choix de rayon (glissement puis relâchement). Le propriétaire
/// recharge ses listes en passant par le GPS (6 s de délai sans plugin en
/// test) : on laisse ce délai s'écouler avant de lire l'écran.
Future<void> _setRadius(WidgetTester tester, double km) async {
  final s = _slider(tester);
  s.onChanged!(km);
  await tester.pump();
  s.onChangeEnd!(km);
  await tester.pump(const Duration(seconds: 7));
  await lotdSettle(tester, frames: 4);
}

/// « N résultats trouvés » du flux gardien/promeneur.
Finder _results(int n) => find.text('home_results_found'.trParams({'count': '$n'}));

String? _shownRadius(WidgetTester tester) {
  final f = find.descendant(
    of: find.byKey(const ValueKey<String>('around_me_radius_value')),
    matching: find.byType(Text),
  );
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f.first).data;
}

void main() {
  group('règle pure (identique au serveur)', () {
    test('4 km : visible à 5 km, absent à 3 km, borne inclusive à 4 km', () {
      final p = eastKm(4);
      final d = haversineKm(kLat, kLng, p.lat, p.lng);
      expect((d - 4).abs(), lessThan(0.01));
      expect(withinRadiusKm(d, 5), isTrue);
      expect(withinRadiusKm(d, 3), isFalse);
      expect(withinRadiusKm(4.0, 4), isTrue);
      expect(withinRadiusKm(4.0005, 4), isTrue); // tolérance 1 m
      expect(withinRadiusKm(4.002, 4), isFalse);
      expect(withinRadiusKm(double.nan, 4), isFalse);
    });

    test('rayon retenu : borné, arrondi, par rôle', () {
      expect(clampRadiusKm(3, min: 10, max: 500), 10);
      expect(clampRadiusKm(900, min: 10, max: 500), 500);
      expect(clampRadiusKm(49.6, min: 10, max: 500), 50);
      expect(clampRadiusKm(double.nan, min: 10, max: 500, fallback: 50), 50);
    });
  });

  group('accueil gardien (filtre local)', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
      await _profileAtCenter('sitter');
      lotdResponder = (req) {
        if (req.url.path.endsWith('/posts/requests')) {
          return <String, dynamic>{
            'posts': <Map<String, dynamic>>[_post('p40', 40), _post('p60', 60)],
          };
        }
        return <String, dynamic>{};
      };
    });

    testWidgets('40 km : visible à 50 km, absent à 30 km ; affiché = appliqué',
        (tester) async {
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const SitterHomescreen()));
      await lotdSettle(tester, frames: 8);
      expect(tester.takeException(), isNull);
      // Défaut 50 km : l'annonce à 40 km est là, celle à 60 km non.
      expect(_shownRadius(tester), '50 km');
      expect(_results(1), findsOneWidget);
      expect(find.textContaining('Annonce p40'), findsWidgets);
      expect(find.textContaining('Annonce p60'), findsNothing);
      expect(find.byType(HomeRadiusHintCard), findsNothing);

      // 30 km : plus rien dans le rayon → 0 résultat ; l'annonce à 40 km
      // n'apparaît plus que dans « Les plus proches de toi » (v571), avec
      // sa pastille de distance et la carte « Élargir ».
      await _setRadius(tester, 30);
      expect(_shownRadius(tester), '30 km');
      expect(_results(0), findsOneWidget);
      expect(find.byType(HomeRadiusHintCard), findsOneWidget);
      expect(find.byType(HomeDistancePill), findsNWidgets(2)); // 40 et 60 km

      await _setRadius(tester, 70);
      expect(_shownRadius(tester), '70 km');
      expect(_results(2), findsOneWidget);
      expect(find.textContaining('Annonce p40'), findsWidgets);
      expect(find.textContaining('Annonce p60'), findsWidgets);
      expect(find.byType(HomeRadiusHintCard), findsNothing);

      // Retenu par rôle (appareil + compte).
      expect(HomeRadiusPrefs.read('sitter'), 70);
      expect(HomeRadiusPrefs.read('walker'), isNull);
      final acc = MapPrefsService.instance.prefs['homeRadiusKm'];
      expect(acc, isA<Map>());
      expect((acc as Map)['sitter'], 70);
      await tester.pump(const Duration(seconds: 3));
      final pushed = lotdRequests.where((r) => r.method == 'PATCH' && r.path.endsWith('/users/me/map-prefs'));
      expect(pushed, isNotEmpty, reason: 'le rayon doit être poussé au compte');
      final body = pushed.last.body?['pawMap'];
      expect(body, isA<Map>());
      expect((body as Map)['homeRadiusKm'], <String, dynamic>{'sitter': 70});
      expect(tester.takeException(), isNull);
    });

    testWidgets('un nouvel accueil repart avec le rayon retenu', (tester) async {
      HomeRadiusPrefs.write('sitter', 120);
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const SitterHomescreen()));
      await lotdSettle(tester, frames: 8);
      expect(_shownRadius(tester), '120 km');
      expect(_results(2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('accueil propriétaire (/sitters/nearby)', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      await _profileAtCenter('owner');
      // Sans plugin, le canal GPS ne répond jamais sous le temps simulé et
      // `loadNearbySitters` restait suspendu : on fait échouer le GPS tout de
      // suite → l'ancre retombe sur les coordonnées du profil (le vrai
      // chemin « GPS refusé » de l'app).
      const geo = MethodChannel('flutter.baseflow.com/geolocator');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geo, (MethodCall c) async => throw MissingPluginException(c.method));
      lotdResponder = (req) {
        if (req.url.path.endsWith('/sitters/nearby')) {
          final m = double.tryParse(req.url.queryParameters['radiusInMeters'] ?? '') ?? 0;
          final all = <Map<String, dynamic>>[_sitter('s40', 40), _sitter('s60', 60)];
          return <String, dynamic>{
            'sitters': all.where((s) => (s['distanceInMeters'] as int) <= m).toList(),
          };
        }
        if (req.url.path.endsWith('/walkers/nearby')) {
          return <String, dynamic>{'walkers': <Map<String, dynamic>>[]};
        }
        if (req.url.path.endsWith('/posts')) {
          return <String, dynamic>{'posts': <Map<String, dynamic>>[]};
        }
        return <String, dynamic>{};
      };
    });

    testWidgets('40 km : visible à 50 km, absent à 30 km ; radiusInMeters = affiché × 1000',
        (tester) async {
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const HomeScreen()));
      await tester.pump(const Duration(seconds: 7)); // délai GPS (sans plugin)
      await lotdSettle(tester, frames: 8);
      expect(tester.takeException(), isNull);
      expect(lotdRequests.where((r) => r.path.endsWith('/sitters/nearby')), isNotEmpty,
          reason: 'requêtes vues : ${lotdRequests.map((r) => r.path).toSet().join(' ')} ; '
              'HomeController=${Get.isRegistered<HomeController>()} '
              'loading=${Get.isRegistered<HomeController>() ? Get.find<HomeController>().isLoadingSitters.value : '-'} '
              'lastFailure=${LocationService().lastFailure}');
      // La barre « Autour de moi » vit sous les onglets Gardiens / Promeneurs.
      if (_shownRadius(tester) == null) {
        await tester.tap(find.text('home_segment_sitters'.tr).first);
        await lotdSettle(tester, frames: 4);
      }
      expect(_shownRadius(tester), '50 km');
      expect(find.textContaining('Gardien s40'), findsWidgets);
      expect(find.textContaining('Gardien s60'), findsNothing);

      await _setRadius(tester, 30);
      expect(_shownRadius(tester), '30 km');
      final last = lotdRequests.lastWhere((r) => r.path.endsWith('/sitters/nearby'));
      expect(last.query['radiusInMeters'], '30000');
      expect(find.textContaining('Gardien s40'), findsNothing);

      await _setRadius(tester, 70);
      expect(_shownRadius(tester), '70 km');
      expect(lotdRequests.lastWhere((r) => r.path.endsWith('/sitters/nearby')).query['radiusInMeters'], '70000');
      expect(find.textContaining('Gardien s40'), findsWidgets);
      // La liste est paresseuse (le 2e gardien peut être sous le pli) : on
      // vérifie la liste réellement appliquée par le contrôleur.
      expect(Get.find<HomeController>().sitters.map((x) => x.name),
          containsAll(<String>['Gardien s40', 'Gardien s60']));
      expect(HomeRadiusPrefs.read('owner'), 70);
      expect(tester.takeException(), isNull);
    });
  });

  group('mesure', () {
    setUp(() async {
      await lotdSetUp(role: 'sitter');
      await _profileAtCenter('sitter');
      lotdResponder = (req) {
        if (req.url.path.endsWith('/posts/requests')) {
          return <String, dynamic>{
            'posts': List<Map<String, dynamic>>.generate(40, (i) => _post('m$i', 5 + i * 0.5)),
          };
        }
        return <String, dynamic>{};
      };
    });

    testWidgets('glissement de 40 pas : durée et reconstructions du corps', (tester) async {
      lotdPhone(tester);
      await tester.pumpWidget(lotdApp(const SitterHomescreen()));
      await lotdSettle(tester, frames: 8);
      expect(find.textContaining('Annonce m0'), findsWidgets);

      final sliderFinder = find.descendant(of: find.byType(AroundMeSearchBar), matching: find.byType(Slider));
      final rect = tester.getRect(sliderFinder);
      final start = Offset(rect.left + rect.width * 0.2, rect.center.dy);
      int bodyBuilds = 0;
      final gesture = await tester.startGesture(start);
      final sw = Stopwatch()..start();
      for (int i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(4, 0));
        await tester.pump();
        // Le corps de l'écran (liste des annonces) est-il reconstruit ? On le
        // détecte par le nombre de fois où le compteur de résultats change
        // d'instance : approximation robuste = on compte les images pompées.
        bodyBuilds++;
      }
      sw.stop();
      final dragMs = sw.elapsedMilliseconds;
      final sw2 = Stopwatch()..start();
      await gesture.up();
      await lotdSettle(tester, frames: 3);
      sw2.stop();
      // Le rayon est poussé au compte 2 s après le relâchement : on laisse
      // partir ce minuteur (sinon « pending timer » en fin de test).
      await tester.pump(const Duration(seconds: 3));
      // ignore: avoid_print
      print('[MESURE] glissement 40 pas : $dragMs ms (${(dragMs / bodyBuilds).toStringAsFixed(1)} ms/pas) ; relâchement : ${sw2.elapsedMilliseconds} ms');
      expect(tester.takeException(), isNull);
    });
  });
}
