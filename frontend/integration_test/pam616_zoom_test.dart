// 616 (PAM, 15/10/2026) — PawMap : 3 pincements RAPIDES d'affilée (zoom puis
// dézoom) sur l'Europe avec la couche monde chargée, et à CHAQUE image :
//   · aucune personne (membre, ami, Moi) ne change de position ;
//   · aucune ancre aberrante (décalage > 4 images = épingle « ailleurs ») ;
//   · les ronds de groupe suivent le zoom (recalculés à ≤ 0,5 niveau près,
//     au plus toutes les 120 ms) : écart entre deux ronds jamais inférieur à
//     l'écart minimal du regroupement compte tenu du retard autorisé ;
//   · au repos : aucun rond à moins de 50 px d'un autre (jamais deux ronds
//     l'un sur l'autre).
// Le compte de test arrive par --dart-define (jamais écrit ici), le
// simulateur est en ZONE TEST (lat −35 / lng −30). Lancé par
// ~/hopetsit-social/preuves/pam/build_616/run_zoom.sh, qui prend des captures
// de l'extérieur pendant les pincements.
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_zoom616.dart';
import 'package:integration_test/integration_test.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'owner');

Future<void> _step(WidgetTester tester, String name,
    {Duration hold = const Duration(seconds: 2)}) async {
  debugPrint('[PARCOURS] ${DateTime.now().toIso8601String()} $name');
  await tester.pump(hold);
}

class _Frame {
  _Frame(this.at, this.markers);
  final DateTime at;
  final Set<Marker> markers;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    // Le journal API (`[HOPETSIT] … Response Body` : la couche monde entière)
    // noyait la sortie et `debugPrint` la BRIDE (12 Ko/s) : l'exception d'un
    // échec n'arrivait jamais. Ici : journal API coupé, sortie SYNCHRONE.
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null || message.startsWith('[HOPETSIT]')) return;
      debugPrintSynchronously(message, wrapWidth: wrapWidth);
    };
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('[PARCOURS] Firebase : $e');
    }
    setupDependencies();
  });

  testWidgets('PawMap 616 — 3 pincements rapides : aucun rond ni épingle fantôme',
      (tester) async {
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr', 'FR'),
        fallbackLocale: const Locale('en', 'US'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    ));
    await _step(tester, '00 demarrage', hold: const Duration(seconds: 1));

    // ── Connexion réelle (compte de test, zone test) ──
    if (kEmail.isNotEmpty && kPassword.isNotEmpty) {
      final auth = Get.find<AuthController>();
      auth.emailController.text = kEmail;
      auth.passwordController.text = kPassword;
      final logged =
          await auth.login(preferredRole: kRole, skipFormValidation: true);
      debugPrint('[PARCOURS] connexion $kRole : ${logged ? 'OK' : 'ECHEC'}');
      expect(logged, isTrue, reason: 'connexion du compte de test');
      await tester.pump(const Duration(seconds: 1));
    } else {
      debugPrint('[PARCOURS] sans compte (HPS_EMAIL absent) : couche monde vide');
    }

    Get.offAll(() => const PawMapScreen());
    await _step(tester, '01 ouverture de la carte', hold: const Duration(seconds: 4));
    for (var i = 0; i < 60; i++) {
      if (find.byKey(const ValueKey<String>('rail_around')).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(seconds: 1));
    }
    for (var i = 0; i < 3; i++) {
      final next = find.byKey(const ValueKey<String>('coach_next'));
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 900));
    }
    expect(find.byType(GoogleMap), findsOneWidget, reason: 'UNE seule GoogleMap');
    final ctl = PawMapScreen.debugMapController616;
    expect(ctl, isNotNull, reason: 'contrôleur de carte (crochet 616)');

    // ── Europe au zoom pays : la couche monde regroupe les membres ──
    await ctl!.moveCamera(CameraUpdate.newCameraPosition(
        const CameraPosition(target: LatLng(46.5, 4.0), zoom: 4.5)));
    await _step(tester, '02 europe zoom 4.5 (chargement)', hold: const Duration(seconds: 6));

    final frames = <_Frame>[];
    PawMapScreen.debugMarkersTap616 = (m) => frames.add(_Frame(DateTime.now(), Set.of(m)));
    // Première image de référence.
    await tester.pump(const Duration(milliseconds: 300));
    int clustersOf(Set<Marker> m) =>
        m.where((k) => k.markerId.value.startsWith('mcluster_')).length;
    int personsOf(Set<Marker> m) => m
        .where((k) =>
            k.markerId.value.startsWith('nearby_') ||
            k.markerId.value.startsWith('friend_'))
        .length;
    final Set<Marker> start = frames.isEmpty ? <Marker>{} : frames.last.markers;
    debugPrint('[PARCOURS] depart : marqueurs=${start.length} ronds=${clustersOf(start)} '
        'personnes=${personsOf(start)}');
    expect(clustersOf(start) + personsOf(start), greaterThan(0),
        reason: 'des membres sont posés sur la carte (couche monde)');

    final violations = <String>[];
    var maxBuildUs = 0;
    var maxLag = 0.0;
    var clusterIdChurn = 0;
    var framesSeen = 0;
    Map<String, LatLng> lastPersons = {};
    Set<String> lastClusterIds = {};

    Future<void> check(double zoom, String phase) async {
      if (frames.isEmpty) return;
      final f = frames.last;
      framesSeen++;
      maxBuildUs = math.max(maxBuildUs, PawMapScreen.debugLastBuildUs616);
      final persons = <String, LatLng>{
        for (final m in f.markers)
          if (m.markerId.value.startsWith('nearby_') ||
              m.markerId.value.startsWith('friend_') ||
              m.markerId.value == 'me')
            m.markerId.value: m.position,
      };
      for (final id in pawMovedPersonIds616(lastPersons, persons)) {
        violations.add('$phase z=$zoom : $id a changé de position '
            '${lastPersons[id]} → ${persons[id]}');
      }
      lastPersons = persons;
      for (final m in f.markers) {
        final a = m.anchor;
        if ((a.dx - 0.5).abs() > 4 || (a.dy - 0.5).abs() > 4) {
          violations.add('$phase z=$zoom : ancre aberrante ${m.markerId.value} $a');
        }
      }
      final clusters = f.markers
          .where((m) => m.markerId.value.startsWith('mcluster_'))
          .toList();
      final ids = clusters.map((m) => m.markerId.value).toSet();
      clusterIdChurn += ids.difference(lastClusterIds).length +
          lastClusterIds.difference(ids).length;
      lastClusterIds = ids;
      // Écart minimal entre deux ronds au zoom COURANT.
      var minPx = double.infinity;
      for (var i = 0; i < clusters.length; i++) {
        final a = pawMercatorPx(clusters[i].position.latitude,
            clusters[i].position.longitude, zoom);
        for (var j = i + 1; j < clusters.length; j++) {
          final b = pawMercatorPx(clusters[j].position.latitude,
              clusters[j].position.longitude, zoom);
          minPx = math.min(minPx, (a - b).distance);
        }
      }
      if (minPx.isFinite && minPx > 0) {
        // Retard de zoom équivalent : les ronds ont été calculés avec
        // ≥ 50 px d'écart à leur zoom ; à `zoom`, l'écart vaut 50·2^(zoom−zc).
        final lag = math.log(kPawGroupMinPx / minPx) / math.ln2;
        maxLag = math.max(maxLag, lag);
        if (phase == 'repos' && minPx < kPawGroupMinPx - 1) {
          violations.add('repos z=$zoom : deux ronds à ${minPx.toStringAsFixed(1)} px');
        }
      }
    }

    // ── 3 pincements rapides : 4,5 → 12,5 → 4,5, 16 pas de 0,5 par sens, 35 ms par pas ──
    for (var cycle = 1; cycle <= 3; cycle++) {
      debugPrint('[PARCOURS] ${DateTime.now().toIso8601String()} 03 zoom-start cycle $cycle');
      for (var z = 5.0; z <= 12.5; z += 0.5) {
        await ctl.moveCamera(CameraUpdate.zoomTo(z));
        await tester.pump(const Duration(milliseconds: 35));
        await check(z, 'zoom$cycle');
      }
      for (var z = 12.0; z >= 4.5; z -= 0.5) {
        await ctl.moveCamera(CameraUpdate.zoomTo(z));
        await tester.pump(const Duration(milliseconds: 35));
        await check(z, 'dezoom$cycle');
      }
      debugPrint('[PARCOURS] ${DateTime.now().toIso8601String()} 04 zoom-end cycle $cycle');
      await tester.pump(const Duration(milliseconds: 150)); // enchaînement rapide
    }
    await _step(tester, '05 repos apres les 3 pincements', hold: const Duration(seconds: 2));
    await check(4.5, 'repos');
    await _step(tester, '06 fin', hold: const Duration(seconds: 1));
    PawMapScreen.debugMarkersTap616 = null;

    debugPrint('[PARCOURS] images=$framesSeen listes=${frames.length} '
        'construction max=${(maxBuildUs / 1000).toStringAsFixed(1)} ms '
        'retard max=${maxLag.toStringAsFixed(2)} niveau(x) '
        'ronds crees+retires=$clusterIdChurn violations=${violations.length}');
    for (final v in violations) {
      debugPrint('[PARCOURS] VIOLATION $v');
    }
    expect(violations, isEmpty);
    // Retard de regroupement toléré pendant un geste aussi rapide (16 niveaux
    // par seconde, recalcul au plus toutes les 120 ms) : < 2,5 niveaux.
    expect(maxLag, lessThan(2.5), reason: 'les ronds suivent le zoom');
  });
}
