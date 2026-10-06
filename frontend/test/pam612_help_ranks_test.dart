// 612 (PAM, 05/10/2026) — Daniel : « les rangs ne sont pas expliqués dans
// Comprendre la carte ». Section à part : 5 pastilles réelles + seuils (lus
// à la source serveur) + comment gagner des points, 375 et 768 px, 9 langues.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/v565/ranks611_i18n.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/widgets/paw_rank611.dart';

import 'lotd_harness.dart';

void main() {
  test('seuils de l\'app = seuils du serveur (backend/src/services/ranks611.js)', () {
    final js = File('../backend/src/services/ranks611.js').readAsStringSync();
    final mins = RegExp(r"key: '(\w+)', min: (\d+)")
        .allMatches(js)
        .map((m) => (m.group(1)!, int.parse(m.group(2)!)))
        .toList();
    expect(mins.map((e) => e.$1).toList(), kPawRankKeys611);
    expect(mins.map((e) => e.$2).toList(), kPawRankMins611);
  });

  test('9 langues : textes présents et non vides', () {
    for (final lang in ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      final m = ranks611I18n[lang]!;
      for (final k in ['help611_ranks_t', 'help611_ranks_b', 'help612_rank_from', 'help612_earn_t']) {
        expect((m[k] ?? '').trim(), isNotEmpty, reason: '$lang/$k');
      }
      expect(m['help612_rank_from']!.contains('{n}'), isTrue, reason: lang);
    }
  });

  test('section « Les rangs » au sommaire, numéro 6', () {
    final s = kPawHelpSections.firstWhere((e) => e.$1 == 'ranks');
    expect(s.$2, 6);
  });

  for (final w in const [375.0, 768.0]) {
    for (final dark in const [false, true]) {
      testWidgets('${w.toInt()} px ${dark ? 'sombre' : 'clair'} : 5 pastilles + seuils + gains', (t) async {
        t.view.physicalSize = Size(w * 2, 1624);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(lotdApp(const PawMapHelpScreen(role: 'owner'),
            locale: const Locale('fr', 'FR'), brightness: dark ? Brightness.dark : Brightness.light));
        await t.pump(const Duration(milliseconds: 100));
        for (final k in kPawRankKeys611) {
          final row = find.byKey(ValueKey<String>('help612_rank_$k'), skipOffstage: false);
          expect(row, findsOneWidget, reason: k);
          expect(find.descendant(of: row, matching: find.byType(PawRankPill611), skipOffstage: false),
              findsOneWidget);
        }
        expect(find.text('dès 10 000 PawPoints', skipOffstage: false).evaluate().isNotEmpty ||
            find.text('dès 10 000 PawPoints', skipOffstage: false).evaluate().isNotEmpty, isTrue);
        expect(find.text('Chef de meute', skipOffstage: false), findsWidgets);
        expect(find.byKey(const ValueKey<String>('help607_pawpoints'), skipOffstage: false), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
