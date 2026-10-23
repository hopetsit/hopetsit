// 619 (PAM, 23/10/2026) — « Comprendre la PawMap » aussi complète que la
// page web /pawmap (ordre de Daniel du 23/10) : héros patte-pin, signalements,
// 9 catégories de lieux, « Comment ça marche », nouveautés (collection du
// mois, pins, ×2 Premium), abonnements expliqués + bande PawPremium, « Voir
// sur la carte » toujours en bas. Clair et sombre, 375 px et 320 px (allemand,
// la langue la plus longue) sans débordement ; 56 clés × 9 langues.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/v565/help619_i18n.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_help619_sections.dart';
import 'package:hopetsit/views/map/widgets/pawmap_buttons.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

import 'lotd_harness.dart';

const List<String> _langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

/// Les blocs nouveaux, dans l'ordre de l'écran.
const List<String> _blocks = <String>[
  'help619_hero',
  'help619_points_teaser',
  'help_sec_reports',
  'help_x_r610_comfort',
  'help_sec_places',
  'help619_cat_restaurant',
  'help_sec_steps',
  'help619_step_3',
  'help_sec_news',
  'help619_news_month',
  'help619_news_pins',
  'help619_news_premium',
  'help619_ppg_link',
  'help_sec_subs',
  'help619_plan_pf',
  'help619_plan_ps',
  'help619_plan_pp',
  'help619_premium_band',
  'help619_premium_cta',
];

Future<void> _open(WidgetTester t,
    {double width = 375,
    Locale locale = const Locale('fr', 'FR'),
    Brightness brightness = Brightness.light}) async {
  t.view.physicalSize = Size(width * 2, 812 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(lotdApp(const PawMapHelpScreen(role: 'owner'),
      locale: locale, brightness: brightness));
  await t.pump(const Duration(milliseconds: 100));
}

/// Fait défiler jusqu'à chaque bloc : le moindre débordement lève une
/// exception de rendu, relevée ici.
Future<void> _scrollAll(WidgetTester t) async {
  final scrollable = find.byType(Scrollable).first;
  for (final k in _blocks) {
    final f = find.byKey(ValueKey<String>(k), skipOffstage: false);
    expect(f, findsOneWidget, reason: k);
    await t.dragUntilVisible(f, scrollable, const Offset(0, -300));
    await t.pump(const Duration(milliseconds: 120));
    expect(t.takeException(), isNull, reason: 'rendu de $k');
  }
}

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  test('help619 : 56 clés, les 9 langues complètes, jamais vides', () {
    final fr = help619I18n['fr']!;
    expect(fr.length, 56);
    for (final l in _langs) {
      final m = help619I18n[l]!;
      expect(m.keys.toSet(), fr.keys.toSet(), reason: l);
      for (final e in m.entries) {
        expect(e.value.trim(), isNotEmpty, reason: '$l ${e.key}');
      }
    }
    // Les textes sont ceux du site, mot pour mot (extraits vérifiés).
    expect(fr['help619_title'], 'Qui est autour de toi, sur la carte');
    expect(fr['help619_privacy'], "Positions approximatives (~1 km), jamais l'adresse exacte.");
    expect(fr['help619_how'], 'Comment ça marche');
    expect(fr['help619_cat_vet'], 'Vétérinaires');
    expect(fr['help619_month_soon'], 'À partir du 1er novembre 2026');
    expect(fr['help619_sub_free_label'], 'Gratuit pour tous');
    expect(help619I18n['en']!['help619_r610_sec'], isNot(fr['help619_r610_sec']));
    expect(help619I18n['de']!['help619_premium_cta'], isNot(fr['help619_premium_cta']));
  });

  test('sommaire : les 9 numérotées inchangées, puis 5 sections du site avec icône, FAQ en dernier', () {
    final numbered = kPawHelpSections.map((s) => s.$2).whereType<int>().toList();
    expect(numbered, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    final ids = kPawHelpSections.map((s) => s.$1).toList();
    expect(ids.sublist(9), ['reports', 'places', 'steps', 'news', 'subs', 'faq']);
    for (final s in kPawHelpSections.sublist(9, 14)) {
      expect(s.$2, isNull, reason: s.$1);
      expect(s.$4, isNotNull, reason: '${s.$1} : icône du sommaire');
    }
    expect(kPawHelpCategories619.length, 9);
    expect(kPawHelpPlans619.map((p) => p.name).toList(), ['PawFollow', 'PawSpot', 'PawPremium']);
    expect(kPawHelpPlans619.map((p) => p.tab).toList(), [1, 2, 3]);
  });

  for (final dark in const [false, true]) {
    testWidgets('375 px, ${dark ? 'sombre' : 'clair'} : tout est là, sans débordement, « Voir sur la carte » en bas',
        (t) async {
      await _open(t, brightness: dark ? Brightness.dark : Brightness.light);
      expect(t.takeException(), isNull);
      expect(find.text('Comprendre la PawMap'), findsOneWidget);
      // Le héros du site : titre, sous-titre, ligne vie privée.
      expect(find.text('Qui est autour de toi, sur la carte'), findsOneWidget);
      expect(find.text("Positions approximatives (~1 km), jamais l'adresse exacte."), findsOneWidget);
      // Sommaire : une puce par section, nouvelles comprises.
      for (final id in const ['reports', 'places', 'steps', 'news', 'subs', 'faq']) {
        expect(find.byKey(ValueKey<String>('help_toc_$id')), findsOneWidget, reason: id);
      }
      await _scrollAll(t);
      // Les 9 catégories, chacune avec son libellé du site.
      for (final c in kPawHelpCategories619) {
        expect(find.byKey(ValueKey<String>('help619_cat_$c'), skipOffstage: false), findsOneWidget, reason: c);
      }
      expect(find.text('Vétérinaires', skipOffstage: false), findsOneWidget);
      expect(find.text('Restos pet-friendly', skipOffstage: false), findsOneWidget);
      // Les 3 étapes du site, numérotées 01 · 02 · 03.
      for (final n in const ['01', '02', '03']) {
        expect(find.text(n, skipOffstage: false), findsOneWidget, reason: n);
      }
      // Nouveautés : les 5 peluches habillées, les 4 pins, le « ×2 ».
      expect(find.text('×2', skipOffstage: false), findsOneWidget);
      expect(find.text('La collection du mois', skipOffstage: false), findsOneWidget);
      expect(find.text('Les pins', skipOffstage: false), findsOneWidget);
      // Abonnements : gratuit / avec, 3 offres, itinéraire vers les amis gratuit.
      expect(find.text('GRATUIT POUR TOUS', skipOffstage: false), findsNWidgets(3));
      expect(find.text('AVEC PAWFOLLOW', skipOffstage: false), findsOneWidget);
      expect(find.text('Itinéraire vers tes amis : gratuit', skipOffstage: false), findsOneWidget);
      expect(find.text('Découvrir PawPremium', skipOffstage: false), findsOneWidget);
      expect(find.text('Choisir PawPremium', skipOffstage: false), findsOneWidget);
      // « Voir sur la carte » : le bouton du bas du gabarit, toujours là.
      final seeMap = find.byKey(const ValueKey<String>('pawmap_help_see_map'));
      expect(seeMap, findsOneWidget);
      expect(find.ancestor(of: seeMap, matching: find.byType(ProfileSubPageScaffold)), findsOneWidget);
      expect(t.widget<PawSignatureButton>(seeMap).label, 'Voir sur la carte');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('le sommaire mène aux nouvelles sections', (t) async {
    await _open(t);
    for (final id in const ['subs', 'places', 'news']) {
      await t.tap(find.byKey(ValueKey<String>('help_toc_$id')));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(ValueKey<String>('help_sec_$id')), findsOneWidget, reason: id);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('320 px en allemand (la langue la plus longue) : aucun débordement', (t) async {
    await _open(t, width: 320, locale: const Locale('de', 'DE'));
    expect(t.takeException(), isNull);
    expect(find.text("So funktioniert's"), findsNWidgets(2)); // puce du sommaire + titre
    await _scrollAll(t);
    expect(find.text('Haustierfreundliche Restaurants', skipOffstage: false), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('320 px en polonais : aucun débordement', (t) async {
    await _open(t, width: 320, locale: const Locale('pl', 'PL'));
    await _scrollAll(t);
    expect(t.takeException(), isNull);
  });
}
