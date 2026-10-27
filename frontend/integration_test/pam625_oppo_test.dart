// 625 (PAM, 27/10/2026) — Oppo / ColorOS (téléphone du frère de Daniel) :
//   a) le rond « Moi » n'est pas dessiné ;
//   b) des groupes « carrés blancs » (39, 10, 99+, 20) ;
//   c) un nouveau promeneur en Espagne : la carte s'ouvre sur Paris.
// Sonde Android (émulateur) : compte de test en ZONE TEST, position
// refusée / approximative / accordée (HPS_GPS), 1re ouverture (mémoire de
// caméra effacée). Relève à 3 s, 12 s et 30 s : position GPS connue,
// centre de la carte, rond « Moi » présent ou non ; puis vue d'Alhama de
// Murcie (caméra seulement, rien n'est écrit) : nature des groupes dessinés.
// Compte par --dart-define (jamais écrit ici).
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
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/pawmap_camera_memory.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'walker');
const String kTag = String.fromEnvironment('HPS_TAG', defaultValue: 'apres');
const String kGps = String.fromEnvironment('HPS_GPS', defaultValue: 'denied');

void say(String s) => debugPrint('[PARCOURS] $s');

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 900));
  debugPrint('[SHOT] $name');
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
    PushNotificationService.skipInitForIntegrationTests = true;
    // Position refusée : la fenêtre système ne peut pas être touchée par un
    // test → on rejoue « refusé » sans l'afficher.
    if (kGps == 'denied') {
      LocationService.skipPromptForTests = true;
      PawMapScreen.debugNoNativeDot625 = true;
    }
    setupDependencies();
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('fr');
  });

  testWidgets('PawMap 625 — Oppo : Moi, groupes, centrage ($kGps)', (t) async {
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
    await t.pump(const Duration(seconds: 2));
    // 1re ouverture : pas de mémoire de caméra sur ce téléphone.
    await GetStorage().remove('pawmap_last_center');
    final profile = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
    final pc = PawMapCameraMemory.profileCenter(profile);
    say('position du profil (stockage) : ${pc == null ? 'AUCUNE' : '${pc.latitude.toStringAsFixed(3)},${pc.longitude.toStringAsFixed(3)}'}'
        ' ; cles location=${profile?['location']?.runtimeType}');
    Set<Marker> last = <Marker>{};
    PawMapScreen.debugMarkersTap616 = (m) => last = Set.of(m);
    Get.offAll(() => const PawMapScreen());
    await t.pump(const Duration(seconds: 3));
    for (final k in const ['coach_close', 'pawmap_announce_close', 'coach_next']) {
      for (var i = 0; i < 3; i++) {
        final f = find.byKey(ValueKey<String>(k));
        if (f.evaluate().isEmpty) break;
        await t.tap(f.first);
        await t.pump(const Duration(milliseconds: 900));
      }
    }
    Future<void> sample(String when) async {
      final st = PawMapScreen.debugState625?.call() ?? const <String, Object?>{};
      final me = last.where((m) => m.markerId.value == 'me').toList();
      final meSize = me.isEmpty ? null : PawMapPinCache.sizeOf(me.first.icon);
      String cam = '?';
      final ctl = PawMapScreen.debugMapController616;
      if (ctl != null) {
        try {
          final r = await ctl.getVisibleRegion();
          cam = '${((r.northeast.latitude + r.southwest.latitude) / 2).toStringAsFixed(3)},'
              '${((r.northeast.longitude + r.southwest.longitude) / 2).toStringAsFixed(3)}';
        } catch (_) {}
      }
      say('ETAT625 $kTag $kGps $when gps=${st['gps']} centre=${st['center']} camera=$cam '
          'moi=${me.isEmpty ? 'ABSENT' : 'present ${me.first.position.latitude.toStringAsFixed(3)},${me.first.position.longitude.toStringAsFixed(3)} image=${meSize == null ? 'VIDE(transparente)' : '${meSize.width.round()}x${meSize.height.round()}'}'} '
          'marqueurs=${last.length}');
      say('TRACE625 $when ${LocationService.debugTrace625.join(' | ')}');
    }

    await t.pump(const Duration(seconds: 3));
    await sample('t3s');
    await t.pump(const Duration(seconds: 9));
    await sample('t12s');
    await shot(t, '${kTag}_${kGps}_ouverture_12s');
    await t.pump(const Duration(seconds: 18));
    await sample('t30s');
    await shot(t, '${kTag}_${kGps}_ouverture_30s');
    await t.pump(const Duration(seconds: 30));
    await sample('t60s');
    await shot(t, '${kTag}_${kGps}_ouverture_60s');

    // Vue d'Alhama de Murcie (caméra seulement) : quels groupes ?
    final ctl = PawMapScreen.debugMapController616;
    if (ctl != null) {
      for (final v in const <(String, double, double, double)>[
        ('alhama_z9', 37.851, -1.425, 9.0),
        ('alhama_z12', 37.851, -1.425, 12.0),
      ]) {
        await ctl.moveCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(v.$2, v.$3), zoom: v.$4)));
        await t.pump(const Duration(seconds: 9));
        final kinds = <String, int>{};
        for (final m in last) {
          final id = m.markerId.value;
          final k = id.contains('_') ? id.substring(0, id.indexOf('_')) : id;
          kinds[k] = (kinds[k] ?? 0) + 1;
        }
        final squares = last
            .where((m) => m.markerId.value.startsWith('pcluster_'))
            .map((m) => m.markerId.value.split('_').last)
            .toList();
        say('GROUPES625 $kTag ${v.$1} types=$kinds groupes_de_lieux=${squares.join('/')}');
        await shot(t, '${kTag}_${kGps}_${v.$1}');
      }
      // Caméra remise en zone test.
      await ctl.moveCamera(CameraUpdate.newCameraPosition(
          const CameraPosition(target: LatLng(-49.35, 70.22), zoom: 11)));
      await t.pump(const Duration(seconds: 3));
    }
    PawMapScreen.debugMarkersTap616 = null;
    say('fin');
  });
}
