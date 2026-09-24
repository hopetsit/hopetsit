// v584 — consigne de Daniel (25/09) : sur ANDROID la barre de navigation
// système (3 boutons = 48 dp, ou barre de gestes) ne doit cacher aucun bouton
// de la PawMap. Ici : la règle d'inset partagée (`appBottomInset`) et les
// feuilles de la carte, avec un écran « Samsung » qui annonce 0 alors que la
// barre à 3 boutons recouvre 48 px, puis 48, puis un iPhone (34).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';

Widget _app(Widget child, {required double viewPaddingBottom}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(393, 852),
          viewPadding: EdgeInsets.only(bottom: viewPaddingBottom),
          padding: EdgeInsets.only(bottom: viewPaddingBottom),
        ),
        child: Builder(builder: (ctx) => child),
      ),
    ),
  );
}

/// Fixe la plateforme (règle d'inset) le temps du corps du test et la remet
/// avant la fin.
Future<void> _on(TargetPlatform p, Future<void> Function() body) async {
  debugBottomInsetForceAndroid = p == TargetPlatform.android;
  try {
    await body();
  } finally {
    debugBottomInsetForceAndroid = null;
  }
}

void main() {

  group('règle d\'inset bas (appBottomInset)', () {
    testWidgets('Samsung barre 3 boutons annoncée 0 → jamais moins de 48', (tester) async {
      await _on(TargetPlatform.android, () async {
        late double got;
        await tester.pumpWidget(_app(
          Builder(builder: (ctx) {
            got = appBottomInset(ctx);
            return const SizedBox();
          }),
          viewPaddingBottom: 0,
        ));
        expect(got, 48);
      });
    });
    testWidgets('Android barre de gestes (20) → 48 ; barre 3 boutons (48) → 48', (tester) async {
      await _on(TargetPlatform.android, () async {
        for (final v in [20.0, 48.0]) {
          late double got;
          await tester.pumpWidget(_app(
            Builder(builder: (ctx) {
              got = appBottomInset(ctx);
              return const SizedBox();
            }),
            viewPaddingBottom: v,
          ));
          expect(got, 48, reason: 'viewPadding $v');
        }
      });
    });
    testWidgets('iPhone (34) → l\'inset réel', (tester) async {
      await _on(TargetPlatform.iOS, () async {
        late double got;
        await tester.pumpWidget(_app(
          Builder(builder: (ctx) {
            got = appBottomInset(ctx);
            return const SizedBox();
          }),
          viewPaddingBottom: 34,
        ));
        expect(got, 34);
      });
    });
  });

  group('feuilles de la carte au-dessus de la barre système', () {
    testWidgets('PawMapSheetShell garde ≥ 48 px sous elle sur Android (inset 0)', (tester) async {
      await _on(TargetPlatform.android, () async {
        await tester.pumpWidget(_app(
          const PawMapSheetShell(child: SizedBox(height: 120, child: Text('x'))),
          viewPaddingBottom: 0,
        ));
        final pad = tester.widget<Padding>(find.ancestor(
          of: find.byType(Container).first,
          matching: find.byType(Padding),
        ).first);
        expect(pad.padding.resolve(TextDirection.ltr).bottom, greaterThanOrEqualTo(48));
      });
    });
  });

  group('menu du bas : la carte se cale sur la même hauteur que la barre', () {
    test('pawTabBarTotalHeight inclut l\'inset système', () {
      expect(pawTabBarTotalHeight(48) - pawTabBarTotalHeight(0), 48);
      expect(pawTabBarUsefulHeight(48) - pawTabBarUsefulHeight(0), 48);
      // Le rail et la feuille basse s'ancrent au-dessus de cette hauteur
      // (`_menuInset` = pawTabBarTotalHeight(viewPadding.bottom)).
      expect(pawTabBarTotalHeight(0), greaterThan(kPawTabBarPillHeight));
    });
  });
}
