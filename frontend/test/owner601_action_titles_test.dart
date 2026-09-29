// v601 (PAM, 29/09) — accueil propriétaire : les deux cartes d'action
// (« Faire garder mon animal » / « Faire promener mon chien ») ne sont JAMAIS
// coupées. Capture iPhone 15 du 29/09 : « Faire garder mon anim… » et
// « Faire promener mon … » en version basse (1 ligne + ellipse). Contrôle :
// 9 langues × 5 largeurs × (version haute, version basse) + mode sombre :
// aucun « … », aucun paragraphe qui dépasse ses lignes, aucune exception.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/v565/ownerhome571_i18n.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/owner_home_kit.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';

const List<String> kLangs = <String>[
  'fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ja', 'ko',
];
const List<double> kWidths = <double>[320, 360, 375, 393, 440];

Widget _harness(Widget child, {Brightness brightness = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    ),
  );
}

void _sizeTo(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectNoCut(WidgetTester tester, String where) {
  final paragraphs = tester.allRenderObjects.whereType<RenderParagraph>();
  expect(paragraphs, isNotEmpty, reason: where);
  for (final RenderParagraph rp in paragraphs) {
    final String plain = rp.text.toPlainText();
    expect(plain.contains('…'), isFalse, reason: '$where : « … » dans "$plain"');
    expect(rp.overflow == TextOverflow.ellipsis && rp.didExceedMaxLines, isFalse,
        reason: '$where : "$plain" coupé');
    final double maxW = rp.constraints.maxWidth;
    final TextPainter tp = TextPainter(
      text: rp.text,
      textDirection: rp.textDirection,
      maxLines: rp.maxLines,
      textScaler: rp.textScaler,
    )..layout(maxWidth: maxW.isFinite ? maxW : double.infinity);
    expect(tp.didExceedMaxLines, isFalse,
        reason: '$where : "$plain" dépasse ${rp.maxLines} ligne(s) à $maxW px');
    tp.dispose();
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('les 9 langues ont les deux titres', () {
    for (final l in kLangs) {
      expect(ownerhome571I18n[l]?['ownerhome571_action_sitting'], isNotEmpty,
          reason: l);
      expect(ownerhome571I18n[l]?['ownerhome571_action_walking'], isNotEmpty,
          reason: l);
    }
  });

  for (final bool compact in <bool>[true, false]) {
    for (final String lang in kLangs) {
      for (final double w in kWidths) {
        testWidgets(
            'cartes propriétaire ${compact ? 'basses' : 'hautes'} · $lang · $w dp',
            (tester) async {
          _sizeTo(tester, w);
          final t = ownerhome571I18n[lang]!;
          await tester.pumpWidget(_harness(OwnerActionCards(
            compact: compact,
            sittingTitle: t['ownerhome571_action_sitting']!,
            walkingTitle: t['ownerhome571_action_walking']!,
            onSitting: () {},
            onWalking: () {},
          )));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(PawButtonLabel), findsNWidgets(2));
          _expectNoCut(tester, '$lang $w ${compact ? 'basse' : 'haute'}');
        });
      }
    }
  }

  testWidgets('mode sombre, version basse, français 320 dp', (tester) async {
    _sizeTo(tester, 320);
    await tester.pumpWidget(_harness(
      OwnerActionCards(
        compact: true,
        sittingTitle: 'Faire garder mon animal',
        walkingTitle: 'Faire promener mon chien',
        onSitting: () {},
        onWalking: () {},
      ),
      brightness: Brightness.dark,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    _expectNoCut(tester, 'sombre fr 320');
  });
}
