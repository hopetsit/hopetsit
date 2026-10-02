// 607 (ZOE, 02/10/2026) — catalogue PawPoints unique : textes de l'app (9 langues),
// aide « Comprendre la PawMap » (peluches + PawPoints, Pionnier) = mêmes textes que
// le site (LEO, website/src/lib/i18n/site607.ts).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/v565/pawpoints607_i18n.dart';
import 'package:hopetsit/localization/v565/v565_i18n.dart' show v565Packs;
import 'package:hopetsit/localization/v565/pioneer607_i18n.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';

import 'lotd_harness.dart';

const _langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

Set<String> _vars(String s) => RegExp(r'@[a-z]+').allMatches(s).map((m) => m.group(0)!).toSet();

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  test('9 langues, mêmes clés, mêmes variables, aucun texte vide', () {
    final fr = pawpoints607I18n['fr']!;
    expect(pawpoints607I18n.keys.toSet(), _langs.toSet());
    for (final l in _langs) {
      final d = pawpoints607I18n[l]!;
      expect(d.keys.toSet(), fr.keys.toSet(), reason: l);
      for (final k in fr.keys) {
        expect(d[k]!.trim(), isNotEmpty, reason: '$l $k');
        expect(_vars(d[k]!), _vars(fr[k]!), reason: '$l $k');
      }
    }
  });

  test('aucune langue n\'est restée en anglais (hors noms de marque)', () {
    final en = pawpoints607I18n['en']!;
    for (final l in _langs.where((x) => x != 'en')) {
      final d = pawpoints607I18n[l]!;
      for (final k in en.keys) {
        if (k == 'pp607_gain_toast' || k == 'pp607_help_points_title') continue;
        expect(d[k] == en[k] && en[k]!.split(' ').length > 1, isFalse, reason: '$l $k = anglais');
      }
    }
  });

  test('aucune promesse d\'argent ni de réduction en %', () {
    for (final l in _langs) {
      for (final v in pawpoints607I18n[l]!.values) {
        expect(RegExp(r'[-−]\s?\d+\s?%').hasMatch(v), isFalse, reason: '$l : $v');
      }
    }

  });

  test('page PawPoints : chaque libellé pp607_* du site = celui de l\'app, 9 langues', () {
    for (final l in _langs) {
      final site = jsonDecode(File('../website/src/lib/i18n/generated/$l.json').readAsStringSync()) as Map<String, dynamic>;
      var n = 0;
      for (final e in pawpoints607I18n[l]!.entries) {
        if (!site.containsKey(e.key)) continue;
        n++;
        final siteText = (site[e.key] as String).replaceAllMapped(RegExp(r'\{([a-z]+)\}'), (m) => '@${m[1]}');
        expect(e.value, siteText, reason: '$l ${e.key}');
      }
      expect(n, greaterThanOrEqualTo(20), reason: l);
    }
  });

  test('aide : une seule définition par clé, identique au site (JSON de LEO) au caractère près, 9 langues', () {
    const keys = [
      'help607_pioneer_badge', 'help607_pioneer_title', 'help607_pioneer_body',
      'help607_plush_title', 'help607_plush_body', 'pp607_help_points_title', 'pp607_help_points_body',
      'help607_plush_names_1', 'help607_plush_names_2', 'help607_plush_names_3', 'help607_plush_names_4',
      'help607_plush_names_5', 'help607_plush_gold', 'help607_plush_bonus',
    ];
    for (final l in _langs) {
      final site = jsonDecode(File('../website/src/lib/i18n/generated/$l.json').readAsStringSync()) as Map<String, dynamic>;
      for (final k in keys) {
        final defs = v565Packs.where((p) => p[l]?.containsKey(k) ?? false).toList();
        expect(defs, hasLength(1), reason: '$l $k : ${defs.length} définitions');
        expect(defs.single[l]![k], site[k], reason: '$l $k diffère du site');
      }
    }
  });

  for (final l in _langs) {
    testWidgets('aide 320 px $l : 5 peluches + la dorée, noms dessous, barème, sans débordement', (t) async {
      t.view.physicalSize = const Size(320 * 2, 700 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(lotdApp(const PawMapHelpScreen(role: 'owner'), locale: Locale(l)));
      await t.pump(const Duration(milliseconds: 100));
      final g = find.byKey(const ValueKey<String>('help607_plush_gallery'), skipOffstage: false);
      await t.ensureVisible(g);
      await t.pump(const Duration(milliseconds: 50));
      for (final ty in const ['teddy', 'bunny', 'kitty', 'puppy', 'fox', 'golden']) {
        expect(find.byKey(ValueKey<String>('help607_plush_$ty'), skipOffstage: false), findsOneWidget, reason: ty);
      }
      final bonus = find.byKey(const ValueKey<String>('help607_plush_bonus'), skipOffstage: false);
      await t.ensureVisible(bonus);
      await t.pump(const Duration(milliseconds: 50));
      expect(bonus, findsOneWidget);
      // Les 5 noms + la dorée sont dans la largeur de l'écran.
      for (final ty in const ['teddy', 'bunny', 'kitty', 'puppy', 'fox', 'golden']) {
        final r = t.getRect(find.byKey(ValueKey<String>('help607_plush_$ty'), skipOffstage: false));
        expect(r.left >= 0 && r.right <= 320, isTrue, reason: '$ty hors écran : $r');
      }
      expect(t.takeException(), isNull);
    });
  }

  for (final width in const [375.0, 768.0]) {
    for (final l in _langs) {
      testWidgets('aide ${width.toInt()} px $l : sections 5 peluches/PawPoints et 6 Pionnier', (t) async {
        t.view.physicalSize = Size(width * 2, 812 * 2);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(lotdApp(const PawMapHelpScreen(role: 'sitter'), locale: Locale(l)));
        await t.pump(const Duration(milliseconds: 100));
        final d = pawpoints607I18n[l]!;
        for (final key in const ['help607_plush', 'help607_pawpoints', 'help607_pioneer']) {
          final f = find.byKey(ValueKey<String>(key), skipOffstage: false);
          await t.ensureVisible(f);
          await t.pump(const Duration(milliseconds: 50));
          expect(f, findsOneWidget, reason: key);
        }
        expect(find.text(d['pp607_help_points_body']!, skipOffstage: false), findsOneWidget);
        expect(find.text(pioneer607I18n[l]!['help607_pioneer_body']!, skipOffstage: false), findsOneWidget);
        expect(kPawHelpSections.map((s) => s.$2).whereType<int>().toList(), [1, 2, 3, 4, 5, 6, 7, 8]);
        expect(t.takeException(), isNull);
      });
    }
  }
}
