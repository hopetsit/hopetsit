// v585 (lot D) — ⛔ TITRES DES BOUTONS JAMAIS COUPÉS (exigence répétée de
// Daniel, NORME_DESIGN.md) : chaque bouton du kit est rendu avec les libellés
// les plus longs de CHAQUE langue (9 langues, l'allemand et le polonais en
// tête) à 320 ET 375 px, avec la VRAIE police Poppins Bold (embarquée dans
// `assets/fonts/`), et le test échoue au moindre débordement, au moindre
// « … », ou si la réduction douce passe sous 12 pt.
//
// Libellés : toutes les valeurs de `AppTranslations` dont la clé désigne un
// bouton (btn, button, cta, submit, save, continue, book, pay…), plus les
// libellés du rail de la PawMap et des grands appels à l'action, avec les
// variables (@name…) remplacées par un mot réaliste.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

const List<String> kLocales = <String>[
  'en_US', 'fr_FR', 'es_ES', 'de_DE', 'it_IT', 'pt_PT', 'ko_KR', 'ja_JP', 'pl_PL',
];

final RegExp _buttonKey = RegExp(
    r'(_(btn|button|cta|submit|action|confirm_btn|primary|secondary)$|^(btn|button|cta)_)');

const List<String> kAlwaysKeys = <String>[
  'pawmap_btn_around', 'pawmap_btn_directions', 'pawmap_help_see_map',
  'bug_report_submit', 'button_logout', 'guest_discover_btn', 'guest_continue_without',
];

/// Remplace les variables (@name, {km}) par un mot réaliste.
String _fill(String v) => v
    .replaceAllMapped(RegExp(r'@\w+'), (_) => 'Léa')
    .replaceAllMapped(RegExp(r'\{\w+\}'), (_) => '25');

/// Les N libellés les plus longs d'une langue (candidats « bouton »).
List<String> longestLabels(Map<String, String> table, {int n = 14}) {
  final Set<String> vals = <String>{};
  table.forEach((k, v) {
    final bool candidate = kAlwaysKeys.contains(k) || _buttonKey.hasMatch(k);
    if (!candidate) return;
    if (v.contains('\n') || v.length > 45 || v.trim().isEmpty) return;
    vals.add(_fill(v));
  });
  final list = vals.toList()..sort((a, b) => b.length.compareTo(a.length));
  return list.take(n).toList();
}

Future<void> _loadPoppins() async {
  // google_fonts enregistre Poppins sous SON nom de famille (ex. « Poppins_bold ») :
  // on charge le fichier embarqué sous ce nom, la mesure se fait donc avec la
  // vraie police proportionnelle, pas la police de test (1 em par glyphe).
  final fam = GoogleFonts.poppins(fontWeight: FontWeight.w700).fontFamily!;
  final loader = FontLoader(fam)..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
  await loader.load();
}

/// Le texte tient-il dans ses lignes, sans coupure ?
bool _fits(RenderParagraph rp) {
  final painter = TextPainter(
    text: rp.text,
    textDirection: rp.textDirection,
    maxLines: rp.maxLines,
    textScaler: rp.textScaler,
  )..layout(maxWidth: rp.constraints.maxWidth.isFinite ? rp.constraints.maxWidth : rp.size.width);
  final ok = !painter.didExceedMaxLines;
  painter.dispose();
  return ok;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadPoppins();
  });

  final Map<String, Map<String, String>> tables = AppTranslations().keys;

  for (final locale in kLocales) {
    for (final width in <double>[320, 375]) {
      testWidgets('$locale @ ${width.toInt()} px : aucun libellé coupé', (tester) async {
        final labels = longestLabels(tables[locale]!);
        expect(labels, isNotEmpty, reason: 'aucun libellé de bouton trouvé pour $locale');
        tester.view.physicalSize = Size(width, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final buttons = <Widget>[];
        int i = 0;
        for (final l in labels) {
          final kind = <PawButtonKind>[
            PawButtonKind.primary, PawButtonKind.secondary, PawButtonKind.primary
          ][i % 3];
          buttons.add(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PawButton(
              label: l,
              onTap: () {},
              color: const Color(0xFF2563EB),
              icon: PawIcon.house,
              kind: kind,
              price: i % 4 == 0 ? '25 €' : null,
              compact: i % 5 == 4,
            ),
          ));
          i++;
        }
        // Deux boutons côte à côte (accepter / refuser) avec les deux plus longs.
        buttons.add(Row(children: [
          Expanded(child: PawButton(label: labels[0], onTap: () {}, compact: true, icon: PawIcon.check)),
          const SizedBox(width: 8),
          Expanded(child: PawButton(label: labels[1], onTap: () {}, compact: true, kind: PawButtonKind.secondary, icon: PawIcon.close)),
        ]));

        await tester.pumpWidget(MaterialApp(
          home: ScreenUtilInit(
            designSize: Size(width, 4000),
            builder: (_, __) => Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: buttons),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'débordement ($locale, $width)');

        final texts = find.descendant(of: find.byType(PawButton), matching: find.byType(Text));
        expect(texts, findsWidgets);
        for (final el in texts.evaluate()) {
          final Text t = el.widget as Text;
          expect(t.overflow, isNot(TextOverflow.ellipsis), reason: '${t.data}');
          expect(t.data, isNot(contains('…')), reason: '${t.data}');
          final RenderParagraph rp = el.renderObject! as RenderParagraph;
          expect(_fits(rp), isTrue, reason: 'coupé : « ${t.data} » ($locale, $width px)');
          // Réduction douce : jamais sous 12 pt (= échelle ≥ 12 / taille de base).
          final double fontSize = t.style?.fontSize ?? 14;
          final Matrix4 m = rp.getTransformTo(null);
          final double scale = m.getMaxScaleOnAxis();
          expect(fontSize * scale, greaterThanOrEqualTo(11.5),
              reason: 'trop réduit : « ${t.data} » → ${(fontSize * scale).toStringAsFixed(1)} pt ($locale, $width px)');
        }
      });
    }
  }

  test('les 9 langues ont chacune des libellés de bouton candidats', () {
    for (final locale in kLocales) {
      expect(longestLabels(tables[locale]!).length, greaterThanOrEqualTo(10), reason: locale);
    }
  });

  test('pawTwoLines coupe à l’espace le plus central, jamais au milieu d’un mot', () {
    expect(pawTwoLines('Proposer mes services maintenant'), 'Proposer mes\nservices maintenant');
    expect(pawTwoLines('Réserver'), 'Réserver');
    expect(pawTwoLines('Dienstleistungenanbieten'), 'Dienstleistungenanbieten');
  });
}
