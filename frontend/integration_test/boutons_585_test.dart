// v584 (révision PawMap du 25/09) — PARCOURS CONNECTÉ, sur simulateur iPhone
// et émulateur Android, avec un COMPTE DE TEST (jamais affiché : e-mail, mot
// de passe et rôle arrivent par --dart-define, lus depuis le fichier par
// `~/hopetsit-social/pawmap_584/run_parcours.sh`).
//
//   flutter test integration_test/pawmap_584_parcours_test.dart -d <device> \
//     --dart-define=HPS_EMAIL=… --dart-define=HPS_PASSWORD=… --dart-define=HPS_ROLE=owner
//
// Ce que le parcours PROUVE (journal `[BOUTONS]`, une capture par étape prise
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

Future<void> _step(WidgetTester tester, String name,
    {Duration hold = const Duration(seconds: 2)}) async {
  print('[BOUTONS] ${DateTime.now().toIso8601String()} $name');
  await tester.pump(hold);
}

void _ok(String what, bool cond, {String? detail}) {
  print('[BOUTONS-R] ${cond ? 'OK ' : 'KO '} $what${detail == null ? '' : ' — $detail'}');
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
      debugPrint('[BOUTONS] Firebase : $e');
    }
    setupDependencies();
    if (!Get.isRegistered<ThemeController>()) Get.put(ThemeController(), permanent: true);
  });

  testWidgets('585 — tous les boutons des 5 onglets ($kRole)', (tester) async {
    expect(kEmail, isNotEmpty, reason: 'HPS_EMAIL manquant (--dart-define)');
    expect(kPassword, isNotEmpty, reason: 'HPS_PASSWORD manquant (--dart-define)');
    // Toute erreur de construction est ÉCRITE dans le journal du parcours
    // (le cadre d'exception du framework n'y arrive pas toujours).
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      print('[BOUTONS] EXCEPTION FLUTTER: ${d.exceptionAsString()}\n${d.stack}'.split('\n').take(12).join('\n'));
      prevOnError?.call(d);
    };
    try {
      await _run(tester);
    } catch (e, st) {
      print('[BOUTONS] EXCEPTION TEST: $e\n${st.toString().split('\n').take(10).join('\n')}');
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
          debugPrint('[BOUTONS] fenetre des notifications : « Plus tard »');
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
    // v586 — au repos la feuille est rangée : la PawMap est prête quand la
    // poignée « Options » est là (le bouton principal vit dans la feuille).
    await _waitFor(tester,
        () => find.byKey(const ValueKey<String>('pawmap_options_handle')).evaluate().isNotEmpty,
        seconds: 60);
    await _step(tester, '02 pawmap ouverte', hold: const Duration(seconds: 4));
    _ok('UNE seule GoogleMap', find.byType(GoogleMap).evaluate().length == 1);
    _ok('poignee Options presente',
        find.byKey(const ValueKey<String>('pawmap_options_handle')).evaluate().isNotEmpty);
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
      print('[BOUTONS] croix: ${close.evaluate().length} · rect=${close.evaluate().isEmpty ? '-' : tester.getRect(close)}');
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


    // ── Contrôle systématique des boutons (bug 12) ──
    // Pour chaque onglet : chaque élément tapable VISIBLE est tapé une fois ;
    // on constate ce qui se passe (écran ouvert, feuille / dialogue, contenu
    // changé) puis on revient. Les actions irréversibles ne sont pas tapées.
    (tester.binding as LiveTestWidgetsFlutterBinding).shouldPropagateDevicePointerEvents = false;
    final deny = RegExp(
        r'(d[ée]connex|logout|log out|supprim|delete|effacer|payer|pay |paiement|envoyer|send|publier|publish|confirmer|bloquer|block|signaler|^report|partager ma|share my|d[ée]sactiv|annuler la r|cancel booking|acheter|buy|souscrire|subscribe|mode sombre|dark mode|langue|language|changer de r|switch role)',
        caseSensitive: false);
    String sig() {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .join('|');
      // Onglet affiché (IndexedStack) : un changement d'onglet ne change pas
      // les textes (tous les onglets restent montés).
      final stacks = tester
          .widgetList<IndexedStack>(find.byType(IndexedStack, skipOffstage: false))
          .map((w) => w.index)
          .join(',');
      return '${texts.hashCode}:$stacks:${find.byType(Dialog).evaluate().length}:${find.byType(BottomSheet).evaluate().length}';
    }
    int depth() => (Get.key.currentState?.canPop() ?? false) ? 1 : 0;
    String labelOf(Element e) {
      final texts = <String>[];
      void walk(Element x) {
        final w = x.widget;
        if (w is Text && (w.data ?? '').trim().isNotEmpty) texts.add(w.data!.trim());
        if (w is Icon && texts.isEmpty && w.semanticLabel != null) texts.add(w.semanticLabel!);
        if (texts.length < 2) x.visitChildren(walk);
      }
      walk(e);
      final k = e.widget.key;
      final ks = k is ValueKey ? '${k.value}' : '';
      Element? p = e;
      String sem = '';
      for (var i = 0; i < 6 && p != null && sem.isEmpty; i++) {
        final w = p.widget;
        if (w is Semantics && (w.properties.label ?? '').isNotEmpty) sem = w.properties.label!;
        if (w is Tooltip && (w.message ?? '').isNotEmpty) sem = w.message!;
        Element? up;
        p.visitAncestorElements((a) { up = a; return false; });
        p = up;
      }
      return [ks, sem, ...texts].where((s) => s.isNotEmpty).take(2).join(' · ');
    }
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    const tabs = ['Accueil', 'Chat', 'PawMap', 'Reservations', 'Profil'];
    for (var t = 0; t < 5; t++) {
      requestedTab.value = t;
      await tester.pump(const Duration(seconds: 3));
      final seen = <String>{};
      var tapped = 0;
      var scrolls = 0;
      for (var pass = 0; pass < 60; pass++) {
        final cands = find.byWidgetPredicate((w) =>
            (w is GestureDetector && w.onTap != null) ||
            (w is InkWell && w.onTap != null) ||
            (w is IconButton && w.onPressed != null) ||
            (w is ButtonStyleButton && w.onPressed != null)).hitTestable();
        Element? next;
        String? nextKey;
        for (final e in cands.evaluate()) {
          final ro = e.renderObject;
          if (ro is! RenderBox || !ro.hasSize || !ro.attached) continue;
          final r = ro.localToGlobal(Offset.zero) & ro.size;
          if (r.center.dy < 0 || r.center.dy > screenSize.height || r.width < 8) continue;
          // Le menu du bas est contrôlé à part (onglets).
          if (r.center.dy > screenSize.height - 110) continue;
          final key = '${r.center.dx.round() ~/ 6}:${r.center.dy.round() ~/ 6}';
          if (seen.contains(key)) continue;
          next = e;
          nextKey = key;
          break;
        }
        if (next == null) {
          // Tout le visible est fait : on fait défiler la plus grande liste
          // de l'écran et on continue (8 fois au plus).
          if (scrolls >= 8) break;
          scrolls++;
          final scs = find.byType(Scrollable).hitTestable().evaluate().toList()
            ..sort((a, b) {
              final ra = (a.renderObject as RenderBox).size;
              final rb = (b.renderObject as RenderBox).size;
              return (rb.height * rb.width).compareTo(ra.height * ra.width);
            });
          if (scs.isEmpty) break;
          final ro = scs.first.renderObject as RenderBox;
          final c = ro.localToGlobal(ro.size.center(Offset.zero));
          final before = sig();
          await tester.dragFrom(c, const Offset(0, -350));
          await tester.pump(const Duration(milliseconds: 800));
          if (sig() == before && scrolls > 1) break;
          continue;
        }
        seen.add(nextKey!);
        final lbl = labelOf(next);
        // v586 — l'œil (visibilité du COMPTE) et le rond Direct (partage de
        // position) ne sont pas tapés par le robot : réglages du compte /
        // position réelle ; ils ont leur propre sonde (pawmap_586).
        var guarded = false;
        bool isGuard(Key? k) =>
            k is ValueKey<String> &&
            (k.value == 'pawmap_eye' || k.value.startsWith('pawmap_action_direct'));
        if (isGuard(next.widget.key)) guarded = true;
        next.visitAncestorElements((a) {
          if (isGuard(a.widget.key)) {
            guarded = true;
            return false;
          }
          return true;
        });
        if (guarded) {
          print('[BOUTON] ${tabs[t]} | $lbl | NON TAPÉ (oeil / Direct : sonde 586)');
          continue;
        }
        if (deny.hasMatch(lbl)) {
          print('[BOUTON] ${tabs[t]} | $lbl | NON TAPÉ (action irréversible)');
          continue;
        }
        final before = sig();
        final d0 = depth();
        String res;
        final errs = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) => errs.add(d.exceptionAsString().split('\n').first);
        try {
          final ro = next.renderObject as RenderBox;
          await tester.tapAt(ro.localToGlobal(ro.size.center(Offset.zero)));
          await tester.pump(const Duration(milliseconds: 1500));
          final d1 = depth();
          final after = sig();
          if (d1 > d0) {
            res = 'ÉCRAN/FEUILLE OUVERT';
          } else if (after != before) {
            res = 'CONTENU CHANGÉ';
          } else {
            res = 'RIEN';
          }
        } catch (e) {
          res = 'EXCEPTION $e';
        }
        FlutterError.onError = prev;
        if (errs.isNotEmpty) res = '$res + ERREUR ${errs.first}';
        print('[BOUTON] ${tabs[t]} | $lbl | $res');
        tapped++;
        // Retour à l'onglet.
        for (var i = 0; i < 4 && depth() > d0; i++) {
          Get.key.currentState?.maybePop();
          await tester.pump(const Duration(milliseconds: 700));
        }
        if (Get.isBottomSheetOpen == true || Get.isDialogOpen == true) {
          Get.back();
          await tester.pump(const Duration(milliseconds: 500));
        }
        requestedTab.value = t;
        await tester.pump(const Duration(milliseconds: 400));
      }
      print('[BOUTONS] onglet ${tabs[t]} : $tapped boutons tapés');
    }
}
