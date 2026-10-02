// 607 (PAM, 02/10/2026) — rappel « N peluches près de toi » (validé par
// Daniel) : hors Balade seulement, rien si N = 0, un appui ouvre la feuille
// Balade, refermé = plus rien jusqu'au lendemain. Le serveur ne donne que le
// NOMBRE hors Balade (jamais les positions).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('pam607f');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await GetStorage.init();
  });

  test('1. visible seulement hors Balade, N > 0, couche allumée, pas refermé', () {
    bool v({bool logged = true, bool walk = false, bool layer = true, int n = 3, bool closed = false}) =>
        pawPlushHintVisible(loggedIn: logged, walking: walk, layerShown: layer, count: n, closedToday: closed);
    expect(v(), isTrue);
    expect(v(walk: true), isFalse);
    expect(v(n: 0), isFalse);
    expect(v(layer: false), isFalse);
    expect(v(closed: true), isFalse);
    expect(v(logged: false), isFalse);
  });

  test('2. refermé aujourd\'hui → revient le lendemain', () {
    final box = GetStorage();
    box.remove(kPawPlushHintClosedKey);
    final today = DateTime(2026, 10, 2, 23, 50);
    expect(pawPlushHintClosedToday(box: box, now: today), isFalse);
    pawPlushHintClose(box: box, now: today);
    expect(pawPlushHintClosedToday(box: box, now: today), isTrue);
    expect(pawPlushHintClosedToday(box: box, now: DateTime(2026, 10, 2, 8)), isTrue);
    expect(pawPlushHintClosedToday(box: box, now: DateTime(2026, 10, 3, 0, 5)), isFalse);
  });

  test('3. refreshHint lit nearbyCount, limite les appels (5 min / 1 km)', () async {
    var calls = 0;
    Object? reply = <String, dynamic>{'walkActive': false, 'plushies': <dynamic>[], 'nearbyCount': 4};
    final layer = PawPlushLayer(
      get: (path, q) async {
        calls++;
        expect(path, '/plush/active');
        return reply;
      },
      post: (_, __) async => null,
    );
    final t0 = DateTime(2026, 10, 2, 10);
    const paris = LatLng(48.8566, 2.3522);
    await layer.refreshHint(paris, now: t0);
    expect(layer.nearbyCount.value, 4);
    expect(calls, 1);
    // 1 min plus tard, même endroit : pas de nouvel appel
    await layer.refreshHint(paris, now: t0.add(const Duration(minutes: 1)));
    expect(calls, 1);
    // 2 km plus loin : nouvel appel
    reply = <String, dynamic>{'nearbyCount': 0};
    await layer.refreshHint(const LatLng(48.8746, 2.3522), now: t0.add(const Duration(minutes: 2)));
    expect(calls, 2);
    expect(layer.nearbyCount.value, 0);
    // forcé
    await layer.refreshHint(paris, now: t0.add(const Duration(minutes: 3)), force: true);
    expect(calls, 3);
  });

  testWidgets('4. texte singulier / pluriel, appui = feuille Balade, croix = fermer', (tester) async {
    var opened = 0;
    var closed = 0;
    Widget app(int n) => ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('fr'),
            home: Scaffold(
              body: Center(
                child: PawPlushHint(
                  count: n,
                  accent: const Color(0xFFD83C28),
                  onTap: () => opened++,
                  onClose: () => closed++,
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(app(3));
    await tester.pump();
    expect(find.text('3 peluches près de toi — lance une Balade pour les attraper'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_plush_hint_open')));
    expect(opened, 1);
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_plush_hint_close')));
    expect(closed, 1);
    expect(opened, 1);
    await tester.pumpWidget(app(1));
    await tester.pump();
    expect(find.text("1 peluche près de toi — lance une Balade pour l'attraper"), findsOneWidget);
    // Les 9 langues ont la phrase (aucune clé brute).
    for (final l in ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      final m = AppTranslations().keys[l] ?? AppTranslations().keys.entries
          .firstWhere((e) => e.key.startsWith(l)).value;
      expect(m['plush607_hint'], contains('@count'), reason: l);
      expect(m['plush607_hint_one'], isNotNull, reason: l);
      expect(m['plush607_hint_close'], isNotNull, reason: l);
    }
  });
}
