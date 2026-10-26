// 623 (PAM, 26/10/2026) — maquette de Daniel « Améliorer boutons et profil
// PawMap ». Parcours au simulateur, pour UN rôle (HPS_ROLE), clair puis
// sombre (thème sombre + carte de nuit) :
//   · vue Paris : AUCUN prix posé par défaut (PRIX=0) ;
//   · toucher un profil 1 rôle : zoom +2 centré + bulle (segments selon
//     visiblePrices) ; re-toucher : bulle masquée + caméra remise ;
//   · profils 2 et 3 rôles : rond + pastilles, bulle ;
//   · bulle près des bords gauche / droit (corps dans l'écran) ;
//   · groupe : éclatement (6 sur 72, le reste sur 132) + « dès X », puis un
//     profil du groupe touché, puis toucher le vide = tout se referme.
// Captures par l'hôte (ligne « [SHOT] nom »). Compte de test par
// --dart-define (jamais écrit ici), simulateur en ZONE TEST.
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
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/meta_events_service.dart';
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart' show openPawMap;
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/map/widgets/pawmap_ring2610.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'sitter');
const String kTag = String.fromEnvironment('HPS_TAG', defaultValue: 'pam623');
const bool kSkipPush = bool.fromEnvironment('HPS_SKIP_PUSH');

void say(String s) => debugPrint('[PARCOURS] $s');

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 900));
  debugPrint('[SHOT] ${kTag}_${kRole}_$name');
  await t.pump(const Duration(milliseconds: 2600));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null || message.startsWith('[HOPETSIT]')) return;
      // ignore: avoid_print
      print(message);
    };
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      say('Firebase : $e');
    }
    if (kSkipPush) PushNotificationService.skipInitForIntegrationTests = true;
    // Fenêtre système « suivi publicitaire » : jamais touchée par un test.
    MetaEventsService.skipTrackingPromptForTests = true;
    setupDependencies();
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('fr');
  });

  testWidgets('PawMap 623 — maquette 26/10', (t) async {
    final theme = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : Get.put<ThemeController>(ThemeController(), permanent: true);
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => Obx(() => GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('fr', 'FR'),
            fallbackLocale: const Locale('en', 'US'),
            debugShowCheckedModeBanner: false,
            themeMode: theme.themeMode.value,
            theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
            darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: const Scaffold(body: SizedBox.expand()),
          )),
    ));
    await t.pump(const Duration(seconds: 1));
    expect(kEmail, isNotEmpty, reason: 'HPS_EMAIL manquant');
    final auth = Get.find<AuthController>();
    auth.emailController.text = kEmail;
    auth.passwordController.text = kPassword;
    final logged = await auth.login(preferredRole: kRole, skipFormValidation: true);
    say('connexion $kRole : ${logged ? 'OK' : 'ECHEC'}');
    expect(logged, isTrue);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 500));
      if (find.text('Plus tard').evaluate().isNotEmpty) {
        await t.tap(find.text('Plus tard').first);
        await t.pump(const Duration(milliseconds: 800));
        break;
      }
    }

    Set<Marker> last = <Marker>{};
    var fails = 0;
    void check(bool ok, String what) {
      say('${ok ? 'OK ' : 'KO '} $what');
      if (!ok) fails++;
    }

    Future<GoogleMapController> openMap({required bool dark}) async {
      await GetStorage().write('pawmap_night_mode', dark);
      await theme.setMode(dark ? ThemeMode.dark : ThemeMode.light);
      // La carte d'un écran précédent (menu monté à la connexion) ne doit
      // pas être pilotée à la place de celle-ci : contrôleur remis à zéro.
      PawMapScreen.debugMapController616 = null;
      Get.offAll(() => const PawMapScreen());
      await t.pump(const Duration(seconds: 4));
      for (var i = 0; i < 60; i++) {
        if (find.byKey(const ValueKey<String>('rail_around')).evaluate().isNotEmpty) break;
        await t.pump(const Duration(seconds: 1));
      }
      for (final k in const ['coach_close', 'pawmap_announce_close', 'coach_next']) {
        for (var i = 0; i < 3; i++) {
          final f = find.byKey(ValueKey<String>(k));
          if (f.evaluate().isEmpty) break;
          await t.tap(f.first);
          await t.pump(const Duration(milliseconds: 900));
        }
      }
      PawMapScreen.debugMarkersTap616 = (m) => last = Set.of(m);
      for (var i = 0; i < 20 && PawMapScreen.debugMapController616 == null; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      await t.pump(const Duration(seconds: 3));
      final ctl = PawMapScreen.debugMapController616;
      expect(ctl, isNotNull);
      // Carte de nuit (préférence du compte de test, remise à la fin).
      PawMapScreen.debugNight2610?.call(dark);
      await t.pump(const Duration(seconds: 2));
      return ctl!;
    }

    Future<LatLng> center(GoogleMapController ctl) async {
      final r = await ctl.getVisibleRegion();
      return LatLng((r.northeast.latitude + r.southwest.latitude) / 2,
          (r.northeast.longitude + r.southwest.longitude) / 2);
    }

    int pricedOnMap() => last
        .where((m) =>
            m.markerId.value != 'bub2610' &&
            PawMapScreen.debugPricedIds622.contains(m.markerId.value))
        .length;

    bool hasBubble() => last.any((m) => m.markerId.value == 'bub2610');

    Marker? pick(bool Function(Marker m) ok, LatLng c) {
      Marker? best;
      double bd = 1e9;
      for (final m in last) {
        if (!ok(m)) continue;
        final d = math.pow(m.position.latitude - c.latitude, 2) +
            math.pow(m.position.longitude - c.longitude, 2);
        if (d < bd) {
          bd = d.toDouble();
          best = m;
        }
      }
      return best;
    }

    Future<void> tapEmpty() async {
      final gm = t.widget<GoogleMap>(find.byType(GoogleMap));
      gm.onTap?.call(const LatLng(0, 0));
      await t.pump(const Duration(seconds: 3));
    }

    // Un profil : toucher → zoom +2 centré + bulle ; re-toucher → remis.
    Future<void> focusCase(GoogleMapController ctl, String name, int nRoles, String mode) async {
      const paris = LatLng(48.8566, 2.3522);
      await ctl.moveCamera(CameraUpdate.newCameraPosition(const CameraPosition(target: paris, zoom: 11.5)));
      await t.pump(const Duration(seconds: 6));
      final m = pick(
          (m) =>
              m.markerId.value.startsWith('nearby_') &&
              (PawMapScreen.debugRoles2610[m.markerId.value]?.length ?? 0) == nRoles,
          paris);
      if (m == null) {
        say('NON EXÉCUTÉ $name : aucun profil à $nRoles rôle(s) dans la zone');
        return;
      }
      final roles = PawMapScreen.debugRoles2610[m.markerId.value];
      final z0 = await ctl.getZoomLevel();
      final c0 = await center(ctl);
      m.onTap!();
      await t.pump(const Duration(seconds: 4));
      final z1 = await ctl.getZoomLevel();
      final c1 = await center(ctl);
      final off = math.sqrt(math.pow(c1.latitude - m.position.latitude, 2) +
          math.pow(c1.longitude - m.position.longitude, 2));
      check((z1 - z0 - 2).abs() < 0.05, '$name $mode zoom ${z0.toStringAsFixed(2)} → ${z1.toStringAsFixed(2)} (+2) roles=$roles');
      check(off < 0.0005, '$name $mode centré sur le profil (écart ${off.toStringAsFixed(6)}°)');
      final expectPrices = PawMapScreen.debugBubble2610;
      say('  bulle=${hasBubble()} segments=$expectPrices');
      for (final s in expectPrices) {
        final r = s.split(':').first;
        final ok = kRole == 'owner' ? (r == 'sitter' || r == 'walker') : r == 'owner';
        check(ok, '$name $mode segment $s conforme à visiblePrices pour $kRole');
      }
      // Clignotement (Daniel 26/10) : après l'animation, plus AUCUNE
      // reconstruction ni nouvelle image du rond sélectionné / de sa bulle.
      await t.pump(const Duration(seconds: 2));
      final b0 = PawMapScreen.debugBuilds2610;
      BitmapDescriptor? iconOf(String id) =>
          last.where((x) => x.markerId.value == id).map((x) => x.icon).firstOrNull;
      final sel0 = iconOf(m.markerId.value), bub0 = iconOf('bub2610');
      for (var k = 0; k < 6; k++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      final rebuilt = PawMapScreen.debugBuilds2610 - b0;
      check(rebuilt == 0 && identical(sel0, iconOf(m.markerId.value)) && identical(bub0, iconOf('bub2610')),
          '$name $mode net : $rebuilt reconstruction(s) en 3 s après l\'animation, image du rond ${identical(sel0, iconOf(m.markerId.value)) ? 'inchangée' : 'CHANGÉE'}, bulle ${identical(bub0, iconOf('bub2610')) ? 'inchangée' : 'CHANGÉE'}');
      await shot(t, '${name}_$mode');
      // Bulle au bord : la carte glisse pour poser le rond à 40 px du bord.
      if (hasBubble() && nRoles >= 1 && mode == 'clair' && name == 'profil_${nRoles}r') {
        final size = t.getSize(find.byType(GoogleMap));
        final dpr = t.view.devicePixelRatio;
        for (final side in const ['gauche', 'droite']) {
          final target = side == 'gauche' ? 108.0 : size.width - 100.0; // rond entier, juste à côté de la barre / capsule
          for (var k = 0; k < 2; k++) {
            final sc = await ctl.getScreenCoordinate(m.position);
            final sx = (sc.x > size.width * 1.2) ? sc.x / dpr : sc.x.toDouble();
            await ctl.moveCamera(CameraUpdate.scrollBy(sx - target, 0));
            await t.pump(const Duration(milliseconds: 600));
          }
          await t.pump(const Duration(seconds: 4));
          final sc = await ctl.getScreenCoordinate(m.position);
          final sx = (sc.x > size.width * 1.2) ? sc.x / dpr : sc.x.toDouble();
          say('  rond à x=${sx.toStringAsFixed(0)} / ${size.width.toStringAsFixed(0)}');
          check(hasBubble(), '$name bulle toujours posée, rond au bord $side');
          await shot(t, '${name}_bord_$side');
        }
      }
      // Re-toucher le même profil : bulle masquée, caméra remise.
      final again = last.firstWhere((x) => x.markerId == m.markerId, orElse: () => m);
      again.onTap!();
      await t.pump(const Duration(seconds: 4));
      final z2 = await ctl.getZoomLevel();
      final c2 = await center(ctl);
      final back = math.sqrt(math.pow(c2.latitude - c0.latitude, 2) + math.pow(c2.longitude - c0.longitude, 2));
      check(!hasBubble(), '$name $mode 2e toucher : bulle masquée');
      check((z2 - z0).abs() < 0.05 && back < 0.0005,
          '$name $mode 2e toucher : caméra remise (zoom ${z2.toStringAsFixed(2)}, écart ${back.toStringAsFixed(6)}°)');
    }

    for (final dark in const [false, true]) {
      final mode = dark ? 'sombre' : 'clair';
      final ctl = await openMap(dark: dark);
      // 1. Vues sans prix.
      for (final v in const <(String, LatLng, double)>[
        ('france', LatLng(46.7, 2.6), 5.8),
        ('paris', LatLng(48.8566, 2.3522), 11.0),
      ]) {
        await ctl.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: v.$2, zoom: v.$3)));
        await t.pump(const Duration(seconds: 7));
        final n = pricedOnMap();
        check(n == 0 && !hasBubble(), 'vue ${v.$1} $mode : aucun prix posé (PRIX=$n)');
        final rings = last.where((m) => PawMapScreen.debugRoles2610.containsKey(m.markerId.value)).length;
        final groups = last.where((m) => m.markerId.value.startsWith('mcluster_')).length;
        say('  ronds=$rings groupes=$groups');
        await shot(t, '${v.$1}_$mode');
      }
      // 2. Profils 1, 2, 3 rôles.
      await focusCase(ctl, 'profil_1r', 1, mode);
      await focusCase(ctl, 'profil_2r', 2, mode);
      await focusCase(ctl, 'profil_3r', 3, mode);
      // 2 ter. Signes gardés (Daniel 26/10) : un rond par signe, touché.
      if (!dark) {
        for (final z in const [11.0, 9.0]) {
          await ctl.moveCamera(CameraUpdate.newCameraPosition(
              CameraPosition(target: const LatLng(48.8566, 2.3522), zoom: z)));
          await t.pump(const Duration(seconds: 6));
          final seen = <String>{};
          for (final sign in const ['couronne', 'pawboost', 'verifie', 'en_ligne', 'hors_ligne', 'podium']) {
            final m = pick(
                (m) => (PawMapScreen.debugSigns2610[m.markerId.value] ?? const <String>{}).contains(sign) &&
                    last.any((x) => x.markerId == m.markerId),
                const LatLng(48.8566, 2.3522));
            if (m == null) continue;
            seen.add(sign);
            m.onTap!();
            await t.pump(const Duration(seconds: 4));
            say('  signe $sign : ${m.markerId.value} signes=${PawMapScreen.debugSigns2610[m.markerId.value]}');
            await shot(t, 'signe_${sign}_z${z.toInt()}');
            await tapEmpty();
            await ctl.moveCamera(CameraUpdate.newCameraPosition(
                CameraPosition(target: const LatLng(48.8566, 2.3522), zoom: z)));
            await t.pump(const Duration(seconds: 5));
          }
          say('  signes présents (zoom $z) : $seen');
        }
        // Légende « ? » (mêmes peintres que la carte).
        final legend = find.byKey(const ValueKey<String>('pawmap_header_legend'));
        if (legend.evaluate().isNotEmpty) {
          await t.tap(legend.first);
          await t.pump(const Duration(seconds: 3));
          await shot(t, 'legende_1');
          for (final k in const ['legend_member_owner', 'legend_duo2709', 'legend_boost', 'legend_verified']) {
            final f = find.byKey(ValueKey<String>(k));
            try {
              await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first, maxScrolls: 60);
              await t.pump(const Duration(seconds: 1));
              await shot(t, 'legende_$k');
            } catch (e) {
              say('NON EXÉCUTÉ légende $k : $e');
            }
          }
          final nav = Get.key.currentState;
          if (nav != null && nav.canPop()) nav.pop();
          await t.pump(const Duration(seconds: 3));
        }
      }
      // 2 bis. Gardien / promeneur : toucher une demande = bulle du budget.
      if (kRole != 'owner') {
        await ctl.moveCamera(CameraUpdate.newCameraPosition(
            const CameraPosition(target: LatLng(48.8566, 2.3522), zoom: 11.5)));
        await t.pump(const Duration(seconds: 6));
        final reqs = last.where((m) => m.markerId.value.startsWith('req_') && !m.markerId.value.startsWith('req_g_')).toList();
        say('  demandes seules visibles : ${reqs.length}');
        var shown = 0;
        for (final r in reqs.take(6)) {
          r.onTap!();
          await t.pump(const Duration(seconds: 4));
          final segs = PawMapScreen.debugBubble2610;
          say('  demande ${r.markerId.value} : bulle=${hasBubble()} segments=$segs');
          if (hasBubble()) {
            shown++;
            check(segs.every((x) => x.startsWith('owner:')), 'demande $mode : bulle = budget du propriétaire');
            if (shown == 1) await shot(t, 'demande_budget_$mode');
          }
          await tapEmpty();
          if (shown >= 1) break;
        }
        if (shown == 0) say('NON EXÉCUTÉ demande $mode : aucune des demandes touchées n\'a de budget');
      }
      // 3. Groupe : éclatement.
      Marker? g;
      for (final z in const [10.0, 9.0, 8.0, 7.0]) {
        await ctl.moveCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: const LatLng(48.8566, 2.3522), zoom: z)));
        await t.pump(const Duration(seconds: 6));
        g = pick(
            (m) =>
                m.markerId.value.startsWith('mcluster_') &&
                (PawMapScreen.debugCluster2610[m.markerId.value] ?? 99) <= kSpiderMax2610 &&
                (PawMapScreen.debugCluster2610[m.markerId.value] ?? 0) >= 2,
            const LatLng(48.8566, 2.3522));
        if (g != null) break;
      }
      if (g == null) {
        say('NON EXÉCUTÉ éclatement $mode : aucun groupe de 2 à $kSpiderMax2610 profils');
      } else {
        final n = PawMapScreen.debugCluster2610[g.markerId.value]!;
        final z0 = await ctl.getZoomLevel();
        g.onTap!();
        await t.pump(const Duration(seconds: 4));
        final z1 = await ctl.getZoomLevel();
        final kids = last.where((m) => m.markerId.value.startsWith('spider_')).toList();
        check((z1 - z0 - 1.5).abs() < 0.05, 'groupe $mode zoom ${z0.toStringAsFixed(2)} → ${z1.toStringAsFixed(2)} (+1,5)');
        check(kids.length == n, 'groupe $mode éclaté : $n profils posés (${kids.length})');
        final fan = pawSpiderfy2610(n);
        check(fan.take(6).every((o) => (o.distance - 72).abs() < 0.1), 'groupe $mode : 6 premiers sur 72 pt');
        await shot(t, 'eclatement_$mode');
        if (kids.isNotEmpty) {
          kids.first.onTap!();
          await t.pump(const Duration(seconds: 3));
          final z2 = await ctl.getZoomLevel();
          check((z2 - z1).abs() < 0.05, 'profil du groupe $mode : caméra immobile');
          say('  bulle=${hasBubble()} segments=${PawMapScreen.debugBubble2610}');
          await shot(t, 'eclatement_profil_$mode');
        }
        await tapEmpty();
        final z3 = await ctl.getZoomLevel();
        check(!last.any((m) => m.markerId.value.startsWith('spider_')) && !hasBubble(),
            'toucher le vide $mode : groupe refermé, bulle masquée');
        check((z3 - z0).abs() < 0.05, 'toucher le vide $mode : caméra remise (${z3.toStringAsFixed(2)})');
      }
    }
    // Propriétaire : les 4 boutons ET le menu du bas sur la même image
    // (Daniel 26/10 : même orange que le menu).
    if (kRole == 'owner') {
      for (final dark in const [false, true]) {
        await theme.setMode(dark ? ThemeMode.dark : ThemeMode.light);
        Get.offAll(() => const BottomNavWrapper());
        await t.pump(const Duration(seconds: 5));
        openPawMap();
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(seconds: 1));
          if (find.byKey(const ValueKey<String>('pawmap_header_legend')).evaluate().isNotEmpty) break;
        }
        await t.pump(const Duration(seconds: 3));
        PawMapScreen.debugNight2610?.call(dark);
        await t.pump(const Duration(seconds: 4));
        await shot(t, 'menu_et_boutons_${dark ? 'sombre' : 'clair'}');
      }
    }
    PawMapScreen.debugNight2610?.call(false);
    await t.pump(const Duration(seconds: 2));
    PawMapScreen.debugMarkersTap616 = null;
    await GetStorage().write('pawmap_night_mode', false);
    await theme.setMode(ThemeMode.light);
    say('TOTAL $kTag $kRole KO=$fails');
    say('06 fin');
  });
}
