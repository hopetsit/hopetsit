// 607 (PAM, 02/10/2026) — BOB : « j'appuie sur Balade → pilule « En balade »
// mais le serveur répond walkActive:false pendant plus d'une minute ».
// Cause mesurée : sans profil local, l'app n'envoyait pas `map:identify` et le
// serveur jetait les positions socket ; le HTTP n'était tenté que socket
// coupée. Désormais le serveur fait foi : la Balade n'est « confirmée » que si
// POST /friends/live-position renvoie une `session`. Ce fichier rejoue :
//   1. réponse avec session → confirmée ;
//   2. réponse sans session (ou `ignored`) → non confirmée ;
//   3. erreur réseau → non confirmée ;
//   4. la pilule dit « Connexion… » tant que ce n'est pas confirmé.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_walk_badge.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart' show pawFriendHaloShown;

class _FakeApi implements ApiClient {
  Object? reply;
  bool fail = false;
  final List<Object?> bodies = <Object?>[];

  @override
  Future<dynamic> post(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Object? body,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    bodies.add(body);
    if (fail) throw const SocketException('hors ligne');
    return reply;
  }

  @override
  Future<dynamic> get(String endpoint,
          {Map<String, dynamic>? queryParameters,
          Map<String, String>? headers,
          bool requiresAuth = false}) async =>
      <String, dynamic>{};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dir = Directory.systemTemp.createTempSync('pam607e');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  late _FakeApi api;
  setUp(() {
    Get.testMode = true;
    Get.reset();
    api = _FakeApi();
    Get.put<ApiClient>(api);
  });

  const paris = LatLng(48.8566, 2.3522);

  test('1. session renvoyée → Balade confirmée par le serveur', () async {
    final s = LiveMapService();
    s.broadcasting.value = true;
    api.reply = <String, dynamic>{'ok': true, 'session': <String, dynamic>{'startedAt': 'x'}};
    await s.postHttpForTest(paris);
    expect(s.serverConfirmed.value, isTrue);
    final body = api.bodies.single as Map;
    expect(body['lat'], paris.latitude);
    expect(body['lng'], paris.longitude);
  });

  test('2. pas de session, ou position ignorée → NON confirmée', () async {
    final s = LiveMapService();
    s.broadcasting.value = true;
    api.reply = <String, dynamic>{'ok': true};
    await s.postHttpForTest(paris);
    expect(s.serverConfirmed.value, isFalse);
    api.reply = <String, dynamic>{'ok': true, 'ignored': true, 'session': <String, dynamic>{}};
    await s.postHttpForTest(paris);
    expect(s.serverConfirmed.value, isFalse);
  });

  test('3. réseau coupé → NON confirmée, puis confirmée au retour', () async {
    final s = LiveMapService();
    s.broadcasting.value = true;
    api.fail = true;
    await s.postHttpForTest(null);
    expect(s.serverConfirmed.value, isFalse);
    expect((api.bodies.single as Map)['heartbeat'], isTrue);
    api.fail = false;
    api.reply = <String, dynamic>{'session': <String, dynamic>{}};
    await s.postHttpForTest(paris);
    expect(s.serverConfirmed.value, isTrue);
  });

  test('3b. Balade arrêtée entre-temps : une réponse tardive ne la confirme pas', () async {
    final s = LiveMapService();
    s.broadcasting.value = false;
    api.reply = <String, dynamic>{'session': <String, dynamic>{}};
    await s.postHttpForTest(paris);
    expect(s.serverConfirmed.value, isFalse);
  });

  testWidgets('4. pilule : « Connexion… » tant que le serveur n\'a pas confirmé',
      (tester) async {
    Widget pill(bool connecting) => ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('fr'),
            home: Scaffold(
              body: Center(
                child: PawMapDirectPill(
                  live: true,
                  startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
                  onTap: () {},
                  connecting: connecting,
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(pill(true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('live607_connecting'.tr), findsOneWidget);
    expect(find.textContaining('En balade'), findsNothing);
    await tester.pumpWidget(pill(false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('live607_connecting'.tr), findsNothing);
    expect(find.textContaining('En balade'), findsOneWidget);
  });

  test('5. halo d\'un ami : jamais seul après l\'arrêt de son direct', () {
    expect(pawFriendHaloShown(showFriends: true, state: FriendLiveState.live), isTrue);
    expect(pawFriendHaloShown(showFriends: true, state: FriendLiveState.lost), isTrue);
    expect(pawFriendHaloShown(showFriends: true, state: FriendLiveState.seen), isFalse);
    expect(pawFriendHaloShown(showFriends: false, state: FriendLiveState.live), isFalse);
  });

  testWidgets('6. « 1 te suit » au singulier, « 2 te suivent » au pluriel', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      home: const SizedBox(),
    ));
    expect(pawFollowersLabel(1), '1 te suit');
    expect(pawFollowersLabel(2), '2 te suivent');
  });
}
