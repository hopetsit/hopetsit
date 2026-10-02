// 607 (PAM, 02/10/2026) — bouton « PawPoints » de la barre de gauche (idée
// de Daniel). Mêmes ids que le site (LEO) : `pawpoints`, marqueur
// `no_pawpoints` ; en tête pour les réglages existants (affichage seulement).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dir = Directory.systemTemp.createTempSync('pam607h');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });

  test('1. ordre d\'origine : PawPoints en tête', () {
    expect(kPawRailDefaultOrder.first, 'pawpoints');
    expect(normalizeRailOrder(null).first, 'pawpoints');
  });

  test('2. réglage enregistré AVANT le bouton : affiché en tête, sans réécrire', () {
    final legacy = <String>['report', 'around', 'chat'];
    expect(normalizeRailOrder(legacy), <String>['pawpoints', 'report', 'around', 'chat']);
    expect(legacy, <String>['report', 'around', 'chat'], reason: 'liste du compte intacte');
  });

  test('3. masqué → marqueur no_pawpoints enregistré, et il reste masqué', () {
    final shown = <String>['around', 'report'];
    final saved = railOrderToSave(shown);
    expect(saved, <String>['around', 'report', 'no_pawpoints']);
    expect(normalizeRailOrder(saved), <String>['around', 'report']);
  });

  test('4. réaffiché → plus de marqueur ; synchro site ⇄ app dans les deux sens', () {
    // Ce que le site enregistre (railToSave de LEO) : ordre + marqueur.
    final fromSite = <String>['around', 'directions', 'no_pawpoints'];
    expect(normalizeRailOrder(fromSite), <String>['around', 'directions']);
    final fromSite2 = <String>['around', 'pawpoints', 'directions'];
    expect(normalizeRailOrder(fromSite2), <String>['around', 'pawpoints', 'directions']);
    // Ce que l'app enregistre est lu tel quel par le site (mêmes ids).
    expect(railOrderToSave(<String>['pawpoints', 'around']), <String>['pawpoints', 'around']);
    expect(railOrderToSave(<String>['around', 'no_pawpoints']), <String>['around', 'no_pawpoints']);
  });

  test('5. compteur du jour : seulement les peluches d\'aujourd\'hui', () async {
    final layer = PawPlushLayer(
      get: (path, q) async {
        expect(path, '/plush/collection');
        return <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{'type': 'fox', 'day': '2026-10-02'},
            <String, dynamic>{'type': 'kitty', 'day': '2026-10-02'},
            <String, dynamic>{'type': 'teddy', 'day': '2026-10-01'},
          ],
        };
      },
      post: (_, __) async => null,
    );
    await layer.refreshTodayCount(now: DateTime(2026, 10, 2, 9));
    expect(layer.caughtTodayCount.value, 2);
  });

  testWidgets('6. la barre : ourson, pastille verte si > 0, appui = action', (t) async {
    final taps = <String>[];
    Widget app(Map<String, Widget> badges) => ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('fr'),
            home: Scaffold(
              body: SingleChildScrollView(
                child: PawMapRail(
                  order: kPawRailDefaultOrder,
                  onTap: taps.add,
                  onLongPress: (_) {},
                  onCustomize: () {},
                  badges: badges,
                ),
              ),
            ),
          ),
        );
    await t.pumpWidget(app(const <String, Widget>{}));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('rail_pawpoints')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pawpoints_today_badge')), findsNothing);
    final img = find.descendant(
        of: find.byKey(const ValueKey<String>('rail_pawpoints')),
        matching: find.byType(Image));
    expect(img, findsOneWidget);
    await t.tap(find.byKey(const ValueKey<String>('rail_pawpoints')));
    expect(taps, <String>['pawpoints']);
    await t.pumpWidget(app(const <String, Widget>{'pawpoints': PawPlushTodayBadge(count: 2)}));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('pawpoints_today_badge')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // libellé et explication traduits (9 langues)
    for (final l in ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      final m = AppTranslations().keys[l] ??
          AppTranslations().keys.entries.firstWhere((e) => e.key.startsWith(l)).value;
      expect(m['ppr607_btn'], 'PawPoints', reason: l);
      expect((m['ppr607_help'] ?? '').length, greaterThan(20), reason: l);
      expect(m['help587_b_pawpoints'], isNotNull, reason: l);
    }
  });
}
