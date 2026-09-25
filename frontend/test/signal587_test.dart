// v587 (25/09/2026, point 9) — pastille signature de l'œil / du Direct et
// feuille « Arrêter le direct ? » : zéro gris, 9 langues, 2 s, mode sombre.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/v565/signal587_i18n.dart';
import 'package:hopetsit/views/map/widgets/pawmap_signal.dart';

import 'lotd_harness.dart';

const _langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

/// Gris = canaux R, G, B presque égaux (hors blanc pur, noir-encre et transparents).
bool _isGrey(Color c) {
  final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
  if (c.a < 0.05) return false;
  if (r > 235 && g > 235 && b > 235 && r >= b) return false; // blanc / crème chaud
  final spread = [r, g, b].reduce((a, x) => a > x ? a : x) - [r, g, b].reduce((a, x) => a < x ? a : x);
  return spread < 10 && r > 40;
}

List<Color> _colorsIn(WidgetTester tester, Finder root) {
  final out = <Color>[];
  for (final e in find.descendant(of: root, matching: find.byWidgetPredicate((_) => true)).evaluate()) {
    final w = e.widget;
    if (w is Container && w.decoration is BoxDecoration) {
      final d = w.decoration as BoxDecoration;
      if (d.color != null) out.add(d.color!);
      if (d.gradient is LinearGradient) out.addAll((d.gradient as LinearGradient).colors);
      final b = d.border;
      if (b is Border) out.add(b.top.color);
    }
    if (w is Text && w.style?.color != null) out.add(w.style!.color!);
    if (w is Icon && w.color != null) out.add(w.color!);
  }
  return out;
}

void main() {
  test('9 langues : toutes les clés, aucune vide, aucun anglais recopié', () {
    final en = signal587I18n['en']!;
    for (final l in _langs) {
      final m = signal587I18n[l];
      expect(m, isNotNull, reason: l);
      expect(m!.keys.toSet(), en.keys.toSet(), reason: l);
      for (final k in m.keys) {
        expect(m[k]!.trim(), isNotEmpty, reason: '$l $k');
        if (l != 'en') expect(m[k] == en[k], isFalse, reason: '$l $k recopie l\'anglais');
      }
    }
  });

  for (final dark in [false, true]) {
    for (final kind in PawSignalKind.values) {
      testWidgets('pastille $kind (${dark ? 'sombre' : 'clair'}) : aucun gris', (tester) async {
        lotdPhone(tester);
        await tester.pumpWidget(lotdApp(
          Scaffold(body: Center(child: PawSignalPill(kind: kind, text: 'Direct arrêté'))),
          brightness: dark ? Brightness.dark : Brightness.light,
        ));
        await lotdSettle(tester, frames: 2);
        final grey = _colorsIn(tester, find.byType(PawSignalPill)).where(_isGrey).toList();
        expect(grey, isEmpty, reason: 'couleurs grises : $grey');
        expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      });
    }
  }

  testWidgets('œil : la pastille dit le nouvel état puis disparaît après 2 s', (tester) async {
    lotdPhone(tester);
    late BuildContext ctx;
    await tester.pumpWidget(lotdApp(Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    }))));
    PawSignal.visibility(ctx, 'friends');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Visible par tes amis seulement'), findsOneWidget);
    // Une nouvelle pastille remplace la précédente : jamais d'empilement.
    PawSignal.visibility(ctx, 'hidden');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Visible par tes amis seulement'), findsNothing);
    expect(find.text('Tu es masqué sur la carte'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey<String>('pawmap_signal_toast')), findsNothing);
  });

  for (final lang in ['fr', 'ja']) {
    testWidgets('« Arrêter le direct ? » ($lang, 320 px) : feuille signature, confirmer = vrai', (tester) async {
      lotdPhone(tester, width: 320, height: 700);
      bool? result;
      await tester.pumpWidget(lotdApp(
        Scaffold(body: Builder(builder: (c) => Center(
          child: TextButton(onPressed: () async => result = await showPawStopLiveSheet(c), child: const Text('go')),
        ))),
        locale: Locale(lang),
      ));
      await tester.tap(find.text('go'));
      await lotdSettle(tester);
      expect(find.byKey(const ValueKey<String>('pawmap_stop_live_sheet')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull); // aucun débordement
      final grey = _colorsIn(tester, find.byKey(const ValueKey<String>('pawmap_stop_live_sheet'))).where(_isGrey).toList();
      expect(grey, isEmpty, reason: 'couleurs grises : $grey');
      await tester.tap(find.byKey(const ValueKey<String>('pawmap_stop_live_confirm')));
      await lotdSettle(tester);
      expect(result, isTrue);
    });
  }

  testWidgets('« Continuer le direct » = faux', (tester) async {
    lotdPhone(tester);
    bool? result;
    await tester.pumpWidget(lotdApp(Scaffold(body: Builder(builder: (c) => Center(
      child: TextButton(onPressed: () async => result = await showPawStopLiveSheet(c), child: const Text('go')),
    )))));
    await tester.tap(find.text('go'));
    await lotdSettle(tester);
    expect(find.text('Arrêter le direct ?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('pawmap_stop_live_keep')));
    await lotdSettle(tester);
    expect(result, isFalse);
  });
}
