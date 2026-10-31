// ignore_for_file: avoid_print, depend_on_referenced_packages
// ZOE (07/10/2026) — passage qualité du mercredi dans l'APP RÉELLE (main de l'app,
// vrais appuis) branchée sur le BANC LOCAL (backend/scripts/banc_android_613.js,
// 127.0.0.1, base en mémoire, comptes jetables) — jamais la production.
// Parcours : ajout d'un animal AVEC photo, fiche animal, message, avis (étoiles),
// pop-up de confirmation — sur les 3 rôles.
//
//   flutter test integration_test/zoe0710_qualite_test.dart -d <udid> \
//     --dart-define=HPS_API_ROOT=http://127.0.0.1:5615 --dart-define=Z_ROLE=owner|sitter|walker \
//     --dart-define=Z_EMAIL=… --dart-define=Z_PW=… --dart-define=Z_*_TOKEN=… (état du banc, jamais affichés)
//
// « [CAP] nom » : l'hôte prend la capture. « [RESULTAT] OK|KO … » : une ligne par étape.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/main.dart' as app;
import 'package:hopetsit/services/meta_events_service.dart';
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/pet_profile_screen.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/views/profile/my_pets_screen.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/pet_form_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_detail_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/reviews/reviews_screen.dart';
import 'package:hopetsit/widgets/submit_review_dialog.dart';
import 'package:hopetsit/views/pet_owner/booking-application/owner_booking_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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
  final h = <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $token', 'X-App-Version': '614'};
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

const String kZoe = 'http://127.0.0.1:5617';
const String kSitterId = String.fromEnvironment('Z_SITTER_ID');
const String kWalkerId = String.fromEnvironment('Z_WALKER_ID');

/// Sélecteur de photos du système remplacé : il rend un VRAI fichier JPEG
/// (la galerie native ne se pilote pas depuis un test).
class _FakePicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  _FakePicker(this.path);
  final String path;
  int calls = 0;
  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async {
    calls += 1;
    return XFile(path);
  }
}

/// Les URL d'images affichées dans l'écran courant (Image, CircleAvatar,
/// décorations) : la preuve que la photo est réellement dessinée.
List<String> _imageUrls() {
  final out = <String>[];
  void add(ImageProvider? p) {
    if (p == null) return;
    if (p is FileImage) {
      out.add('file:${p.file.path}');
      return;
    }
    final m = RegExp(r'"?(https?://[^",)\s]+)').firstMatch(p.toString());
    if (m != null) out.add(m.group(1)!);
  }
  for (final e in find.byWidgetPredicate((_) => true).evaluate()) {
    final w = e.widget;
    if (w is Image) add(w.image);
    if (w is CachedNetworkImage) out.add(w.imageUrl);
    if (w is CircleAvatar) add(w.backgroundImage);
    if (w is DecoratedBox && w.decoration is BoxDecoration) add((w.decoration as BoxDecoration).image?.image);
    if (w is Container && w.decoration is BoxDecoration) add((w.decoration as BoxDecoration).image?.image);
  }
  return out;
}

/// Fait défiler jusqu'à rendre visible un texte (listes construites à la demande).
Future<bool> _scrollTo(WidgetTester t, String text) async {
  if (_has(find.text(text))) return true;
  final sc = find.byType(Scrollable);
  for (var i = 0; i < sc.evaluate().length; i++) {
    try {
      await t.scrollUntilVisible(find.text(text), 250, scrollable: sc.at(i), maxScrolls: 25);
      await _pump(t, 300);
      if (_has(find.text(text))) return true;
    } catch (_) {}
  }
  return _has(find.text(text));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('ZOE 07/10 — qualité, rôle $kRole (banc local)', (t) async {
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
      // ZOE 14/10 : détail complet (widget en cause + pile) pour localiser fichier:ligne.
      if (s.contains('during build')) {
        print('[DETAIL] ${d.toString().split('\n').take(60).join('\n[DETAIL] ')}');
        print('[DETAIL] ${d.stack.toString().split('\n').take(40).join('\n[DETAIL] ')}');
      }
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
    await _cap(t, '${kRole}_01_accueil');
    await _cgu616(t);
    if (kRole == 'owner') {
      await _owner(t);
      await _ownerDialogReview(t);
    } else {
      await _provider(t);
    }
    print('[RESULTAT] ---- erreurs Flutter vues : ${errors.length} ${errors.take(6).join(' // ')}');
    for (final l in _res) {
      print('[BILAN] $l');
    }
  });
}


/// 616 (ZOE, 15/10) — CGU 2.4 : la clause « Responsabilité individuelle et
/// conformité aux législations applicables » est visible dans l'écran CGU
/// (texte servi par le serveur, sinon texte embarqué), dans la langue de l'app.
Future<void> _cgu616(WidgetTester t) async {
  // Pas d’await : Get.to ne rend la main qu’à la fermeture de l’écran (blocage du 21/10).
  unawaited(Get.to<void>(() => const TermsAndConditionsScreen()));
  final shown = await _waitFor(t, () => _has(find.byType(SelectableText)), seconds: 20);
  String txt = '';
  if (shown) {
    txt = (find.byType(SelectableText).evaluate().first.widget as SelectableText).data ?? '';
  }
  _ok('CGU : écran affiché', shown);
  _ok('CGU : version 2.4 en en-tête', RegExp(r'(Version|Versión|Versione|Versão) 2\.4').hasMatch(txt),
      txt.isEmpty ? '' : txt.split('\n').take(4).join(' ¦ '));
  _ok('CGU : clause responsabilité individuelle (règlement (UE) 2022/2065)', txt.contains('2022/2065'));
  await _cap(t, '${kRole}_00_cgu');
  Get.back<void>();
  await _wait(t, 1200);
}

String _convId(Map<String, dynamic> j) {
  final c = j['conversation'];
  if (c is Map) return (c['id'] ?? c['_id'] ?? '').toString();
  return '';
}

Future<List<String>> _messages(String convId, String token) async {
  final r = await _api('GET', '/conversations/$convId/messages', token);
  final list = (r['messages'] ?? r['data'] ?? <dynamic>[]) as List<dynamic>;
  return list.map((m) => ((m as Map)['body'] ?? m['text'] ?? m['content'] ?? '').toString()).toList();
}

Future<Map<String, dynamic>> _zoe(String path) async {
  final r = await http.post(Uri.parse('$kZoe$path'), headers: <String, String>{'content-type': 'application/json'}, body: '{}');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

/// Ouvre une conversation depuis l'onglet Chat (appui sur le nom), écrit et envoie.
Future<void> _chat(WidgetTester t, String peerName, String convId, String text, String myToken, String tag) async {
  await _goTab(t, 1);
  await _wait(t, 2500);
  await _cap(t, '${tag}_chat_liste');
  final listed = _has(find.text(peerName));
  _ok('$tag MESSAGE : la conversation avec « $peerName » est dans la liste', listed);
  if (!listed) {
    _dump('liste des chats');
    return;
  }
  await _tapText(t, peerName, settle: 3000);
  final field = find.byType(TextField);
  _ok('$tag MESSAGE : écran de discussion ouvert (champ de saisie)', _has(field));
  if (!_has(field)) return;
  await t.enterText(field.last, text);
  await _pump(t, 500);
  final send = find.byIcon(Icons.send_rounded);
  _ok('$tag MESSAGE : bouton Envoyer visible après saisie', _has(send));
  if (_has(send)) {
    await t.tap(send.last, warnIfMissed: false);
    await _wait(t, 2500);
  }
  final onScreen = _has(find.text(text));
  final server = await _messages(convId, myToken);
  _ok('$tag MESSAGE : envoyé, affiché dans le fil et reçu par le serveur', onScreen && server.contains(text),
      'à l’écran : $onScreen · serveur : ${server.contains(text)} (${server.length} messages)');
  await _cap(t, '${tag}_chat_envoye');
  await _back(t);
}

Future<void> _owner(WidgetTester t) async {
  // ── 1. AJOUTER UN ANIMAL AVEC PHOTO ──
  final img = await http.get(Uri.parse('$kRoot/img/101.jpg'));
  final photo = File('${Directory.systemTemp.path}/zoe0710_mimi.jpg')..writeAsBytesSync(img.bodyBytes);
  final picker = _FakePicker(photo.path);
  ImagePickerPlatform.instance = picker;
  final before = await _api('GET', '/pets/me', kOwnerTok);
  final nBefore = ((before['pets'] ?? <dynamic>[]) as List<dynamic>).length;
  Get.to(() => const MyPetsScreen());
  await _wait(t, 2500);
  await _cap(t, 'owner_02_mes_animaux');
  final addOk = await _tapKey(t, 'my_pets_add_bottom', settle: 2000) || await _tapKey(t, 'my_pets_add_round', settle: 2000);
  _ok('1 AJOUT : « Ajouter un animal » ouvre le formulaire', addOk && _has(find.byType(EditPetScreen)));
  if (!_has(find.byType(EditPetScreen))) return;
  await t.tap(find.byType(EditProfileAvatar).first, warnIfMissed: false);
  await _wait(t, 1500);
  final preview = _imageUrls().any((u) => u.startsWith('file:'));
  _ok('1 AJOUT : la photo choisie s’affiche tout de suite dans le formulaire', picker.calls == 1 && preview, 'sélecteur appelé ${picker.calls} fois');
  Finder input(String labelKey) => find.descendant(
      of: find.byWidgetPredicate((w) => w is ProfileInput && w.label == labelKey.tr), matching: find.byType(TextFormField));
  await t.enterText(input('edit_pet_name_label').first, 'Mimi');
  await _pump(t, 300);
  final cat = find.byWidgetPredicate((w) => w is PetPill && w.label == 'create_pet_category_cat'.tr);
  if (_has(cat)) {
    await t.ensureVisible(cat.first);
    await t.tap(cat.first, warnIfMissed: false);
    await _wait(t, 600);
  }
  await t.enterText(input('edit_pet_breed_label').first, 'Européen');
  FocusManager.instance.primaryFocus?.unfocus();
  await _wait(t, 600);
  await _cap(t, 'owner_03_formulaire_rempli');
  final save = find.byType(ProfileSaveBar);
  await t.tap(save.first, warnIfMissed: false);
  final closed = await _waitFor(t, () => !_has(find.byType(EditPetScreen)), seconds: 20);
  await _wait(t, 2500);
  final after = await _api('GET', '/pets/me', kOwnerTok);
  final pets = ((after['pets'] ?? <dynamic>[]) as List<dynamic>).cast<Map<String, dynamic>>();
  final mimi = pets.firstWhere((p) => p['petName'] == 'Mimi', orElse: () => <String, dynamic>{});
  final avatar = ((mimi['avatar'] as Map?)?['url'] ?? '').toString();
  _ok('1 AJOUT : enregistré, retour à « Mes animaux »', closed && pets.length == nBefore + 1 && mimi.isNotEmpty,
      'animaux : $nBefore → ${pets.length} · espèce ${mimi['category']} · race ${mimi['breed']}');
  _ok('1 AJOUT : la photo est enregistrée sur le serveur', avatar.contains('/img/'), avatar); // photothèque simulée du banc (21/10)
  _ok('1 AJOUT : Mimi apparaît dans la liste avec SA photo', _has(find.text('Mimi')) && _imageUrls().contains(avatar), 'images : ${_imageUrls().where((u) => u.contains('up_')).length}');
  await _cap(t, 'owner_04_liste_avec_mimi');

  // ── 2. FICHE ANIMAL ──
  await _tapText(t, 'Mimi', settle: 3000);
  final onProfile = _has(find.byType(PetProfileScreen));
  _ok('2 FICHE : appui sur Mimi ouvre sa fiche', onProfile);
  _ok('2 FICHE : la fiche montre la photo, le nom et la race', _imageUrls().contains(avatar) && _has(find.text('Mimi')) && _has(find.textContaining('Européen')),
      'photo : ${_imageUrls().contains(avatar)} · race : ${_has(find.textContaining('Européen'))}');
  _dump('fiche Mimi');
  await _cap(t, 'owner_05_fiche_mimi');

  // ── 3. POP-UP DE CONFIRMATION : supprimer l'animal (Annuler puis Supprimer) ──
  final menu = find.byIcon(Icons.more_horiz_rounded);
  if (_has(menu)) {
    await t.tap(menu.first, warnIfMissed: false);
    await _wait(t, 1200);
    await _tapText(t, 'post_action_delete'.tr, settle: 1500);
  }
  final dlg = _has(find.text('pet_delete_dialog_title'.tr));
  _ok('3 POP-UP : « Supprimer » ouvre la confirmation', dlg);
  await _cap(t, 'owner_06_popup_suppression');
  if (dlg) {
    await _tapText(t, 'common_cancel'.tr, settle: 1500, last: true);
    final still = ((await _api('GET', '/pets/me', kOwnerTok))['pets'] as List<dynamic>).length;
    _ok('3 POP-UP : « Annuler » ferme la fenêtre sans rien supprimer', !_has(find.text('pet_delete_dialog_title'.tr)) && still == pets.length, 'animaux : $still');
    await t.tap(find.byIcon(Icons.more_horiz_rounded).first, warnIfMissed: false);
    await _wait(t, 1200);
    await _tapText(t, 'post_action_delete'.tr, settle: 1500);
    await _tapText(t, 'common_delete'.tr, settle: 3000, last: true);
    final left = ((await _api('GET', '/pets/me', kOwnerTok))['pets'] as List<dynamic>).cast<Map<String, dynamic>>();
    final gone = !left.any((p) => p['petName'] == 'Mimi');
    _ok('3 POP-UP : « Supprimer » supprime Mimi sur le serveur', gone, 'animaux : ${left.length}');
    final stuck = _has(find.byType(PetProfileScreen));
    _ok('3 POP-UP : après suppression on QUITTE la fiche de l’animal supprimé', !stuck, stuck ? 'la fiche de Mimi reste affichée' : '');
    await _cap(t, 'owner_07_apres_suppression');
  }
  while (Get.key.currentState?.canPop() == true) {
    Get.key.currentState!.pop();
    await _wait(t, 600);
  }

  // ── 4. MESSAGE ──
  final st = await _api('POST', '/conversations/start?sitterId=$kSitterId', kOwnerTok, <String, dynamic>{'message': 'Bonjour Sasha (banc ZOE)'});
  final cid = _convId(st);
  _ok('4 MESSAGE : conversation propriétaire ↔ gardien prête', cid.isNotEmpty, 'HTTP ${st['status']}');
  if (cid.isNotEmpty) await _chat(t, 'Sasha Gardien', cid, 'Rex mange à 19 h, merci !', kOwnerTok, 'owner');

  // ── 5. AVIS (étoiles) sur une balade payée et confirmée — promeneur ──
  for (final role in <String>['walker']) {
    final b = await _zoe('/__zoe/booking/$role');
    final bid = (b['id'] ?? '').toString();
    final name = role == 'walker' ? 'Paul Promeneur' : 'Sasha Gardien';
    await _goTab(t, 3);
    // Réservation posée directement en base (pas de signal temps réel) : on
    // recharge la liste comme le ferait un « tirer pour actualiser ».
    await Get.find<BookingsController>().loadBookings();
    await _wait(t, 2500);
    final shown = await _scrollTo(t, name);
    await _cap(t, 'owner_08_reservations_$role');
    _ok('5 AVIS ($role) : la réservation payée de $name est listée', shown);
    if (!shown) {
      _dump('réservations');
      continue;
    }
    // Le bouton est sur la carte de la réservation (« Suivi du service »),
    // la plus récente en premier.
    await _scrollTo(t, 'review_prompt_cta'.tr);
    final btn = find.text('review_prompt_cta'.tr);
    _ok('5 AVIS ($role) : bouton « Noter le prestataire » sur la réservation', _has(btn));
    if (!_has(btn)) {
      _dump('réservations ($role)');
      continue;
    }
    // 4e étoile de l'invitation → écran « Avis » pré-rempli à 4★.
    final card = find.ancestor(of: btn.first, matching: find.byType(GestureDetector)).first;
    final st4 = find.descendant(of: card, matching: find.byIcon(Icons.star_rounded));
    await t.ensureVisible(btn.first);
    await _pump(t, 300);
    await t.tap(st4.evaluate().length >= 4 ? st4.at(3) : btn.first, warnIfMissed: false);
    await _wait(t, 2500);
    final open = _has(find.byType(ReviewsScreen));
    _ok('5 AVIS ($role) : l’écran « Avis » s’ouvre', open);
    if (!open) continue;
    final rsStars = find.descendant(of: find.byType(ReviewsScreen),
        matching: find.byWidgetPredicate((w) => w is Icon && (w.icon == Icons.star_rounded || w.icon == Icons.star_outline_rounded)));
    print('[ETAPE] étoiles dans l’écran Avis : ${rsStars.evaluate().length}');
    if (rsStars.evaluate().length >= 5) {
      await t.tap(rsStars.at(3), warnIfMissed: false);
      await _wait(t, 600);
    }
    await t.enterText(find.descendant(of: find.byType(ReviewsScreen), matching: find.byType(TextField)).first, 'Très bien ($role, banc)');
    FocusManager.instance.primaryFocus?.unfocus();
    await _wait(t, 600);
    await _cap(t, 'owner_09_avis_$role');
    _dump('écran Avis ($role) avant envoi');
    await _scrollTo(t, 'reviews_submit'.tr);
    await _tapText(t, 'reviews_submit'.tr, settle: 3500, last: true);
    final mine = await _api('GET', '/reviews/mine?bookingId=$bid', kOwnerTok);
    final rv = (mine['review'] ?? <String, dynamic>{}) as Map;
    _ok('5 AVIS ($role) : avis enregistré 4★ sur le serveur, au bon prestataire', rv['rating'] == 4,
        'serveur : ${rv['rating']}★ ${rv['revieweeModel'] ?? ''} · écran Avis encore ouvert : ${_has(find.byType(ReviewsScreen))}');
    while (_has(find.byType(ReviewsScreen))) {
      await _back(t);
    }
    await Get.find<BookingsController>().loadBookings();
    await _wait(t, 2000);
    await _scrollTo(t, 'review_already_rated'.tr);
    final rated = _has(find.text('review_already_rated'.tr));
    _ok('5 AVIS ($role) : la réservation affiche « déjà noté »', rated);
    if (!rated) _dump('réservations après avis');
    await _cap(t, 'owner_10_apres_avis');
    await _cap(t, 'owner_10_avis_envoye_$role');
  }
}

Future<void> _ownerDialogReview(WidgetTester t) async {
  // ── 6. AVIS par la fenêtre d'étoiles (détail de réservation) sur un PROMENEUR ──
  final b = await _zoe('/__zoe/booking/walker');
  final bid = (b['id'] ?? '').toString();
  await _goTab(t, 3);
  await Get.find<BookingsController>().loadBookings();
  await _wait(t, 2500);
  // Même ouverture qu'un appui sur la notification « service terminé » :
  // le détail de LA réservation (notifications_screen.dart).
  final bk = Get.find<BookingsController>().bookings.firstWhereOrNull((x) => x.id == bid);
  if (bk == null) {
    _ok('6 FENÊTRE D’AVIS : réservation chargée par l’app', false);
    return;
  }
  Get.to(() => OwnerBookingDetailScreen(booking: bk));
  await _wait(t, 3500);
  final onDetail = _has(find.byType(OwnerBookingDetailScreen));
  _ok('6 FENÊTRE D’AVIS : le détail de la réservation s’ouvre', onDetail, 'écran : ${onDetail ? 'détail' : 'autre'}');
  if (!onDetail) {
    _dump('après Voir les détails');
    await _back(t);
    return;
  }
  await _scrollTo(t, 'booking_leave_review'.tr);
  if (!await _tapText(t, 'booking_leave_review'.tr, settle: 1500)) {
    _ok('6 FENÊTRE D’AVIS : bouton « Laisser un avis » présent', false);
    _dump('détail');
    await _back(t);
    return;
  }
  final dlg = find.byType(SubmitReviewDialog);
  _ok('6 FENÊTRE D’AVIS : la fenêtre des étoiles s’ouvre', _has(dlg));
  if (!_has(dlg)) return;
  await t.enterText(find.descendant(of: dlg, matching: find.byType(TextField)).first, 'Balade parfaite (fenêtre)');
  FocusManager.instance.primaryFocus?.unfocus();
  await _wait(t, 500);
  await _cap(t, 'owner_11_fenetre_avis_promeneur');
  await _tapText(t, 'review_leave_submit'.tr, settle: 3500);
  final mine = await _api('GET', '/reviews/mine?bookingId=$bid', kOwnerTok);
  final rv = (mine['review'] ?? <String, dynamic>{}) as Map;
  _ok('6 FENÊTRE D’AVIS : avis du promeneur enregistré (avant le correctif : 404 « Reviewee not found »)',
      !_has(find.byType(SubmitReviewDialog)) && rv['rating'] == 5,
      'serveur : ${rv['rating']}★ ${rv['revieweeModel'] ?? ''} · texte d’erreur visible : ${_texts().where((x) => x.contains('Exception')).join(' ')}');
  await _cap(t, 'owner_12_fenetre_avis_envoye');
  await _back(t);
}

Future<void> _provider(WidgetTester t) async {
  final myTok = kRole == 'walker' ? kWalkerTok : kSitterTok;
  final myId = kRole == 'walker' ? kWalkerId : kSitterId;
  // ── MESSAGE : le propriétaire écrit, le prestataire répond depuis l'app ──
  final q = kRole == 'walker' ? 'walkerId=$myId' : 'sitterId=$myId';
  final st = await _api('POST', '/conversations/start?$q', kOwnerTok, <String, dynamic>{'message': 'Bonjour ($kRole), dispo samedi ?'});
  final cid = _convId(st);
  _ok('MESSAGE : conversation prête', cid.isNotEmpty, 'HTTP ${st['status']}');
  if (cid.isNotEmpty) await _chat(t, 'Camille Durand', cid, 'Oui, samedi 10 h (banc $kRole)', myTok, kRole);

  // ── FICHE ANIMAL vue par le prestataire, depuis une réservation ──
  await _zoe('/__zoe/booking/$kRole');
  await _goTab(t, 3);
  await _wait(t, 1500);
  try {
    if (kRole == 'walker') {
      await Get.find<WalkerBookingsController>().loadBookings();
    } else {
      await Get.find<SitterBookingsController>().loadBookings();
    }
  } catch (e) {
    print('[ETAPE] rechargement des réservations : $e');
  }
  await _wait(t, 2500);
  final shown = await _scrollTo(t, 'Camille Durand');
  await _cap(t, '${kRole}_02_reservations');
  _ok('FICHE : la réservation de Camille est listée', shown);
  if (shown) {
    await _tapText(t, 'Camille Durand', settle: 3500);
    _dump('détail réservation $kRole');
    await _cap(t, '${kRole}_03_detail_reservation');
    // Avis : le prestataire peut-il noter le propriétaire depuis l'app ?
    final rv = _has(find.text('booking_leave_review'.tr));
    print('[CONSTAT] $kRole : bouton « Laisser un avis » sur la réservation = $rv');
    await _back(t);
  }

  // ── FICHE ANIMAL depuis une demande publiée par Camille (accueil) ──
  final d = DateTime.now().toUtc().add(const Duration(days: 4));
  final st0 = DateTime.utc(d.year, d.month, d.day, 9);
  final walk = kRole == 'walker';
  final pub = await _api('POST', '/posts', kOwnerTok, <String, dynamic>{
    'body': 'Demande banc ZOE ($kRole)', 'serviceTypes': <String>[walk ? 'dog_walking' : 'pet_sitting'],
    'serviceLocation': 'at_owner', if (walk) 'walkDurationMinutes': 60,
    'startDate': st0.toIso8601String(), 'endDate': st0.add(Duration(hours: walk ? 1 : 48)).toIso8601String(),
    'location': <String, dynamic>{'city': 'Paris', 'lat': 48.8566, 'lng': 2.3522}, 'petIds': <String>[kPetId],
  });
  _ok('FICHE : demande de Camille publiée (banc)', pub['status'] == 201, 'HTTP ${pub['status']}');
  await _goTab(t, 0);
  await _wait(t, 1500);
  final sc0 = find.byType(Scrollable);
  if (_has(sc0)) {
    await t.fling(sc0.first, const Offset(0, 500), 1200);
    await _wait(t, 4000);
  }
  var seen = await _scrollTo(t, 'Rex');
  if (!seen) {
    // Bouton « Rafraîchir » de l'accueil vide : le geste d'un vrai utilisateur.
    for (final k in <String>['home571_refresh', 'common_refresh', 'refresh']) {
      if (await _tapText(t, k.tr, settle: 5000)) break;
    }
    seen = await _scrollTo(t, 'Rex');
    print('[ETAPE] après Rafraîchir : Rex visible = $seen');
  }
  _ok('FICHE : la demande avec « Rex » est visible sur l’accueil', seen);
  await _cap(t, '${kRole}_06_accueil_demande');
  if (seen) {
    // ZOE 14/10 : le « Rex » DE LA CARTE de demande (une réservation de Rex
    // existe aussi dans un autre onglet du promeneur).
    final inCard = find.descendant(of: find.byType(PetPostCard), matching: find.text('Rex'));
    print('[ETAPE] « Rex » dans une carte de demande : ${inCard.evaluate().length}');
    await t.tap(_has(inCard) ? inCard.first : find.text('Rex').first, warnIfMissed: false);
    await _wait(t, 3500);
    final open = _has(find.byType(PetDetailScreen));
    _ok('FICHE : appui sur Rex ouvre la fiche de l’animal', open);
    _dump('fiche Rex ($kRole)');
    await _cap(t, '${kRole}_07_fiche_rex');
    if (open) await _back(t);
  } else {
    _dump('accueil $kRole');
  }

  // ── POP-UP : déconnexion (Annuler) ──
  await _goTab(t, 4);
  await _wait(t, 2500);
  final lo = find.text('button_logout'.tr);
  if (_has(lo)) {
    await t.ensureVisible(lo.first);
    await t.tap(lo.first, warnIfMissed: false);
    await _wait(t, 1500);
  }
  final dlg = _has(find.text('logout_dialog_message'.tr));
  _ok('POP-UP : « Se déconnecter » demande confirmation', dlg);
  await _cap(t, '${kRole}_05_popup_deconnexion');
  if (dlg) {
    await _tapText(t, 'common_cancel'.tr, settle: 1500, last: true);
    _ok('POP-UP : « Annuler » ferme la fenêtre et garde la session', !_has(find.text('logout_dialog_message'.tr)) && _has(find.byType(PawTabBar)));
  }
}
