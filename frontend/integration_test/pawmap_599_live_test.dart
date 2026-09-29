// ignore_for_file: avoid_print
// v599 (29/09/2026) — SUIVI EN DIRECT DE BOUT EN BOUT, côté RÉCEPTEUR (iPhone).
// Le compte de test propriétaire (3 profils) est connecté sous le rôle
// HPS_ROLE (walker = « autre profil de la même personne », comme Daniel
// qui reçoit la demande de son frère sous un autre profil). L'expéditeur
// (compte gardien de test) est piloté à la main sur l'émulateur Android.
//   Phase 1 : chat « Test Sitter » → la carte de demande arrive en direct →
//             Accepter → statut « Acceptée » + pilule « En direct ».
//   Phase 2 : accueil → point vert sur la patte dès que la balade démarre →
//             onglet PawMap → rond de l'ami avec nom + photo, suivi.
//   Phase 3 : fin de balade → le point vert disparaît.
//   Phase 4 : « Comprendre la PawMap » → section La Balade.
// Journal : lignes [LIVE] / [RESULTAT] ; captures faites de l'extérieur.

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
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/pawfollow_request_card.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'walker');
const String kPeer = String.fromEnvironment('HPS_PEER', defaultValue: 'Test Sitter');
const int kWait = int.fromEnvironment('HPS_WAIT', defaultValue: 300);
const bool kOnlyChat = bool.fromEnvironment('HPS_ONLY_CHAT', defaultValue: false);

/// Une demande de suivi qui M'EST adressée et encore valable (pas une vieille
/// demande à moi, pas une demande expirée).
bool _isFreshIncoming(PawfollowRequestCard c) =>
    c.status == 'pending' &&
    c.isMine == false &&
    (c.expiresAt == null || c.expiresAt!.isAfter(DateTime.now()));

Future<void> _step(WidgetTester tester, String name,
    {Duration hold = const Duration(seconds: 2)}) async {
  print('[LIVE] ${DateTime.now().toIso8601String()} $name');
  await tester.pump(hold);
}

void _ok(String what, bool cond, {String? detail}) {
  print('[RESULTAT] ${cond ? 'OK ' : 'KO '} $what${detail == null ? '' : ' — $detail'}');
}

Future<bool> _waitFor(WidgetTester tester, bool Function() cond,
    {int seconds = 30, String? tag}) async {
  for (var i = 0; i < seconds * 2; i++) {
    if (cond()) return true;
    if (tag != null && i % 20 == 0) print('[LIVE] … attente $tag (${i ~/ 2} s)');
    await tester.pump(const Duration(milliseconds: 500));
  }
  return false;
}

GoogleMap? _map(WidgetTester tester) {
  final f = find.byType(GoogleMap, skipOffstage: false);
  if (f.evaluate().isEmpty) return null;
  return tester.widget<GoogleMap>(f);
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
    for (final code in ['fr', 'fr_FR', 'en', 'en_US']) {
      try {
        await initializeDateFormatting(code);
      } catch (_) {/* locale inconnue */}
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('[LIVE] Firebase : $e');
    }
    setupDependencies();
  });

  testWidgets('PawMap 599 — suivi en direct, récepteur ($kRole)', (tester) async {
    expect(kEmail, isNotEmpty, reason: 'HPS_EMAIL manquant');
    expect(kPassword, isNotEmpty, reason: 'HPS_PASSWORD manquant');
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      print('[LIVE] EXCEPTION FLUTTER: ${d.exceptionAsString()}'.split('\n').take(6).join('\n'));
      prevOnError?.call(d);
    };
    try {
      await _run(tester);
    } catch (e, st) {
      print('[LIVE] EXCEPTION TEST: $e\n${st.toString().split('\n').take(10).join('\n')}');
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
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
  if (!logged) return;
  await tester.pump(const Duration(seconds: 1));
  Get.offAll(() => switch (kRole) {
        'sitter' => const SitterNavWrapper(),
        'walker' => const WalkerNavWrapper(),
        _ => const BottomNavWrapper(),
      });
  await _step(tester, '01 connecte, accueil', hold: const Duration(seconds: 4));
  for (var i = 0; i < 40 && !navWrapperMounted.value; i++) {
    await _dismissDialogs(tester);
    await tester.pump(const Duration(seconds: 1));
  }
  _ok('menu du bas monte', navWrapperMounted.value);
  await _dismissDialogs(tester);

  // ── Phase 1 : le chat ────────────────────────────────────────────────────
  requestedTab.value = 1;
  await tester.pump(const Duration(seconds: 2));
  final tile = await _waitFor(tester, () => find.text(kPeer).evaluate().isNotEmpty, seconds: 60, tag: 'liste des conversations');
  _ok('conversation « $kPeer » dans la liste', tile);
  if (tile) {
    await tester.tap(find.text(kPeer).first);
    await tester.pump(const Duration(seconds: 3));
  }
  await _step(tester, '10 PHASE1 chat ouvert — envoie la demande depuis Android', hold: const Duration(seconds: 2));
  final cardArrived = await _waitFor(
      tester,
      () => find.byType(PawfollowRequestCard).evaluate().any((e) =>
          _isFreshIncoming(e.widget as PawfollowRequestCard)),
      seconds: kWait,
      tag: 'carte de demande (pending)');
  _ok('carte de demande recue EN DIRECT dans le chat', cardArrived);
  if (cardArrived) {
    final card = tester.widgetList<PawfollowRequestCard>(find.byType(PawfollowRequestCard)).lastWhere(_isFreshIncoming);
    print('[LIVE] carte : requesterRole=${card.requesterRole} responderRole=${card.responderRole} myRole=${card.myRole} isMine=${card.isMine}');
    await _step(tester, '11 carte affichee (capture)', hold: const Duration(seconds: 4));
    final accept = find.text('pawfollow_accept'.tr);
    _ok('bouton Accepter visible (autre profil que le rôle vise)', accept.evaluate().isNotEmpty,
        detail: 'responderRole=${card.responderRole} ≠ myRole=${card.myRole}');
    if (accept.evaluate().isNotEmpty) {
      await tester.ensureVisible(accept.first);
      await tester.tap(accept.first);
      final accepted = await _waitFor(tester, () => find.text('pawfollow_status_accepted'.tr).evaluate().isNotEmpty, seconds: 40, tag: 'statut Acceptee');
      _ok('statut « Acceptee » (serveur OK)', accepted);
      final pill = await _waitFor(tester, () => find.text('cs_pf_live_open'.tr).evaluate().isNotEmpty, seconds: 20);
      _ok('pilule du haut « En direct · voir la carte »', pill);
      await _step(tester, '12 acceptee (capture)', hold: const Duration(seconds: 5));
    }
  }

  if (kOnlyChat) {
    await _step(tester, '99 FIN (chat seulement)', hold: const Duration(seconds: 2));
    return;
  }

  // ── Phase 2 : la balade ──────────────────────────────────────────────────
  Get.until((r) => r.isFirst);
  requestedTab.value = 0;
  await _step(tester, '20 PHASE2 accueil — demarre la balade sur Android', hold: const Duration(seconds: 2));
  final live = Get.find<LiveMapService>();
  final started = await _waitFor(tester, () => live.liveFriendsCount.value > 0, seconds: kWait, tag: 'ami en balade');
  _ok('ami en balade detecte (liveFriendsCount=${live.liveFriendsCount.value})', started);
  await tester.pump(const Duration(seconds: 1));
  final dot = find.byKey(const ValueKey<String>('paw_tab_live_dot'));
  _ok('point vert sur la patte du menu (accueil)', dot.evaluate().isNotEmpty);
  await _step(tester, '21 point vert (capture)', hold: const Duration(seconds: 5));
  for (final p in live.friendPositions.values) {
    print('[LIVE] position ${p.userId.substring(p.userId.length - 6)} role=${p.role} name="${p.name}" avatar=${p.avatar.isEmpty ? 'VIDE' : 'oui'} state=${p.liveState} lat=${p.latitude.toStringAsFixed(4)} lng=${p.longitude.toStringAsFixed(4)}');
  }
  _ok('nom + photo dans la position live (v599 serveur)', live.friendPositions.values.any((p) => p.avatar.isNotEmpty && p.name.isNotEmpty));
  // Onglet PawMap par la patte (un seul ami en balade → centrage sur lui).
  final paw = find.byKey(const ValueKey<String>('paw_tab_2'));
  if (paw.evaluate().isNotEmpty) {
    await tester.tap(paw);
  } else {
    requestedTab.value = kPawMapTabIndex;
  }
  await tester.pump(const Duration(seconds: 2));
  await _dismissDialogs(tester);
  await _waitFor(tester, () => find.byKey(const ValueKey<String>('pawmap_sheet_grip')).evaluate().isNotEmpty, seconds: 60);
  if (find.byKey(const ValueKey<String>('pawmap_coach')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const ValueKey<String>('coach_close')));
    await tester.pump(const Duration(milliseconds: 800));
  }
  final friendMarker = await _waitFor(tester, () => (_map(tester)?.markers ?? {}).any((m) => m.markerId.value.startsWith('friend_')), seconds: 60, tag: 'rond de l ami');
  _ok('rond de l ami en direct sur la carte', friendMarker);
  await _step(tester, '22 pawmap centree sur l ami (capture)', hold: const Duration(seconds: 6));
  // Mouvement : la position doit bouger pendant 60 s (Android change de place).
  final before = live.friendPositions.values.map((p) => '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}').join(' ');
  await _step(tester, '23 suivi 60 s', hold: const Duration(seconds: 60));
  final after = live.friendPositions.values.map((p) => '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}').join(' ');
  _ok('position en direct qui bouge', before != after, detail: '$before → $after');
  _ok('trace de la balade recu', live.friendTrails.values.any((t) => t.length >= 2), detail: 'points=${live.friendTrails.values.map((t) => t.length).join(',')}');
  await _step(tester, '24 apres suivi (capture)', hold: const Duration(seconds: 4));

  // ── Phase 3 : fin de balade ──────────────────────────────────────────────
  requestedTab.value = 0;
  await _step(tester, '30 PHASE3 accueil — arrete la balade sur Android', hold: const Duration(seconds: 2));
  final stopped = await _waitFor(tester, () => live.liveFriendsCount.value == 0, seconds: kWait, tag: 'fin de balade');
  _ok('fin de balade detectee (liveFriendsCount=0)', stopped);
  await tester.pump(const Duration(seconds: 1));
  _ok('point vert disparu', dot.evaluate().isEmpty);
  await _step(tester, '31 sans point vert (capture)', hold: const Duration(seconds: 5));

  // ── Phase 4 : Comprendre la PawMap → La Balade ───────────────────────────
  Get.to(() => const PawMapHelpScreen());
  await tester.pump(const Duration(seconds: 2));
  final img = find.byKey(const ValueKey<String>('help_balade_image'), skipOffstage: false);
  if (img.evaluate().isNotEmpty) {
    await tester.ensureVisible(img);
    await tester.pump(const Duration(seconds: 1));
  }
  _ok('section La Balade presente dans l aide', img.evaluate().isNotEmpty);
  await _step(tester, '40 aide La Balade (capture)', hold: const Duration(seconds: 6));
  await _step(tester, '99 FIN', hold: const Duration(seconds: 2));
}
