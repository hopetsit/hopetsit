// v587 (point 10) — « Comprendre la PawMap » plus explicatif : les 5 sections
// (Se repérer · Voir qui est autour · Être visible / en direct · Agir ·
// Réglages), un exemple par section et la FAQ, en français ET en japonais,
// sans aucun débordement à 320 px de large ; seuls les boutons du rôle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hopetsit/localization/v565/help587_i18n.dart';
import 'package:hopetsit/localization/v565/vis587_i18n.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';

import 'lotd_harness.dart';

const List<String> _sections = [
  'help587_sec_find',
  'help587_sec_see',
  'help587_sec_live',
  'help587_sec_act',
  'help587_sec_set',
];

Future<void> _open(WidgetTester tester, Locale locale, String role,
    {Brightness brightness = Brightness.light}) async {
  // 320 px de large (petit Android), densité 2.
  tester.view.physicalSize = const Size(320 * 2, 640 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      lotdApp(PawMapHelpScreen(role: role), locale: locale, brightness: brightness));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() async => lotdSetUp(role: 'walker'));

  for (final lang in const ['fr', 'ja']) {
    testWidgets('$lang : 5 sections, exemples et FAQ, sans débordement à 320 px',
        (tester) async {
      final locale = lang == 'fr' ? const Locale('fr', 'FR') : const Locale('ja', 'JP');
      await _open(tester, locale, 'walker');
      expect(tester.takeException(), isNull, reason: 'débordement / exception');
      final t = help587I18n[lang]!;
      for (final k in _sections) {
        expect(find.text(t[k]!, skipOffstage: false), findsOneWidget, reason: k);
      }
      expect(find.byKey(const ValueKey<String>('help_faq'), skipOffstage: false),
          findsOneWidget);
      expect(find.text(t['help587_faq_title']!, skipOffstage: false), findsOneWidget);
      for (final n in [1, 2, 3, 4]) {
        expect(find.text(t['help587_q$n']!, skipOffstage: false), findsOneWidget);
        if (n == 2) continue; // v587 : réponse = les phrases du réglage (plus bas)
        expect(find.text(t['help587_a$n']!, skipOffstage: false), findsOneWidget);
      }
      // v587 — « Qui voit ma position ? » : les 3 réglages mot pour mot, plus
      // où le changer et ce que voient les amis en direct ; même carte dans
      // la section « Être visible / en direct ».
      final v = vis587I18n[lang]!;
      final expected = [
        '${v['vis587_all_t']} — ${v['vis587_all_d']}',
        '${v['vis587_friends_t']} — ${v['vis587_friends_d']}',
        '${v['vis587_hidden_t']} — ${v['vis587_hidden_d']}',
        v['vis587_live'],
        v['vis587_where'],
      ].join('\n');
      expect(find.text(expected, skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('help_visibility'), skipOffstage: false),
          findsOneWidget);
      for (final ex in ['find', 'see', 'live', 'act', 'set']) {
        expect(find.byKey(ValueKey<String>('help_ex_$ex'), skipOffstage: false),
            findsOneWidget, reason: ex);
      }
      // Défile jusqu'en bas : aucune exception de mise en page en route.
      final faq = find.byKey(const ValueKey<String>('help_faq_4'), skipOffstage: false);
      await tester.ensureVisible(faq);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gardien / promeneur : Direct décrit, pas Publier', (tester) async {
    await _open(tester, const Locale('fr', 'FR'), 'walker');
    expect(find.byKey(const ValueKey<String>('help_capsule_direct'), skipOffstage: false),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('help_capsule_publish'), skipOffstage: false),
        findsNothing);
    expect(
        find.textContaining(help587I18n['fr']!['help587_ex_live_walker']!,
            findRichText: true, skipOffstage: false),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('help_ex_live'), skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('propriétaire : Publier ET Direct décrits (v587, 3 profils) ; mode sombre sans erreur',
      (tester) async {
    await _open(tester, const Locale('fr', 'FR'), 'owner', brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('help_capsule_publish'), skipOffstage: false),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('help_capsule_direct'), skipOffstage: false),
        findsOneWidget);
    // Chaque clé help587 utilisée existe dans les 9 langues.
    for (final l in const ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      expect(help587I18n[l]!.keys.toSet(), help587I18n['fr']!.keys.toSet(), reason: l);
    }
    expect('help587_sec_find'.tr, help587I18n['fr']!['help587_sec_find']);
  });
}
