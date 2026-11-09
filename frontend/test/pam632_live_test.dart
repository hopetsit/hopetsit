// 632 (PAM, 01/11/2026) — Daniel, iPhone 631, Condado de Alhama (Espagne) :
//   1. capture : « En direct · autre téléphone » alors qu'il n'était en
//      direct sur AUCUN autre téléphone ;
//   2. vidéo 1 : le bouton rond vert flottant affiche « 0 min » pendant que
//      la pilule du haut dit « Connexion… » (deux vérités) ;
//   3. vidéo 2 : « En balade » retombe en « Connexion… » en pleine marche,
//      puis « La peluche n'a pas pu être attrapée : on réessaie tout seul »
//      sans jamais l'attraper.
// Ce fichier rejoue chaque point AVANT / APRÈS sur le code réel.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/open_on_prefs_3110.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_walk_badge.dart';
import 'package:hopetsit/widgets/quick_walk_button_3110.dart';

import 'lotd_harness.dart';

class _FakeApi implements ApiClient {
  Object? reply;
  bool fail = false;
  final List<String> posts = <String>[];
  final List<Object?> bodies = <Object?>[];

  @override
  Future<dynamic> post(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Object? body,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    posts.add(endpoint);
    bodies.add(body);
    if (fail) throw const SocketException('réseau coupé');
    return reply;
  }

  @override
  Future<dynamic> get(String endpoint,
          {Map<String, dynamic>? queryParameters,
          Map<String, String>? headers,
          bool requiresAuth = false}) async =>
      reply;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('pam632');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });

  group('1. « autre téléphone » seulement si un AUTRE appareil tient la balade', () {
    final state = <String, dynamic>{'active': true, 'stopped': false, 'deviceId': 'IPH-DANIEL'};

    test('AVANT (serveur sans appareil) : toute session = « autre téléphone »', () {
      final d = liveStateDecision(<String, dynamic>{'active': true}, broadcasting: false,
          myDeviceId: 'IPH-DANIEL');
      expect(d.elsewhere, isTrue, reason: 'appareil inconnu (serveur ≤ 631) : comportement d\'avant');
    });

    test('APRÈS : la session de CE téléphone n\'est jamais « ailleurs »', () {
      final d = liveStateDecision(state, broadcasting: false, myDeviceId: 'IPH-DANIEL');
      expect(d.elsewhere, isFalse);
      expect(d.ownOrphan, isTrue, reason: 'balade restée ouverte côté serveur : à refermer');
    });

    test('un vrai autre téléphone reste « ailleurs »', () {
      final d = liveStateDecision(state, broadcasting: false, myDeviceId: 'ANDROID-2');
      expect(d.elsewhere, isTrue);
      expect(d.ownOrphan, isFalse);
    });

    test('identifiants vides : jamais « ce téléphone »', () {
      expect(pawLiveSessionIsThisDevice632('', ''), isFalse);
      expect(pawLiveSessionIsThisDevice632(null, 'X'), isFalse);
      expect(pawLiveSessionIsThisDevice632(' X ', 'X'), isTrue);
    });

    test('syncLiveState : ma balade orpheline → « Direct off » + arrêt renvoyé', () async {
      Get.testMode = true;
      Get.reset();
      final api = _FakeApi();
      Get.put<ApiClient>(api);
      final live = LiveMapService();
      api.reply = <String, dynamic>{
        'active': true,
        'stopped': false,
        'deviceId': live.liveDeviceId,
        'startedAt': DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String(),
      };
      await live.syncLiveState();
      expect(live.liveElsewhere.value, isFalse);
      expect(api.posts, contains('/friends/live-position'));
      expect((api.bodies.last as Map)['offline'], isTrue);
      // contrôle ZOE : fermeture d'orpheline = arrêt CONDITIONNEL, avec l'appareil
      expect((api.bodies.last as Map)['onlyIfMine'], isTrue);
      expect((api.bodies.last as Map)['deviceId'], live.liveDeviceId);
    });

    test('corps de l\'arrêt : sans condition par défaut, appareil vide omis', () {
      expect(pawLiveOfflineBody632(), <String, dynamic>{'offline': true});
      expect(pawLiveOfflineBody632(deviceId: ' A ', onlyIfMine: true),
          <String, dynamic>{'offline': true, 'deviceId': 'A', 'onlyIfMine': true});
    });

    test('self-live : mon propre départ (même appareil) ne dit pas « ailleurs »', () {
      Get.testMode = true;
      Get.reset();
      Get.put<ApiClient>(_FakeApi());
      final live = LiveMapService();
      live.handleSelfLive611(<String, dynamic>{
        'active': true,
        'at': DateTime.now().toIso8601String(),
        'deviceId': live.liveDeviceId,
      });
      expect(live.liveElsewhere.value, isFalse);
      live.handleSelfLive611(<String, dynamic>{
        'active': true,
        'at': DateTime.now().toIso8601String(),
        'deviceId': 'UN-AUTRE',
      });
      expect(live.liveElsewhere.value, isTrue);
    });
  });

  group('3. « En balade » ne retombe pas en « Connexion… » au premier envoi raté', () {
    late _FakeApi api;
    setUp(() {
      Get.testMode = true;
      Get.reset();
      api = _FakeApi();
      Get.put<ApiClient>(api);
    });
    const p = LatLng(37.85, -1.43);

    test('confirmée puis réseau coupé : reste confirmée (< 90 s)', () async {
      final s = LiveMapService();
      s.broadcasting.value = true;
      api.reply = <String, dynamic>{'ok': true, 'session': <String, dynamic>{}};
      await s.postHttpForTest(p);
      expect(s.serverConfirmed.value, isTrue);
      api.fail = true;
      await s.postHttpForTest(p);
      expect(s.serverConfirmed.value, isTrue, reason: 'AVANT 632 : false → « Connexion… »');
    });

    test('jamais confirmée + réseau coupé : « Connexion… » (honnête)', () async {
      final s = LiveMapService();
      s.broadcasting.value = true;
      api.fail = true;
      await s.postHttpForTest(p);
      expect(s.serverConfirmed.value, isFalse);
    });

    test('refus explicite du serveur (ignored) : coupe tout de suite', () async {
      final s = LiveMapService();
      s.broadcasting.value = true;
      api.reply = <String, dynamic>{'ok': true, 'session': <String, dynamic>{}};
      await s.postHttpForTest(p);
      api.reply = <String, dynamic>{'ok': true, 'ignored': true, 'stopped': true};
      await s.postHttpForTest(p);
      expect(s.serverConfirmed.value, isFalse);
    });

    test('délai de grâce : 90 s après le dernier envoi réussi', () {
      final t0 = DateTime(2026, 11, 1, 14, 3);
      expect(pawLiveStillConfirmed632(lastOkAt: t0, now: t0.add(const Duration(seconds: 89))), isTrue);
      expect(pawLiveStillConfirmed632(lastOkAt: t0, now: t0.add(const Duration(seconds: 91))), isFalse);
      expect(pawLiveStillConfirmed632(lastOkAt: null, now: t0), isFalse);
    });

    test('arrêt perdu : 7 nouveaux essais sur ~4 min (avant : 3 en 18 s)', () {
      expect(kLiveOfflineRetrySeconds632.length, 7);
      expect(kLiveOfflineRetrySeconds632.fold<int>(0, (a, b) => a + b), greaterThanOrEqualTo(200));
    });
  });

  group('2. bouton rond = même vérité que la pilule', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      OpenOnPrefs3110.resetForTest();
    });
    Widget host(Widget child) => lotdApp(Scaffold(body: Center(child: child)));

    testWidgets('balade non confirmée : « Connexion… », jamais « 0 min »', (t) async {
      final confirmed = false.obs;
      final start = DateTime(2026, 11, 1, 13, 59);
      await t.pumpWidget(host(QuickWalkButton3110(
        visible: true.obs,
        broadcasting: true.obs,
        confirmed: confirmed,
        elsewhere: false.obs,
        startedAt: Rxn<DateTime>(start),
        now: () => start.add(const Duration(seconds: 40)),
      )));
      await t.pump();
      // 633 (design de Daniel) : « Connexion… » sur la ligne de statut, le
      // compteur de minutes reste « — » tant que rien n'est confirmé.
      final chrono = find.byKey(const ValueKey<String>('quick_walk_3110_chrono'));
            expect(_qwStatus(t), startsWith('live607_connecting'.tr));
      expect((t.widget<Text>(chrono)).data, '—');
      confirmed.value = true;
      await t.pump();
      expect(_qwStatus(t), startsWith('pamc3110_qw_live'.tr));
      // 0 min 40 s : même minute que la barre (« 0 min »).
      expect((t.widget<Text>(chrono)).data, '0');
      expect(pawWalkBadgeMinutes(start, start.add(const Duration(seconds: 40))), startsWith('0'));
      expect(t.widget<Text>(find.byKey(const ValueKey<String>('quick_walk_3110_secs'))).data, startsWith('40'));
    });

    testWidgets('même minute que la barre au même instant (horloge commune)', (t) async {
      final start = DateTime(2026, 11, 1, 14, 2, 10);
      final now = DateTime(2026, 11, 1, 14, 4, 5); // 1 min 55 s
      await t.pumpWidget(host(QuickWalkButton3110(
        visible: true.obs,
        broadcasting: true.obs,
        confirmed: true.obs,
        elsewhere: false.obs,
        startedAt: Rxn<DateTime>(start),
        now: () => now,
      )));
      await t.pump();
      final txt = t.widget<Text>(find.byKey(const ValueKey<String>('quick_walk_3110_chrono'))).data;
      // 633 : le rond affiche les minutes seules (« 1 » + « MIN »), la barre
      // « 1 min » — même minute au même instant.
      expect(txt, '1');
      expect(pawWalkBadgeMinutes(start, now), startsWith('1 '));
      expect(t.widget<Text>(find.byKey(const ValueKey<String>('quick_walk_3110_secs'))).data, startsWith('55'));
    });

    testWidgets('dans la PawMap : 1 toucher = le geste du bouton Balade de la barre', (t) async {
      var railTaps = 0, starts = 0;
      await t.pumpWidget(host(QuickWalkButton3110(
        visible: true.obs,
        broadcasting: false.obs,
        confirmed: true.obs,
        elsewhere: true.obs, // balade sur un autre téléphone
        startedAt: Rxn<DateTime>(),
        onStart: () async => starts++,
        onTapOverride: () async => railTaps++,
      )));
      await t.pump();
      await t.tap(find.byKey(const ValueKey<String>('quick_walk_3110_tap')));
      await t.pump(const Duration(milliseconds: 300));
      expect(railTaps, 1);
      expect(starts, 0);
    });
  });

  group('3b. peluche : un échec passager est VRAIMENT retenté', () {
    test('réseau coupé → retentée 5 s plus tard (avant : 20 s et seulement si le GPS bouge)', () async {
      var calls = 0;
      var fail = true;
      final c = PawPlushLayer(
        get: (_, __) async => <String, dynamic>{},
        post: (path, body) async {
          calls++;
          if (fail) throw const SocketException('réseau coupé');
          return <String, dynamic>{'ok': true, 'points': 20, 'plush': <String, dynamic>{'type': 'puppy'}};
        },
      );
      c.shown.value = true;
      c.items.assignAll(<PawPlush>[
        PawPlush(id: 'p1', type: 'puppy', golden: false, lat: 37.8500, lng: -1.4300),
      ]);
      const me = LatLng(37.85015, -1.43); // ~17 m
      final t0 = DateTime(2026, 11, 1, 14, 3, 40);
      final (r1, _) = await c.onPosition(me, now: t0, accuracy: 8);
      expect(r1, PawPlushCatch.refused);
      expect(c.lastRefusalRetryable, isTrue);
      final (r2, _) = await c.onPosition(me, now: t0.add(const Duration(seconds: 3)), accuracy: 8);
      expect(r2, PawPlushCatch.none, reason: 'pas de rafale');
      fail = false;
      final (r3, pts) = await c.onPosition(me, now: t0.add(const Duration(seconds: 6)), accuracy: 8);
      expect(r3, PawPlushCatch.caught);
      expect(pts, 20);
      expect(calls, 2);
    });

    test('refus clair (TOO_FAR) : pas de retentative rapide', () async {
      final c = PawPlushLayer(
        get: (_, __) async => <String, dynamic>{},
        post: (path, body) async =>
            throw ApiException('loin', statusCode: 422, details: <String, dynamic>{'code': 'TOO_FAR', 'distanceM': 41}),
      );
      c.shown.value = true;
      c.items.assignAll(<PawPlush>[
        PawPlush(id: 'p1', type: 'puppy', golden: false, lat: 37.8500, lng: -1.4300),
      ]);
      final (r, _) = await c.onPosition(const LatLng(37.85015, -1.43), now: DateTime(2026, 11, 1), accuracy: 8);
      expect(r, PawPlushCatch.refused);
      expect(c.lastRefusalRetryable, isFalse);
      expect(pawPlushRetryable632(code: 'TOO_FAR', statusCode: 422), isFalse);
      expect(pawPlushRetryable632(code: '', statusCode: 500), isTrue);
      expect(pawPlushRetryable632(code: 'X', statusCode: 503), isTrue);
    });
  });

  test('peluche : 3 relances rapides au plus, puis délai normal (contrôle ZOE)', () async {
    var calls = 0;
    final c = PawPlushLayer(
      get: (_, __) async => <String, dynamic>{},
      post: (path, body) async {
        calls++;
        throw ApiException('panne', statusCode: 500);
      },
    );
    c.shown.value = true;
    c.items.assignAll(<PawPlush>[PawPlush(id: 'p1', type: 'puppy', lat: 37.85, lng: -1.43)]);
    const me = LatLng(37.85015, -1.43);
    var t = DateTime(2026, 11, 1, 14);
    final retryable = <bool>[];
    for (var i = 0; i < 4; i++) {
      await c.onPosition(me, now: t, accuracy: 8);
      retryable.add(c.lastRefusalRetryable);
      t = t.add(const Duration(seconds: 6));
    }
    expect(calls, 4);
    expect(retryable, <bool>[true, true, true, false]);
    final (r, _) = await c.onPosition(me, now: t, accuracy: 8); // 6 s après le 4e
    expect(r, PawPlushCatch.none, reason: 'retour au délai normal de 20 s');
    expect(calls, 4);
  });
}

/// 634 — le texte d'état vit dans la sémantique du rond (62 pt, plus de ligne
/// « BALADE EN DIRECT » visible).
String _qwStatus(WidgetTester t) => t
    .widgetList<Semantics>(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.button == true &&
            (w.key is ValueKey<String>) &&
            (w.key as ValueKey<String>).value.startsWith('quick_walk_3110_')))
    .first
    .properties
    .label!;
