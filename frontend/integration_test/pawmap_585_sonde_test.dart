// v584 (révision PawMap du 25/09) — PARCOURS CONNECTÉ, sur simulateur iPhone
// et émulateur Android, avec un COMPTE DE TEST (jamais affiché : e-mail, mot
// de passe et rôle arrivent par --dart-define, lus depuis le fichier par
// `~/hopetsit-social/pawmap_584/run_parcours.sh`).
//
//   flutter test integration_test/pawmap_584_parcours_test.dart -d <device> \
//     --dart-define=HPS_EMAIL=… --dart-define=HPS_PASSWORD=… --dart-define=HPS_ROLE=owner
//
// Ce que le parcours PROUVE (journal `[SONDE]`, une capture par étape prise
// de l'extérieur) : connexion réelle → onglet PawMap → UNE GoogleMap → les
// épingles construites (comptées par famille : moi, membres, amis, groupes,
// demandes) au zoom ville et au zoom rue → chaque bouton du rail, de
// l'en-tête, de la feuille, le bouton principal (il s'ouvre), la fiche d'un
// membre (Voir le profil → la bonne fiche selon SON rôle, Réserver, Message,
// Ami, Itinéraire), un groupe (zoom puis liste), un ami en direct (fiche →
// Suivre la balade → pilule → feuille → Arrêter), mode nuit, calques,
// recherche de ville, Autour de moi, signalements, PawSpots, chat du cercle,
// partage de carte, compteur. Rien n'est publié ni payé : la réservation
// s'arrête sur l'écran de demande (fermé sans envoyer).

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';
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
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';
import 'package:hopetsit/views/map/alerts_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart';
import 'package:hopetsit/views/service_provider/owner_profile_view_screen.dart';
import 'package:hopetsit/views/service_provider/send_request_screen.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/service_provider/walker_detail_screen.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hopetsit/main.dart' as app;
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'owner');
const bool kInset0 = bool.fromEnvironment('HPS_INSET0');
const bool kRealApp = bool.fromEnvironment('HPS_REAL_APP');
// iOS : pas d'outil de gestes réels en session non surveillée → gestes
// synthétisés par le test (même arène de gestes, mêmes reconstructions).
const bool kSelfGestures = bool.fromEnvironment('HPS_SELF_GESTURES');

Future<void> _step(WidgetTester tester, String name,
    {Duration hold = const Duration(seconds: 2)}) async {
  print('[SONDE] ${DateTime.now().toIso8601String()} $name');
  await tester.pump(hold);
}

void _ok(String what, bool cond, {String? detail}) {
  print('[SONDE-R] ${cond ? 'OK ' : 'KO '} $what${detail == null ? '' : ' — $detail'}');
}

Future<void> _closeAll(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    final nav = Navigator.of(
        tester.element(find.byType(PawMapScreen, skipOffstage: false).first));
    if (!nav.canPop()) break;
    nav.pop();
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Map<String, int> _markerFamilies(WidgetTester tester) {
  final f = find.byType(GoogleMap, skipOffstage: false);
  if (f.evaluate().isEmpty) return const {};
  final map = tester.widget<GoogleMap>(f);
  final out = <String, int>{};
  for (final m in map.markers) {
    final id = m.markerId.value;
    final fam = id == 'me'
        ? 'moi'
        : id.startsWith('nearby_')
            ? 'membre'
            : id.startsWith('friend_')
                ? 'ami_direct'
                : id.startsWith('mcluster_')
                    ? 'groupe_membres'
                    : id.startsWith('req_') || id.startsWith('myreq_')
                        ? 'demande'
                        : id.startsWith('poi_')
                            ? 'lieu'
                            : id.startsWith('pcluster_')
                                ? 'groupe_lieux'
                                : id.startsWith('pawspot_')
                                    ? 'pawspot'
                                    : id.startsWith('scluster_')
                                        ? 'groupe_pawspots'
                                        : id.startsWith('report_')
                                            ? 'signalement'
                                            : 'autre';
    out[fam] = (out[fam] ?? 0) + 1;
  }
  return out;
}

Marker? _firstMarker(WidgetTester tester, bool Function(String id) where) {
  final f = find.byType(GoogleMap, skipOffstage: false);
  if (f.evaluate().isEmpty) return null;
  final map = tester.widget<GoogleMap>(f);
  for (final m in map.markers) {
    if (where(m.markerId.value)) return m;
  }
  return null;
}

Future<void> _waitFor(WidgetTester tester, bool Function() cond,
    {int seconds = 30}) async {
  for (var i = 0; i < seconds * 2; i++) {
    if (cond()) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    // Comme `main.dart` : données de date d'intl (sinon LocaleDataException
    // en construisant l'accueil).
    for (final code in ['fr', 'fr_FR', 'en', 'en_US']) {
      try {
        await initializeDateFormatting(code);
      } catch (_) {/* locale inconnue */}
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('[SONDE] Firebase : $e');
    }
    setupDependencies();
    if (!Get.isRegistered<ThemeController>()) Get.put(ThemeController(), permanent: true);
  });

  testWidgets('PawMap 585 — sonde inset ($kRole)', (tester) async {
    expect(kEmail, isNotEmpty, reason: 'HPS_EMAIL manquant (--dart-define)');
    expect(kPassword, isNotEmpty, reason: 'HPS_PASSWORD manquant (--dart-define)');
    // Toute erreur de construction est ÉCRITE dans le journal du parcours
    // (le cadre d'exception du framework n'y arrive pas toujours).
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      print('[SONDE] EXCEPTION FLUTTER: ${d.exceptionAsString()}\n${d.stack}'.split('\n').take(12).join('\n'));
      prevOnError?.call(d);
    };
    try {
      await _run(tester);
    } catch (e, st) {
      print('[SONDE] EXCEPTION TEST: $e\n${st.toString().split('\n').take(10).join('\n')}');
      rethrow;
    }
  });
}

Future<void> _run(WidgetTester tester) async {
    if (kInset0) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    (tester.binding as LiveTestWidgetsFlutterBinding).shouldPropagateDevicePointerEvents = true;

    await tester.pumpWidget(kRealApp ? const app.MyApp() : ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr', 'FR'),
        home: const SignUpAsScreen(),
      ),
    ));
    await _step(tester, '00 ecran de depart', hold: const Duration(seconds: 2));

    // ── Connexion réelle par le contrôleur (mêmes champs que l'écran) ──
    final auth = Get.find<AuthController>();
    auth.emailController.text = kEmail;
    auth.passwordController.text = kPassword;
    final logged = await auth.login(preferredRole: kRole, skipFormValidation: true);
    _ok('connexion $kRole', logged);
    // `login()` ne navigue pas lui-même (c'est l'écran qui le fait) : même
    // destination que `_navigateToHome` selon le rôle.
    if (logged) {
      await tester.pump(const Duration(seconds: 1));
      Get.offAll(() => switch (kRole) {
            'sitter' => const SitterNavWrapper(),
            'walker' => const WalkerNavWrapper(),
            _ => const BottomNavWrapper(),
          });
    }
    await _step(tester, '01 connecte, accueil', hold: const Duration(seconds: 4));
    // Après la connexion, l'app peut poser la question des notifications
    // (« Activer / Plus tard ») AVANT d'entrer : on répond « Plus tard »,
    // comme le ferait Daniel, jusqu'à ce que le menu du bas soit monté.
    for (var i = 0; i < 40 && !navWrapperMounted.value; i++) {
      // Fenêtre des notifications (CustomConfirmationDialog : Activer /
      // Plus tard = 2e CustomButton) ou tout dialogue maison (2e bouton).
      final dlg = find.byType(CustomConfirmationDialog);
      if (dlg.evaluate().isNotEmpty) {
        final buttons = find.descendant(of: dlg, matching: find.byType(CustomButton));
        if (buttons.evaluate().length >= 2) {
          await tester.tap(buttons.last);
          debugPrint('[SONDE] fenetre des notifications : « Plus tard »');
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

    // ── Onglet PawMap ──
    requestedTab.value = kPawMapTabIndex;
    await tester.pump(const Duration(seconds: 1));
    await _waitFor(tester,
        () => find.byKey(const ValueKey<String>('pawmap_sheet_grip')).evaluate().isNotEmpty,
        seconds: 60);
    await _step(tester, '02 pawmap ouverte', hold: const Duration(seconds: 4));
    _ok('UNE seule GoogleMap', find.byType(GoogleMap).evaluate().length == 1);
    _ok('feuille + bouton principal presents',
        find.byKey(const ValueKey<String>('pawmap_primary')).evaluate().isNotEmpty);
    // Découverte guidée : uniquement au 1er lancement ; si elle est là, on la
    // ferme par la croix « Ne plus montrer » (point 13).
    // La question des notifications peut revenir après l'entrée (au-dessus
    // de tout) : « Plus tard » d'abord, sinon les taps vont au voile.
    for (var i = 0; i < 3; i++) {
      final dlg = find.byType(CustomConfirmationDialog);
      if (dlg.evaluate().isEmpty) break;
      final buttons = find.descendant(of: dlg, matching: find.byType(CustomButton));
      if (buttons.evaluate().length >= 2) await tester.tap(buttons.last);
      await tester.pump(const Duration(seconds: 1));
    }
    if (find.byKey(const ValueKey<String>('pawmap_coach')).evaluate().isNotEmpty) {
      await _step(tester, '02b decouverte guidee (1er lancement)');
      final close = find.byKey(const ValueKey<String>('coach_close'));
      print('[SONDE] croix: ${close.evaluate().length} · rect=${close.evaluate().isEmpty ? '-' : tester.getRect(close)}');
      await tester.tap(close);
      await tester.pump(const Duration(milliseconds: 800));
      _ok('croix « Ne plus montrer » ferme la decouverte', find.byKey(const ValueKey<String>('pawmap_coach')).evaluate().isEmpty);
      // Secours : « Suivant » jusqu'au bout, pour que le parcours continue.
      for (var i = 0; i < 3 && find.byKey(const ValueKey<String>('coach_next')).evaluate().isNotEmpty; i++) {
        await tester.tap(find.byKey(const ValueKey<String>('coach_next')));
        await tester.pump(const Duration(milliseconds: 600));
      }
    }
    _ok('decouverte guidee absente', find.byKey(const ValueKey<String>('pawmap_coach')).evaluate().isEmpty);

    // La pop-up promo (une fois) peut recouvrir le bas : « Plus tard ».
    final later = find.text('common_later'.tr);
    if (later.evaluate().isNotEmpty) {
      await tester.tap(later.last);
      await tester.pump(const Duration(seconds: 1));
      print('[SONDE] pop-up promo fermee (Plus tard)');
    }
    // ── Mesures ──
    final ctx = tester.element(find.byType(PawMapScreen));
    final mq = MediaQuery.of(ctx);
    final dpr = tester.view.devicePixelRatio;
    print('[SONDE] inset0=$kInset0 viewPadding.bottom=${mq.viewPadding.bottom} padding.bottom=${mq.padding.bottom} viewInsets=${mq.viewInsets.bottom} size=${mq.size} dpr=$dpr');
    Rect r(Finder f) => f.evaluate().isEmpty ? Rect.zero : tester.getRect(f.first);
    final primary = find.byKey(const ValueKey<String>('pawmap_primary'));
    final grip = find.byKey(const ValueKey<String>('pawmap_sheet_grip'));
    final chip = find.byKey(const ValueKey<String>('pawmap_status_friends_only'));
    final bar = find.byType(PawTabBar);
    final sheet = find.byType(DraggableScrollableSheet);
    print('[SONDE] primary=${r(primary)} grip=${r(grip)} chip=${r(chip)} sheet=${r(sheet)} tabbar=${r(bar)}');
    // Sonde de hit-test : qui reçoit un toucher à ces points ?
    final primaryRO = tester.renderObject(primary.first);
    final barRO = bar.evaluate().isEmpty ? null : tester.renderObject(bar.first);
    bool under(RenderObject? t, RenderObject? anc) {
      RenderObject? o = t;
      while (o != null) { if (identical(o, anc)) return true; o = o.parent; }
      return false;
    }
    final pr = r(primary);
    final pts = <String, Offset>{
      'bouton centre': pr.center,
      'bouton gauche': Offset(pr.left + 30, pr.center.dy),
      'bouton bas-centre': Offset(pr.center.dx, pr.bottom - 4),
      'poignee': r(grip).center,
      'chip': r(chip).center,
    };
    pts.forEach((name, p) {
      final res = HitTestResult();
      RendererBinding.instance.hitTestInView(res, p, tester.view.viewId);
      final targets = res.path.map((e) => e.target).whereType<RenderObject>().toList();
      final toBar = targets.any((t) => under(t, barRO));
      final toPrimary = targets.any((t) => under(t, primaryRO));
      print('[SONDE-R] $name @$p -> menu=${toBar} bouton=${toPrimary} premier=${targets.isEmpty ? '-' : targets.first.runtimeType}');
    });
    print('[SONDE] READY tapX=${(pr.left + 40) * dpr} tapY=${pr.center.dy * dpr} gripX=${r(grip).center.dx * dpr} gripY=${r(grip).center.dy * dpr}');
    // 70 s : on laisse l'hôte taper / glisser (adb input) et on journalise.
    final nav = Navigator.of(ctx);
    final basePop = nav.canPop();
    print('[SONDE] canPop initial=$basePop');
    double? lastGrip;
    var upFor = 0;
    var selfTapped = false;
    String lastP = '';
    for (var i = 0; i < 700; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (kSelfGestures && i == 20) {
        print('[SONDE] geste : glissement (test)');
        await tester.timedDragFrom(r(grip).center, const Offset(0, -250),
            const Duration(milliseconds: 300));
      }
      {
        final d = tester.widget<DraggableScrollableSheet>(sheet);
        final cc = d.controller;
        final sz = (cc != null && cc.isAttached) ? cc.size.toStringAsFixed(3) : '-';
        final pstr = 'min=${d.minChildSize.toStringAsFixed(3)} init=${d.initialChildSize.toStringAsFixed(3)} max=${d.maxChildSize.toStringAsFixed(3)} size=$sz';
        if (pstr != lastP) { print('[SONDE] ${DateTime.now().toIso8601String().substring(11, 22)} t=${i / 10}s $pstr'); lastP = pstr; }
      }
      final g = r(grip).top;
      if (lastGrip == null || (g - lastGrip).abs() > 2) print('[SONDE] t=${i / 10}s poignee.top=$g');
      lastGrip = g;
      final dss = tester.widget<DraggableScrollableSheet>(sheet);
      final c = dss.controller;
      if (c != null && c.isAttached && c.size > dss.minChildSize + 0.05) {
        upFor++;
        if (upFor == 1) print('[SONDE] t=${i / 10}s FEUILLE MONTEE par un vrai glissement (taille ${c.size.toStringAsFixed(2)})');
        if (upFor >= 15) {
          c.jumpTo(dss.minChildSize); upFor = 0; print('[SONDE] feuille remise en bas');
          if (kSelfGestures && !selfTapped) {
            selfTapped = true;
            await tester.pump(const Duration(seconds: 2));
            print('[SONDE] geste : tap bouton (test)');
            await tester.tapAt(r(primary).center);
          }
        }
      }
      final opened = find.byType(Dialog).evaluate().isNotEmpty ||
          find.byType(BottomSheet).evaluate().isNotEmpty || (nav.canPop() && !basePop);
      if (opened) {
        print('[SONDE] t=${i / 10}s OUVERT par un vrai toucher');
        await tester.pump(const Duration(seconds: 2));
        await _closeAll(tester);
      }
    }
    (tester.binding as LiveTestWidgetsFlutterBinding).shouldPropagateDevicePointerEvents = false;
    if (kInset0) await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}
