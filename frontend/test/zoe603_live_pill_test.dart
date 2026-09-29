// v603 (ZOE, 29/09/2026) — Daniel : la pilule « En direct · voir la carte » du
// chat restait affichée après l'arrêt du direct. Elle suit maintenant l'état
// RÉEL du partage : le mien (broadcasting / liveElsewhere, comme le bouton
// Balade) si c'est ma position, celui de l'autre (positions en direct reçues
// par socket) sinon ; arrêté → « Relancer le direct » / « Direct arrêté ·
// redemander ». Tests : règle pure, réaction en temps réel aux événements du
// direct, rendu de la pilule et de la carte du chat, 9 langues, branchements.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/notif599_i18n.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_widgets.dart';
import 'package:hopetsit/widgets/pawfollow_request_card.dart';

const kLangs = <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ja', 'ko'];
const peer = '6a0000000000000000000005';

Widget _app(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: Scaffold(body: Center(child: child)),
      ),
    );

ChatMessage _pf({
  required bool mine,
  required String requesterRole,
  String status = 'accepted',
}) =>
    ChatMessage(
      id: 'm1',
      senderId: mine ? 'me' : peer,
      senderName: 'X',
      senderImage: '',
      message: '',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isFromCurrentUser: mine,
      type: 'pawfollow_request',
      metadata: <String, dynamic>{
        'status': status,
        'requesterRole': requesterRole,
        'responderRole': requesterRole == 'owner' ? 'walker' : 'owner',
        'requesterId': mine ? 'me' : peer,
        if (mine) 'respondedBy': peer,
      },
    );

FriendPosition _peerPos({required bool sharing, int ageSec = 5}) => FriendPosition(
      userId: 'k-$peer',
      role: 'walker',
      latitude: -35.2,
      longitude: -30.4,
      at: DateTime.now(),
      lastSeenAt: DateTime.now().subtract(Duration(seconds: ageSec)),
      sharing: sharing,
      personIds: const <String>[peer],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // GetStorage (lu par LiveMapService) écrit dans un dossier temporaire.
    tmp = await Directory.systemTemp.createTemp('zoe603_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') return tmp.path;
      throw MissingPluginException(call.method);
    });
  });

  group('règle pure', () {
    test('pas de demande acceptée → rien', () {
      expect(
          pawFollowLiveStatus(accepted: false, iShare: true, myLive: true, peerLive: true),
          PawFollowLiveStatus.none);
    });
    test('ma position : suit MON direct', () {
      expect(pawFollowLiveStatus(accepted: true, iShare: true, myLive: true, peerLive: null),
          PawFollowLiveStatus.live);
      expect(pawFollowLiveStatus(accepted: true, iShare: true, myLive: false, peerLive: true),
          PawFollowLiveStatus.stopped);
    });
    test('position de l\'autre : suit SON direct ; inconnu = arrêté', () {
      expect(pawFollowLiveStatus(accepted: true, iShare: false, myLive: true, peerLive: true),
          PawFollowLiveStatus.live);
      expect(pawFollowLiveStatus(accepted: true, iShare: false, myLive: true, peerLive: false),
          PawFollowLiveStatus.stopped);
      expect(pawFollowLiveStatus(accepted: true, iShare: false, myLive: false, peerLive: null),
          PawFollowLiveStatus.stopped);
    });
    test('ids de l\'autre : expéditeur, ou répondant si la demande est de moi', () {
      expect(pawFollowPeerIds(_pf(mine: false, requesterRole: 'walker')), {peer});
      expect(pawFollowPeerIds(_pf(mine: true, requesterRole: 'owner')), {peer});
      expect(pawFollowPeerIds(_pf(mine: true, requesterRole: 'owner'), contactId: 'C1'),
          {peer, 'c1'});
    });
  });

  group('temps réel (même service que la PawMap)', () {
    late LiveMapService live;
    setUp(() {
      Get.testMode = true;
      live = LiveMapService();
      Get.put<LiveMapService>(live);
    });
    tearDown(Get.reset);

    test('je partage : direct arrêté puis relancé ailleurs', () {
      // Propriétaire qui a accepté la demande d'un promeneur qui VEUT le suivre ?
      // Non : ici un promeneur (moi) a proposé de partager → c'est moi qui partage.
      final msgs = [_pf(mine: true, requesterRole: 'walker')];
      live.broadcasting.value = true;
      expect(pawFollowLiveStatusFor(msgs), PawFollowLiveStatus.live);
      live.broadcasting.value = false; // arrêté depuis la PawMap
      expect(pawFollowLiveStatusFor(msgs), PawFollowLiveStatus.stopped);
      live.liveElsewhere.value = true; // relancé sur mon autre téléphone
      expect(pawFollowLiveStatusFor(msgs), PawFollowLiveStatus.live);
    });

    test('je suis : suit map:friend-position puis map:friend-offline', () {
      // Moi propriétaire, j'ai demandé à suivre le promeneur → il partage.
      final msgs = [_pf(mine: true, requesterRole: 'owner')];
      expect(pawFollowLiveStatusFor(msgs), PawFollowLiveStatus.stopped); // rien reçu
      live.friendPositions['k-$peer'] = _peerPos(sharing: true);
      expect(pawFollowLiveStatusFor(msgs), PawFollowLiveStatus.live);
      live.friendPositions['k-$peer'] = _peerPos(sharing: false); // friend-offline
      expect(pawFollowLiveStatusFor(msgs), PawFollowLiveStatus.stopped);
      live.friendPositions['k-$peer'] = _peerPos(sharing: true, ageSec: 5 * 60);
      expect(pawFollowLiveStatusFor(msgs), PawFollowLiveStatus.live); // signal perdu < 10 min
      live.friendPositions['k-$peer'] = _peerPos(sharing: true, ageSec: 30 * 60);
      expect(pawFollowLiveStatusFor(msgs), PawFollowLiveStatus.stopped);
    });

    testWidgets('la carte du chat se met à jour sans recharger', (tester) async {
      final m = _pf(mine: true, requesterRole: 'owner');
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: pawFollowWithLiveState(m,
            build: (myLive, peerLive) => PawfollowRequestCard(
                  messageId: m.id,
                  requesterRole: 'owner',
                  responderRole: 'walker',
                  status: 'accepted',
                  myRole: 'owner',
                  isMine: true,
                  onAccept: () {},
                  onRefuse: () {},
                  onOpenMap: () {},
                  iShare: false,
                  liveNow: myLive,
                  peerLiveNow: peerLive,
                )),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('pawfollow_open_map_live')), findsNothing);
      expect(find.text('Voir sur la carte'), findsOneWidget);
      live.friendPositions['k-$peer'] = _peerPos(sharing: true);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('pawfollow_open_map_live')), findsOneWidget);
      live.friendPositions['k-$peer'] = _peerPos(sharing: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('pawfollow_open_map_live')), findsNothing);
    });
  });

  group('pilule', () {
    Future<void> pill(WidgetTester t, {bool live = false, String? stopped}) async {
      await t.pumpWidget(_app(PawFollowPill(
        label: 'Suivre',
        onTap: () {},
        live: live,
        stoppedLabel: stopped,
      )));
      await t.pump(const Duration(milliseconds: 50));
    }

    testWidgets('en direct : point vert + « En direct · voir la carte »', (t) async {
      await pill(t, live: true, stopped: 'ignoré');
      expect(find.text('En direct · voir la carte'), findsOneWidget);
      expect(find.byType(PawFollowLiveDot), findsOneWidget);
    });
    testWidgets('arrêté : « Relancer le direct », jamais le point vert', (t) async {
      await pill(t, stopped: 'chat603_live_restart'.tr);
      expect(find.text('Relancer le direct'), findsOneWidget);
      expect(find.text('En direct · voir la carte'), findsNothing);
      expect(find.byType(PawFollowLiveDot), findsNothing);
      expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
    });
    testWidgets('sans demande : libellé d\'origine', (t) async {
      await pill(t);
      expect(find.text('Suivre'), findsOneWidget);
    });
  });

  test('9 langues, mêmes clés', () {
    final fr = notif599I18n['fr']!.keys.where((k) => k.startsWith('chat603_')).toSet();
    expect(fr, {'chat603_live_restart', 'chat603_live_stopped_ask'});
    for (final l in kLangs) {
      for (final k in fr) {
        expect(notif599I18n[l]?[k], isNotEmpty, reason: '$l $k');
      }
    }
    expect(notif599I18n['fr']!['chat603_live_stopped_ask'], 'Direct arrêté · redemander');
  });

  test('les 2 écrans de chat branchent la pilule et la carte sur l\'état réel', () {
    for (final f in [
      'lib/views/pet_owner/chat/individual_chat_screen.dart',
      'lib/views/pet_sitter/chat/sitter_individual_chat_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('pawFollowLiveStatusFor('), reason: f);
      expect(src, contains("'chat603_live_restart'.tr"), reason: f);
      expect(src, contains('pawFollowWithLiveState('), reason: f);
      expect(src, contains('peerLiveNow: peerLiveNow'), reason: f);
      expect(src, isNot(contains('live: live != null')), reason: f);
    }
  });
}
