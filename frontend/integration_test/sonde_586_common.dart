// v586 — outils communs des sondes du build 586 (PawMap discrète, fond).
// Compte de test par --dart-define (jamais affiché) ; l'HÔTE
// (`~/hopetsit-social/pawmap_586/run_sonde.sh`) lit le journal et exécute
// les VRAIS gestes (`adb shell input`) et les captures annoncés ici :
//   [SHOT] nom            → capture de l'écran
//   [TAP] x y             → adb shell input tap (pixels physiques)
//   [SWIPE] x1 y1 x2 y2 ms → adb shell input swipe
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/main.dart' as app;
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'owner');
const bool kInset0 = bool.fromEnvironment('HPS_INSET0');
/// iOS : pas d'outil de gestes réels en session non surveillée → le test
/// fait lui-même le geste (même arène de gestes).
const bool kSelfGestures = bool.fromEnvironment('HPS_SELF_GESTURES');

void say(String s) => print('[SONDE] ${DateTime.now().toIso8601String().substring(11, 19)} $s');
void ok(String what, bool cond, {String? detail}) =>
    print('[SONDE-R] ${cond ? 'OK ' : 'KO '} $what${detail == null ? '' : ' — $detail'}');

Future<void> hold(WidgetTester t, [int ms = 1000]) =>
    t.pump(Duration(milliseconds: ms));

/// Capture par l'hôte (le test attend qu'elle soit prise).
Future<void> shot(WidgetTester t, String name) async {
  await hold(t, 900);
  print('[SHOT] $name');
  await hold(t, 2600);
}

double _dpr(WidgetTester t) => t.view.devicePixelRatio;

/// VRAI toucher au centre de [f] (hôte, adb) ; en iOS : tap du test.
Future<void> realTap(WidgetTester t, Finder f, {String? why}) async {
  final c = t.getCenter(f.first);
  if (kSelfGestures) {
    say('tap (test) ${why ?? ''} @$c');
    await t.tapAt(c);
  } else {
    print('[TAP] ${(c.dx * _dpr(t)).round()} ${(c.dy * _dpr(t)).round()} ${why ?? ''}');
  }
  await hold(t, 2500);
}

Future<void> realLongPress(WidgetTester t, Finder f, {String? why}) async {
  final c = t.getCenter(f.first);
  if (kSelfGestures) {
    await t.longPressAt(c);
  } else {
    final x = (c.dx * _dpr(t)).round(), y = (c.dy * _dpr(t)).round();
    print('[SWIPE] $x $y $x $y 900 ${why ?? ''}');
  }
  await hold(t, 2500);
}

/// VRAI glissement depuis [from] de [dy] (px logiques, négatif = vers le haut).
Future<void> realSwipe(WidgetTester t, Offset from, double dy,
    {int ms = 300, String? why}) async {
  if (kSelfGestures) {
    await t.timedDragFrom(from, Offset(0, dy), Duration(milliseconds: ms));
  } else {
    final d = _dpr(t);
    print('[SWIPE] ${(from.dx * d).round()} ${(from.dy * d).round()} '
        '${(from.dx * d).round()} ${((from.dy + dy) * d).round()} $ms ${why ?? ''}');
  }
  await hold(t, 2500);
}

Future<void> waitFor(WidgetTester t, bool Function() cond, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 2; i++) {
    if (cond()) return;
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<void> sondeSetUp() async {
  await GetStorage.init();
  await dotenv.load(fileName: '.env');
  for (final code in ['fr', 'fr_FR', 'en', 'en_US']) {
    try {
      await initializeDateFormatting(code);
    } catch (_) {}
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('[SONDE] Firebase : $e');
  }
  setupDependencies();
  if (!Get.isRegistered<ThemeController>()) Get.put(ThemeController(), permanent: true);
}

Future<void> _dismissDialogs(WidgetTester t) async {
  final dlg = find.byType(CustomConfirmationDialog);
  if (dlg.evaluate().isNotEmpty) {
    final b = find.descendant(of: dlg, matching: find.byType(CustomButton));
    if (b.evaluate().length >= 2) await t.tap(b.last);
    await hold(t);
  }
  final later = find.byType(AppDialogSecondaryButton);
  if (later.evaluate().isNotEmpty) {
    await t.tap(later.first);
    await hold(t);
  }
}

/// Lance la VRAIE app, se connecte avec le compte de test, entre dans l'app.
Future<void> loginAndEnter(WidgetTester t) async {
  expect(kEmail, isNotEmpty, reason: 'HPS_EMAIL manquant');
  expect(kPassword, isNotEmpty, reason: 'HPS_PASSWORD manquant');
  if (kInset0) await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  (t.binding as LiveTestWidgetsFlutterBinding).shouldPropagateDevicePointerEvents = true;
  await t.pumpWidget(const app.MyApp());
  await hold(t, 2500);
  final auth = Get.find<AuthController>();
  auth.emailController.text = kEmail;
  auth.passwordController.text = kPassword;
  final logged = await auth.login(preferredRole: kRole, skipFormValidation: true);
  ok('connexion $kRole', logged);
  if (logged) {
    await hold(t);
    Get.offAll(() => switch (kRole) {
          'sitter' => const SitterNavWrapper(),
          'walker' => const WalkerNavWrapper(),
          _ => const BottomNavWrapper(),
        });
  }
  await hold(t, 4000);
  for (var i = 0; i < 40 && !navWrapperMounted.value; i++) {
    await _dismissDialogs(t);
    await hold(t);
  }
  for (var i = 0; i < 3; i++) {
    await _dismissDialogs(t);
  }
  ok('menu du bas monte', navWrapperMounted.value);
}

Future<void> openTab(WidgetTester t, int index) async {
  requestedTab.value = index;
  await hold(t, 2500);
  await _dismissDialogs(t);
  final later = find.text('common_later'.tr);
  if (later.evaluate().isNotEmpty) {
    await t.tap(later.last);
    await hold(t);
  }
}

Future<void> sondeTearDown(WidgetTester t) async {
  (t.binding as LiveTestWidgetsFlutterBinding).shouldPropagateDevicePointerEvents = false;
  if (kInset0) await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}
