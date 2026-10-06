// ignore_for_file: avoid_print
// 612 §8 (ZOE, 05/10/2026) — CIRCUIT DE L'ARGENT dans l'APP RÉELLE (main de l'app,
// vrais appuis), branchée sur le BANC LOCAL (backend/scripts/banc_local_612.js,
// 127.0.0.1, base en mémoire, comptes locaux jetables) — jamais la production.
//
//   flutter test integration_test/zoe612_circuit_test.dart -d <udid> \
//     --dart-define=HPS_API_ROOT=http://127.0.0.1:5612 --dart-define=Z_ROLE=owner|walker|sitter \
//     --dart-define=Z_EMAIL=… --dart-define=Z_PW=… (lus dans l'état du banc, jamais affichés)
//
// « [CAP] nom » : l'hôte prend la capture (xcrun simctl io … screenshot).
// « [RESULTAT] OK|KO … » : une ligne par étape. « [ECRAN] » : textes visibles.
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/main.dart' as app;
import 'package:hopetsit/services/meta_events_service.dart';
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const String kRoot = String.fromEnvironment('HPS_API_ROOT');
const String kRole = String.fromEnvironment('Z_ROLE', defaultValue: 'owner');
const String kEmail = String.fromEnvironment('Z_EMAIL');
const String kPw = String.fromEnvironment('Z_PW');
const String kOwnerTok = String.fromEnvironment('Z_OWNER_TOKEN');
const String kOwnerId = String.fromEnvironment('Z_OWNER_ID');
const String kWalkerTok = String.fromEnvironment('Z_WALKER_TOKEN');
const String kSitterTok = String.fromEnvironment('Z_SITTER_TOKEN');
const String kPetId = String.fromEnvironment('Z_PET_ID');

final List<String> _res = <String>[];
void _ok(String what, bool cond, [String detail = '']) {
  final l = '${cond ? 'OK ' : 'KO '} | $what${detail.isEmpty ? '' : ' | $detail'}';
  _res.add(l);
  print('[RESULTAT] $l');
}

Future<void> _pump(WidgetTester t, int ms) => t.pump(Duration(milliseconds: ms));
Future<void> _wait(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 250; i++) {
    await _pump(t, 250);
  }
}

Future<void> _cap(WidgetTester t, String name) async {
  await _pump(t, 500);
  print('[CAP] $name');
  for (var i = 0; i < 8; i++) {
    await _pump(t, 200);
  }
}

bool _has(Finder f) => f.evaluate().isNotEmpty;
bool _hppOpen() => _has(find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == '_AirwallexCheckoutScreen'));
Finder _key(String k) => find.byKey(ValueKey<String>(k));
Future<bool> _waitFor(WidgetTester t, bool Function() c, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 4; i++) {
    if (c()) return true;
    await _pump(t, 250);
  }
  return c();
}

/// Textes visibles à l'écran (ce que la personne lit), dans l'ordre.
List<String> _texts() {
  final out = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget as Text;
    final s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
    if (s.isNotEmpty && !out.contains(s)) out.add(s.replaceAll('\n', ' '));
  }
  return out;
}

void _dump(String name) {
  final t = _texts();
  print('[ECRAN] $name (${t.length}) : ${t.take(60).join(' ¦ ')}');
}

Future<bool> _tapText(WidgetTester t, String text, {int settle = 1500, bool last = false}) async {
  final f = find.text(text);
  if (!_has(f)) return false;
  final target = last ? f.last : f.first;
  try {
    await t.ensureVisible(target);
  } catch (_) {}
  await _pump(t, 250);
  await t.tap(target, warnIfMissed: false);
  await _wait(t, settle);
  return true;
}

Future<bool> _tapKey(WidgetTester t, String k, {int settle = 1500}) async {
  final f = _key(k);
  if (!_has(f)) return false;
  try {
    await t.ensureVisible(f.first);
  } catch (_) {}
  await _pump(t, 250);
  await t.tap(f.first, warnIfMissed: false);
  await _wait(t, settle);
  return true;
}

Future<Map<String, dynamic>> _api(String method, String path, String token, [Map<String, dynamic>? body]) async {
  final uri = Uri.parse('$kRoot/api/v1$path');
  final h = <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $token', 'X-App-Version': '612'};
  final r = method == 'GET'
      ? await http.get(uri, headers: h)
      : await http.post(uri, headers: h, body: jsonEncode(body ?? <String, dynamic>{}));
  Map<String, dynamic> j = <String, dynamic>{};
  try {
    final d = jsonDecode(r.body);
    if (d is Map<String, dynamic>) j = d;
  } catch (_) {}
  return <String, dynamic>{'status': r.statusCode, ...j};
}

DateTime _start() {
  final d = DateTime.now().toUtc().add(const Duration(days: 3));
  return DateTime.utc(d.year, d.month, d.day, 9);
}

Future<void> _goTab(WidgetTester t, int i) async {
  final bar = find.byType(PawTabBar);
  if (!_has(bar)) return;
  if (!await _tapKey(t, 'paw_tab_$i', settle: 1800)) {
    t.widget<PawTabBar>(bar).onTap(i);
    await _wait(t, 1800);
  }
}

Future<void> _back(WidgetTester t) async {
  final nav = Get.key.currentState;
  if (nav != null && nav.canPop()) nav.pop();
  await _wait(t, 1200);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('612 §8 — circuit de l’argent, rôle $kRole (banc local)', (t) async {
    expect(kRoot.startsWith('http://127.0.0.1'), isTrue, reason: 'ce parcours ne tourne QUE sur le banc local');
    expect(kPw, isNotEmpty);
    PushNotificationService.skipInitForIntegrationTests = true;
    MetaEventsService.skipTrackingPromptForTests = true;
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    await SecureTokenStore.instance.migrateFromLegacyIfNeeded();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}
    setupDependencies();
    Get.put(ThemeController(), permanent: true);
    final errors = <String>[];
    FlutterError.onError = (FlutterErrorDetails d) {
      final s = d.exceptionAsString().split('\n').first;
      if (!errors.contains(s)) errors.add(s);
      print('[ERREUR FLUTTER] $s');
    };
    WidgetsBinding.instance.platformDispatcher.onError = (Object e, StackTrace st) {
      print('[ERREUR ASYNC] $e');
      return true;
    };
    await GetStorage().write('pawmap_intro_seen_count', 1);
    print('[ETAPE] démarrage de l’app');
    await t.pumpWidget(app.MyApp());
    await _wait(t, 4000);
    print('[ETAPE] app affichée, menu présent : ${_has(find.byType(PawTabBar))}');
    // Session déjà ouverte sur ce simulateur : on la garde si c'est le bon compte ;
    // sinon VRAIE déconnexion, attendue jusqu'au bout (une déconnexion laissée en
    // suspens garde l'ancienne prise temps réel : faux résultat de mesure).
    String sessionEmail() {
      final p = GetStorage().read<Map<String, dynamic>>('user_profile') ?? GetStorage().read<Map<String, dynamic>>('userProfile');
      return (p?['email'] ?? '').toString().toLowerCase();
    }

    var logged = _has(find.byType(PawTabBar)) && sessionEmail() == kEmail.toLowerCase();
    print('[ETAPE] session existante pour ce compte : $logged');
    if (!logged) {
      if (_has(find.byType(PawTabBar)) && Get.isRegistered<AuthController>()) {
        var finished = false;
        // ignore: unawaited_futures
        Get.find<AuthController>().logout().whenComplete(() => finished = true);
        await _waitFor(t, () => finished && _has(find.byType(LoginScreen)), seconds: 20);
        print('[ETAPE] ancienne session fermée (terminée : $finished)');
        if (!finished) {
          // La déconnexion attend un service tiers qui ne répond pas sur le
          // simulateur : on finit nous-mêmes le ménage essentiel (jeton, prise).
          try {
            await SecureTokenStore.instance.clear();
            await GetStorage().remove('auth_token');
            await GetStorage().remove('user_profile');
            if (Get.isRegistered<SocketService>()) Get.find<SocketService>().resetForLogout();
          } catch (e) {
            print('[ETAPE] ménage de session : $e');
          }
          Get.offAll(() => const LoginScreen());
          await _wait(t, 2000);
          print('[ETAPE] session nettoyée à la main');
        }
      }
      if (!_has(find.byType(LoginScreen))) {
        Get.to(() => const LoginScreen());
        await _wait(t, 1500);
      }
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), kEmail);
      await _pump(t, 300);
      await t.enterText(fields.at(1), kPw);
      await _pump(t, 300);
      FocusManager.instance.primaryFocus?.unfocus();
      await _pump(t, 400);
      final loginBtn = find.widgetWithText(CustomButton, 'title_login'.tr);
      if (_has(loginBtn)) {
        await t.ensureVisible(loginBtn);
        await _pump(t, 300);
        await t.tap(loginBtn, warnIfMissed: false);
      }
      logged = await _waitFor(t, () => _has(find.byType(PawTabBar)), seconds: 25);
      if (!logged) {
        await Get.find<AuthController>().login();
        logged = await _waitFor(t, () => _has(find.byType(PawTabBar)), seconds: 25);
      }
    }
    _ok('connexion ($kRole) et menu du bas', logged);
    if (!logged) {
      _dump('après connexion');
      fail('connexion impossible sur le banc local');
    }
    await _wait(t, 3000);
    // Fenêtres d'accueil éventuelles (promo, notifications…) : on les ferme.
    for (var i = 0; i < 3; i++) {
      final nav = Get.key.currentState;
      if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
        nav?.pop();
        await _wait(t, 800);
      }
    }
    // La prise temps réel : connectée après la connexion ? (c'est elle qui fait
    // monter la cloche et la pastille sans rien toucher.)
    final sock = Get.find<SocketService>();
    final up = await _waitFor(t, () => sock.isConnected, seconds: 10);
    String rooms = '';
    try {
      final r = await http.get(Uri.parse('${kRoot.replaceFirst('5612', '5613')}/__banc/sockets'));
      rooms = r.body;
    } catch (_) {}
    _ok('prise temps réel connectée après la connexion', up, 'vue par le serveur : $rooms');
    try {
      sock.socket?.onAny((String ev, dynamic data) => print('[PRISE] reçu : $ev ${data is Map ? (data['type'] ?? '') : ''}'));
    } catch (e) {
      print('[PRISE] écoute impossible : $e');
    }
    await _cap(t, '${kRole}_01_accueil');
    _dump('accueil');

    if (kRole == 'owner') {
      await _owner(t);
    } else {
      await _provider(t);
    }

    print('[RESULTAT] ---- erreurs Flutter vues : ${errors.length} ${errors.take(5).join(' // ')}');
    for (final l in _res) {
      print('[BILAN] $l');
    }
  });
}

Future<void> _owner(WidgetTester t) async {
  // 1. PORTE ACCUEIL : les deux cartes ouvrent le formulaire de publication.
  for (final k in <String>['owner_action_walking', 'owner_action_sitting']) {
    final ok = await _tapKey(t, k, settle: 2000);
    final open = _has(find.byType(PublishReservationRequestScreen));
    _ok('1 porte ACCUEIL : « $k » ouvre le formulaire Publier', ok && open, 'appui pris : $ok');
    if (open) {
      await _cap(t, 'owner_02_publier_$k');
      if (k == 'owner_action_walking') _dump('formulaire publier (balade)');
      await _back(t);
    }
  }
  // 1 bis. PORTE PAWMAP : le bouton « Publier » de la carte ouvre le MÊME formulaire.
  await _goTab(t, 2);
  await _wait(t, 6000);
  await _cap(t, 'owner_03_pawmap');
  final okMap = await _tapKey(t, 'pawmap_action_publish', settle: 2500);
  final openMap = _has(find.byType(PublishReservationRequestScreen));
  _ok('1 porte PAWMAP : le bouton « Publier » ouvre le formulaire Publier', okMap && openMap, 'bouton trouvé : $okMap');
  if (openMap) {
    await _cap(t, 'owner_04_publier_depuis_pawmap');
    await _back(t);
  } else {
    _dump('pawmap (bouton Publier introuvable ?)');
  }
  await _goTab(t, 0);

  // 2. La demande est publiée (même appel que le formulaire : POST /posts), puis un promeneur postule.
  final s = _start();
  final pub = await _api('POST', '/posts', kOwnerTok, <String, dynamic>{
    'body': 'Balade pour Rex', 'serviceTypes': <String>['dog_walking'], 'serviceLocation': 'at_owner', 'walkDurationMinutes': 60,
    'startDate': s.toIso8601String(), 'endDate': s.add(const Duration(hours: 1)).toIso8601String(),
    'location': <String, dynamic>{'city': 'Zone test', 'lat': -35, 'lng': -30}, 'petIds': <String>[kPetId],
  });
  final postId = ((pub['post'] as Map?)?['id'] ?? (pub['post'] as Map?)?['_id'] ?? '').toString();
  _ok('2 demande publiée', pub['status'] == 201 && postId.isNotEmpty, 'HTTP ${pub['status']}');
  final nc = Get.find<NotificationsController>();
  final bellBefore = nc.unreadCount.value;
  final appsBefore = Get.isRegistered<ApplicationsController>() ? Get.find<ApplicationsController>().applications.length : -1;
  final ap = await _api('POST', '/applications?ownerId=$kOwnerId', kWalkerTok, <String, dynamic>{
    'petIds': <String>[kPetId], 'serviceType': 'dog_walking', 'serviceDate': DateTime.utc(s.year, s.month, s.day).toIso8601String(),
    'startDate': s.toIso8601String(), 'timeSlot': '9:00 AM', 'basePrice': 18, 'duration': 60, 'postId': postId,
  });
  final appId = ((ap['application'] as Map?)?['id'] ?? (ap['application'] as Map?)?['_id'] ?? '').toString();
  _ok('3 le promeneur postule', ap['status'] == 201, 'HTTP ${ap['status']}');

  // 4. LE PROPRIÉTAIRE EST PRÉVENU, app ouverte sur l'accueil, sans rien toucher.
  final bellLive = await _waitFor(t, () => nc.unreadCount.value > bellBefore, seconds: 8);
  _ok('4 cloche : la pastille monte toute seule (app ouverte)', bellLive, 'non lues $bellBefore → ${nc.unreadCount.value}');
  final inList = await _waitFor(t, () => nc.notifications.any((n) => n.type.toLowerCase() == 'application_new'), seconds: 4);
  _ok('4 cloche : la ligne « candidature » est dans la liste', inList,
      inList ? '« ${nc.notifications.firstWhere((n) => n.type.toLowerCase() == 'application_new').title} — ${nc.notifications.firstWhere((n) => n.type.toLowerCase() == 'application_new').body} »' : '');
  if (Get.isRegistered<ApplicationsController>()) {
    final c = Get.find<ApplicationsController>();
    final live = await _waitFor(t, () => c.applications.length > (appsBefore < 0 ? 0 : appsBefore), seconds: 6);
    _ok('4 la liste des candidats se met à jour toute seule', live, 'candidatures $appsBefore → ${c.applications.length}');
  } else {
    _ok('4 la liste des candidats se met à jour toute seule', false, 'contrôleur des candidatures pas encore créé sur l’accueil');
  }
  await _wait(t, 1500);
  // « Mes annonces » : on tire l'écran (la demande a été créée hors de cet appareil).
  // Même rechargement que le retour du formulaire « Publier » / le tirage de l'écran.
  try {
    await Get.find<PostsController>().loadPostsWithoutMedia();
  } catch (e) {
    print('[ETAPE] rechargement des annonces : $e');
  }
  await _wait(t, 2500);
  final mesAnnonces = _texts().where((x) => x.startsWith('Mes annonces')).join(' ');
  _ok('4 la demande apparaît dans « Mes annonces » de l’accueil', mesAnnonces.contains('(1)'), mesAnnonces);
  if (await _tapText(t, mesAnnonces, settle: 2500)) {
    _dump('onglet Mes annonces');
  }
  final cands = _texts().where((x) => x.toLowerCase().contains('candidat')).join(' ¦ ');
  _ok('4 la carte de la demande annonce le candidat', cands.isNotEmpty, cands);
  await _cap(t, 'owner_05_accueil_apres_candidature');
  _dump('accueil après candidature');

  // 4 bis. Depuis la cloche : appui sur la notification.
  var taps = 0;
  Get.to(() => const NotificationsScreen());
  taps++; // appui sur la cloche
  await _wait(t, 2500);
  await _cap(t, 'owner_06_cloche');
  _dump('cloche');
  final notif = nc.notifications.where((n) => n.type.toLowerCase() == 'application_new').toList();
  var opened = false;
  if (notif.isNotEmpty) {
    opened = await _tapText(t, notif.first.title, settle: 3000);
    if (!opened) opened = await _tapText(t, notif.first.body, settle: 3000);
    taps++;
  }
  _ok('4 cloche → appui sur la candidature ouvre un écran', opened);
  await _cap(t, 'owner_07_candidature_ouverte');
  _dump('candidature ouverte');

  // 5. Accepter puis payer : on compte les appuis.
  final choose = 'candidates_choose_button'.tr;
  var accepted = false;
  for (final label in <String>[choose, 'common_accept'.tr, 'Accepter', 'Choisir']) {
    if (await _tapText(t, label, settle: 1800)) {
      taps++;
      print('[PAS] appui « $label »');
      _dump('après « $label »');
      await _cap(t, 'owner_08_apres_appui_accepter');
      // Confirmation éventuelle.
      for (final c in <String>['candidates_choose_confirm'.tr, 'common_confirm'.tr, 'Confirmer', 'common_yes'.tr]) {
        if (_has(find.text(c))) {
          await t.tap(find.text(c).last, warnIfMissed: false);
          taps++;
          print('[PAS] appui de confirmation « $c »');
          final direct = await _waitFor(t, _hppOpen, seconds: 6);
          _ok('5 après « Choisir » + confirmation, la page de paiement s’ouvre TOUTE SEULE', direct, 'appuis depuis la cloche : $taps');
          if (direct) {
            await _cap(t, 'owner_08b_page_de_paiement');
            _dump('page de paiement (après Choisir)');
          }
          await _wait(t, 3500);
          break;
        }
      }
      accepted = true;
      break;
    }
  }
  final after = await _api('GET', '/applications', kOwnerTok);
  final st = ((after['applications'] as List?) ?? const <dynamic>[])
      .cast<Map>()
      .firstWhere((a) => (a['id'] ?? a['_id']).toString() == appId, orElse: () => <String, dynamic>{})['status'];
  _ok('5 accepter la candidature depuis l’app', accepted && st == 'accepted', 'statut serveur : $st · appuis jusqu’ici : $taps');
  await _wait(t, 2500);
  await _cap(t, 'owner_09_apres_acceptation');
  _dump('après acceptation');

  // Vers le paiement : on cherche le bouton proposé à l'écran, sinon on revient à l'accueil.
  var onPay = _hppOpen();
  final payLabels = <String>['booking_pay_now'.tr, 'pay_now'.tr, 'common_pay'.tr, 'Payer', 'Payer maintenant', 'Procéder au paiement'];
  Future<bool> tryPay(String where) async {
    for (final l in payLabels) {
      final f = find.textContaining(l);
      if (_has(f)) {
        try {
          await t.ensureVisible(f.first);
        } catch (_) {}
        await t.tap(f.first, warnIfMissed: false);
        taps++;
        print('[PAS] appui « $l » ($where)');
        final open = await _waitFor(t, _hppOpen, seconds: 6);
        if (open) await _cap(t, 'owner_pay_$where');
        _ok('5 « $l » depuis $where ouvre la page de paiement en 1 appui', open);
        await _wait(t, 3500);
        return open;
      }
    }
    return false;
  }

  {
    Get.until((r) => r.isFirst);
    await _wait(t, 1500);
    await _goTab(t, 0);
    await _wait(t, 2500);
    await _cap(t, 'owner_10_accueil_a_payer');
    _dump('accueil (à payer)');
    onPay = await tryPay('accueil') || onPay;
  }
  {
    Get.until((r) => r.isFirst);
    await _wait(t, 1200);
    await _goTab(t, 3);
    await _wait(t, 2500);
    await _cap(t, 'owner_11_reservations_a_payer');
    _dump('réservations (à payer)');
    onPay = await tryPay('réservations') || onPay;
  }
  Get.until((r) => r.isFirst);
  await _wait(t, 1500);

  // 5 bis. PAIEMENT SIMULÉ (aucune carte, aucun argent) : l'intention passe « réussie », le webhook arrive.
  final ctl = kRoot.replaceFirst('5612', '5613');
  // (La page Airwallex ne peut pas aboutir ici : l'intention est locale. En la fermant, l'app
  //  annule l'intention — la réservation reste payable. On rejoue donc le paiement côté
  //  serveur : nouvelle intention, « réussie », webhook.)
  final bell0 = Get.find<NotificationsController>().unreadCount.value;
  final bk0 = await _api('GET', '/bookings/my', kOwnerTok);
  final b0 = ((bk0['bookings'] as List?) ?? const <dynamic>[]).cast<Map>();
  final bookingId = b0.isEmpty ? '' : (b0.first['id'] ?? b0.first['_id']).toString();
  _ok('5 page de paiement fermée sans payer : la réservation reste payable', b0.isNotEmpty && b0.first['status'] == 'agreed', b0.isEmpty ? '' : 'statut ${b0.first['status']} / paiement ${b0.first['paymentStatus']}');
  final pi = await _api('POST', '/bookings/$bookingId/create-payment-intent', kOwnerTok, <String, dynamic>{});
  final intentId = (pi['paymentIntentId'] ?? '').toString();
  var whCode = 0;
  try {
    final li = jsonDecode((await http.get(Uri.parse('$ctl/__banc/intents'))).body) as List;
    final it = li.cast<Map>().firstWhere((x) => x['id'] == intentId);
    await http.post(Uri.parse('$ctl/__banc/payer/$intentId'));
    final wh = await http.post(Uri.parse('$kRoot/webhooks/airwallex'), headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'id': 'evt_$intentId', 'name': 'payment_intent.succeeded', 'data': <String, dynamic>{'id': intentId, 'amount': it['amount'], 'currency': 'EUR', 'metadata': it['metadata'] ?? <String, dynamic>{}}}));
    whCode = wh.statusCode;
  } catch (e) {
    print('[ETAPE] paiement simulé : $e');
  }
  await _wait(t, 1500);
  final bk = await _api('GET', '/bookings/my', kOwnerTok);
  final paid = ((bk['bookings'] as List?) ?? const <dynamic>[]).cast<Map>().any((b) => b['paymentStatus'] == 'paid');
  _ok('5 paiement simulé accepté par le serveur (réservation « payée »)', paid, 'intention HTTP ${pi['status']} · webhook HTTP $whCode');
  final nc2 = Get.find<NotificationsController>();
  final paidLive = await _waitFor(t, () => nc2.notifications.any((n) => n.type.toLowerCase().contains('paid')), seconds: 10);
  _ok('6 « payé » arrive tout seul dans l’app du propriétaire', paidLive, 'cloche $bell0 → ${nc2.unreadCount.value}');
  await _goTab(t, 3);
  await _wait(t, 3500);
  final txt = _texts();
  _ok('6 Réservations affiche la réservation PAYÉE (plus de bouton Payer)', !txt.any((x) => x.contains('Payer maintenant')), txt.where((x) => x.contains('Pay') || x.contains('pay')).join(' ¦ '));
  await _cap(t, 'owner_13_reservations_payee');
  _dump('réservations après paiement');
  await _goTab(t, 0);
  await _wait(t, 2500);
  await _cap(t, 'owner_14_accueil_paye');
  _dump('accueil après paiement');
}

Future<void> _provider(WidgetTester t) async {
  final myTok = kRole == 'walker' ? kWalkerTok : kSitterTok;
  final service = kRole == 'walker' ? 'dog_walking' : 'house_sitting';
  final nc = Get.find<NotificationsController>();
  final before = nc.unreadCount.value;
  final s = _start().add(Duration(days: kRole == 'walker' ? 2 : 4));
  // Le propriétaire publie (sans animal enregistré côté formulaire : cas du site / app 600).
  final pub = await _api('POST', '/posts', kOwnerTok, <String, dynamic>{
    'body': kRole == 'walker' ? 'Balade du matin' : 'Garde deux jours',
    'serviceTypes': <String>[service], 'serviceLocation': 'at_owner',
    if (kRole == 'walker') 'walkDurationMinutes': 60,
    if (kRole != 'walker') 'houseSittingVenue': 'owners_home',
    'startDate': s.toIso8601String(),
    'endDate': s.add(kRole == 'walker' ? const Duration(hours: 1) : const Duration(days: 2)).toIso8601String(),
    'location': <String, dynamic>{'city': 'Zone test', 'lat': -35, 'lng': -30}, 'petIds': <String>[kPetId],
  });
  final postId = ((pub['post'] as Map?)?['id'] ?? (pub['post'] as Map?)?['_id'] ?? '').toString();
  _ok('1 demande publiée par le propriétaire', pub['status'] == 201, 'HTTP ${pub['status']}');
  final live = await _waitFor(t, () => nc.unreadCount.value > before, seconds: 10);
  _ok('2 prévenu de l’annonce : la cloche monte toute seule', live, 'non lues $before → ${nc.unreadCount.value}');
  final n = nc.notifications.where((x) => x.type.toLowerCase() == 'new_request_nearby').toList();
  _ok('2 la ligne de la cloche dit le service, la ville et les dates', n.isNotEmpty, n.isEmpty ? '' : '« ${n.first.title} — ${n.first.body} »');
  await _wait(t, 2500);
  await _cap(t, '${kRole}_02_accueil_avec_annonce');
  _dump('accueil avec annonce');

  // 3. Postuler depuis l'ACCUEIL : le bouton de la carte.
  var applied = false;
  for (final l in <String>['Proposer mon service', 'Proposer mes services', 'Envoyer une demande', 'Postuler']) {
    final f = find.textContaining(l);
    if (_has(f)) {
      try {
        await t.ensureVisible(f.first);
      } catch (_) {}
      await _pump(t, 300);
      await t.tap(f.first, warnIfMissed: false);
      print('[PAS] appui « $l » (accueil)');
      await _wait(t, 4000);
      applied = true;
      break;
    }
  }
  final mine = await _api('GET', '/applications/my', myTok);
  final list = ((mine['applications'] as List?) ?? const <dynamic>[]).cast<Map>();
  final sent = list.any((a) => (a['postId'] ?? '').toString() == postId || ((a['postId'] is Map) && ((a['postId'] as Map)['_id'] ?? (a['postId'] as Map)['id']).toString() == postId));
  _ok('3 postuler depuis l’ACCUEIL en un appui', applied && sent, 'bouton trouvé : $applied · candidature créée côté serveur : $sent (${list.length})');
  await _cap(t, '${kRole}_03_apres_candidature');
  _dump('après candidature');

  // 3 bis. PORTE PAWMAP : une 2e demande, vue et acceptée depuis la carte.
  final s2 = s.add(const Duration(days: 3));
  final pub2 = await _api('POST', '/posts', kOwnerTok, <String, dynamic>{
    'body': kRole == 'walker' ? 'Balade du soir' : 'Garde du week-end',
    'serviceTypes': <String>[service], 'serviceLocation': 'at_owner',
    if (kRole == 'walker') 'walkDurationMinutes': 60,
    if (kRole != 'walker') 'houseSittingVenue': 'owners_home',
    'startDate': s2.toIso8601String(),
    'endDate': s2.add(kRole == 'walker' ? const Duration(hours: 1) : const Duration(days: 2)).toIso8601String(),
    'location': <String, dynamic>{'city': 'Zone test', 'lat': -35, 'lng': -30}, 'petIds': <String>[kPetId],
  });
  final post2 = ((pub2['post'] as Map?)?['id'] ?? (pub2['post'] as Map?)?['_id'] ?? '').toString();
  await _goTab(t, 2);
  await _wait(t, 7000);
  await _cap(t, '${kRole}_04_pawmap');
  final okReq = await _tapKey(t, 'pawmap_action_requests', settle: 3000);
  _ok('3 PORTE PAWMAP : bouton « Demandes » présent et ouvre la liste', okReq);
  await _cap(t, '${kRole}_05_pawmap_demandes');
  _dump('pawmap demandes');
  var appliedMap = false;
  if (await _tapText(t, 'Voir', settle: 3000)) {
    print('[PAS] appui « Voir » (PawMap)');
    await _cap(t, '${kRole}_05b_pawmap_fiche_demande');
    _dump('pawmap fiche de la demande');
    for (final l in <String>['Proposer mes services', 'Proposer mon service', 'Postuler']) {
      final f = find.textContaining(l);
      if (_has(f)) {
        await t.tap(f.last, warnIfMissed: false);
        print('[PAS] appui « $l » (PawMap)');
        await _wait(t, 1200);
        _dump('juste après « $l » (PawMap)');
        await _wait(t, 3000);
        appliedMap = true;
        break;
      }
    }
  }
  final mine2 = await _api('GET', '/applications/my', myTok);
  final list2 = ((mine2['applications'] as List?) ?? const <dynamic>[]).cast<Map>();
  String pid(Map a) => a['postId'] is Map ? ((a['postId'] as Map)['_id'] ?? (a['postId'] as Map)['id']).toString() : (a['postId'] ?? '').toString();
  final sentMap = list2.any((a) => pid(a) == post2) || (list2.length > list.length);
  _ok('3 PORTE PAWMAP : postuler depuis la carte', appliedMap && sentMap, 'bouton trouvé : $appliedMap · candidatures côté serveur : ${list2.length}');
  await _cap(t, '${kRole}_05c_pawmap_apres_candidature');
  Get.until((r) => r.isFirst);
  await _wait(t, 1000);

  // 5. Le propriétaire accepte la 1re candidature : le prestataire est prévenu.
  if (sent) {
    final appRow = list.firstWhere((a) => pid(a) == postId, orElse: () => list.first);
    final b0 = nc.unreadCount.value;
    final acc = await _api('POST', '/applications/${appRow['id'] ?? appRow['_id']}/respond', kOwnerTok, <String, dynamic>{'action': 'accept'});
    final got = await _waitFor(t, () => nc.notifications.any((x) => x.type.toLowerCase() == 'application_accepted'), seconds: 8);
    _ok('5 prévenu « candidature acceptée » (cloche en direct)', acc['status'] == 200 && got, 'HTTP ${acc['status']} · non lues $b0 → ${nc.unreadCount.value}');
    final booking = (acc['booking'] as Map?) ?? ((acc['application'] as Map?)?['bookingId'] as Map?) ?? <String, dynamic>{};
    var bookingId = (booking['id'] ?? booking['_id'] ?? '').toString();
    if (bookingId.isEmpty) {
      final bk = await _api('GET', '/bookings/my', kOwnerTok);
      final bl = ((bk['bookings'] as List?) ?? const <dynamic>[]).cast<Map>();
      if (bl.isNotEmpty) bookingId = (bl.first['id'] ?? bl.first['_id']).toString();
    }
    await _goTab(t, 3);
    await _wait(t, 3000);
    await _cap(t, '${kRole}_06_reservations_acceptee');
    _dump('réservations (acceptée, pas encore payée)');

    // 6. Le propriétaire paie (simulé) : « payé » arrive tout seul chez le prestataire.
    final ctl = kRoot.replaceFirst('5612', '5613');
    final pi = await _api('POST', '/bookings/$bookingId/create-payment-intent', kOwnerTok, <String, dynamic>{});
    final intentId = (pi['paymentIntentId'] ?? '').toString();
    try {
      final li = jsonDecode((await http.get(Uri.parse('$ctl/__banc/intents'))).body) as List;
      final it = li.cast<Map>().firstWhere((x) => x['id'] == intentId);
      await http.post(Uri.parse('$ctl/__banc/payer/$intentId'));
      await http.post(Uri.parse('$kRoot/webhooks/airwallex'), headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{'id': 'evt_$intentId', 'name': 'payment_intent.succeeded', 'data': <String, dynamic>{'id': intentId, 'amount': it['amount'], 'currency': 'EUR', 'metadata': it['metadata'] ?? <String, dynamic>{}}}));
    } catch (e) {
      print('[ETAPE] paiement simulé : $e');
    }
    final paid = await _waitFor(t, () => nc.notifications.any((x) => x.type.toLowerCase() == 'booking_paid'), seconds: 10);
    _ok('6 « payé » arrive tout seul chez le prestataire (cloche)', paid,
        paid ? '« ${nc.notifications.firstWhere((x) => x.type.toLowerCase() == 'booking_paid').title} — ${nc.notifications.firstWhere((x) => x.type.toLowerCase() == 'booking_paid').body} »' : 'intention HTTP ${pi['status']}');
    await _wait(t, 3000);
    await _cap(t, '${kRole}_07_reservations_payee');
    _dump('réservations (payée)');
    await _goTab(t, 0);
    await _wait(t, 2500);
    await _cap(t, '${kRole}_08_accueil_paye');
    _dump('accueil (payée)');

    // 6 bis. Le jour du service : démarrer depuis l'app.
    await http.post(Uri.parse('$ctl/__banc/avancer/$bookingId'));
    await _goTab(t, 3);
    await _wait(t, 3500);
    _dump('réservations (jour du service)');
    await _cap(t, '${kRole}_09_jour_du_service');
    Future<String> conf() async {
      final bk = await _api('GET', '/bookings/my', kOwnerTok);
      final bl = ((bk['bookings'] as List?) ?? const <dynamic>[]).cast<Map>();
      final row = bl.firstWhere((b) => (b['id'] ?? b['_id']).toString() == bookingId, orElse: () => <String, dynamic>{});
      return '${row['confirmationStatus']}';
    }

    // Le code de remise est affiché au propriétaire dans SON app : on le lit comme lui.
    final det = await _api('GET', '/bookings/$bookingId', kOwnerTok);
    final code = ((det['booking'] as Map?)?['handoverCode'] ?? det['handoverCode'] ?? '').toString();
    _ok('6 le propriétaire dispose d’un code de remise à 4 chiffres', code.length == 4, code.isEmpty ? 'absent' : '•••• (présent)');
    Future<void> fillCodeAndConfirm(String confirmLabel) async {
      final fields = find.byType(TextField);
      final n = fields.evaluate().length;
      if (n >= 4) {
        for (var i = 0; i < 4; i++) {
          await t.enterText(fields.at(n - 4 + i), code[i]);
          await _pump(t, 150);
        }
      } else if (n >= 1) {
        await t.enterText(fields.last, code);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await _pump(t, 400);
      if (await _tapText(t, confirmLabel, settle: 3500, last: true)) print('[PAS] appui « $confirmLabel »');
    }

    var started = false;
    if (await _tapText(t, 'Animal récupéré', settle: 2500, last: true)) {
      print('[PAS] appui « Animal récupéré »');
      await _cap(t, '${kRole}_10_apres_animal_recupere');
      _dump('après « Animal récupéré »');
      await fillCodeAndConfirm('Confirmer la récupération');
      started = (await conf()) == 'in_progress';
      if (!started) _dump('après confirmation de la récupération');
    }
    _ok('6 démarrer le service depuis l’app (« Animal récupéré »)', started, 'état serveur : ${await conf()}');
    await _wait(t, 2000);
    _dump('service en cours');
    await _cap(t, '${kRole}_11_service_en_cours');
    var ended = false;
    if (await _tapText(t, 'Animal rendu', settle: 2500, last: true)) {
      print('[PAS] appui « Animal rendu »');
      _dump('après « Animal rendu »');
      for (final c in <String>['Confirmer le rendu', 'Confirmer la restitution', 'common_confirm'.tr, 'Confirmer', 'Valider']) {
        if (_has(find.text(c))) {
          await fillCodeAndConfirm(c);
          break;
        }
      }
      final st = await conf();
      ended = st == 'awaiting_owner_confirmation' || st == 'completed_by_provider' || st == 'confirmed' || st.contains('await');
      _ok('6 terminer le service depuis l’app (« Animal rendu »)', ended, 'état serveur : $st');
    } else {
      _ok('6 terminer le service depuis l’app (« Animal rendu »)', false, 'bouton introuvable');
    }
    // Le propriétaire confirme : la part du prestataire est créditée, il est prévenu.
    final cf = await _api('POST', '/bookings/$bookingId/service/confirm', kOwnerTok, <String, dynamic>{});
    final credited = await _waitFor(t, () => nc.notifications.any((x) => x.type.toLowerCase() == 'handover_return_confirmed' || x.type.toLowerCase() == 'wallet_credited'), seconds: 8);
    _ok('6 fin confirmée par le propriétaire : le prestataire est prévenu (cloche)', cf['status'] == 200 && credited, 'HTTP ${cf['status']} · ${nc.notifications.take(2).map((x) => x.type).join(', ')}');
    await _wait(t, 2500);
    await _cap(t, '${kRole}_12_termine');
    _dump('réservations (terminée)');
  }
}
