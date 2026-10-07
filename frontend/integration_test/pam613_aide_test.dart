// ignore_for_file: avoid_print
// 613 (PAM) — §8 : « Comprendre la PawMap », section « Les rangs », au
// simulateur (fr + de, police normale puis grande police). Captures prises
// de l'extérieur à chaque `[P613] SNAP <nom>`. Même fichier sur « avant » et
// « après » (seul le code de l'app change).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => GetStorage.init());

  testWidgets('aide : rangs fr / de, police normale et grande', (t) async {
    for (final scale in const [1.0, 1.35]) {
      for (final loc in const [Locale('fr', 'FR'), Locale('de', 'DE')]) {
        Get.locale = loc;
        await t.pumpWidget(MediaQuery(
          data: MediaQueryData.fromView(t.view).copyWith(textScaler: TextScaler.linear(scale)),
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (_, __) => GetMaterialApp(
              key: ValueKey('$loc$scale'),
              debugShowCheckedModeBanner: false,
              translations: AppTranslations(),
              locale: loc,
              fallbackLocale: const Locale('en', 'US'),
              theme: ThemeData(useMaterial3: true),
              home: const PawMapHelpScreen(role: 'owner'),
            ),
          ),
        ));
        await t.pump(const Duration(seconds: 2));
        final row = find.byKey(const ValueKey<String>('help612_rank_puppy'), skipOffstage: false);
        await t.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
        await t.pump(const Duration(milliseconds: 600));
        // la section entière à l'écran : on remonte un peu
        await t.drag(find.byType(Scrollable).first, const Offset(0, 120));
        await t.pump(const Duration(seconds: 1));
        print('[P613] SNAP aide-rangs-${loc.languageCode}-x$scale');
        await t.pump(const Duration(seconds: 3));
      }
    }
  });
}
