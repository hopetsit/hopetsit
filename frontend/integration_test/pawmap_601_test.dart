// ignore_for_file: avoid_print
// v601 (PAM, 29/09/2026) — preuves du build 601 sur simulateur / émulateur.
//   · Mesure : ouverture de l'onglet PawMap dès que le menu est monté, horodatée
//     ([T] …, heure murale en ms) ; la vidéo de l'écran, prise de l'extérieur,
//     donne la première image de carte. Journal : photo de lancement affichée
//     ou non, retirée quand.
//   · Captures (prises de l'extérieur sur chaque ligne [CAP] nom) : carte hors
//     balade, carte en balade (drapeau au-dessus du bouton Balade), réglage de
//     la barre de droite, accueil propriétaire.
// Compte de test (3 profils) : HPS_EMAIL / HPS_PASSWORD / HPS_ROLE.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';
import 'package:hopetsit/views/map/pawmap_snapshot.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'owner');
const bool kDark = bool.fromEnvironment('HPS_DARK', defaultValue: false);
const bool kNoSnapshot = bool.fromEnvironment('HPS_NO_SNAPSHOT', defaultValue: false);
const bool kWalk = bool.fromEnvironment('HPS_WALK', defaultValue: true);
const int kTabDelayMs = int.fromEnvironment('HPS_TAB_DELAY_MS', defaultValue: 0);

int _ms() => DateTime.now().millisecondsSinceEpoch;

Future<void> _cap(WidgetTester tester, String name, {int holdMs = 2500}) async {
  print('[CAP] $name ${_ms()}');
  await tester.pump(Duration(milliseconds: holdMs));
}

void _ok(String what, bool cond, {String? detail}) {
  print('[RESULTAT] ${cond ? 'OK ' : 'KO '} $what${detail == null ? '' : ' — $detail'}');
}

Future<bool> _waitFor(WidgetTester tester, bool Function() cond, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 4; i++) {
    if (cond()) return true;
    await tester.pump(const Duration(milliseconds: 250));
  }
  return false;
}

Future<void> _dismissDialogs(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    final dlg = find.byType(CustomConfirmationDialog);
    if (dlg.evaluate().isNotEmpty) {
      final buttons = find.descendant(of: dlg, matching: find.byType(CustomButton));
      if (buttons.evaluate().length >= 2) await tester.tap(buttons.last);
      await tester.pump(const Duration(seconds: 1));
    }
    final later = find.byType(AppDialogSecondaryButton);
    if (later.evaluate().isNotEmpty) {
      await tester.tap(later.first);
      await tester.pump(const Duration(seconds: 1));
    }
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
    } catch (e) {
      debugPrint('[T] Firebase : $e');
    }
    setupDependencies();
  });

  testWidgets('PawMap 601 — photo de lancement, barre de droite, drapeau Balade ($kRole)',
      (tester) async {
    expect(kEmail, isNotEmpty);
    final meta = PawMapSnapshotStore.readSync();
    print('[T] photo enregistrée au départ : ${meta == null ? 'AUCUNE' : '${meta.savedAt} z=${meta.zoom}'}');
    // Le guide « ? » de premier lancement masquerait les captures.
    GetStorage().write('pawmap_intro_seen_count', 99);
    if (kNoSnapshot) {
      await GetStorage().remove(PawMapSnapshotStore.metaKey);
      print('[T] photo effacée (mesure AVANT = comportement 600)');
    }
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr', 'FR'),
        fallbackLocale: const Locale('en', 'US'),
        debugShowCheckedModeBanner: false,
        themeMode: kDark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
        darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: const SignUpAsScreen(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    final auth = Get.find<AuthController>();
    auth.emailController.text = kEmail;
    auth.passwordController.text = kPassword;
    final logged = await auth.login(preferredRole: kRole, skipFormValidation: true);
    _ok('connexion $kRole', logged);
    if (!logged) return;
    MapPrefsService.instance.update({'coachShown': 99});
    await tester.pump(const Duration(milliseconds: 300));
    Get.offAll(() => switch (kRole) {
          'sitter' => const SitterNavWrapper(),
          'walker' => const WalkerNavWrapper(),
          _ => const BottomNavWrapper(),
        });
    for (var i = 0; i < 200 && !navWrapperMounted.value; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // ── MESURE : l'onglet PawMap est ouvert tout de suite (ou après
    // HPS_TAB_DELAY_MS, cas réel : on regarde l'accueil puis on touche la patte).
    if (kTabDelayMs > 0) {
      print('[T] ACCUEIL ${_ms()}');
      await tester.pump(Duration(milliseconds: kTabDelayMs));
    }
    print('[T] TAB_OPEN ${_ms()}');
    requestedTab.value = kPawMapTabIndex;
    int? snapSeen;
    int? snapGone;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final shown = find
          .byKey(const ValueKey<String>('pawmap_snapshot_image'), skipOffstage: false)
          .evaluate()
          .isNotEmpty;
      if (shown && snapSeen == null) snapSeen = _ms();
      if (!shown && snapSeen != null && snapGone == null) snapGone = _ms();
    }
    print('[T] SNAPSHOT_SHOWN ${snapSeen ?? 'jamais'} GONE ${snapGone ?? '-'}');
    await _dismissDialogs(tester);
    await tester.pump(const Duration(seconds: 3));
    await _cap(tester, '${kRole}_carte_hors_balade${kDark ? '_nuit' : ''}');

    // ── Réglage de la barre de droite ─────────────────────────────────────
    final edit = find.byKey(const ValueKey<String>('capsule_customize'));
    _ok('bouton « Modifier la barre de droite » présent', edit.evaluate().isNotEmpty);
    if (edit.evaluate().isNotEmpty) {
      await tester.tap(edit.first);
      await tester.pump(const Duration(milliseconds: 900));
      _ok('écran de réglage ouvert (phrase des fixes)',
          find.byKey(const ValueKey('capsule_fixed_note')).evaluate().isNotEmpty);
      await _cap(tester, '${kRole}_reglage_droite${kDark ? '_nuit' : ''}');
      Navigator.of(tester.element(find.byKey(const ValueKey('capsule_fixed_note')))).pop();
      await tester.pump(const Duration(milliseconds: 800));
    }

    // ── Balade : drapeau au-dessus du bouton ──────────────────────────────
    final live = Get.find<LiveMapService>();
    if (kWalk) {
      GetStorage().write('pawmap_live_hint_seen', true);
      final btn = find.byKey(const ValueKey<String>('pawmap_walk_btn'));
      _ok('bouton Balade dans la barre de droite', btn.evaluate().isNotEmpty);
      if (btn.evaluate().isNotEmpty && !live.broadcasting.value) {
        await tester.tap(btn.first);
        await tester.pump(const Duration(seconds: 1));
        await _dismissDialogs(tester);
      }
      final on = await _waitFor(tester, () => live.broadcasting.value, seconds: 20);
      _ok('balade démarrée', on);
      final badge = await _waitFor(tester,
          () => find.byKey(const ValueKey('pawmap_walk_badge')).evaluate().isNotEmpty,
          seconds: 10);
      _ok('drapeau vert au-dessus du bouton Balade', badge);
      if (badge) {
        final b = tester.getRect(find.byKey(const ValueKey('pawmap_walk_badge')));
        final j = tester.getRect(find.byKey(const ValueKey('pawmap_walk_btn')));
        _ok('drapeau AU-DESSUS du bouton (${b.bottom.toStringAsFixed(0)} ≤ ${j.top.toStringAsFixed(0)})',
            b.bottom <= j.top + 1);
      }
      _ok('plus de pilule en haut à gauche',
          find.byKey(const ValueKey('pawmap_direct_pill_on')).evaluate().isEmpty);
      await tester.pump(const Duration(seconds: 2));
      await _cap(tester, '${kRole}_carte_en_balade${kDark ? '_nuit' : ''}');
      await live.stopEverywhere();
      live.stopBroadcasting();
      final off = await _waitFor(tester, () => !live.broadcasting.value, seconds: 15);
      _ok('balade arrêtée', off);
      await tester.pump(const Duration(seconds: 2));
      _ok('drapeau disparu hors balade',
          find.byKey(const ValueKey('pawmap_walk_badge')).evaluate().isEmpty);
    }

    // Laisse le temps de prendre la photo de carte (caméra stable ≥ 1,5 s).
    await tester.pump(const Duration(seconds: 4));
    final after = PawMapSnapshotStore.readSync();
    _ok('photo de la carte enregistrée', after != null,
        detail: after == null ? null : '${after.savedAt} z=${after.zoom.toStringAsFixed(1)} ${after.lat.toStringAsFixed(4)},${after.lng.toStringAsFixed(4)}');

    // ── Accueil (propriétaire : cartes d'action) ──────────────────────────
    requestedTab.value = 0;
    await tester.pump(const Duration(seconds: 3));
    await _cap(tester, '${kRole}_accueil${kDark ? '_nuit' : ''}');
    print('[T] FIN ${_ms()}');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
