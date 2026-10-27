// 626 (PAM, 27/10/2026) — bug de Daniel : « le zoom dézoom bug, des fois ça
// apparaît les groupes d'autres fois pas, après ça ouvre les gens dans l'eau ».
// Sonde (même fichier pour la 625 « avant » et la 626 « après », n'utilise que
// des crochets présents dans les deux) :
//   · STABILITÉ : Europe, Nord-Est USA, Paris atteints par 2 chemins (zoom
//     avant depuis plus loin / dézoom depuis une autre zone) → mêmes groupes ?
//     + même vue à +0,3 de zoom (pincement) ;
//   · TOUCHER le plus gros groupe du Nord-Est dézoomé : zoom d'arrivée,
//     ronds « éclatés » (spider_), masqués, glissement max.
// Compte de test par --dart-define (jamais écrit ici), simulateur en ZONE TEST.

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
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'sitter');
const String kTag = String.fromEnvironment('HPS_TAG', defaultValue: 'apres');
const bool kSkipPush = bool.fromEnvironment('HPS_SKIP_PUSH');

void say(String s) => debugPrint('[PARCOURS] $s');

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 900));
  debugPrint('[SHOT] $name');
  await t.pump(const Duration(milliseconds: 2600));
}


bool _member(String id) => id.startsWith('mcluster_') || id.startsWith('nearby_') || id.startsWith('spider_');

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
    setupDependencies();
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('fr');
  });

  testWidgets('PawMap 626 — zoom / dézoom stable, toucher un groupe', (t) async {
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
    await theme.setMode(ThemeMode.light);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 500));
      if (find.text('Plus tard').evaluate().isNotEmpty) break;
    }
    if (find.text('Plus tard').evaluate().isNotEmpty) {
      await t.tap(find.text('Plus tard').first);
      await t.pump(const Duration(milliseconds: 800));
    }
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
    final ctl = PawMapScreen.debugMapController616;
    expect(ctl, isNotNull);
    Set<Marker> last = <Marker>{};
    PawMapScreen.debugMarkersTap616 = (m) => last = Set.of(m);

    Future<void> go(LatLng c, double z, {int ms = 2500, bool animate = false}) async {
      final u = CameraUpdate.newCameraPosition(CameraPosition(target: c, zoom: z));
      if (animate) {
        await ctl!.animateCamera(u);
      } else {
        await ctl!.moveCamera(u);
      }
      await t.pump(Duration(milliseconds: ms));
    }

    // Groupes de membres VISIBLES à l'écran : « id(effectif) » triés.
    Future<List<String>> visible(LatLng c, double z) async {
      final size = t.getRect(find.byType(GoogleMap)).size;
      final scr = Offset.zero & size;
      final cam = pawMercatorPx(c.latitude, c.longitude, z);
      final out = <String>[];
      for (final m in last) {
        final id = m.markerId.value;
        if (!_member(id)) continue;
        final p = pawMercatorPx(m.position.latitude, m.position.longitude, z) - cam +
            Offset(size.width / 2, size.height / 2);
        if (!scr.contains(p)) continue;
        final n = PawMapScreen.debugCluster2610[id];
        out.add(n == null ? id : '$id($n)');
      }
      out.sort();
      return out;
    }

    String sizes(List<String> v) {
      final n = <int>[
        for (final s in v)
          s.contains('(') ? int.parse(s.substring(s.indexOf('(') + 1, s.length - 1)) : 1,
      ]..sort((a, b) => b.compareTo(a));
      return '[${n.join(',')}]';
    }

    final views = <(String, LatLng, double, LatLng)>[
      ('europe', const LatLng(48.5, 4.0), 4.6, const LatLng(37.8, -1.4)),
      ('nordest_usa', const LatLng(41.5, -73.0), 5.3, const LatLng(32.78, -96.8)),
      ('paris', const LatLng(48.8566, 2.3522), 10.4, const LatLng(45.76, 4.83)),
    ];
    var diff = 0;
    for (final v in views) {
      // Chemin A : on arrive en zoomant depuis plus loin.
      await go(v.$2, v.$3 - 2, ms: 5000);
      await go(v.$2, v.$3 - 1, ms: 1500, animate: true);
      await go(v.$2, v.$3, ms: 7000, animate: true);
      final a = await visible(v.$2, v.$3);
      await shot(t, '${kTag}_${v.$1}_cheminA');
      // Chemin B : on passe par une autre zone, très zoomé, puis on dézoome.
      await go(v.$4, v.$3 + 3, ms: 5000);
      await go(v.$2, v.$3 + 2, ms: 2500, animate: true);
      await go(v.$2, v.$3, ms: 7000, animate: true);
      final b = await visible(v.$2, v.$3);
      await shot(t, '${kTag}_${v.$1}_cheminB');
      // Même vue, pincement de +0,3.
      await go(v.$2, v.$3 + 0.3, ms: 4000, animate: true);
      final c = await visible(v.$2, v.$3 + 0.3);
      final same = a.length == b.length && a.toSet().containsAll(b);
      if (!same) diff++;
      say('STABLE626 $kTag ${v.$1} z=${v.$3} A=${sizes(a)} B=${sizes(b)} memes_groupes=${same ? 'OUI' : 'NON'} | z+0.3=${sizes(c)} memes_groupes_que_z=${a.toSet().containsAll(c) ? 'OUI' : 'NON'}');
    }
    say('TOTAL_STABLE626 $kTag vues_differentes=$diff/3');

    // Toucher le plus gros groupe du Nord-Est des USA, dézoomé (capture daniel_1).
    final ne = views[1];
    await go(ne.$2, ne.$3, ms: 7000);
    await shot(t, '${kTag}_nordest_avant_toucher');
    Marker? big;
    var bigN = 0;
    final onScr = (await visible(ne.$2, ne.$3)).map((s) => s.split('(').first).toSet();
    for (final m in last) {
      final n = PawMapScreen.debugCluster2610[m.markerId.value] ?? 0;
      if (m.markerId.value.startsWith('mcluster_') && onScr.contains(m.markerId.value) && n > bigN) {
        big = m;
        bigN = n;
      }
    }
    say('TOUCHER626 $kTag groupe=$bigN zoom_depart=${await ctl!.getZoomLevel()}');
    if (big != null) {
      big.onTap?.call();
      await t.pump(const Duration(seconds: 6));
      final z1 = await ctl.getZoomLevel();
      final vr = await ctl.getVisibleRegion();
      final c1 = LatLng((vr.northeast.latitude + vr.southwest.latitude) / 2,
          (vr.northeast.longitude + vr.southwest.longitude) / 2);
      final vis = await visible(c1, z1);
      final spiders = last.where((m) => m.markerId.value.startsWith('spider_')).length;
      var gapMax = 0.0;
      PawMapScreen.debugGap625.forEach((k, g) {
        if (g > gapMax) gapMax = g;
      });
      say('TOUCHER626 $kTag zoom_arrivee=${z1.toStringAsFixed(2)} ronds_visibles=${sizes(vis)} '
          'eclates_anneau=$spiders masques=${PawMapScreen.debugHidden625} glissement_max=${gapMax.toStringAsFixed(1)}pt '
          'groupe_de_$bigN encore affiche=${vis.any((v) => v.endsWith('($bigN)')) ? 'OUI' : 'NON'}');
      await shot(t, '${kTag}_nordest_apres_toucher');
    }
    PawMapScreen.debugMarkersTap616 = null;
    await go(const LatLng(-49.35, 70.22), 11, ms: 3000);
    say('06 fin');
  });
}
