// ignore_for_file: avoid_print
// 612 (PAM, 05/10/2026) — PARCOURS AU SIMULATEUR de la balade suivie en
// direct (retours de Daniel du 05/10, La Isla, Alhama de Murcia).
//
// SANS COMPTE (aucun mot de passe, aucune écriture serveur) : la carte est
// ouverte en visiteur, la personne suivie (« Cam ») est INJECTÉE dans le
// service du direct comme le ferait le socket `map:friend-position`, et
// « Moi » = la position GPS du simulateur (`xcrun simctl location`).
//
// Étapes (chaque `[P612] SNAP <nom>` = capture prise de l'extérieur) :
//   1. zoom de rue 18,5 (comme Daniel) ; Cam en direct à 3 m de moi ;
//   2. 1er appui sur Cam → fiche ; 2e appui → fiche membre → « Suivre » ;
//   3. Cam marche (avec 2 sauts GPS « Mercadona ») ;
//   4. je lance MA balade pendant le suivi (3D ?) ;
//   5. je zoome à 19,3 puis « Recentrer » → même zoom ?
//   6. dézoom / zoom pendant que Cam bouge (la photo saute ?).
// Mesures `[P612] M ...` : zoom réel (contrôleur), cercles, traits, position
// du rond de Cam vs sa vraie position, ancre, état de caméra (612).

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const double kMeLat = 37.84918; // La Isla, Alhama de Murcia
const double kMeLng = -1.42370;
const String kCam = 'cam612';
const double _m = 1 / 111320;

LatLng _off(double north, double east) =>
    LatLng(kMeLat + north * _m, kMeLng + east * _m / 0.79);

Future<void> _snap(WidgetTester t, String name, {int secs = 3}) async {
  print('[P612] SNAP $name');
  await t.pump(Duration(seconds: secs));
}

GoogleMap? _map(WidgetTester t) {
  final f = find.byType(GoogleMap, skipOffstage: false);
  if (f.evaluate().isEmpty) return null;
  return t.widget<GoogleMap>(f);
}

Future<void> _measure(WidgetTester t, String tag, LatLng camReal) async {
  final g = _map(t);
  final st = t.state(find.byType(PawMapScreen)) as dynamic;
  double? zoom;
  try {
    final GoogleMapController? c = await st.activeMapCtlForTest();
    zoom = await c?.getZoomLevel();
  } catch (_) {}
  final circles = g?.circles.map((c) => c.circleId.value).toList() ?? const [];
  final lines = g?.polylines
          .map((p) => '${p.polylineId.value}(${p.points.length}pts)')
          .toList() ??
      const [];
  String cam = 'absent';
  String me = 'absent';
  for (final mk in g?.markers ?? const <Marker>{}) {
    final v = mk.markerId.value;
    if (v == 'friend_$kCam') {
      final dLat = (mk.position.latitude - camReal.latitude) / _m;
      final dLng = (mk.position.longitude - camReal.longitude) / _m * 0.79;
      cam = 'ecart=${dLat.toStringAsFixed(1)}m/${dLng.toStringAsFixed(1)}m '
          'ancre=${mk.anchor.dx.toStringAsFixed(2)},${mk.anchor.dy.toStringAsFixed(2)} z=${mk.zIndexInt}';
    }
    if (v == 'me') {
      me = 'ancre=${mk.anchor.dx.toStringAsFixed(2)},${mk.anchor.dy.toStringAsFixed(2)} z=${mk.zIndexInt}';
    }
  }
  String dbg = '';
  try {
    dbg = ' etat=${st.p612DebugForTest()}';
  } catch (_) {
    dbg = ' etat=(pas d\'accès 612)';
  }
  print('[P612] M $tag zoom=${zoom?.toStringAsFixed(2)} cercles=$circles '
      'traits=$lines cam=[$cam] moi=[$me]$dbg');
}

/// Écart à l'ÉCRAN (px) entre la photo suivie (position glissée) et le
/// centre de la caméra, lu sur la carte native.
Future<void> _centre(WidgetTester t, String tag) async {
  final st = t.state(find.byType(PawMapScreen)) as dynamic;
  final GoogleMapController c = (await st.activeMapCtlForTest())!;
  final Map<String, dynamic> d = st.p612DebugForTest() as Map<String, dynamic>;
  final g = d['glide'] as List?;
  if (g == null) {
    print('[P612] C $tag pas de suivi');
    return;
  }
  final vr = await c.getVisibleRegion();
  final a = await c.getScreenCoordinate(LatLng(g[0] as double, g[1] as double));
  final mid = await c.getScreenCoordinate(LatLng(
      (d['target'] as List)[0] as double, (d['target'] as List)[1] as double));
  final ne = await c.getScreenCoordinate(vr.northeast);
  final sw = await c.getScreenCoordinate(vr.southwest);
  final dx = a.x - mid.x, dy = a.y - mid.y;
  print('[P612] C $tag ecart_px=${dx.abs() > dy.abs() ? dx.abs() : dy.abs()} '
      '(dx=$dx dy=$dy) photo=${a.x},${a.y} centre_camera=${mid.x},${mid.y} '
      'coins=${sw.x},${ne.y}→${ne.x},${sw.y} tilt=${d['tilt']} zoom=${(d['zoom'] as double).toStringAsFixed(2)}');
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

  testWidgets('612 — balade suivie en direct (visiteur, Cam injectée)', (t) async {
    // Guide de découverte déjà vu (sinon ses bulles couvrent les captures).
    await GetStorage().write('pawmap_intro_seen_count', 1);
    // Laisse le script redonner l'autorisation de position (réinstallation).
    await Future<void>.delayed(const Duration(seconds: 8));
    final live = Get.isRegistered<LiveMapService>()
        ? Get.find<LiveMapService>()
        : Get.put(LiveMapService(), permanent: true);
    final sw = Stopwatch()..start();
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr', 'FR'),
        fallbackLocale: const Locale('en', 'US'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const PawMapScreen(initialLat: kMeLat, initialLng: kMeLng),
      ),
    ));
    for (var i = 0; i < 20 && _map(t) == null; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    final st = t.state(find.byType(PawMapScreen)) as dynamic;
    GoogleMapController? ctl0;
    for (var i = 0; i < 300 && ctl0 == null; i++) {
      ctl0 = await (st.activeMapCtlForTest() as Future<GoogleMapController?>)
          .timeout(const Duration(milliseconds: 50), onTimeout: () => null);
      if (ctl0 == null) await t.pump(const Duration(milliseconds: 100));
    }
    final GoogleMapController ctl = ctl0!;
    print('[P612] T carte_creee_ms=${sw.elapsedMilliseconds}');
    double? z0;
    for (var i = 0; i < 100 && z0 == null; i++) {
      try {
        z0 = await ctl.getZoomLevel();
      } catch (_) {}
      if (z0 == null) await t.pump(const Duration(milliseconds: 100));
    }
    print('[P612] T carte_repond_ms=${sw.elapsedMilliseconds}');
    await t.pump(const Duration(seconds: 6));

    // 1 — Cam en direct à ~3 m de moi ; zoom de rue 18,5.
    var camAt = _off(2, 2);
    void push(LatLng p) => live.ingestLivePosition(FriendPosition(
          userId: kCam,
          role: 'owner',
          latitude: p.latitude,
          longitude: p.longitude,
          at: DateTime.now(),
          sharing: true,
          name: 'Cam Chetmou',
        ));
    push(camAt);
    await ctl.animateCamera(CameraUpdate.newLatLngZoom(LatLng(kMeLat, kMeLng), 18.5));
    await t.pump(const Duration(seconds: 3));
    await _measure(t, '1-depart', camAt);
    await _snap(t, '1-depart');

    // 2 — 1er appui sur Cam, 2e appui → fiche → « Suivre ».
    Marker camMk() => _map(t)!.markers.firstWhere((m) => m.markerId.value == 'friend_$kCam');
    camMk().onTap?.call();
    await t.pump(const Duration(seconds: 3));
    await _measure(t, '2a-1er-appui', camAt);
    await _snap(t, '2a-1er-appui');
    camMk().onTap?.call();
    await t.pump(const Duration(seconds: 2));
    final sheet = find.byType(PawMapMemberSheet, skipOffstage: false);
    print('[P612] fiche membre ouverte=${sheet.evaluate().isNotEmpty}');
    if (sheet.evaluate().isNotEmpty) {
      t.widget<PawMapMemberSheet>(sheet).onFollow?.call();
    }
    await t.pump(const Duration(seconds: 3));
    await _measure(t, '2b-suivre', camAt);
    await _snap(t, '2b-suivre');

    // 3 — Cam marche vers le nord-est, 2 sauts GPS au milieu.
    final path = <LatLng>[
      for (var i = 1; i <= 4; i++) _off(2 + i * 9.0, 2 + i * 4.0),
      _off(95, 70), // saut « Mercadona »
      _off(48, 22),
      _off(-30, 60), // saut
      for (var i = 6; i <= 8; i++) _off(2 + i * 9.0, 2 + i * 4.0),
    ];
    final frames = <FrameTiming>[];
    void onT(List<FrameTiming> l) => frames.addAll(l);
    SchedulerBinding.instance.addTimingsCallback(onT);
    for (final p in path) {
      camAt = p;
      push(p);
      await t.pump(const Duration(milliseconds: 2500));
    }
    SchedulerBinding.instance.removeTimingsCallback(onT);
    final ms = frames.map((f) => f.totalSpan.inMicroseconds / 1000.0).toList()..sort();
    final slow = ms.where((x) => x > 16.7).length;
    print('[P612] T marche images=${ms.length} lentes(>16,7ms)=$slow '
        'mediane=${ms.isEmpty ? 0 : ms[ms.length ~/ 2].toStringAsFixed(1)}ms '
        'pire=${ms.isEmpty ? 0 : ms.last.toStringAsFixed(1)}ms');
    await _measure(t, '3-apres-marche', camAt);
    await _snap(t, '3-apres-marche');

    // C1 — vue À PLAT, suivi actif : boutons − − + puis pincement.
    Future<void> press0(String key) async {
      final f = find.byKey(ValueKey<String>(key), skipOffstage: false);
      if (f.evaluate().isNotEmpty) (t.widget(f) as dynamic).onTap();
    }
    await _centre(t, 'plat-avant-zoom');
    for (final k in ['pawmap_btn_zoom_out', 'pawmap_btn_zoom_out', 'pawmap_btn_zoom_in']) {
      await press0(k);
      camAt = _off(camAt.latitude == 0 ? 0 : (camAt.latitude - kMeLat) / _m + 5,
          (camAt.longitude - kMeLng) / _m * 0.79 + 3);
      push(camAt);
      await t.pump(const Duration(milliseconds: 400));
    }
    await t.pump(const Duration(milliseconds: 2500));
    await _centre(t, 'plat-apres-boutons');
    await _snap(t, 'c1-plat-apres-boutons', secs: 1);
    // pincement (deux doigts sur la carte) + zoom de la caméra pendant le geste
    final mapBox = t.getRect(find.byType(GoogleMap));
    final g1 = await t.startGesture(mapBox.center + const Offset(-40, -120), pointer: 71);
    final g2 = await t.startGesture(mapBox.center + const Offset(40, -40), pointer: 72);
    await g1.moveBy(const Offset(-30, -30));
    await g2.moveBy(const Offset(30, 30));
    await ctl.moveCamera(CameraUpdate.zoomBy(0.9));
    camAt = _off((camAt.latitude - kMeLat) / _m + 6, (camAt.longitude - kMeLng) / _m * 0.79 + 4);
    push(camAt);
    await t.pump(const Duration(milliseconds: 300));
    await g1.up();
    await g2.up();
    await t.pump(const Duration(milliseconds: 2500));
    await _centre(t, 'plat-apres-pincement');
    await _snap(t, 'c2-plat-apres-pincement', secs: 1);

    // H — reconstructions de la carte Google (chaque reconstruction renvoie
    // marqueurs / cercles / traits au SDK natif) : 10 s sans geste, Cam en
    // direct suivie, ma balade allumée (le cas de Daniel et Cam).
    live.broadcasting.value = true;
    await t.pump(const Duration(seconds: 3));
    final seen = <int>{};
    final swR = Stopwatch()..start();
    while (swR.elapsedMilliseconds < 10000) {
      final g = _map(t);
      if (g != null) seen.add(identityHashCode(g));
      await t.pump(const Duration(milliseconds: 20));
    }
    final circ = _map(t)?.circles.length ?? 0;
    print('[P612] T reconstructions_carte_10s=${seen.length} cercles=$circ');
    live.broadcasting.value = false;
    await t.pump(const Duration(seconds: 3));

    // 4 — je lance MA balade pendant le suivi (vue rue penchée ?).
    live.broadcasting.value = true;
    await t.pump(const Duration(seconds: 4));
    await _measure(t, '4-ma-balade', camAt);
    await _snap(t, '4-ma-balade');

    // 5 — je zoome à 19,3 puis « Recentrer » (pilule de suivi → feuille).
    await ctl.animateCamera(CameraUpdate.zoomTo(19.3));
    await t.pump(const Duration(seconds: 2));
    await _measure(t, '5a-zoom-19', camAt);
    final pill = find.byType(PawMapFollowPill, skipOffstage: false);
    print('[P612] pilule de suivi=${pill.evaluate().isNotEmpty}');
    if (pill.evaluate().isNotEmpty) {
      t.widget<PawMapFollowPill>(pill).onTap();
      await t.pump(const Duration(seconds: 2));
      final fs = find.byType(PawMapFollowSheet, skipOffstage: false);
      if (fs.evaluate().isNotEmpty) t.widget<PawMapFollowSheet>(fs).onResume();
    }
    await t.pump(const Duration(seconds: 3));
    await _measure(t, '5b-recentrer', camAt);
    await _snap(t, '5b-recentrer');

    // 6 — boutons − puis + pendant que Cam bouge (la photo saute ? le
    // zoom est-il coupé par le suivi ?).
    Future<void> press(String key) async {
      final f = find.byKey(ValueKey<String>(key), skipOffstage: false);
      if (f.evaluate().isEmpty) {
        print('[P612] bouton $key absent');
        return;
      }
      (t.widget(f) as dynamic).onTap();
    }
    print('[P612] RAFALE debut');
    for (var k = 0; k < 6; k++) {
      await press(k < 3 ? 'pawmap_btn_zoom_out' : 'pawmap_btn_zoom_in');
      camAt = _off(80 + k * 6.0, 36 + k * 3.0);
      push(camAt);
      for (var f = 0; f < 4; f++) {
        await t.pump(const Duration(milliseconds: 250));
      }
      if (k == 2) await _measure(t, '6a-apres-3-moins', camAt);
    }
    print('[P612] RAFALE fin');
    await t.pump(const Duration(seconds: 3));
    await _centre(t, 'penche-apres-boutons');
    await _measure(t, '6-apres-zoom', camAt);
    await _snap(t, '6-apres-zoom');

    live.broadcasting.value = false;
    await t.pump(const Duration(seconds: 3));
    await _centre(t, 'fin-balade-a-plat');
    await _measure(t, '7-fin-balade', camAt);
    await _snap(t, '7-fin-balade');
    print('[P612] FIN');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
