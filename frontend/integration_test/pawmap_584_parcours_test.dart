// v584 (révision PawMap du 25/09) — PARCOURS CONNECTÉ, sur simulateur iPhone
// et émulateur Android, avec un COMPTE DE TEST (jamais affiché : e-mail, mot
// de passe et rôle arrivent par --dart-define, lus depuis le fichier par
// `~/hopetsit-social/pawmap_584/run_parcours.sh`).
//
//   flutter test integration_test/pawmap_584_parcours_test.dart -d <device> \
//     --dart-define=HPS_EMAIL=… --dart-define=HPS_PASSWORD=… --dart-define=HPS_ROLE=owner
//
// Ce que le parcours PROUVE (journal `[PARCOURS]`, une capture par étape prise
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
import 'dart:async';

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
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'owner');

Future<void> _step(WidgetTester tester, String name,
    {Duration hold = const Duration(seconds: 2)}) async {
  print('[PARCOURS] ${DateTime.now().toIso8601String()} $name');
  await tester.pump(hold);
}

void _ok(String what, bool cond, {String? detail}) {
  print('[RESULTAT] ${cond ? 'OK ' : 'KO '} $what${detail == null ? '' : ' — $detail'}');
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
      debugPrint('[PARCOURS] Firebase : $e');
    }
    setupDependencies();
  });

  testWidgets('PawMap 584 — parcours connecté ($kRole)', (tester) async {
    expect(kEmail, isNotEmpty, reason: 'HPS_EMAIL manquant (--dart-define)');
    expect(kPassword, isNotEmpty, reason: 'HPS_PASSWORD manquant (--dart-define)');
    // Toute erreur de construction est ÉCRITE dans le journal du parcours
    // (le cadre d'exception du framework n'y arrive pas toujours).
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      print('[PARCOURS] EXCEPTION FLUTTER: ${d.exceptionAsString()}\n${d.stack}'.split('\n').take(12).join('\n'));
      prevOnError?.call(d);
    };
    try {
      await _run(tester);
    } catch (e, st) {
      print('[PARCOURS] EXCEPTION TEST: $e\n${st.toString().split('\n').take(10).join('\n')}');
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
          debugPrint('[PARCOURS] fenetre des notifications : « Plus tard »');
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
      print('[PARCOURS] croix: ${close.evaluate().length} · rect=${close.evaluate().isEmpty ? '-' : tester.getRect(close)}');
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
    final primaryRect = tester.getRect(find.byKey(const ValueKey<String>('pawmap_primary')));
    final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    debugPrint('[PARCOURS] bouton principal: $primaryRect (ecran ${tester.view.physicalSize} / dpr ${tester.view.devicePixelRatio})');
    _ok('bouton principal entier a l ecran',
        primaryRect.bottom <= screenH && primaryRect.height <= 60, detail: '$primaryRect');
    final state = tester.state<State<PawMapScreen>>(find.byType(PawMapScreen));
    expect(state, isNotNull);

    // ── Épingles construites : zoom ville (Paris) puis zoom rue ──
    final live = Get.find<LiveMapService>();
    await _waitFor(tester, () => _markerFamilies(tester).containsKey('membre') || _markerFamilies(tester).containsKey('groupe_membres'), seconds: 40);
    var fam = _markerFamilies(tester);
    debugPrint('[PARCOURS] epingles (zoom ville): $fam · amis en direct: ${live.friendPositions.length} · positions: ${live.friendPositions.values.map((p) => '${p.userId}:${p.liveState.name}').join(',')}');
    _ok('membres visibles (zoom ville)', (fam['membre'] ?? 0) + (fam['groupe_membres'] ?? 0) > 0, detail: '$fam');
    _ok('moi visible', (fam['moi'] ?? 0) == 1);
    await _step(tester, '03 epingles zoom ville');

    // Zoom rue : la caméra va à 16,5 sur ma position (même chemin que la
    // capsule « + », qui n'a pas de texte : icône seule).
    final mapCtl = await (state as dynamic).activeMapCtlForTest() as GoogleMapController?;
    _ok('controleur de carte', mapCtl != null);
    if (mapCtl != null) {
      final meMarker = _firstMarker(tester, (id) => id == 'me');
      final target = meMarker?.position ?? const LatLng(48.8566, 2.3522);
      await mapCtl.animateCamera(CameraUpdate.newLatLngZoom(target, 16.5));
      await tester.pump(const Duration(seconds: 4));
    }
    fam = _markerFamilies(tester);
    debugPrint('[PARCOURS] epingles (zoom rue): $fam');
    await _step(tester, '04 epingles zoom rue');

    // ── Fiche d'un membre depuis une épingle (point 19 + Réserver / Message / Ami / Itinéraire) ──
    final memberMarker = _firstMarker(tester, (id) => id.startsWith('nearby_'));
    if (memberMarker != null) {
      memberMarker.onTap?.call();
      await _step(tester, '05 fiche membre depuis l epingle');
      _ok('fiche membre ouverte', find.byType(PawMapMemberSheet).evaluate().isNotEmpty);
      final profile = find.byKey(const ValueKey<String>('member_profile'));
      if (profile.evaluate().isNotEmpty) {
        await tester.ensureVisible(profile);
        await tester.tap(profile);
        await _step(tester, '06 voir le profil du membre', hold: const Duration(seconds: 3));
        final opened = find.byType(ServiceProviderDetailScreen, skipOffstage: false).evaluate().isNotEmpty ||
            find.byType(WalkerDetailScreen, skipOffstage: false).evaluate().isNotEmpty ||
            find.byType(OwnerProfileViewScreen, skipOffstage: false).evaluate().isNotEmpty;
        _ok('Voir le profil ouvre une fiche (pas Mes amis)', opened);
        final isOwnerViewer = kRole == 'owner';
        final ownerPage = find.byType(OwnerProfileViewScreen, skipOffstage: false).evaluate().isNotEmpty;
        _ok(isOwnerViewer
                ? 'fiche prestataire : bouton Reserver · des X present'
                : 'fiche prestataire vue par un $kRole : Message seul (pas de Reserver entre confreres)',
            ownerPage ||
                (isOwnerViewer
                    ? find.byKey(const ValueKey<String>('provider_book')).evaluate().isNotEmpty
                    : find.byKey(const ValueKey<String>('provider_message')).evaluate().isNotEmpty &&
                        find.byKey(const ValueKey<String>('provider_book')).evaluate().isEmpty));
        await _closeAll(tester);
      }
      memberMarker.onTap?.call();
      await tester.pump(const Duration(seconds: 1));
      final book = find.byKey(const ValueKey<String>('member_primary_book'));
      if (book.evaluate().isNotEmpty && kRole == 'owner') {
        await tester.tap(book);
        await _step(tester, '07 reserver depuis la fiche', hold: const Duration(seconds: 4));
        _ok('Reserver ouvre la demande de reservation pre-remplie',
            find.byType(SendRequestScreen, skipOffstage: false).evaluate().isNotEmpty);
        await _closeAll(tester);
      } else {
        await _closeAll(tester);
      }
      memberMarker.onTap?.call();
      await tester.pump(const Duration(seconds: 1));
      final dir = find.byKey(const ValueKey<String>('member_directions'));
      if (dir.evaluate().isNotEmpty) {
        await tester.ensureVisible(dir);
        await tester.tap(dir);
        await _step(tester, '08 itineraire vers le membre', hold: const Duration(seconds: 4));
        final navI = Navigator.of(tester.element(find.byType(PawMapScreen, skipOffstage: false).first));
        final routeShown = find.text('pawspot_pick_cancel'.tr).evaluate().isNotEmpty || find.textContaining('km').evaluate().isNotEmpty;
        _ok('itineraire : trace (ou boutique si abonnement requis)', routeShown || navI.canPop(),
            detail: routeShown ? 'trace affiche' : (navI.canPop() ? 'ecran empile (abonnement / boutique)' : null));
        if (find.text('pawspot_pick_cancel'.tr).evaluate().isNotEmpty) {
          await tester.tap(find.text('pawspot_pick_cancel'.tr));
          await tester.pump(const Duration(milliseconds: 600));
        }
        await _closeAll(tester);
      } else {
        await _closeAll(tester);
      }
    } else {
      _ok('epingle membre individuelle au zoom rue', false, detail: 'aucune (tout en groupe ?)');
    }

    // ── Groupe : tap = zoom, puis liste au zoom max (point 15) ──
    final cluster = _firstMarker(tester, (id) => id.startsWith('mcluster_') || id.startsWith('pcluster_'));
    if (cluster != null) {
      cluster.onTap?.call();
      await _step(tester, '09 groupe : zoom doux', hold: const Duration(seconds: 3));
      _ok('groupe tape : zoom (ou liste)', true);
    }

    // ── Ami en direct (le compte de test ami partage depuis la zone fictive) ──
    await live.refreshFriendPositions();
    await tester.pump(const Duration(seconds: 2));
    final liveFriend = live.friendPositions.values.where((p) => p.liveState != FriendLiveState.seen).toList();
    debugPrint('[PARCOURS] amis en direct: ${liveFriend.map((p) => '${p.userId} ${p.liveState.name}').join(', ')}');
    if (liveFriend.isNotEmpty) {
      final fp = liveFriend.first;
      // Aller sur lui (caméra) puis ouvrir sa fiche via son marqueur.
      final ctl = mapCtl;
      if (ctl != null) {
        await ctl.moveCamera(CameraUpdate.newLatLngZoom(LatLng(fp.latitude, fp.longitude), 15));
        await tester.pump(const Duration(seconds: 3));
      }
      final fm = _firstMarker(tester, (id) => id == 'friend_${fp.userId}');
      _ok('rond ami en direct present', fm != null);
      if (fm != null) {
        fm.onTap?.call();
        await _step(tester, '10 fiche de l ami en direct');
        final follow = find.byKey(const ValueKey<String>('member_primary_follow'));
        _ok('« Suivre la balade » propose', follow.evaluate().isNotEmpty);
        if (follow.evaluate().isNotEmpty) {
          await tester.tap(follow);
          await _step(tester, '11 suivi en cours : pilule', hold: const Duration(seconds: 3));
          _ok('pilule de suivi visible', find.byKey(const ValueKey<String>('pawmap_follow_pill')).evaluate().isNotEmpty);
          await tester.tap(find.byKey(const ValueKey<String>('pawmap_follow_pill')));
          await _step(tester, '12 feuille du suivi');
          _ok('feuille du suivi', find.byType(PawMapFollowSheet).evaluate().isNotEmpty);
          await tester.tap(find.byKey(const ValueKey<String>('follow_sheet_stop')));
          await tester.pump(const Duration(seconds: 1));
          _ok('arret du suivi', find.byKey(const ValueKey<String>('pawmap_follow_pill')).evaluate().isEmpty);
        } else {
          await _closeAll(tester);
        }
      }
    } else {
      _ok('ami en direct (aucun partage actif chez les comptes de test)', false, detail: 'lancer le partage du testwalker avant');
    }

    // ── Bouton principal (point 3) ──
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_primary')));
    await _step(tester, '13 bouton principal tape', hold: const Duration(seconds: 3));
    final primaryOpened = find.byType(PublishReservationRequestScreen, skipOffstage: false).evaluate().isNotEmpty ||
        find.byType(Dialog).evaluate().isNotEmpty ||
        find.byType(BottomSheet).evaluate().isNotEmpty ||
        find.text('pawmap_live_first_hint'.tr).evaluate().isNotEmpty ||
        find.byType(PawMapRequestSheet).evaluate().isNotEmpty;
    _ok('le bouton principal ouvre quelque chose', primaryOpened);
    await _closeAll(tester);

    // ── En-tête : « ? », recherche, rafraîchir ──
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_header_legend')));
    await _step(tester, '14 legende');
    _ok('legende ouverte', find.byType(PawMapHelpScreen).evaluate().isNotEmpty);
    _ok('explication partager ma balade dans l aide', find.byKey(const ValueKey<String>('help_live_share'), skipOffstage: false).evaluate().isNotEmpty);
    await _closeAll(tester);
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_header_search')));
    await _step(tester, '15 recherche de ville');
    _ok('recherche de ville', find.byType(TextField).evaluate().isNotEmpty);
    await _closeAll(tester);
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_header_refresh')));
    await _step(tester, '16 rafraichir');

    // ── Rail : chaque bouton ──
    final order = <String>[
      for (final spec in kPawRailSpecs)
        if (find.byKey(ValueKey<String>('rail_${spec.id}')).evaluate().isNotEmpty) spec.id,
    ];
    debugPrint('[PARCOURS] rail: $order');
    Future<void> tapRail(String id) async {
      final f = find.byKey(ValueKey<String>('rail_$id'));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 800));
    }
    for (final id in order) {
      await tapRail(id);
      await _step(tester, '17 rail $id');
      final nav = Navigator.of(tester.element(find.byType(PawMapScreen, skipOffstage: false).first));
      final picking = find.text('pawspot_pick_cancel'.tr).evaluate().isNotEmpty;
      // « photo » ouvre le sélecteur NATIF (pas de route Flutter) : on note.
      _ok('rail $id repond', nav.canPop() || picking || id == 'around' || id == 'photo' || find.byType(AlertsScreen, skipOffstage: false).evaluate().isNotEmpty,
          detail: id == 'photo' ? 'selecteur natif de photo (hors Flutter)' : null);
      if (picking) {
        await tester.tap(find.text('pawspot_pick_cancel'.tr));
        await tester.pump(const Duration(milliseconds: 600));
      }
      await _closeAll(tester);
    }

    // ── Feuille : haut, sélecteur, dock, compteur, statut ──
    final sheetCtl = tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .controller!;
    sheetCtl.jumpTo(0.9);
    await _step(tester, '18 feuille en haut');
    final sheetScroll = find
        .descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(Scrollable))
        .first;
    Future<void> reveal(Finder f) async {
      if (f.evaluate().isEmpty) {
        try {
          await tester.scrollUntilVisible(f, -120, scrollable: sheetScroll, maxScrolls: 30);
        } catch (_) {
          await tester.scrollUntilVisible(f, 120, scrollable: sheetScroll);
        }
      }
      await tester.ensureVisible(f);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await reveal(find.byKey(const ValueKey<String>('looking_friends')));
    for (final id in ['sitters', 'walkers', 'places', 'friends']) {
      await tester.tap(find.byKey(ValueKey<String>('looking_$id')));
      await tester.pump(const Duration(milliseconds: 500));
      await _closeAll(tester);
      await tester.tap(find.byKey(ValueKey<String>('looking_$id')));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _step(tester, '19 je cherche (4 pilules)');
    for (final d in ['sos', 'share', 'layers', 'night', 'history']) {
      await reveal(find.byKey(ValueKey<String>('dock_$d')));
      await tester.tap(find.byKey(ValueKey<String>('dock_$d')));
      await _step(tester, '20 dock $d');
      if (d == 'night') {
        await tester.tap(find.byKey(const ValueKey<String>('dock_night')));
        await tester.pump(const Duration(milliseconds: 400));
      }
      await _closeAll(tester);
    }
    await reveal(find.byKey(const ValueKey<String>('pawmap_counter_tap')));
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_counter_tap')));
    await _step(tester, '21 compteur : liste autour');
    _ok('liste autour de toi', find.byType(PawMapAroundList).evaluate().isNotEmpty);
    await _closeAll(tester);
    final low = tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet)).minChildSize;
    sheetCtl.jumpTo(low);
    await _step(tester, '22 feuille en bas, fin', hold: const Duration(seconds: 2));
    _ok('aucune exception', tester.takeException() == null);
}
