// 639 (lot D) — rangs PawPoints, série 1 : NOMS seulement. Contrat
// `CONTRATS.md` §4 : clés internes et seuils (0 / 150 / 800 / 3 000 / 10 000)
// inchangés ; nouveaux noms dans les 9 langues ; pin « 1er Ambassadeur » ;
// la PELUCHE « Chiot » garde son nom.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/help619_i18n.dart';
import 'package:hopetsit/localization/v565/pawpoints607_i18n.dart';
import 'package:hopetsit/localization/v565/plush607_i18n.dart';
import 'package:hopetsit/localization/v565/plush618_i18n.dart';
import 'package:hopetsit/localization/v565/ranks611_i18n.dart';
import 'package:hopetsit/localization/v565/v565_i18n.dart';
import 'package:hopetsit/widgets/paw_rank611.dart';

const _langs = <String>['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

/// Tableau figé du contrat : puppy, young_dog, adult_dog, pack_leader, legend.
const _names = <String, List<String>>{
  'fr': <String>['Découvreur', 'Explorateur', 'Guide', 'Ambassadeur', 'Légende'],
  'en': <String>['Newcomer', 'Explorer', 'Guide', 'Ambassador', 'Legend'],
  'es': <String>['Descubridor', 'Explorador', 'Guía', 'Embajador', 'Leyenda'],
  'de': <String>['Entdecker', 'Erkunder', 'Wegweiser', 'Botschafter', 'Legende'],
  'it': <String>['Scopritore', 'Esploratore', 'Guida', 'Ambasciatore', 'Leggenda'],
  'pt': <String>['Descobridor', 'Explorador', 'Guia', 'Embaixador', 'Lenda'],
  'ko': <String>['새내기', '탐험가', '가이드', '앰배서더', '전설'],
  'ja': <String>['ビギナー', '探検家', 'ガイド', 'アンバサダー', 'レジェンド'],
  'pl': <String>['Odkrywca', 'Eksplorator', 'Przewodnik', 'Ambasador', 'Legenda'],
};

/// Anciens noms (build 638) des 4 rangs renommés — « Légende » ne change pas.
const _old = <String, List<String>>{
  'fr': <String>['Chiot', 'Jeune chien', 'Chien adulte', 'Chef de meute'],
  'en': <String>['Puppy', 'Young dog', 'Grown dog', 'Adult dog', 'Pack leader'],
  'es': <String>['Cachorro', 'Perro joven', 'Perro adulto', 'Líder de la manada'],
  'de': <String>['Welpe', 'Junghund', 'Erwachsener Hund', 'Rudelführer'],
  'it': <String>['Cucciolo', 'Cane giovane', 'Cane adulto', 'Capobranco'],
  'pt': <String>['Cachorrinho', 'Cão jovem', 'Cão adulto', 'Líder da matilha'],
  'ko': <String>['강아지', '청소년견', '성견', '무리의 리더'],
  'ja': <String>['子犬', '若犬', '成犬', '群れのリーダー'],
  'pl': <String>['Szczeniak', 'Młody pies', 'Dorosły pies', 'Przywódca stada'],
};

const _pin = <String, String>{
  'fr': '1er Ambassadeur',
  'en': '1st Ambassador',
  'es': '1.er Embajador',
  'de': 'Erster Botschafter',
  'it': '1º Ambasciatore',
  'pt': '1.º Embaixador',
  'ko': '최초의 앰배서더',
  'ja': '最初のアンバサダー',
  'pl': 'Pierwszy Ambasador',
};

Widget _app(String lang, Widget home) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: Locale(lang),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: Center(child: home)),
      ),
    );

void main() {
  setUpAll(() => Get.testMode = true);
  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  test('clés internes et seuils inchangés', () {
    expect(kPawRankKeys611, <String>['puppy', 'young_dog', 'adult_dog', 'pack_leader', 'legend']);
    expect(kPawRankMins611, <int>[0, 150, 800, 3000, 10000]);
  });

  test('nouveaux noms du contrat dans les 9 langues (paquet et registre)', () {
    expect(ranks611I18n.keys.toSet(), _langs.toSet());
    for (final lang in _langs) {
      final merged = v565For(lang);
      for (var i = 0; i < kPawRankKeys611.length; i++) {
        final k = 'rank611_${kPawRankKeys611[i]}';
        expect(ranks611I18n[lang]![k], _names[lang]![i], reason: '$lang / $k');
        expect(merged[k], _names[lang]![i], reason: 'registre $lang / $k');
      }
    }
  });

  test('aucun ancien nom de rang dans les textes des rangs, des pins et de l\'aide', () {
    final hits = <String>[];
    final packs = <String, Map<String, Map<String, String>>>{
      'ranks611': ranks611I18n,
      'plush618': plush618I18n,
      'help619': help619I18n,
    };
    packs.forEach((name, pack) {
      for (final lang in _langs) {
        final olds = _old[lang]!.map((o) => o.toLowerCase()).toList();
        pack[lang]!.forEach((k, v) {
          final low = v.toLowerCase();
          for (final o in olds) {
            if (low.contains(o)) hits.add('$name/$lang/$k : « $o »');
          }
        });
      }
    });
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('aide « rangs » : nouveaux noms, mêmes seuils', () {
    for (final lang in _langs) {
      final b = ranks611I18n[lang]!['help611_ranks_b']!;
      for (final n in _names[lang]!) {
        expect(b.toLowerCase(), contains(n.toLowerCase()), reason: '$lang : $n');
      }
      final digits = b.replaceAll(RegExp(r'[\s  .,]'), '');
      for (final seuil in const <String>['150', '800', '3000', '10000']) {
        expect(digits, contains(seuil), reason: '$lang : seuil $seuil');
      }
    }
    expect(ranks611I18n['fr']!['help611_ranks_b'], contains('Explorateur (150), Guide (800), Ambassadeur (3 000), Légende (10 000)'));
  });

  test('aide 619 : « de Découvreur à Légende » dans chaque langue', () {
    for (final lang in _langs) {
      final s = help619I18n[lang]!['help619_step3']!;
      // Le polonais et l'allemand déclinent le nom : on compare sur la racine.
      final first = _names[lang]!.first;
      final root = first.substring(0, first.length > 6 ? 6 : first.length).toLowerCase();
      expect(s.toLowerCase(), contains(root), reason: '$lang : $s');
    }
    expect(help619I18n['fr']!['help619_step3'], contains('Tu montes de Découvreur à Légende'));
    expect(help619I18n['en']!['help619_step3'], contains('from Newcomer to Legend'));
  });

  test('pin « 1er Ambassadeur » dans les 9 langues', () {
    for (final lang in _langs) {
      expect(plush618I18n[lang]!['pins618_first_pack_leader'], _pin[lang], reason: lang);
      expect(v565For(lang)['pins618_first_pack_leader'], _pin[lang], reason: 'registre $lang');
      final how = plush618I18n[lang]!['pins618_how']!;
      expect(how.trim(), isNotEmpty, reason: lang);
    }
  });

  test('la PELUCHE « Chiot » garde son nom', () {
    expect(plush607I18n['fr']!['plush607_type_puppy'], 'Chiot');
    expect(plush607I18n['en']!['plush607_type_puppy'], 'Puppy');
    expect(pawpoints607I18n['fr']!['help607_plush_names_4'], 'Chiot');
    expect(pawpoints607I18n['en']!['help607_plush_names_4'], 'Puppy');
    expect(v565For('fr')['plush607_type_puppy'], 'Chiot');
    expect(v565For('fr')['help607_plush_names_4'], 'Chiot');
  });

  test('montée de rang : phrase anglaise sans article (« a Ambassador » impossible)', () {
    expect(ranks611I18n['en']!['rank611_up_title'], 'New rank: @rank!');
    expect(ranks611I18n['fr']!['rank611_up_title'], 'Tu passes @rank !');
    for (final lang in _langs) {
      expect(ranks611I18n[lang]!['rank611_up_title'], contains('@rank'), reason: lang);
      expect(ranks611I18n[lang]!['rank611_to_next'], contains('@rank'), reason: lang);
      expect(ranks611I18n[lang]!['rank611_to_next'], contains('@n'), reason: lang);
    }
  });

  for (final lang in _langs) {
    testWidgets('$lang : la pastille de rang affiche le nouveau nom pour chaque clé', (t) async {
      t.view.physicalSize = const Size(320 * 3, 800 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(
        lang,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < kPawRankKeys611.length; i++)
              PawRankPill611(
                rank: PawRank611(
                  key: kPawRankKeys611[i],
                  level: i + 1,
                  pointsEarned: kPawRankMins611[i],
                  nextAt: i < 4 ? kPawRankMins611[i + 1] : null,
                ),
              ),
          ],
        ),
      ));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      for (var i = 0; i < 5; i++) {
        expect(find.text(_names[lang]![i]), findsOneWidget, reason: '$lang / ${kPawRankKeys611[i]}');
      }
      for (final o in _old[lang]!) {
        expect(find.text(o), findsNothing, reason: '$lang : ancien nom « $o »');
      }
    });
  }

  testWidgets('fr : « Encore N points pour <rang suivant> » avec les nouveaux noms', (t) async {
    t.view.physicalSize = const Size(320 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(
      'fr',
      const PawRankProgress611(
        rank: PawRank611(key: 'young_dog', level: 2, pointsEarned: 200, nextAt: 800, nextKey: 'adult_dog'),
      ),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    final all = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? w.textSpan?.toPlainText() ?? '').join(' | ');
    expect(all, contains('Explorateur'));
    expect(all, contains('Encore 600 points pour Guide'));
    expect(all, isNot(matches(RegExp(r'Jeune chien|Chien adulte|Chef de meute'))));
  });
}
