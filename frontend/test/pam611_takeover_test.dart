// 611 (PAM, 04/10/2026) — capture de Cam (app 610, 17 h 30) : « En direct de
// mon autre iPhone qui est resté à la maison. Du coup je ne peux pas être en
// direct avec ce iPhone. » La barre de droite montrait la pastille « téléphone »
// au-dessus de Balade et AUCUNE façon de passer le direct sur le téléphone en
// main. Ce fichier rejoue :
//   1. la feuille « En direct » quand le direct tourne ailleurs : la ligne
//      claire + « Passer en direct sur ce téléphone » + « Arrêter » ;
//   2. l'appui sur « Passer en direct… » : UN appel de reprise au serveur
//      (avec l'identifiant de CE téléphone), puis le direct démarre ici ;
//   3. l'ancien téléphone reçoit la reprise : il s'arrête SANS prévenir le
//      serveur (aucun « offline » qui couperait le nouveau), puis affiche
//      « direct sur ton autre téléphone » ; le téléphone qui reprend ignore
//      ce même message ;
//   4. chaque position envoyée porte l'identifiant de l'appareil ;
//   5. le filtre 604 reste : l'écho de mon propre arrêt ne rallume rien.
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
import 'package:hopetsit/views/map/widgets/pawmap_live_sheet.dart';

class _FakeApi implements ApiClient {
  final List<String> posts = <String>[];
  final List<Object?> bodies = <Object?>[];

  @override
  Future<dynamic> get(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    if (endpoint.startsWith('/friends/live-state')) {
      return <String, dynamic>{'active': true, 'followers': 1};
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> post(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Object? body,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    posts.add(endpoint);
    bodies.add(body);
    if (endpoint == '/friends/live-takeover') {
      return <String, dynamic>{'ok': true, 'takenOver': true};
    }
    return <String, dynamic>{'ok': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dir = Directory.systemTemp.createTempSync('pm611');
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

  testWidgets('1-2. direct ailleurs : ligne claire, « Passer en direct sur ce téléphone », un appel de reprise', (t) async {
    final live = LiveMapService();
    live.liveElsewhere.value = true;
    var started = 0;
    await t.pumpWidget(_app(PawLiveSheet(
      live: live,
      onTakeOver: () async {
        final ok = await live.requestTakeover();
        if (ok) started++;
      },
    )));
    await t.pump();
    expect(find.text('Ton direct tourne sur un autre téléphone'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('live_sheet_takeover')), findsOneWidget);
    expect(find.text('Passer en direct sur ce téléphone'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('live_sheet_stop_walk')), findsOneWidget,
        reason: '« Arrêter le direct » reste proposé');
    await t.tap(find.byKey(const ValueKey<String>('live_sheet_takeover')));
    await t.pump(const Duration(milliseconds: 50));
    expect(api.posts, contains('/friends/live-takeover'));
    final body = api.bodies[api.posts.indexOf('/friends/live-takeover')] as Map;
    expect((body['deviceId'] ?? '').toString(), live.liveDeviceId);
    expect(live.liveDeviceId.length, greaterThanOrEqualTo(12));
    expect(started, 1);
    expect(live.liveElsewhere.value, isFalse, reason: 'le téléphone en main n\'est plus « ailleurs »');
  });

  testWidgets('1b. ce téléphone diffuse : pas de bouton de reprise', (t) async {
    final live = LiveMapService();
    live.broadcasting.value = true;
    live.sessionStartedAt.value = DateTime.now();
    await t.pumpWidget(_app(PawLiveSheet(live: live)));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('live_sheet_takeover')), findsNothing);
  });

  test('3. reprise reçue par l\'ANCIEN téléphone : arrêt local sans « offline », puis « ailleurs »', () {
    final old = LiveMapService();
    old.broadcasting.value = true;
    old.handleSelfLive611(<String, dynamic>{
      'active': false, 'reason': 'device_takeover', 'keepDeviceId': 'autre-iphone',
      'at': DateTime.now().toIso8601String(),
    });
    expect(old.broadcasting.value, isFalse);
    expect(api.posts.where((p) => p == '/friends/live-position'), isEmpty,
        reason: 'un offline couperait le direct repris par l\'autre téléphone');
    old.handleSelfLive611(<String, dynamic>{
      'active': true, 'reason': 'device_takeover', 'deviceId': 'autre-iphone',
      'at': DateTime.now().toIso8601String(),
    });
    expect(old.liveElsewhere.value, isTrue);
  });

  test('3b. le téléphone qui reprend ignore les deux messages de reprise', () {
    final me = LiveMapService();
    me.broadcasting.value = true;
    me.handleSelfLive611(<String, dynamic>{
      'active': false, 'reason': 'device_takeover', 'keepDeviceId': me.liveDeviceId,
    });
    expect(me.broadcasting.value, isTrue);
    me.handleSelfLive611(<String, dynamic>{
      'active': true, 'reason': 'device_takeover', 'deviceId': me.liveDeviceId,
    });
    expect(me.liveElsewhere.value, isFalse);
  });

  test('4. chaque position HTTP porte l\'identifiant de l\'appareil', () async {
    final live = LiveMapService();
    live.broadcasting.value = true;
    await live.postHttpForTest(const LatLng(-35.2, -30.4));
    final i = api.posts.indexOf('/friends/live-position');
    expect(i, isNonNegative);
    expect(((api.bodies[i] as Map)['deviceId'] ?? '').toString(), live.liveDeviceId);
  });

  test('5. filtre 604 gardé : un ancien « actif » antérieur à mon arrêt ne rallume rien', () async {
    final live = LiveMapService();
    live.broadcasting.value = true;
    await live.stopEverywhere(); // arrêt voulu ici
    live.handleSelfLive611(<String, dynamic>{
      'active': true,
      'at': DateTime.now().subtract(const Duration(seconds: 5)).toIso8601String(),
    });
    expect(live.liveElsewhere.value, isFalse);
  });
}
