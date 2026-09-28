// v598 (28/09) — REPRODUCTION « ronds rognés au zoom / dézoom rapide »
// (Daniel, iPhone, 28/09 à 2 h 49). Parcours connecté sur simulateur iPhone
// avec un COMPTE DE TEST (e-mail, mot de passe et rôle par --dart-define,
// lus depuis le fichier par `~/hopetsit-social/pawmap_598/run_zoom.sh`).
//
// Ce qu'il fait : connexion → onglet PawMap → épingles → puis une rafale de
// zooms / dézooms (caméra + boutons « + » / « − ») SANS attendre la fin des
// animations, pendant qu'un script prend une capture du simulateur tous les
// 0,25 s. À chaque étape, le journal `[ZOOM]` note pour chaque rond photo la
// taille RÉELLE de son image (en-tête PNG) et l'ancre envoyée à Google, pour
// repérer une image et une ancre qui ne vont pas ensemble.
import 'dart:async';
import 'dart:typed_data';

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
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'owner');

Future<void> _step(WidgetTester tester, String name,
    {Duration hold = const Duration(seconds: 2)}) async {
  print('[ZOOM] ${DateTime.now().toIso8601String()} $name');
  await tester.pump(hold);
}

void _ok(String what, bool cond, {String? detail}) {
  print('[RESULTAT] ${cond ? 'OK ' : 'KO '} $what${detail == null ? '' : ' — $detail'}');
}

Future<void> _waitFor(WidgetTester tester, bool Function() cond,
    {int seconds = 30}) async {
  for (var i = 0; i < seconds * 2; i++) {
    if (cond()) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
}

GoogleMap? _map(WidgetTester tester) {
  final f = find.byType(GoogleMap, skipOffstage: false);
  if (f.evaluate().isEmpty) return null;
  return tester.widget<GoogleMap>(f);
}

/// Largeur / hauteur en pixels d'un PNG (en-tête IHDR).
(int, int) _pngSize(Uint8List b) {
  if (b.length < 24) return (0, 0);
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20));
}

/// Journal des ronds photo : id, largeur logique demandée, taille PNG, ancre.
void _dumpPins(WidgetTester tester, String tag) {
  final map = _map(tester);
  if (map == null) return;
  final lines = <String>[];
  var mismatches = 0;
  for (final m in map.markers) {
    final id = m.markerId.value;
    if (!(id == 'me' || id.startsWith('friend') || id.startsWith('nearby'))) continue;
    final icon = m.icon;
    if (icon is BytesMapBitmap) {
      final (pw, ph) = _pngSize(icon.byteData);
      final w = icon.width ?? 0;
      // Hauteur logique déduite du PNG (même échelle que la largeur).
      final double lh = w == 0 || pw == 0 ? 0 : ph * (w / pw);
      // Le centre du rond devrait tomber à anchor.dy * lh : on note le rayon
      // disponible au-dessus / en dessous pour voir si le rond peut être coupé.
      final double above = m.anchor.dy * lh;
      final double below = lh - above;
      final bad = above < 28 || below < 28; // rond ≥ 44 dp + anneau
      if (bad) mismatches++;
      lines.add('$id w=$w png=${pw}x$ph lh=${lh.toStringAsFixed(1)} anchor=${m.anchor.dy.toStringAsFixed(3)} above=${above.toStringAsFixed(1)} below=${below.toStringAsFixed(1)}${bad ? ' <<< SERRE' : ''}');
    } else {
      lines.add('$id icon=${icon.runtimeType} (pas un bitmap maison)');
      mismatches++;
    }
  }
  print('[ZOOM] $tag · ${lines.length} ronds · serres/fallback=$mismatches');
  for (final l in lines.take(12)) {
    print('[ZOOM]   $l');
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    for (final code in ['fr', 'fr_FR', 'en', 'en_US']) {
      try {
        await initializeDateFormatting(code);
      } catch (_) {/* locale inconnue */}
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('[ZOOM] Firebase : $e');
    }
    setupDependencies();
  });

  testWidgets('PawMap 598 — zoom rapide ($kRole)', (tester) async {
    expect(kEmail, isNotEmpty, reason: 'HPS_EMAIL manquant (--dart-define)');
    expect(kPassword, isNotEmpty, reason: 'HPS_PASSWORD manquant (--dart-define)');
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      print('[ZOOM] EXCEPTION FLUTTER: ${d.exceptionAsString()}\n${d.stack}'.split('\n').take(12).join('\n'));
      prevOnError?.call(d);
    };
    try {
      await _run(tester);
    } catch (e, st) {
      print('[ZOOM] EXCEPTION TEST: $e\n${st.toString().split('\n').take(10).join('\n')}');
      rethrow;
    }
  });
}

Future<void> _run(WidgetTester tester) async {
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr', 'FR'),
      fallbackLocale: const Locale('en', 'US'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      home: const SignUpAsScreen(),
    ),
  ));
  await _step(tester, '00 ecran de depart');

  final auth = Get.find<AuthController>();
  auth.emailController.text = kEmail;
  auth.passwordController.text = kPassword;
  final logged = await auth.login(preferredRole: kRole, skipFormValidation: true);
  _ok('connexion $kRole', logged);
  if (logged) {
    await tester.pump(const Duration(seconds: 1));
    Get.offAll(() => switch (kRole) {
          'sitter' => const SitterNavWrapper(),
          'walker' => const WalkerNavWrapper(),
          _ => const BottomNavWrapper(),
        });
  }
  await _step(tester, '01 connecte, accueil', hold: const Duration(seconds: 4));
  for (var i = 0; i < 40 && !navWrapperMounted.value; i++) {
    final dlg = find.byType(CustomConfirmationDialog);
    if (dlg.evaluate().isNotEmpty) {
      final buttons = find.descendant(of: dlg, matching: find.byType(CustomButton));
      if (buttons.evaluate().length >= 2) {
        await tester.tap(buttons.last);
        await tester.pump(const Duration(seconds: 1));
      }
    }
    final later = find.byType(AppDialogSecondaryButton);
    if (later.evaluate().isNotEmpty) {
      await tester.tap(later.first);
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(seconds: 1));
  }
  _ok('menu du bas monte', navWrapperMounted.value);

  requestedTab.value = kPawMapTabIndex;
  await tester.pump(const Duration(seconds: 1));
  await _waitFor(tester,
      () => find.byKey(const ValueKey<String>('pawmap_sheet_grip')).evaluate().isNotEmpty,
      seconds: 60);
  await _step(tester, '02 pawmap ouverte', hold: const Duration(seconds: 3));
  for (var i = 0; i < 3; i++) {
    final dlg = find.byType(CustomConfirmationDialog);
    if (dlg.evaluate().isEmpty) break;
    final buttons = find.descendant(of: dlg, matching: find.byType(CustomButton));
    if (buttons.evaluate().length >= 2) await tester.tap(buttons.last);
    await tester.pump(const Duration(seconds: 1));
  }
  if (find.byKey(const ValueKey<String>('pawmap_coach')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const ValueKey<String>('coach_close')));
    await tester.pump(const Duration(milliseconds: 800));
    for (var i = 0; i < 3 && find.byKey(const ValueKey<String>('coach_next')).evaluate().isNotEmpty; i++) {
      await tester.tap(find.byKey(const ValueKey<String>('coach_next')));
      await tester.pump(const Duration(milliseconds: 600));
    }
  }
  final state = tester.state<State<PawMapScreen>>(find.byType(PawMapScreen));
  await _waitFor(tester, () => (_map(tester)?.markers.length ?? 0) > 1, seconds: 40);
  await _step(tester, '03 epingles chargees', hold: const Duration(seconds: 4));
  _dumpPins(tester, 'repos zoom ville');

  final mapCtl = await (state as dynamic).activeMapCtlForTest() as GoogleMapController?;
  _ok('controleur de carte', mapCtl != null);
  if (mapCtl == null) return;
  Marker? me;
  for (final m in _map(tester)!.markers) {
    if (m.markerId.value == 'me') me = m;
  }
  final target = me?.position ?? const LatLng(48.8566, 2.3522);

  // ── A. rafale caméra : rue → ville → rue → ville, sans attendre ──
  await _step(tester, '10 RAFALE A (camera 17 / 11 / 16.5 / 10 / 17)', hold: Duration.zero);
  for (final z in [17.0, 11.0, 16.5, 10.0, 17.0]) {
    unawaited(mapCtl.animateCamera(CameraUpdate.newLatLngZoom(target, z)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      _dumpPins(tester, 'A z=$z t=${(i + 1) * 120}ms');
    }
  }
  await _step(tester, '11 fin rafale A', hold: const Duration(seconds: 4));
  _dumpPins(tester, 'repos apres A');

  // ── B. rafale boutons « + » ×6 puis « − » ×6, 150 ms entre chaque ──
  final plus = find.byTooltip('+');
  final minus = find.byTooltip('−');
  _ok('boutons + / − trouves', plus.evaluate().isNotEmpty && minus.evaluate().isNotEmpty);
  await mapCtl.moveCamera(CameraUpdate.newLatLngZoom(target, 11.5));
  await tester.pump(const Duration(seconds: 2));
  await _step(tester, '20 RAFALE B (+ x6)', hold: Duration.zero);
  for (var i = 0; i < 6; i++) {
    if (plus.evaluate().isNotEmpty) await tester.tap(plus.first);
    await tester.pump(const Duration(milliseconds: 150));
    _dumpPins(tester, 'B + #${i + 1}');
  }
  await _step(tester, '21 RAFALE B (- x6)', hold: Duration.zero);
  for (var i = 0; i < 6; i++) {
    if (minus.evaluate().isNotEmpty) await tester.tap(minus.first);
    await tester.pump(const Duration(milliseconds: 150));
    _dumpPins(tester, 'B - #${i + 1}');
  }
  await _step(tester, '22 fin rafale B', hold: const Duration(seconds: 4));
  _dumpPins(tester, 'repos apres B');

  // ── C. va-et-vient autour du seuil de zoom rue (12.5) ──
  await _step(tester, '30 RAFALE C (12.2 <-> 12.8 x6)', hold: Duration.zero);
  for (var i = 0; i < 6; i++) {
    unawaited(mapCtl.animateCamera(CameraUpdate.newLatLngZoom(target, i.isEven ? 12.8 : 12.2)));
    await tester.pump(const Duration(milliseconds: 200));
    _dumpPins(tester, 'C #${i + 1}');
  }
  await _step(tester, '31 fin rafale C', hold: const Duration(seconds: 4));
  _dumpPins(tester, 'repos apres C');
  await _step(tester, '99 fin', hold: const Duration(seconds: 2));
}
