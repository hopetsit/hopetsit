// v604 (ZOE, 30/09/2026) — suivi en direct du chat à l'état SERVEUR, PAR SENS.
// Daniel : « En direct · voir la carte », « Suivi actif · Ouvrir la carte » et
// « Ta position part en direct » restaient affichés après l'arrêt ; le suivi
// mutuel (A suit B ET B suit A) se mélangeait.
//
// Les états rejoués ici NE SONT PAS inventés : ce sont les réponses réelles
// de GET /conversations/:id/pawfollow-state produites par le vrai code serveur
// (backend/tests/pawfollowFlow604.test.js, base Mongo en mémoire, vrais
// gestionnaires), écrites dans test/fixtures/pawfollow604/ par
// `PF604_FIXTURES=1 npx jest --runInBand tests/pawfollowFlow604.test.js`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/chat604_i18n.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_state604.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_widgets.dart';
import 'package:hopetsit/widgets/pawfollow_request_card.dart';

const kLangs = <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ja', 'ko'];

Map<String, dynamic> fx(String name) => jsonDecode(
        File('test/fixtures/pawfollow604/$name.json').readAsStringSync())
    as Map<String, dynamic>;

PawFollowConvState st(String name) => PawFollowConvState.fromJson(fx(name));

/// « Maintenant » = 1 min après l'arrêt enregistré dans la réponse (stable).
DateTime nowFor(PawFollowConvState s) {
  final e = s.incoming.endedAt ?? s.outgoing.endedAt;
  return e != null ? e.add(const Duration(minutes: 1)) : DateTime.now();
}

PawFollowHeaderKind kind(String name, {required bool myLive, bool? peer}) {
  final s = st(name);
  return pawFollowHeaderKind(s,
      myLive: myLive, peerLiveLocal: peer, now: nowFor(s));
}

Widget _app(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: Scaffold(body: Center(child: child)),
      ),
    );

ChatMessage _msg(String id, {required bool mine, required String role, String status = 'accepted'}) =>
    ChatMessage(
      id: id,
      senderId: mine ? 'me' : 'peer',
      senderName: 'X',
      senderImage: '',
      message: '',
      timestamp: DateTime.now(),
      isFromCurrentUser: mine,
      type: 'pawfollow_request',
      metadata: <String, dynamic>{
        'status': status,
        'requesterRole': role,
        'requesterId': mine ? 'me' : 'peer',
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tmp = await Directory.systemTemp.createTemp('zoe604_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') return tmp.path;
      throw MissingPluginException(call.method);
    });
  });

  group('en-tête : réponses RÉELLES du serveur, suivi mutuel A (gardien) ⇄ B (promeneur)', () {
    test('acceptées, personne ne diffuse : « direct arrêté » (jamais « en direct »)', () {
      expect(kind('mutual_accepted_nolive_A', myLive: false), PawFollowHeaderKind.peerStopped);
    });
    test('les deux diffusent : chacun voit l\'autre EN DIRECT', () {
      expect(kind('mutual_both_live_A', myLive: true), PawFollowHeaderKind.peerLive);
      expect(kind('mutual_both_live_B', myLive: true), PawFollowHeaderKind.peerLive);
    });
    test('A arrête de suivre : A garde « ma position part en direct », B voit toujours A en direct', () {
      expect(kind('mutual_A_stopped_following_A', myLive: true), PawFollowHeaderKind.myLive);
      expect(kind('mutual_A_stopped_following_B', myLive: true), PawFollowHeaderKind.peerLive);
    });
    test('puis B arrête son direct : A reste en direct pour B', () {
      expect(kind('mutual_B_stopped_live_after_A_unfollow_A', myLive: true), PawFollowHeaderKind.myLive);
      expect(kind('mutual_B_stopped_live_after_A_unfollow_B', myLive: false), PawFollowHeaderKind.peerLive);
    });
    test('B arrête son direct pendant que A le suit : A « direct arrêté », B voit A en direct', () {
      expect(kind('mutual_B_stopped_live_A', myLive: true), PawFollowHeaderKind.peerStopped);
      expect(kind('mutual_B_stopped_live_B', myLive: false), PawFollowHeaderKind.peerLive);
    });
    test('la PawMap a reçu l\'arrêt avant le serveur : un « non » local l\'emporte', () {
      expect(kind('mutual_both_live_A', myLive: true, peer: false), PawFollowHeaderKind.peerStopped);
    });
  });

  group('en-tête : réponses RÉELLES du serveur, un seul sens O (propriétaire) → A (gardien)', () {
    test('demande en attente : pilule d\'origine', () {
      expect(kind('single_pending_O', myLive: false), PawFollowHeaderKind.none);
    });
    test('acceptée sans direct : O « direct arrêté · redemander », A « relancer le direct »', () {
      expect(kind('single_accepted_nolive_O', myLive: false), PawFollowHeaderKind.peerStopped);
      expect(kind('single_accepted_nolive_A', myLive: false), PawFollowHeaderKind.myStopped);
    });
    test('A diffuse : O « en direct », A « ta position part en direct »', () {
      expect(kind('single_live_O', myLive: false), PawFollowHeaderKind.peerLive);
      expect(kind('single_live_A', myLive: true), PawFollowHeaderKind.myLive);
    });
    test('A arrête : O « direct arrêté · redemander », A plus rien — même si son téléphone se croit encore en direct', () {
      expect(kind('single_stopped_O', myLive: false), PawFollowHeaderKind.peerStopped);
      expect(kind('single_stopped_A', myLive: false), PawFollowHeaderKind.none);
      expect(kind('single_stopped_A', myLive: true), PawFollowHeaderKind.none);
    });
    test('« direct arrêté » ne reste pas plus de 12 h', () {
      final s = st('single_stopped_O');
      expect(
          pawFollowHeaderKind(s,
              myLive: false,
              peerLiveLocal: null,
              now: s.incoming.endedAt!.add(const Duration(hours: 13))),
          PawFollowHeaderKind.none);
    });
  });

  group('pilule d\'en-tête : socket `pawfollow:state` rejouée, sans recharger', () {
    setUp(() {
      Get.testMode = true;
      Get.put<LiveMapService>(LiveMapService());
      PawFollowStateStore.states.clear();
    });
    tearDown(() {
      PawFollowStateStore.states.clear();
      Get.reset();
    });

    testWidgets('O : en direct → direct arrêté · redemander en un événement', (t) async {
      final live = fx('single_live_O');
      final stopped = fx('single_stopped_O');
      final cid = live['conversationId'] as String;
      final inc = (live['incoming'] as Map)['messageId'] as String;
      final msgs = <ChatMessageBase>[_msg(inc, mine: true, role: 'owner')];
      PawFollowStateStore.debugApplySocketEvent(live);
      await t.pumpWidget(_app(Obx(() {
        final h = pawFollowHeaderFor(msgs, conversationId: cid);
        return PawFollowPill(
          label: 'cs_pf_pill_follow'.tr,
          onTap: () {},
          live: h.live,
          stoppedLabel: h.kind == PawFollowHeaderKind.peerStopped
              ? 'chat603_live_stopped_ask'.tr
              : null,
        );
      })));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('En direct · voir la carte'), findsOneWidget);
      expect(find.byType(PawFollowLiveDot), findsOneWidget);

      PawFollowStateStore.debugApplySocketEvent(stopped);
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('En direct · voir la carte'), findsNothing);
      expect(find.text('Direct arrêté · redemander'), findsOneWidget);
      expect(find.byType(PawFollowLiveDot), findsNothing);
    });

    testWidgets('A (partageur) : « ma position part » disparaît quand le serveur termine, même si le téléphone diffuse encore', (t) async {
      final liveMap = Get.find<LiveMapService>();
      liveMap.broadcasting.value = true; // cache local resté « en direct »
      final live = fx('single_live_A');
      final cid = live['conversationId'] as String;
      final out = (live['outgoing'] as Map)['messageId'] as String;
      final msgs = <ChatMessageBase>[_msg(out, mine: false, role: 'owner')];
      PawFollowStateStore.debugApplySocketEvent(live);
      await t.pumpWidget(_app(Obx(() {
        final h = pawFollowHeaderFor(msgs, conversationId: cid);
        return Text(h.kind.name, textDirection: TextDirection.ltr);
      })));
      await t.pump(const Duration(milliseconds: 20));
      expect(find.text('myLive'), findsOneWidget);
      PawFollowStateStore.debugApplySocketEvent(fx('single_stopped_A'));
      await t.pump(const Duration(milliseconds: 20));
      expect(find.text('none'), findsOneWidget);
    });

    testWidgets('carte du chat : l\'autre n\'est plus « Suivi actif » dès que le serveur le dit', (t) async {
      // Même conversation, mêmes demandes : avant puis après l'arrêt de B.
      final live = fx('mutual2_both_live_A');
      final cid = live['conversationId'] as String;
      final inc = (live['incoming'] as Map)['messageId'] as String;
      expect(fx('mutual_B_stopped_live_A')['conversationId'], cid);
      final m = _msg(inc, mine: false, role: 'walker');
      PawFollowStateStore.debugApplySocketEvent(live);
      await t.pumpWidget(_app(SingleChildScrollView(
        child: pawFollowWithLiveState(m,
            conversationId: cid,
            build: (myLive, peerLive) => PawfollowRequestCard(
                  messageId: m.id,
                  requesterRole: 'walker',
                  responderRole: 'sitter',
                  status: 'accepted',
                  myRole: 'sitter',
                  isMine: false,
                  onAccept: () {},
                  onRefuse: () {},
                  onOpenMap: () {},
                  iShare: false,
                  liveNow: myLive,
                  peerLiveNow: peerLive,
                  onStop: () {},
                )),
      )));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('pawfollow_open_map_live')), findsOneWidget);
      expect(find.text('Suivi actif · Ouvrir la carte'), findsOneWidget);
      expect(find.text('Arrêter de suivre'), findsOneWidget);
      // B arrête son direct : l'événement serveur arrive.
      PawFollowStateStore.debugApplySocketEvent(fx('mutual_B_stopped_live_A'));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('pawfollow_open_map_live')), findsNothing);
      expect(find.text('Suivi actif · Ouvrir la carte'), findsNothing);
    });
  });

  group('carte du chat : statut terminé et boutons d\'arrêt', () {
    Future<void> card(WidgetTester t, {required String status, required bool iShare, bool liveNow = false}) async {
      await t.pumpWidget(_app(SingleChildScrollView(
        child: PawfollowRequestCard(
          messageId: 'm1',
          requesterRole: 'owner',
          responderRole: 'sitter',
          status: status,
          myRole: 'sitter',
          isMine: !iShare,
          onAccept: () {},
          onRefuse: () {},
          onOpenMap: () {},
          iShare: iShare,
          liveNow: liveNow,
          peerLiveNow: null,
          onStop: () {},
          onStartLive: () {},
        ),
      )));
      await t.pump(const Duration(milliseconds: 50));
    }

    testWidgets('terminée : « Suivi terminé », plus aucun bouton de suivi', (t) async {
      await card(t, status: 'ended', iShare: true, liveNow: true);
      expect(find.text('Suivi terminé'), findsOneWidget);
      expect(find.text('Ta position part en direct'), findsNothing);
      expect(find.text('Arrêter mon direct'), findsNothing);
      expect(find.text('Suivi actif · Ouvrir la carte'), findsNothing);
    });
    testWidgets('je suis l\'autre : « Arrêter de suivre »', (t) async {
      await card(t, status: 'accepted', iShare: false);
      expect(find.text('Arrêter de suivre'), findsOneWidget);
    });
    testWidgets('ma position part en direct : « Arrêter mon direct »', (t) async {
      await card(t, status: 'accepted', iShare: true, liveNow: true);
      expect(find.text('Ta position part en direct'), findsOneWidget);
      expect(find.text('Arrêter mon direct'), findsOneWidget);
    });
    testWidgets('ma position, direct arrêté : pas d\'arrêt, bouton pour relancer', (t) async {
      await card(t, status: 'accepted', iShare: true, liveNow: false);
      expect(find.text('Arrêter mon direct'), findsNothing);
      expect(find.byKey(const ValueKey('pawfollow_my_live_start')), findsOneWidget);
    });
  });

  test('clés chat604 : 9 langues, mêmes clés, accents français', () {
    final fr = chat604I18n['fr']!.keys.toSet();
    expect(fr.length, 10);
    for (final l in kLangs) {
      expect(chat604I18n[l]!.keys.toSet(), fr, reason: l);
      for (final k in fr) {
        expect(chat604I18n[l]![k]!.trim(), isNotEmpty, reason: '$l $k');
      }
    }
    expect(chat604I18n['fr']!['chat604_stop_following'], 'Arrêter de suivre');
    expect(chat604I18n['fr']!['chat604_peer_live_off'], 'Direct arrêté');
    final all = AppTranslations().keys;
    expect(all['fr_FR']!['chat604_stop_my_live'], 'Arrêter mon direct');
  });

  test('branchements : les 2 écrans de chat lisent l\'état serveur et l\'arrêt par sens', () {
    for (final f in [
      'lib/views/pet_owner/chat/individual_chat_screen.dart',
      'lib/views/pet_sitter/chat/sitter_individual_chat_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('PawFollowStateStore.watch(widget.conversationId)'), reason: f);
      expect(src, contains('PawFollowStateStore.unwatch(widget.conversationId)'), reason: f);
      expect(src, contains('pawFollowHeaderFor('), reason: f);
      expect(src, contains('conversationId: widget.conversationId,\n        build:'), reason: f);
      // v605 — les arrêts passent par le branchement unique (feuille « En direct »).
      expect(src, contains('openLiveSheetFromChat(context'), reason: f);
    }
  });
}
