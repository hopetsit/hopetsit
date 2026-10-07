// ignore_for_file: avoid_print
// 614 (PAM, 07/10/2026) — Daniel : « quand j'appuie sur le PawSpot ça me
// donne le profil de Cam ». PARCOURS AU SIMULATEUR, SANS COMPTE (aucune
// écriture serveur). Données = celles MESURÉES par l'API admin le 07/10 :
//   · Cam (amie, propriétaire) à 37.73215, -1.34711 (vue il y a 4 h) ;
//   · john (ami, 3 rôles) à sa position de profil 37.85151, -1.42510 ;
//   · les 4 PawSpots réels de Los Guardianes (créateurs : witoulek ×3, john).
// Le test pose la scène au zoom de la capture de Daniel puis ATTEND : l'appui
// est fait de l'extérieur (vrai toucher natif sur le simulateur) et le test
// journalise ce qui s'est ouvert (`[P614] ETAT …`).
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const double kCamLat = 37.73215424383419, kCamLng = -1.3471085487286405;
const double kJohnLat = 37.8515145, kJohnLng = -1.4251045;

final List<Map<String, dynamic>> kSpots614 = [
  {'id': '6a2fe96aec567e815a3eb7bd', 'type': 'path_walk', 'name': 'paseo perros', 'lat': 37.73161346807051, 'lng': -1.3486844301223755, 'creatorId': '6a0f475de83c5291f5b03525', 'creatorName': 'witoulek', 'isGolden': true},
  {'id': '6a33123e3b5b10fc35fc3f3c', 'type': 'path_walk', 'name': 'perros', 'lat': 37.72384080318378, 'lng': -1.3605810329318047, 'creatorId': '6a3307b73b5b10fc35fbf1eb', 'creatorName': 'witoulek', 'isGolden': true},
  {'id': '6a35641007ee0d7358a0f983', 'type': 'playground', 'name': 'con agua', 'lat': 37.73123746287098, 'lng': -1.348707228899002, 'creatorId': '6a3307b73b5b10fc35fbf1eb', 'creatorName': 'witoulek', 'isGolden': true},
  {'id': '6ac238209219956893109684', 'type': 'path_walk', 'name': 'paseo perros', 'lat': 37.73150014201113, 'lng': -1.349173025076473, 'creatorId': '6a5005bd7be16accb52aa548', 'creatorName': 'john C', 'isGolden': true},
];

class _FakeSpots614 extends PawSpotController {
  @override
  Future<void> loadNearby(LatLng center, {double? radiusM}) async {
    spots.assignAll(kSpots614.map(PawSpotModel.fromJson));
  }
}

GoogleMap? _map(WidgetTester t) {
  final f = find.byType(GoogleMap, skipOffstage: false);
  if (f.evaluate().isEmpty) return null;
  return t.widget<GoogleMap>(f);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    for (final code in ['fr', 'fr_FR']) {
      try {
        await initializeDateFormatting(code);
      } catch (_) {}
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}
    setupDependencies();
  });

  testWidgets('614 — appui sur le PawSpot de Los Guardianes', (t) async {
    final now = DateTime.now();
    await GetStorage().write('pawmap_intro_seen_count', 1);
    await GetStorage().write('pawspot_layer_on', true);
    await GetStorage().write('pawmap_world_cache', [
      {
        'id': '6ac229c59219956893100221', '_role': 'owner', 'role': 'owner',
        'roles': [{'id': '6ac229c59219956893100221', 'role': 'owner'}],
        'personIds': ['6ac229c59219956893100221'],
        'name': 'Cam Chetmou', 'avatar': '', 'isFriend': true, 'isPremium': true,
        'approx': false, 'approxKm': 0,
        'location': {'coordinates': [kCamLng, kCamLat]},
        'lastSeenAt': now.subtract(const Duration(hours: 4, minutes: 27)).toUtc().toIso8601String(),
      },
      {
        'id': '6a5005bd7be16accb52aa548', '_role': 'walker', 'role': 'walker',
        'roles': [
          {'id': '6a5005bd7be16accb52aa548', 'role': 'walker'},
          {'id': '6a5005bd7be16accb52aa548', 'role': 'owner'},
          {'id': '6aaf143cacfed4806196ecb5', 'role': 'sitter'},
        ],
        'personIds': ['6a5005bd7be16accb52aa548', '6aaf143cacfed4806196ecb5'],
        'name': 'john C', 'avatar': '', 'isFriend': true, 'isPremium': true,
        'approx': false, 'approxKm': 0,
        'location': {'coordinates': [kJohnLng, kJohnLat]},
        'lastSeenAt': now.subtract(const Duration(hours: 5, minutes: 4)).toUtc().toIso8601String(),
      },
    ]);
    await GetStorage().write('pawmap_world_cache_at', now.millisecondsSinceEpoch);
    await Future<void>.delayed(const Duration(seconds: 6));
    if (Get.isRegistered<PawSpotController>()) Get.delete<PawSpotController>(force: true);
    final fake = Get.put<PawSpotController>(_FakeSpots614(), permanent: true);
    await fake.loadNearby(const LatLng(kCamLat, kCamLng));
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr', 'FR'),
        fallbackLocale: const Locale('en', 'US'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const PawMapScreen(initialLat: kCamLat, initialLng: kCamLng),
      ),
    ));
    for (var i = 0; i < 20 && _map(t) == null; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    final st = t.state(find.byType(PawMapScreen)) as dynamic;
    GoogleMapController? ctl;
    for (var i = 0; i < 300 && ctl == null; i++) {
      ctl = await (st.activeMapCtlForTest() as Future<GoogleMapController?>)
          .timeout(const Duration(milliseconds: 50), onTimeout: () => null);
      if (ctl == null) await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(seconds: 6));
    // Zoom de la capture de Daniel : ~39 m par point d'écran → 11,6.
    await ctl!.animateCamera(CameraUpdate.newLatLngZoom(
        const LatLng((kCamLat + kJohnLat) / 2, (kCamLng + kJohnLng) / 2 + 0.01), 11.6));
    await t.pump(const Duration(seconds: 5));
    await fake.loadNearby(const LatLng(kCamLat, kCamLng));
    await t.pump(const Duration(seconds: 3));
    final ms = _map(t)!.markers.toList()
      ..sort((a, b) => a.markerId.value.compareTo(b.markerId.value));
    for (final m in ms) {
      final sc = await ctl.getScreenCoordinate(m.position);
      print('[P614] MARKER ${m.markerId.value} z=${m.zIndexInt} '
          'anchor=(${m.anchor.dx.toStringAsFixed(2)},${m.anchor.dy.toStringAsFixed(2)}) '
          'ecran=(${sc.x},${sc.y}) tap=${m.consumeTapEvents}');
    }
    print('[P614] PRET');
    String last = '';
    for (var i = 0; i < 600; i++) {
      await t.pump(const Duration(milliseconds: 500));
      final dbg = st.p612DebugForTest() as Map<String, dynamic>;
      final sheet = find.textContaining('paseo perros').evaluate().length +
          find.textContaining('con agua').evaluate().length;
      final s = 'focus=${dbg['focus']} ficheSpot=$sheet';
      if (s != last) {
        print('[P614] ETAT t=${i / 2}s $s');
        last = s;
      }
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
