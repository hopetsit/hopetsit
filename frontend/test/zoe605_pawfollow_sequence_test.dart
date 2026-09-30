// v605 (ZOE, 30/09/2026) — BOB : « A suit B, puis B suit A » ne doit faire
// disparaître AUCUNE des deux pilules d'en-tête (celle de A, celle de B).
//
// États rejoués = réponses RÉELLES de GET /conversations/:id/pawfollow-state,
// produites par le vrai code serveur (backend/tests/pawfollowFlow604.test.js,
// describe « SÉQUENCE 605 », base Mongo en mémoire) et écrites dans
// test/fixtures/pawfollow604/seq605_*.json par
// `PF604_FIXTURES=1 npx jest --runInBand tests/pawfollowFlow604.test.js`.
//
// Étapes (A = gardien, B = promeneur, conversation d'amis) :
//   1) la demande de A est acceptée par B, A diffuse   → un sens en direct ;
//   2a) B demande l'autre sens (en attente) ;
//   2b) A accepte, B ne diffuse PAS encore ;
//   3) B diffuse                                       → deux sens en direct.
// Les pilules sont rendues par le vrai `PawFollowPill` à partir de
// `pawFollowHeaderFor` (même code que les deux écrans de discussion), avec
// l'état socket appliqué comme dans l'app (`pawfollow:state`).
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
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_state604.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_widgets.dart';

Map<String, dynamic> fx(String name) => jsonDecode(
        File('test/fixtures/pawfollow604/$name.json').readAsStringSync())
    as Map<String, dynamic>;

Widget _app(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: Scaffold(body: Center(child: child)),
      ),
    );

ChatMessage _msg(String id, {required bool mine, required String role}) =>
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
        'status': 'accepted',
        'requesterRole': role,
        'requesterId': mine ? 'me' : 'peer',
      },
    );

/// Une étape vue par un téléphone : réponse serveur + ce téléphone diffuse-t-il.
class _Step {
  const _Step(this.fixture, {required this.myLive});
  final String fixture;
  final bool myLive;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tmp = await Directory.systemTemp.createTemp('zoe605_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') return tmp.path;
      throw MissingPluginException(call.method);
    });
  });

  // A diffuse dès l'étape 1 ; B seulement à l'étape 3.
  const stepsA = <_Step>[
    _Step('seq605_1_A', myLive: true),
    _Step('seq605_2_pending_A', myLive: true),
    _Step('seq605_2_accepted_A', myLive: true),
    _Step('seq605_3_A', myLive: true),
  ];
  const stepsB = <_Step>[
    _Step('seq605_1_B', myLive: false),
    _Step('seq605_2_pending_B', myLive: false),
    _Step('seq605_2_accepted_B', myLive: false),
    _Step('seq605_3_B', myLive: true),
  ];

  group('règle de l\'en-tête, étape par étape (réponses serveur réelles)', () {
    PawFollowHeaderKind k(_Step s) => pawFollowHeaderKind(
        PawFollowConvState.fromJson(fx(s.fixture)),
        myLive: s.myLive,
        peerLiveLocal: null);

    test('A (premier à diffuser) : « En direct » à chaque étape', () {
      expect(k(stepsA[0]), PawFollowHeaderKind.myLive);
      expect(k(stepsA[1]), PawFollowHeaderKind.myLive);
      // Avant le 605 : « Direct arrêté » (faux, B n'avait jamais commencé)
      // et le « En direct » de A disparaissait.
      expect(k(stepsA[2]), PawFollowHeaderKind.myLive);
      expect(k(stepsA[3]), PawFollowHeaderKind.peerLive);
    });

    test('B (suit A, puis se fait suivre) : voit A « En direct » à chaque étape', () {
      for (final s in stepsB) {
        expect(k(s), PawFollowHeaderKind.peerLive, reason: s.fixture);
      }
    });

    test('garde-fou : B a VRAIMENT arrêté son direct → A voit bien « Direct arrêté »', () {
      final s = PawFollowConvState.fromJson(fx('mutual_B_stopped_live_A'));
      final ended = s.incoming.endedAt!;
      expect(
          pawFollowHeaderKind(s,
              myLive: true,
              peerLiveLocal: null,
              now: ended.add(const Duration(minutes: 1))),
          PawFollowHeaderKind.peerStopped);
    });
  });

  group('les DEUX pilules (téléphone de A, téléphone de B), socket rejouée', () {
    setUp(() {
      Get.testMode = true;
      Get.put<LiveMapService>(LiveMapService());
      PawFollowStateStore.states.clear();
    });
    tearDown(() {
      PawFollowStateStore.states.clear();
      Get.reset();
    });

    Future<void> run(WidgetTester t, List<_Step> steps, {required bool isA}) async {
      final live = Get.find<LiveMapService>();
      final first = fx(steps.first.fixture);
      final cid = first['conversationId'] as String;
      final last = fx(steps.last.fixture);
      final aMsg = ((isA ? last['outgoing'] : last['incoming']) as Map)['messageId'] as String;
      final bMsg = ((isA ? last['incoming'] : last['outgoing']) as Map)['messageId'] as String;
      // Messages de la conversation : demande de A (gardien) puis de B (promeneur).
      final msgs = <ChatMessageBase>[
        _msg(aMsg, mine: isA, role: 'sitter'),
        _msg(bMsg, mine: !isA, role: 'walker'),
      ];
      live.broadcasting.value = steps.first.myLive;
      PawFollowStateStore.debugApplySocketEvent(first);
      await t.pumpWidget(_app(Obx(() {
        final h = pawFollowHeaderFor(msgs, conversationId: cid);
        return PawFollowPill(
          key: ValueKey<String>('pill_${h.kind.name}'),
          label: 'cs_pf_pill_follow'.tr,
          onTap: () {},
          live: h.live,
          stoppedLabel: switch (h.kind) {
            PawFollowHeaderKind.myStopped => 'chat603_live_restart'.tr,
            PawFollowHeaderKind.peerStopped => 'chat603_live_stopped_ask'.tr,
            _ => null,
          },
        );
      })));
      for (final s in steps) {
        live.broadcasting.value = s.myLive;
        PawFollowStateStore.debugApplySocketEvent(fx(s.fixture));
        await t.pump(const Duration(milliseconds: 40));
        expect(find.text('En direct · voir la carte'), findsOneWidget,
            reason: '${s.fixture} : la pilule « En direct » a disparu');
        expect(find.byType(PawFollowLiveDot), findsOneWidget, reason: s.fixture);
        expect(find.text('Direct arrêté · redemander'), findsNothing, reason: s.fixture);
        expect(find.text('Relancer le direct'), findsNothing, reason: s.fixture);
      }
    }

    testWidgets('téléphone de A : « En direct » du début à la fin', (t) async {
      await run(t, stepsA, isA: true);
    });
    testWidgets('téléphone de B : « En direct » du début à la fin', (t) async {
      await run(t, stepsB, isA: false);
    });
  });

  testWidgets('branchement unique des arrêts du chat : openLiveSheetFromChat ouvre la confirmation',
      (t) async {
    await t.pumpWidget(_app(Builder(
      builder: (ctx) => TextButton(
        onPressed: () => openLiveSheetFromChat(ctx,
            conversationId: 'c', messageId: 'm', iShare: false),
        child: const Text('stop'),
      ),
    )));
    await t.tap(find.text('stop'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Arrêter de suivre ?'), findsOneWidget);
    expect(find.text('Arrêter de suivre'), findsOneWidget);
  });
}
