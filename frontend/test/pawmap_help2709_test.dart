// v597 (27/09) — « Comprendre la PawMap » modernisé : encadré « position
// privée » (~1 km), mon rond / amis seulement, ami (halo rose), couleurs des
// profils, bulle double prix, un seul halo à la fois. Monté en fr et en en,
// jour et nuit, à 375 px (téléphone) et 768 px (tablette), sans exception.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hopetsit/localization/v565/help587_i18n.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';

import 'lotd_harness.dart';

const List<String> _newKeys = [
  'help2709_priv_t', 'help2709_priv_b', 'help2709_me_t', 'help2709_me_b',
  'help2709_mefr_t', 'help2709_mefr_b', 'help2709_friend_t', 'help2709_friend_b',
  'help2709_roles_t', 'help2709_roles_b', 'help2709_duo_t', 'help2709_duo_b',
  'help2709_follow_t', 'help2709_follow_b', 'help2709_halo_t', 'help2709_halo_b',
];

Future<void> _open(WidgetTester tester, Locale locale,
    {double width = 375, Brightness brightness = Brightness.light, String role = 'owner'}) async {
  tester.view.physicalSize = Size(width * 2, 812 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      lotdApp(PawMapHelpScreen(role: role), locale: locale, brightness: brightness));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  test('les 16 nouvelles clés existent dans les 9 langues, non vides', () {
    for (final l in const ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      for (final k in _newKeys) {
        expect(help587I18n[l]![k]?.trim().isNotEmpty, isTrue, reason: '$l / $k');
      }
    }
  });

  for (final lang in const ['fr', 'en']) {
    for (final dark in const [false, true]) {
      for (final width in const [375.0, 768.0]) {
        testWidgets('$lang ${dark ? 'nuit' : 'jour'} ${width.toInt()} px : nouveaux blocs, sans exception',
            (tester) async {
          final locale = lang == 'fr' ? const Locale('fr', 'FR') : const Locale('en', 'US');
          await _open(tester, locale,
              width: width, brightness: dark ? Brightness.dark : Brightness.light);
          expect(tester.takeException(), isNull);
          final t = help587I18n[lang]!;
          expect(find.byKey(const ValueKey<String>('help_privacy')), findsOneWidget);
          for (final k in _newKeys) {
            expect(find.text(t[k]!, skipOffstage: false), findsOneWidget, reason: k);
          }
          expect(find.byKey(const ValueKey<String>('help_roles'), skipOffstage: false),
              findsOneWidget);
          expect(find.byKey(const ValueKey<String>('help_halo'), skipOffstage: false),
              findsOneWidget);
          // Défile jusqu'en bas : les cartes apparaissent, aucune erreur.
          final faq = find.byKey(const ValueKey<String>('help_faq_4'), skipOffstage: false);
          await tester.ensureVisible(faq);
          for (int i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('réduire les animations : tout est visible tout de suite', (tester) async {
    tester.view.physicalSize = const Size(375 * 2, 812 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(375, 812), disableAnimations: true),
      child: lotdApp(const PawMapHelpScreen(role: 'walker')),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedOpacity), findsNothing);
  });
}
