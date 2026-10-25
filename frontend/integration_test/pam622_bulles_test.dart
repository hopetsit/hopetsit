// 622 (PAM, 25/10/2026) — PawMap : bulles qui se chevauchent / coupées au
// bord, et prix absents (6 captures iPhone de Daniel, app 621).
// Sonde : 4 vues (Europe, France, Paris, rue) en clair puis en sombre. À
// chaque vue, la DERNIÈRE liste de marqueurs remise à la carte est mesurée :
//   · CHEV = paires de bulles (membres, groupes, demandes, amis, Moi) dont
//     les rectangles visibles se recouvrent de plus de 12 % (même seuil que
//     la passe de collision 607) ;
//   · BORD = bulles coupées par le bord de la carte (en partie dehors) ;
//   · PRIX = épingles qui portent un prix (bulle de prix ou étiquette).
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
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_layout607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart' show PawCollapsibleBar;
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

bool _measured(String id) {
  final l = pawLayerOf(id);
  return l == PawLayer.member ||
      l == PawLayer.memberGroup ||
      l == PawLayer.request ||
      l == PawLayer.friend ||
      l == PawLayer.me;
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
    // La fenêtre SYSTÈME des notifications ne peut pas être touchée par un
    // test : pour les captures de la carte, on la saute (HPS_SKIP_PUSH).
    if (kSkipPush) PushNotificationService.skipInitForIntegrationTests = true;
    setupDependencies();
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('fr');
  });

  testWidgets('PawMap 622 — bulles : aucun chevauchement, rien de coupé, prix', (t) async {
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
    // (b) — la question « notifications » posée à l'entrée d'un gardien /
    // promeneur qui n'a jamais répondu : capturée, puis « Plus tard ».
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 500));
      if (find.text('Plus tard').evaluate().isNotEmpty) break;
    }
    if (find.text('Plus tard').evaluate().isNotEmpty) {
      say('question notifications affichee : OUI');
      await shot(t, '${kTag}_${kRole}_question_notifications');
      await t.tap(find.text('Plus tard').first);
      await t.pump(const Duration(milliseconds: 800));
    } else {
      say('question notifications affichee : non (deja repondu ?)');
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

    final views = <(String, LatLng, double)>[
      ('europe', const LatLng(49.0, 5.5), 4.6),
      ('france', const LatLng(46.7, 2.6), 5.8),
      ('paris', const LatLng(48.8566, 2.3522), 11.0),
      ('rue', const LatLng(48.8530, 2.3499), 15.5),
    ];
    final totals = <String, int>{'chev': 0, 'bord': 0};

    Future<void> measure(String name, LatLng c, double z) async {
      final mapBox = t.getRect(find.byType(GoogleMap));
      final size = mapBox.size;
      final camPx = pawMercatorPx(c.latitude, c.longitude, z);
      final placed = <PawPlaced>[];
      var prices = 0;
      for (final m in last) {
        final id = m.markerId.value;
        if (!_measured(id)) continue;
        final sz = PawMapPinCache.sizeOf(m.icon);
        if (sz == null) continue;
        final p = pawMercatorPx(m.position.latitude, m.position.longitude, z) - camPx +
            Offset(size.width / 2, size.height / 2);
        placed.add(PawPlaced(id: id, at: p, size: sz, anchor: m.anchor));
        if (PawMapScreen.debugPricedIds622.contains(id)) prices++;
      }
      final screen = Offset.zero & size;
      final onScreen = placed.where((p) => p.visible.overlaps(screen)).toList();
      final chev = <String>[];
      for (var i = 0; i < onScreen.length; i++) {
        for (var j = i + 1; j < onScreen.length; j++) {
          final a = onScreen[i].visible, b = onScreen[j].visible;
          final x = a.intersect(b);
          if (x.width <= 0 || x.height <= 0) continue;
          final small = math.min(a.width * a.height, b.height * b.width);
          final r = (x.width * x.height) / small;
          if (r > kPawOverlapTolerance) {
            chev.add('${onScreen[i].id}~${onScreen[j].id} ${(r * 100).round()}%');
          }
        }
      }
      final bord = <String>[
        for (final p in onScreen)
          if (!screen.contains(p.visible.topLeft) || !screen.contains(p.visible.bottomRight))
            p.id,
      ];
      // Bulles cachées sous le rail gauche / la capsule droite (> 12 %).
      final bars = <Rect>[
        for (final e in find.byType(PawCollapsibleBar).evaluate())
          t.getRect(find.byWidget(e.widget)).shift(-mapBox.topLeft),
      ];
      final sous = <String>[];
      for (final p in onScreen) {
        for (final b in bars) {
          final x = p.visible.intersect(b);
          if (x.width <= 0 || x.height <= 0) continue;
          if ((x.width * x.height) / (p.visible.width * p.visible.height) > kPawOverlapTolerance) {
            sous.add(p.id);
            break;
          }
        }
      }
      totals['sous'] = (totals['sous'] ?? 0) + sous.length;
      say('  sous_barre ${sous.length}');
      // Boîtes DESSINÉES (simulation de placement : rond, prénom, prix,
      // couronne — sans les marges transparentes des images) qui se touchent.
      final sim = PawMapScreen.debugLayout622;
      final ids = onScreen.map((p) => p.id).where(sim.containsKey).toList();
      var dessin = 0;
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final x = sim[ids[i]]!.intersect(sim[ids[j]]!);
          if (x.width > 0.5 && x.height > 0.5) {
            dessin++;
            say('  dessin ${ids[i]}~${ids[j]}');
          }
        }
      }
      totals['dessin'] = (totals['dessin'] ?? 0) + dessin;
      say('  CHEV_DESSIN $dessin');
      totals['chev'] = totals['chev']! + chev.length;
      totals['bord'] = totals['bord']! + bord.length;
      say('MESURE $kTag $name z=$z bulles=${onScreen.length} CHEV=${chev.length} '
          'BORD=${bord.length} PRIX=$prices');
      for (final s in chev.take(12)) {
        say('  chev $s');
        for (final id in s.split(' ').first.split('~')) {
          final sim = PawMapScreen.debugLayout622[id];
          final real = placed.where((p) => p.id == id).map((p) => p.visible).firstOrNull;
          final realRel = real?.shift(-Offset(size.width / 2, size.height / 2));
          say('     $id sim=$sim reel=$realRel');
        }
      }
      for (final s in bord.take(12)) {
        say('  bord $s');
      }
    }

    LatLng? rueAt;
    for (final dark in const [false, true]) {
      await theme.setMode(dark ? ThemeMode.dark : ThemeMode.light);
      await t.pump(const Duration(seconds: 2));
      final mode = dark ? 'sombre' : 'clair';
      for (var v in views) {
        if (v.$1 == 'rue') {
          // Vue « rue » centrée sur la 1re demande visible (chargée à Paris).
          rueAt ??= PawMapScreen.debugFirstRequestPos622?.call();
          if (rueAt != null) v = ('rue', rueAt!, 15.5);
          say('rue = ${v.$2.latitude.toStringAsFixed(3)},${v.$2.longitude.toStringAsFixed(3)}');
        }
        await ctl!.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: v.$2, zoom: v.$3)));
        // Couche monde + demandes chargées, épingles posées au zoom d'arrêt.
        await t.pump(const Duration(seconds: 7));
        await measure('${v.$1}_$mode', v.$2, v.$3);
        await shot(t, '${kTag}_${kRole}_${v.$1}_$mode');
      }
    }
    // Fiche courte puis feuille du bas d'une demande (gardien / promeneur).
    final reqTap = PawMapScreen.debugRequestTap622;
    if (reqTap != null && (kRole == 'sitter' || kRole == 'walker')) {
      await theme.setMode(ThemeMode.light);
      final ok = await reqTap(false);
      say('fiche courte d\'une demande : ${ok ?? 'aucune'}');
      if (ok != null) {
        await t.pump(const Duration(seconds: 4));
        await shot(t, '${kTag}_${kRole}_demande_fiche_courte');
        await reqTap(true);
        await t.pump(const Duration(seconds: 4));
        await shot(t, '${kTag}_${kRole}_demande_feuille');
      }
    }
    PawMapScreen.debugMarkersTap616 = null;
    await theme.setMode(ThemeMode.light);
    say('TOTAL $kTag CHEV=${totals['chev']} BORD=${totals['bord']} SOUS_BARRE=${totals['sous']} CHEV_DESSIN=${totals['dessin']}');
    say('06 fin');
  });
}
