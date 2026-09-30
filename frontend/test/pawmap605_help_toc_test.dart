// v605 (30/09) — « Comprendre la PawMap » : Daniel, « vu que tout est
// numéroté, fais un menu avec les titres pour aller directement à la section
// sans défiler ». Sommaire cliquable en haut (numéro + titre, 9 langues) ;
// « Le point vert du menu » devient « Le contour de la patte du menu », avec
// une petite patte au contour vert au lieu d'un rond vert.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/v565/balade599_i18n.dart';
import 'package:hopetsit/localization/v565/pawmap605_i18n.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';

import 'lotd_harness.dart';

Future<void> _open(WidgetTester t, {double width = 375, Locale locale = const Locale('fr', 'FR')}) async {
  t.view.physicalSize = Size(width * 2, 812 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(lotdApp(const PawMapHelpScreen(role: 'owner'), locale: locale));
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  test('titre du sommaire + nouveau texte du contour : 9 langues', () {
    for (final l in const ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      expect(pawmap605I18n[l]!['pm605_help_toc']!.trim(), isNotEmpty, reason: l);
      expect(balade599I18n[l]!['help599_t_dot']!.trim(), isNotEmpty, reason: l);
    }
    expect(balade599I18n['fr']!['help599_t_dot'], 'Le contour de la patte du menu');
  });

  for (final width in const [375.0, 768.0]) {
    testWidgets('${width.toInt()} px : chaque puce du sommaire amène à SA section', (t) async {
      await _open(t, width: width);
      expect(find.byKey(const ValueKey<String>('help_toc')), findsOneWidget);
      for (final sec in kPawHelpSections) {
        final chip = find.byKey(ValueKey<String>('help_toc_${sec.$1}'));
        await t.ensureVisible(chip);
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 80));
        }
        await t.tap(chip);
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 80));
        }
        final title = sec.$1 == 'faq'
            ? find.byKey(const ValueKey<String>('help_faq'))
            : find.byKey(ValueKey<String>('help_sec_${sec.$1}'));
        final top = t.getTopLeft(title).dy;
        expect(top, inInclusiveRange(0, 260), reason: '${sec.$1} : titre à y=$top');
      }
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('La Balade : petite patte au contour VERT (plus de rond vert)', (t) async {
    await _open(t);
    final paw = find.byKey(const ValueKey<String>('help_balade_dot_paw'), skipOffstage: false);
    expect(paw, findsOneWidget);
    final glyph = t.widget<PawGlyph>(find.descendant(of: paw, matching: find.byType(PawGlyph), skipOffstage: false));
    expect(glyph.rimColor, PawLiveDot.green);
    expect(find.text('Le contour de la patte du menu', skipOffstage: false), findsOneWidget);
  });
}
