// 631 (PAM, 31/10/2026) — vidéos + vocaux de Daniel (Condado de Alhama, app 630) :
//   A. « je me mets en balade et ça se déconnecte seul » + toast « Direct
//      arrêté depuis ton autre téléphone » : un départ VOULU héritait du vieux
//      début de balade (kBgLiveActive resté à vrai) → l'arrêt serveur plus
//      récent coupait la balade neuve. Rejoué ici avec `liveStateDecision`.
//   D. pilule « En direct · autre téléphone » : la feuille dit depuis quand.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/widgets/pawmap_live_sheet.dart';

class _FakeApi implements ApiClient {
  @override
  Future<dynamic> get(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    if (endpoint.startsWith('/friends/live-positions')) {
      return <String, dynamic>{'positions': <Map<String, dynamic>>[]};
    }
    return <String, dynamic>{'active': false, 'followers': 0};
  }

  @override
  Future<dynamic> post(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Object? body,
      Map<String, String>? headers,
      bool requiresAuth = false}) async =>
      <String, dynamic>{'ok': true};

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
    final dir = Directory.systemTemp.createTempSync('pam631');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  setUp(() {
    Get.testMode = true;
    Get.reset();
    Get.put<ApiClient>(_FakeApi());
  });

  group('A. début de balade (pawLiveSessionStart631)', () {
    final now = DateTime(2026, 10, 31, 14, 10);
    final old = DateTime(2026, 10, 30, 18, 0).millisecondsSinceEpoch;

    test('départ voulu : MAINTENANT, même si un vieux début traîne', () {
      expect(pawLiveSessionStart631(resume: false, storedStartMs: old, now: now), now);
      expect(pawLiveSessionStart631(resume: false, storedStartMs: null, now: now), now);
    });

    test('reprise d\'une session persistée : le début enregistré', () {
      expect(pawLiveSessionStart631(resume: true, storedStartMs: old, now: now),
          DateTime.fromMillisecondsSinceEpoch(old));
      expect(pawLiveSessionStart631(resume: true, storedStartMs: 0, now: now), now);
    });

    test('scénario de Daniel : arrêt serveur d\'hier soir, balade neuve ce midi', () {
      // Le serveur n'a pas encore reçu ma première position : il répond
      // « arrêté » (arrêt fait hier soir depuis l'autre téléphone).
      final state = <String, dynamic>{
        'active': false,
        'stopped': true,
        'stoppedAt': DateTime(2026, 10, 30, 19, 30).toIso8601String(),
      };
      // AVANT (vieux début hérité) : la balade neuve était coupée.
      final avant = liveStateDecision(state,
          broadcasting: true,
          localStartedAt: pawLiveSessionStart631(resume: false, storedStartMs: old, now: now)
              .subtract(const Duration(days: 1)));
      // (vieux début = hier 18 h < arrêt 19 h 30 → coupure)
      expect(avant.stopLocal, isTrue, reason: 'le comportement du 630 rejoué');
      // APRÈS : départ = maintenant, l'arrêt d'hier est périmé → rien ne coupe.
      final apres = liveStateDecision(state,
          broadcasting: true,
          localStartedAt: pawLiveSessionStart631(resume: false, storedStartMs: old, now: now));
      expect(apres.stopLocal, isFalse);
      expect(apres.elsewhere, isFalse);
    });
  });

  group('D. feuille « En direct » quand le direct tourne ailleurs', () {
    testWidgets('ligne « Ma balade · sur ton autre téléphone · 12 min » + reprise', (t) async {
      final live = LiveMapService();
      live.liveElsewhere.value = true;
      live.elsewhereSince.value = DateTime.now().subtract(const Duration(minutes: 12));
      await t.pumpWidget(_app(PawLiveSheet(live: live, onFollowFriend: (_) {})));
      await t.pump();
      expect(find.byKey(const ValueKey<String>('live_sheet_nothing')), findsNothing,
          reason: 'jamais « Rien en direct » quand la pilule dit « autre téléphone »');
      expect(find.byKey(const ValueKey<String>('live_sheet_my_walk')), findsOneWidget);
      expect(find.textContaining('sur ton autre téléphone'), findsOneWidget);
      expect(find.textContaining('12 min'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('live_sheet_takeover')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('live_sheet_stop_walk')), findsOneWidget);
    });

    test('self-live d\'un autre appareil pose « depuis quand » ; l\'arrêt l\'efface', () {
      final live = LiveMapService();
      final at = DateTime.now().subtract(const Duration(minutes: 3));
      live.handleSelfLive611(<String, dynamic>{'active': true, 'at': at.toIso8601String()});
      expect(live.liveElsewhere.value, isTrue);
      expect(live.elsewhereSince.value, at);
      live.handleSelfLive611(<String, dynamic>{'active': false, 'at': DateTime.now().toIso8601String()});
      expect(live.liveElsewhere.value, isFalse);
      expect(live.elsewhereSince.value, isNull);
    });
  });
}
