// ignore_for_file: avoid_print
// 613 (PAM, 06/10/2026) — PARCOURS AU SIMULATEUR, SANS COMPTE (aucun mot de
// passe, aucune écriture serveur) — PROCHAIN_BUILD_613 §1, §2, §4a-d.
// Lieu : La Isla, Alhama de Murcia (les coordonnées des signalements réels du
// 06/10, lues par l'API admin). « Moi » = GPS du simulateur ; john (suivi) et
// les signalements sont INJECTÉS comme le feraient le socket et l'API.
// Chaque `[P613] SNAP <nom>` = capture prise de l'extérieur (run_613.sh).

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/pawmap_osm_tiles.dart';
import 'package:flutter/scheduler.dart';
import 'package:hopetsit/views/map/widgets/pawmap_catch613.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_report_pin613.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const double kMeLat = 37.73060; // La Isla (signalements réels du 06/10)
const double kMeLng = -1.34800;
const String kJohn = 'john613';
const double _m = 1 / 111320;
LatLng _off(double north, double east) =>
    LatLng(kMeLat + north * _m, kMeLng + east * _m / 0.7912);

Future<void> _snap(WidgetTester t, String name, {int ms = 2500}) async {
  print('[P613] SNAP $name');
  await t.pump(Duration(milliseconds: ms));
}

GoogleMap? _map(WidgetTester t) {
  final f = find.byType(GoogleMap, skipOffstage: false);
  if (f.evaluate().isEmpty) return null;
  return t.widget<GoogleMap>(f);
}

Map<String, dynamic> _report(String id, String type, double lat, double lng, Duration age) {
  final c = DateTime.now().subtract(age);
  return {
    '_id': id,
    'type': type,
    'location': {'type': 'Point', 'coordinates': [lng, lat], 'city': 'Alhama de Murcia'},
    'createdAt': c.toIso8601String(),
    'expiresAt': c.add(const Duration(hours: 48)).toIso8601String(),
  };
}

/// Itinéraire « comme Valhalla » SANS réseau : départ et arrivée ACCROCHÉS au
/// sentier (le long de la traîne de john), pas sur les personnes.
List<LatLng> kPath613 = <LatLng>[];
class _FakeSpots613 extends PawSpotController {
  int calls = 0;
  LatLng? lastFrom, lastTo;
  @override
  Future<PawSpotDirections> fetchDirections({
    required LatLng from,
    required LatLng to,
    String mode = 'walk',
    String? friendId,
  }) async {
    calls++;
    lastFrom = from;
    lastTo = to;
    // distance réelle du tracé simulé, temps à pied à 4,8 km/h (comme Valhalla)
    var m = 0.0;
    for (var i = 1; i < kPath613.length; i++) {
      final a = kPath613[i - 1], b = kPath613[i];
      m += math.sqrt(math.pow((a.latitude - b.latitude) * 111320, 2) +
          math.pow((a.longitude - b.longitude) * 111320 * 0.7912, 2));
    }
    return PawSpotDirections(
      points: kPath613,
      distanceMeters: m.round(),
      durationSeconds: (m / (4800 / 3600)).round(),
      steps: [
        PawSpotRouteStep(type: 1, instruction: 'Départ', distanceMeters: 64, position: kPath613.first),
        PawSpotRouteStep(type: 4, instruction: 'Arrivée', distanceMeters: 0, position: kPath613.last),
      ],
    );
  }
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

  testWidgets('613 — emojis des signalements sur le VRAI moteur iOS', (t) async {
    // Mesure AVANT correctif : le dessin de 612 (emoji seul dans un rond blanc)
    // laisse-t-il un rond VIDE pour certains types ?
    await t.runAsync(() async {
      final vides = <String>[];
      for (final type in ReportTypes.all) {
        final img = await pawPaintReportPin613(emoji: ReportTypes.emoji(type));
        final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final ink = pawPinHasInk613(raw!, img.width, img.height);
        print('[P613] EMOJI $type ${ReportTypes.emoji(type)} encre=$ink');
        if (!ink) vides.add(type);
      }
      print('[P613] EMOJI vides=${vides.length} $vides');
      // APRÈS : la fabrique 613 ne rend jamais de rond vide.
      final apres = <String>[];
      for (final type in ReportTypes.all) {
        final pin = await pawBuildReportPin613(type, ReportTypes.emoji(type));
        final img = await ui.instantiateImageCodec(pin.png).then((c) => c.getNextFrame());
        final raw = await img.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (!pawPinHasInk613(raw!, img.image.width, img.image.height)) apres.add(type);
        if (pin.usedFallback) print('[P613] EMOJI secours $type');
      }
      print('[P613] EMOJI apres_vides=${apres.length} $apres');
    });
  });

  testWidgets('613 — carte La Isla : alertes, suivi, Rejoindre, fête', (t) async {
    await GetStorage().write('pawmap_intro_seen_count', 1);
    await GetStorage().write('pawmap_osm_base_v593', true); // fond de Daniel
    await Future<void>.delayed(const Duration(seconds: 8));
    final live = Get.isRegistered<LiveMapService>()
        ? Get.find<LiveMapService>()
        : Get.put(LiveMapService(), permanent: true);
    if (Get.isRegistered<PawSpotController>()) Get.delete<PawSpotController>(force: true);
    final fakeSpots = Get.put<PawSpotController>(_FakeSpots613(), permanent: true) as _FakeSpots613;
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
    await t.pump(const Duration(seconds: 6));

    // ── 4a/4b : les signalements RÉELS du 06/10 (types, positions, heures) ──
    final rc = Get.find<MapReportController>();
    rc.reports.value = [
      _report('r_hazard', 'hazard', 37.730526, -1.347624, const Duration(minutes: 3)), // 22:35
      _report('r_dead', 'dead_animal', 37.730809, -1.347760, const Duration(minutes: 6)),
      _report('r_traffic', 'busy_traffic', 37.730638, -1.347829, const Duration(minutes: 7)),
      _report('r_dog', 'aggressive_dog', 37.731029, -1.344813, const Duration(hours: 30)),
      _report('r_water', 'water_active', 37.73040, -1.34830, const Duration(hours: 40)),
      _report('r_ticks', 'tick_zone', 37.73090, -1.34840, const Duration(hours: 5)),
    ].map(MapReport.fromJson).toList();
    await ctl.animateCamera(CameraUpdate.newLatLngZoom(const LatLng(37.73068, -1.34790), 18.3));
    await t.pump(const Duration(seconds: 4));
    final reps = _map(t)!.markers.where((m) => m.markerId.value.startsWith('report_')).toList();
    for (final m in reps) {
      print('[P613] REPORT ${m.markerId.value} alpha=${m.alpha} z=${m.zIndexInt}');
    }
    print('[P613] REPORT secours=${st.reportPinFallbackForTest()}');
    await _snap(t, '1-alertes');

    // ── §7 : pincements sur fond OSM, A/B dans la MÊME session ──
    // A = 612 (8 tuiles voisines chargées à chaque tuile, même en plein geste)
    // B = 613 (voisines repoussées à l'arrêt). Deux zones distinctes et
    // symétriques (aucune tuile en cache), même suite de zooms.
    for (final (tag, defer, lng) in const [('A-612', false, -1.20), ('B-613', true, -1.60)]) {
      PawOsmTileProvider.deferNeighbors613 = defer;
      final t0 = PawOsmTileProvider.getTileCalls613, n0 = PawOsmTileProvider.netFetches613;
      final ui = <double>[], rs = <double>[];
      void onT(List<FrameTiming> l) {
        for (final f in l) {
          ui.add(f.buildDuration.inMicroseconds / 1000);
          rs.add(f.rasterDuration.inMicroseconds / 1000);
        }
      }
      await ctl.moveCamera(CameraUpdate.newLatLngZoom(LatLng(37.80, lng), 13));
      await t.pump(const Duration(seconds: 3));
      SchedulerBinding.instance.addTimingsCallback(onT);
      for (final z in const [15.0, 17.0, 14.5, 17.5, 16.0]) {
        await ctl.animateCamera(CameraUpdate.zoomTo(z), duration: const Duration(milliseconds: 700));
        await t.pump(const Duration(milliseconds: 900));
      }
      SchedulerBinding.instance.removeTimingsCallback(onT);
      final gT = PawOsmTileProvider.getTileCalls613 - t0, gN = PawOsmTileProvider.netFetches613 - n0;
      String pc(List<double> l) {
        if (l.isEmpty) return '-';
        final v = [...l]..sort();
        return 'p50=${v[v.length ~/ 2].toStringAsFixed(1)} p90=${v[((v.length - 1) * .9).round()].toStringAsFixed(1)} max=${v.last.toStringAsFixed(1)}';
      }
      print('[P613] OSM $tag tuiles_demandees=$gT telechargements=$gN images=${ui.length} UI ${pc(ui)} RASTER ${pc(rs)}');
      await t.pump(const Duration(seconds: 3));
    }
    PawOsmTileProvider.deferNeighbors613 = true;

    // ── §2 : john suivi, Moi à côté ──
    var johnAt = _off(10, 4);
    void push(LatLng p) => live.ingestLivePosition(FriendPosition(
          userId: kJohn,
          role: 'walker',
          latitude: p.latitude,
          longitude: p.longitude,
          at: DateTime.now(),
          sharing: true,
          name: 'john C',
        ));
    push(johnAt);
    await ctl.animateCamera(CameraUpdate.newLatLngZoom(LatLng(kMeLat, kMeLng), 18.5));
    await t.pump(const Duration(seconds: 3));
    Marker johnMk() => _map(t)!.markers.firstWhere((m) => m.markerId.value == 'friend_$kJohn');
    johnMk().onTap?.call();
    await t.pump(const Duration(seconds: 3));
    johnMk().onTap?.call();
    await t.pump(const Duration(seconds: 2));
    final sheet = find.byType(PawMapMemberSheet, skipOffstage: false);
    print('[P613] fiche membre ouverte=${sheet.evaluate().isNotEmpty}');
    if (sheet.evaluate().isNotEmpty) t.widget<PawMapMemberSheet>(sheet).onFollow?.call();
    await t.pump(const Duration(seconds: 3));
    st.debugLiveLayer613();
    // 1) john s'arrête à 7 m au nord de « Moi » (Cam collée sous john,
    //    captures 4-5) : « Moi » doit s'écarter, john jamais.
    johnAt = _off(7, 0);
    push(johnAt);
    await t.pump(const Duration(seconds: 4));
    final me = _map(t)!.markers.where((m) => m.markerId.value == 'me').toList();
    print('[P613] SUIVI etat=${st.p612DebugForTest()} moi_ancre=${me.isEmpty ? '-' : '${me.first.anchor.dx.toStringAsFixed(2)},${me.first.anchor.dy.toStringAsFixed(2)}'}');
    await _snap(t, '2a-suivi-halo-A', ms: 1500);
    await _snap(t, '2b-suivi-halo-B', ms: 1500);

    // la pilule du suivi → la feuille : « Rejoindre john »
    final pill = find.byType(PawMapFollowPill, skipOffstage: false);
    print('[P613] pilule suivi=${pill.evaluate().isNotEmpty}');
    if (pill.evaluate().isNotEmpty) t.widget<PawMapFollowPill>(pill).onTap();
    await t.pump(const Duration(seconds: 2));
    final join = find.byKey(const ValueKey<String>('follow_sheet_directions'), skipOffstage: false);
    print('[P613] bouton=${join.evaluate().isNotEmpty} texte_rejoindre=${find.text('Rejoindre john').evaluate().isNotEmpty}');
    await _snap(t, '3-feuille-rejoindre');
    Navigator.of(t.element(find.byType(PawMapScreen))).maybePop();
    await t.pump(const Duration(seconds: 2));

    // 2) john marche le long d'un SENTIER puis sort dans le champ, à 6 m du
    //    bout du sentier (capture 7 : drapeau sur sa traîne, john à côté).
    final sentier = <LatLng>[for (var i = 0; i <= 6; i++) _off(30 + i * 5.0, 30 - i * 2.0)];
    for (final p in sentier) {
      johnAt = p;
      push(p);
      await t.pump(const Duration(milliseconds: 1800));
    }
    johnAt = _off(64, 12);
    push(johnAt);
    await t.pump(const Duration(seconds: 3));
    // Valhalla accroche départ et arrivée au sentier.
    kPath613 = sentier;
    await ctl.animateCamera(CameraUpdate.newLatLngZoom(_off(32, 12), 18.2));
    await t.pump(const Duration(seconds: 3));
    // ── §6 / BOB : « Rejoindre john » à ~300 m ──
    // john part à 300 m au nord-est ; le trajet à pied (simulé, sans réseau)
    // suit des rues en L, départ et arrivée accrochés à ~10 m des personnes.
    johnAt = _off(210, 215); // ≈ 300 m
    push(johnAt);
    await t.pump(const Duration(seconds: 3));
    kPath613 = <LatLng>[
      _off(8, 6), _off(8, 90), _off(60, 95), _off(120, 100), _off(122, 160),
      _off(170, 165), _off(200, 205),
    ];
    // la pilule → feuille → VRAI bouton « Rejoindre john »
    if (pill.evaluate().isNotEmpty) t.widget<PawMapFollowPill>(pill).onTap();
    await t.pump(const Duration(seconds: 2));
    final joinBtn = find.byKey(const ValueKey<String>('follow_sheet_directions'), skipOffstage: false);
    print('[P613] JOIN bouton=${joinBtn.evaluate().isNotEmpty} '
        'controleur_faux=${identical(Get.find<PawSpotController>(), fakeSpots)} '
        'etat=${st.plushDebugForTest()}');
    // 614 (ZOE 07/10) — l'étape passait sans rien tracer : elle ÉCHOUE
    // désormais si le bouton, l'appel d'itinéraire, le trait ou le bandeau
    // « Rejoindre » manquent.
    expect(joinBtn, findsOneWidget, reason: 'bouton « Rejoindre john » absent de la feuille du suivi');
    final callsBefore = fakeSpots.calls;
    (t.widget(joinBtn) as dynamic).onTap();
    await t.pump(const Duration(milliseconds: 1500));
    print('[P613] JOIN appels_itineraire=${fakeSpots.calls - callsBefore} de=${fakeSpots.lastFrom} vers=${fakeSpots.lastTo}');
    expect(fakeSpots.calls, greaterThan(callsBefore),
        reason: 'le faux itinéraire n\'a jamais été appelé : « Rejoindre » ne demande aucun trajet');
    print('[P613] SNAP 4b-rejoindre-300m-message-vite');
    await t.pump(const Duration(seconds: 4));
    // mesures : Moi et john à l'écran, dans la zone libre ? trait continu ?
    final GoogleMapController c2 = (await st.activeMapCtlForTest())!;
    final (Size scr, Rect free) = st.freeMapRectForTest613() as (Size, Rect);
    final dpr = t.view.devicePixelRatio;
    Future<Offset> px(LatLng p) async {
      final sc = await c2.getScreenCoordinate(p);
      // iOS renvoie des points logiques, Android des pixels physiques
      return Platform.isAndroid ? Offset(sc.x / dpr, sc.y / dpr) : Offset(sc.x.toDouble(), sc.y.toDouble());
    }
    final pMe = await px(const LatLng(kMeLat, kMeLng));
    final pJohn = await px(johnAt);
    final lines = _map(t)!.polylines.where((p) => p.polylineId.value.startsWith('pawspot_route')).toList();
    final inLine = lines.where((p) => p.polylineId.value == 'pawspot_route_in').toList();
    final outLine = lines.where((p) => p.polylineId.value == 'pawspot_route_out').toList();
    print('[P613] JOIN ecran=${scr.width.toInt()}x${scr.height.toInt()} zone_libre=${free.left.toInt()},${free.top.toInt()}→${free.right.toInt()},${free.bottom.toInt()} '
        'moi=${pMe.dx.toInt()},${pMe.dy.toInt()} dans_zone=${free.contains(pMe)} '
        'john=${pJohn.dx.toInt()},${pJohn.dy.toInt()} dans_zone=${free.contains(pJohn)} '
        'trait_depart_moi=${inLine.isNotEmpty && inLine.first.points.first == const LatLng(kMeLat, kMeLng)} '
        'trait_arrivee_john=${outLine.isNotEmpty && outLine.first.points.last == johnAt} '
        'traits=${lines.map((p) => '${p.polylineId.value}:z${p.zIndex}:${p.patterns.isEmpty ? 'plein' : 'pointille'}').toList()}');
    final banner = find.byKey(const ValueKey<String>('join613_banner'), skipOffstage: false);
    expect(lines.where((p) => p.polylineId.value == 'pawspot_route'), isNotEmpty,
        reason: 'aucun trait d\'itinéraire sur la carte après « Rejoindre »');
    expect(lines.firstWhere((p) => p.polylineId.value == 'pawspot_route').points.length, greaterThanOrEqualTo(2));
    expect(banner, findsOneWidget, reason: 'bandeau « Rejoindre john · … » absent');
    expect(find.descendant(of: banner, matching: find.textContaining('john')), findsWidgets,
        reason: 'le bandeau ne nomme pas john');
    if (banner.evaluate().isNotEmpty) {
      final r = t.getRect(banner);
      print('[P613] JOIN bandeau=${r.left.toInt()},${r.top.toInt()}→${r.right.toInt()},${r.bottom.toInt()} '
          'texte=${find.descendant(of: banner, matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data).join('|')} '
          'couvre_moi=${r.inflate(30).contains(pMe)} couvre_john=${r.inflate(30).contains(pJohn)}');
    } else {
      print('[P613] JOIN bandeau=absent');
    }
    await _snap(t, '4c-rejoindre-300m');
    // john bouge : l'itinéraire le suit, la caméra ne saute pas sur lui
    johnAt = _off(265, 200); // ≈ +57 m (seuil de recalcul 611 : 50 m)
    push(johnAt);
    await t.pump(const Duration(seconds: 5));
    print('[P613] ROUTE john_bouge appels=${fakeSpots.calls} vers=${fakeSpots.lastTo}');
    final pMe2 = await px(const LatLng(kMeLat, kMeLng));
    print('[P613] JOIN apres_mouvement moi_toujours_dans_zone=${free.contains(pMe2)}');
    // effacer (✕) → retour au suivi normal
    final clr = find.byKey(const ValueKey<String>('join613_clear'), skipOffstage: false);
    if (clr.evaluate().isNotEmpty) (t.widget(clr) as dynamic).onTap();
    await t.pump(const Duration(seconds: 3));
    print('[P613] JOIN efface traits=${_map(t)!.polylines.where((p) => p.polylineId.value.startsWith('pawspot_route')).length} etat=${st.p612DebugForTest()['follow']}');

    // ── 4c : je passe à ~40 m du « danger » réel ──
    st.debugPassing613(const LatLng(37.73016, -1.34763));
    await t.pump(const Duration(milliseconds: 700));
    print('[P613] PASSAGE bandeau=${find.byKey(const ValueKey<String>('alert613_banner'), skipOffstage: false).evaluate().isNotEmpty}');
    await _snap(t, '5-alerte-en-passant', ms: 300);
    await t.pump(const Duration(seconds: 5));
    st.debugPassing613(const LatLng(37.73020, -1.34763));
    await t.pump(const Duration(milliseconds: 700));
    print('[P613] PASSAGE 2e_fois_bandeau=${find.byKey(const ValueKey<String>('alert613_banner'), skipOffstage: false).evaluate().isNotEmpty}');
    await t.pump(const Duration(seconds: 4));

    // ── 614 §1 : la fête ne se pose JAMAIS sur la pilule « En balade » ──
    // (capture Android 613 17_planche_fete.png). Sans balade puis EN balade
    // (« En balade · 2 min » + « 1,6 km · 1/2 »), mesuré au pixel.
    final ctx614 = t.element(find.byType(PawMapScreen));
    if (Get.isRegistered<AuthController>()) Get.find<AuthController>().userRole.value = 'walker';
    for (final walking in const [false, true]) {
      await (st.debugWalkPills614(walking) as Future<void>);
      await t.pump(const Duration(seconds: 3));
      for (var i = 0; walking && i < 20 && find.byType(PawNearestPlushPill, skipOffstage: false).evaluate().isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      print('[P614] PELUCHES ${st.plushDebugForTest()}');
      PawCatchCelebration.show(ctx614, const PawPlushWin(points: 20, type: 'teddy'));
      await t.pump(const Duration(milliseconds: 700));
      final card = t.getRect(find.byKey(const ValueKey<String>('catch613_card')));
      final direct = find.byKey(const ValueKey<String>('pawmap_direct_pill'), skipOffstage: false);
      final plushPill = find.byType(PawNearestPlushPill, skipOffstage: false);
      final infos = <String, Rect>{
        if (direct.evaluate().isNotEmpty) 'pilule_direct': t.getRect(direct),
        if (plushPill.evaluate().isNotEmpty) 'pilule_peluche': t.getRect(plushPill),
      };
      String r(Rect x) => '${x.left.toInt()},${x.top.toInt()}→${x.right.toInt()},${x.bottom.toInt()}';
      print('[P614] FETE balade=$walking ecran=${t.view.physicalSize / t.view.devicePixelRatio} '
          'carte=${r(card)} ${infos.entries.map((e) => '${e.key}=${r(e.value)} chevauche=${e.value.overlaps(card)}').join(' ')} '
          'texte_pilule=${walking ? find.textContaining('1/2').evaluate().isNotEmpty : '-'}');
      final scr = t.view.physicalSize / t.view.devicePixelRatio;
      expect(infos.values.every((r) => r.right <= scr.width + 0.5), isTrue,
          reason: 'une pilule du haut sort de l\'écran (${scr.width} dp) : $infos');
      print('[P614] SNAP 7${walking ? 'b-fete-en-balade' : 'a-fete-sans-balade'}');
      // le journal arrive en retard au script de capture : la carte est
      // reposée 4 fois (≈ 11 s) pour que la capture la trouve.
      for (var k = 0; k < 4; k++) {
        await t.pump(const Duration(milliseconds: 2800));
        PawCatchCelebration.show(ctx614, const PawPlushWin(points: 20, type: 'teddy'));
        await t.pump(const Duration(milliseconds: 100));
      }
      if (walking) {
        expect(infos.containsKey('pilule_direct'), isTrue, reason: 'pilule « En balade » absente');
        expect(infos.containsKey('pilule_peluche'), isTrue, reason: 'pilule « 1,6 km · 1/2 » absente');
      }
      for (final e in infos.entries) {
        expect(e.value.overlaps(card), isFalse, reason: 'la fête $card couvre ${e.key} ${e.value}');
      }
      await t.pump(const Duration(seconds: 4));
    }
    // AVANT (témoin) : même scène EN balade, zone retirée = rendu du 613.
    final zone614 = PawCatchCelebration.freeZone614;
    PawCatchCelebration.freeZone614 = null;
    PawCatchCelebration.show(ctx614, const PawPlushWin(points: 20, type: 'teddy'));
    await t.pump(const Duration(milliseconds: 700));
    final cardAvant = t.getRect(find.byKey(const ValueKey<String>('catch613_card')));
    final pillAvant = t.getRect(find.byKey(const ValueKey<String>('pawmap_direct_pill'), skipOffstage: false));
    print('[P614] FETE AVANT(613) carte=$cardAvant pilule=$pillAvant chevauche=${cardAvant.overlaps(pillAvant)}');
    print('[P614] SNAP 7c-avant-613-fete-sur-pilule');
    for (var k = 0; k < 4; k++) {
      await t.pump(const Duration(milliseconds: 2800));
      PawCatchCelebration.show(ctx614, const PawPlushWin(points: 20, type: 'teddy'));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(seconds: 4));
    PawCatchCelebration.freeZone614 = zone614;
    await (st.debugWalkPills614(false) as Future<void>);
    await t.pump(const Duration(seconds: 2));

    // ── §1 / 4d : la fête d'une capture (Chiot, +40) ──
    final ctx = t.element(find.byType(PawMapScreen));
    PawCatchCelebration.show(ctx, const PawPlushWin(points: 40, type: 'puppy'));
    await t.pump(const Duration(milliseconds: 60));
    print('[P613] FETE carte=${find.text('+40 points').evaluate().isNotEmpty} '
        'nom=${find.text('Chiot attrapé !').evaluate().isNotEmpty}');
    print('[P613] SNAP 6a-fete-confettis-vite'); await t.pump(const Duration(milliseconds: 900));
    await t.pump(const Duration(milliseconds: 600));
    await _snap(t, '6b-fete', ms: 200);
    await t.pump(const Duration(seconds: 4));
    print('[P613] FETE partie=${find.text('+40 points').evaluate().isEmpty}');
    await _snap(t, '6c-apres-fete', ms: 500);
  });
}
