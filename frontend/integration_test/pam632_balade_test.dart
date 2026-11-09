// ignore_for_file: avoid_print
// 632 (PAM, 01/11/2026) — PARCOURS AU SIMULATEUR de la balade (vidéos de
// Daniel du 01/11, Condado de Alhama) : la pilule, le bouton rond vert et le
// bouton Balade de la barre disent-ils la MÊME chose, et la balade
// retombe-t-elle en « Connexion… » quand un envoi échoue ?
//
// SANS COMPTE ni écriture serveur : la carte est ouverte en visiteur à
// Kerguelen (zone de test), le serveur est un FAUX client API (il confirme,
// puis tombe en panne, puis revient), la balade est lancée dans le service
// du direct. Le GPS du simulateur est déplacé de l'extérieur
// (`xcrun simctl location`). Chaque `[P632] SNAP <nom>` = capture prise de
// l'extérieur ; chaque `[P632] M` = textes lus à l'écran au même instant.

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const double kLat = -49.35; // Kerguelen (zone de test, jamais une vraie ville)
const double kLng = 70.22;

class _FakeServer implements ApiClient {
  bool fail = false;
  int ok = 0, ko = 0;
  @override
  Future<dynamic> post(String endpoint,
      {Map<String, dynamic>? queryParameters,
      Object? body,
      Map<String, String>? headers,
      bool requiresAuth = false}) async {
    if (endpoint == '/friends/live-position') {
      if (fail) {
        ko++;
        throw const SocketException('réseau coupé (simulé)');
      }
      ok++;
      return <String, dynamic>{'ok': true, 'session': <String, dynamic>{}};
    }
    return <String, dynamic>{};
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

/// Textes visibles qui parlent de la balade : minutes et « Connexion… ».
String _read(WidgetTester t) {
  final connecting = 'live607_connecting'.tr;
  final out = <String>[];
  for (final e in find.byType(Text, skipOffstage: true).evaluate()) {
    final w = e.widget as Text;
    final s = (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll('\n', ' ');
    if (s.isEmpty) continue;
    if (s == connecting || RegExp(r'^\d+\s?min').hasMatch(s) || RegExp(r'\b\d+ ?min\b').hasMatch(s) ||
        s.toLowerCase().contains('balade') || s.toLowerCase().contains('direct')) {
      out.add('"$s"');
    }
  }
  final chrono = find.byKey(const ValueKey<String>('quick_walk_3110_chrono'));
  // 633 — un rond de chaque côté : on lit les deux (ils doivent dire pareil).
  final c = chrono.evaluate().isEmpty
      ? 'absent'
      : chrono.evaluate().map((e) => (e.widget as Text).data ?? '?').join('|');
  return 'rond="$c" textes=${out.join(' ')}';
}

Future<void> _snap(WidgetTester t, String name, _FakeServer api, LiveMapService live) async {
  await t.pump(const Duration(milliseconds: 600));
  print('[P632] M $name confirmee=${live.serverConfirmed.value} diffuse=${live.broadcasting.value} '
      'envois_ok=${api.ok} envois_rates=${api.ko} ${_read(t)}');
  print('[P632] SNAP $name');
  await t.pump(const Duration(seconds: 3));
}

Future<void> _wait(WidgetTester t, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    for (final code in ['fr', 'fr_FR']) {
      try {
        await initializeDateFormatting(code);
      } catch (_) {}
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}
    setupDependencies();
  });

  testWidgets('632 — balade : une seule vérité, pas de « Connexion… » au 1er raté', (t) async {
    await GetStorage().write('pawmap_intro_seen_count', 1);
    final api = _FakeServer();
    Get.replace<ApiClient>(api);
    final live = Get.isRegistered<LiveMapService>()
        ? Get.find<LiveMapService>()
        : Get.put(LiveMapService(), permanent: true);
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr', 'FR'),
        fallbackLocale: const Locale('en', 'US'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const PawMapScreen(initialLat: kLat, initialLng: kLng),
      ),
    ));
    for (var i = 0; i < 30 && find.byType(GoogleMap).evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    await _wait(t, 6);
    print('[P632] GPS start');
    await _snap(t, '0-avant', api, live);

    var step = 0;
    LatLng pos() => LatLng(kLat + step * 0.0002, kLng);
    final mover = Timer.periodic(const Duration(seconds: 5), (_) => step++);
    live.startBroadcasting(pos);
    await t.pump(const Duration(milliseconds: 300));
    await _snap(t, '1-depart', api, live);
    await _wait(t, 12);
    await _snap(t, '2-confirmee', api, live);

    api.fail = true; // le réseau tombe en pleine balade
    await _wait(t, 35);
    await _snap(t, '3-reseau-coupe-35s', api, live);

    api.fail = false;
    await _wait(t, 25);
    await _snap(t, '4-reseau-revenu-plus-1min', api, live);

    mover.cancel();
    live.stopBroadcasting();
    await _wait(t, 2);
    await _snap(t, '5-arretee', api, live);
    print('[P632] FIN');
  });
}
