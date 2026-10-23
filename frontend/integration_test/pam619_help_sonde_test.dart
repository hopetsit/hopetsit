// 619 (PAM, 23/10/2026) — sonde SIMULATEUR de « Comprendre la PawMap »
// complétée comme la page web /pawmap (aucun compte, aucun appel réseau) :
// héros patte-pin, puis chaque section nouvelle (signalements, lieux,
// comment ça marche, nouveautés, abonnements) et le bouton « Voir sur la
// carte », en clair puis en sombre.
// Le runner capture l'écran à chaque ligne « [SHOT] nom » (3 s de pause).
//   flutter test integration_test/pam619_help_sonde_test.dart -d <udid>
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:integration_test/integration_test.dart';

Widget _page({Brightness b = Brightness.light}) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('en'),
        theme: ThemeData(
            brightness: b,
            useMaterial3: true,
            scaffoldBackgroundColor:
                b == Brightness.dark ? const Color(0xFF17141F) : const Color(0xFFFFF7F2)),
        home: const PawMapHelpScreen(role: 'owner'),
      ),
    );

/// Les blocs à photographier, dans l'ordre de l'écran (clé → nom de capture).
const List<(String, String)> _shots = <(String, String)>[
  ('help619_hero', 'hero'),
  ('help_sec_reports', 'signalements'),
  ('help_sec_places', 'lieux'),
  ('help_sec_steps', 'comment_ca_marche'),
  ('help619_news_month', 'nouveau_mois'),
  ('help619_news_premium', 'nouveau_pins_x2'),
  ('help619_plan_pf', 'abonnements_pawfollow'),
  ('help619_plan_pp', 'abonnements_premium'),
  ('help619_premium_band', 'bande_premium_voir_carte'),
];

Future<void> _shoot(WidgetTester t, String prefix) async {
  final scrollable = find.byType(Scrollable).first;
  for (final (key, name) in _shots) {
    final target = find.byKey(ValueKey<String>(key), skipOffstage: false);
    expect(target, findsOneWidget, reason: key);
    await t.dragUntilVisible(target, scrollable, const Offset(0, -260));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull, reason: 'rendu $key');
    debugPrint('[SONDE-R] $prefix $name visible');
    debugPrint('[SHOT] ${prefix}_$name');
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sonde 619 — aide PawMap complète, clair puis sombre', (t) async {
    // 1. Clair.
    await t.pumpWidget(_page());
    await t.pump(const Duration(milliseconds: 900));
    expect(find.text('Comprendre la PawMap'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pawmap_help_see_map')), findsOneWidget);
    await _shoot(t, '01_clair');

    // 2. Sombre.
    await t.pumpWidget(_page(b: Brightness.dark));
    await t.pump(const Duration(milliseconds: 900));
    await _shoot(t, '02_sombre');
    expect(t.takeException(), isNull);
  });
}
