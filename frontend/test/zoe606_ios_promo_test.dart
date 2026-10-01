// 606 (ZOE, 01/10/2026) — refus Apple 1.25/605, guideline 3.1.1 :
// « the app uses promo codes to unlock access ».
//
// Ce qui est prouvé ici :
//   · la règle [houseCodesAllowed] : faux sur iOS, vrai sur Android ;
//   · boutique (bloc « Aide & infos ») : sur iOS AUCUNE ligne « J'ai un code »,
//     seulement « Saisir un code App Store » (feuille officielle d'Apple) ;
//     sur Android, la ligne « J'ai un code » est là comme avant ;
//   · `showPromoCodeSheet` sur iOS n'ouvre JAMAIS le formulaire maison (aucun
//     champ de saisie) : seule la feuille Apple est appelée ; sur Android le
//     formulaire s'ouvre comme avant ;
//   · chaque point d'entrée du code maison dans l'app (profil, réservation,
//     boutique, pop-up de l'accueil, écran Code promo) passe par la garde.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/ios_store_rules606.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/promo_code_sheet.dart';

Widget _app(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Widget _help() => Builder(
      builder: (context) => shopHelpCard(
        context,
        accent: Colors.orange,
        oneTime: false,
        onPromo: () {},
        onRestore: () {},
        restoring: false,
        showManage: false,
      ),
    );

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    debugAppleOfferCodeSheet606 = null;
  });

  group('règle houseCodesAllowed', () {
    test('iOS → jamais de code maison', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(houseCodesAllowed(), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
    test('Android → inchangé (codes maison permis)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(houseCodesAllowed(), isTrue);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('boutique — bloc « Aide & infos »', () {
    testWidgets('iOS : aucune entrée « J\'ai un code », seulement la feuille Apple',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_app(_help()));
      await tester.pump();
      expect(find.text('v565_promo_have_code'), findsNothing);
      expect(find.text('promo_ios_button'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android : « J\'ai un code » toujours là, pas de bouton Apple',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_app(_help()));
      await tester.pump();
      expect(find.text('v565_promo_have_code'), findsOneWidget);
      expect(find.text('promo_ios_button'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('showPromoCodeSheet', () {
    testWidgets('iOS : feuille Apple seulement, aucun formulaire maison',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var appleCalls = 0;
      debugAppleOfferCodeSheet606 = () async => appleCalls++;
      late BuildContext ctx;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox(height: 10);
      })));
      bool? result;
      showPromoCodeSheet(ctx, accent: Colors.orange, initialCode: 'HOPDALIOS', autoApply: true)
          .then((r) => result = r);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(appleCalls, 1);
      expect(result, isFalse, reason: 'aucun code maison appliqué');
      expect(find.byType(TextField), findsNothing);
      expect(find.text('HOPDALIOS'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android : le formulaire maison s\'ouvre comme avant', (tester) async {
      // Écran de téléphone (iPhone 15 : 393 × 852 points).
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var appleCalls = 0;
      debugAppleOfferCodeSheet606 = () async => appleCalls++;
      late BuildContext ctx;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox(height: 10);
      })));
      showPromoCodeSheet(ctx, accent: Colors.orange);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(appleCalls, 0);
      expect(find.byType(TextField), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('chaque entrée du code maison est gardée (lecture du code)', () {
    // fichier → motif d'entrée qui DOIT être précédé (≤ 3 lignes) de la garde.
    const entries = <String, String>{
      'lib/views/profile/widgets/profile_categories.dart': "title: 'promo_screen_title'.tr",
      'lib/views/booking/booking_agreement_screen.dart': 'showPromoCodeSheet(',
      'lib/widgets/stacked_navigation_wrapper.dart': 'const PromoPopup()',
      'lib/views/boost/coin_shop_screen.dart': "label: 'v565_promo_have_code'.tr",
      'lib/views/profile/promo_code_screen.dart': "onPressed: () => showPromoCodeSheet(",
    };
    entries.forEach((file, pattern) {
      test(file, () {
        final lines = File(file).readAsLinesSync();
        final idx = <int>[];
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(pattern)) idx.add(i);
        }
        expect(idx, isNotEmpty, reason: 'entrée introuvable : $pattern');
        for (final i in idx) {
          final from = i - 8 < 0 ? 0 : i - 8;
          final window = lines.sublist(from, i + 1).join('\n');
          expect(window.contains('houseCodesAllowed()'), isTrue,
              reason: '$file:${i + 1} non gardé');
        }
      });
    });

    test('le pop-up promo (HOPDALIOS) sort tout de suite sur iOS', () {
      final src = File('lib/widgets/promo_code_sheet.dart').readAsStringSync();
      final decide = src.indexOf('void _decide() {');
      expect(decide, greaterThan(0));
      final body = src.substring(decide, decide + 200);
      expect(body.contains('if (!houseCodesAllowed()) return;'), isTrue);
    });

    test('aucun autre appel de showPromoCodeSheet / PromoCodeScreen non recensé', () {
      final known = {
        'lib/widgets/promo_code_sheet.dart',
        'lib/views/profile/promo_code_screen.dart',
        'lib/views/profile/widgets/profile_categories.dart',
        'lib/views/booking/booking_agreement_screen.dart',
        'lib/views/boost/coin_shop_screen.dart',
      };
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final t = f.readAsStringSync();
        if ((t.contains('showPromoCodeSheet(') || t.contains('PromoCodeScreen(') ||
                t.contains("'/app-config/public-promo'")) &&
            !known.contains(f.path)) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty, reason: 'nouvelle entrée de code maison à garder');
    });
  });
}
