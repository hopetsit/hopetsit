// PAM-B 31/10/2026 (point BOB, build 631) — la croix « fermer » et le ✗
// « refuser » des bandeaux d'accueil demandent confirmation.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/widgets/banner_confirm3110.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';

Widget _app(Future<bool> Function(BuildContext) ask, List<bool> out) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr', 'FR'),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext ctx) => TextButton(
            key: const ValueKey<String>('go'),
            onPressed: () async => out.add(await ask(ctx)),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _btn(String label) => find.byWidgetPredicate((Widget w) =>
    (w is AppDialogPrimaryButton && w.label == label) ||
    (w is AppDialogSecondaryButton && w.label == label));

void main() {
  testWidgets('fermer : Annuler → false, Fermer → true', (tester) async {
    _size(tester);
    final out = <bool>[];
    await tester.pumpWidget(_app(confirmBannerClose3110, out));
    await tester.tap(find.byKey(const ValueKey<String>('go')));
    await tester.pumpAndSettle();
    expect(find.text('Fermer ce bandeau ?'), findsOneWidget);
    expect(find.text('Il ne s’affichera plus sur ton accueil.'), findsOneWidget);
    await tester.tap(_btn('Annuler'));
    await tester.pumpAndSettle();
    expect(out, <bool>[false]);
    await tester.tap(find.byKey(const ValueKey<String>('go')));
    await tester.pumpAndSettle();
    await tester.tap(_btn('Fermer'));
    await tester.pumpAndSettle();
    expect(out, <bool>[false, true]);
  });

  testWidgets('refuser : Annuler → false, Refuser → true', (tester) async {
    _size(tester);
    final out = <bool>[];
    await tester.pumpWidget(_app(confirmBannerRefuse3110, out));
    await tester.tap(find.byKey(const ValueKey<String>('go')));
    await tester.pumpAndSettle();
    expect(find.text('Refuser cette demande ?'), findsOneWidget);
    await tester.tap(_btn('Annuler'));
    await tester.pumpAndSettle();
    expect(out, <bool>[false]);
    await tester.tap(find.byKey(const ValueKey<String>('go')));
    await tester.pumpAndSettle();
    await tester.tap(_btn('Refuser'));
    await tester.pumpAndSettle();
    expect(out, <bool>[false, true]);
  });
}
