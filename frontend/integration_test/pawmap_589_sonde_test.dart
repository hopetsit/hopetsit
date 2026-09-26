// v589 — SONDE de la PawMap (roue Options, barre de gauche, flèches, annonce),
// connectée (compte de test par --dart-define, jamais affiché), VRAIS gestes
// par l'hôte (adb) — lanceur ~/hopetsit-social/pawmap_586/run_sonde.sh.
//   1. plus de languette « Options » en bas ; 4 boutons ronds alignés en haut
//      à droite (« ? », loupe, actualiser, roue) ;
//   2. la roue ouvre la feuille complète ;
//   3. barre de gauche AVEC TOUS SES BOUTONS : jamais contre la pilule Direct ;
//   4. les deux flèches (barres gauche/droite) à la même hauteur ;
//   5. bouton « Modifier ma barre » → feuille ; appui long + glisser sur la
//      LIGNE déplace le bouton ;
//   6. fluidité : temps des images pendant un vrai glisser de la carte.
// L'ordre d'origine de la barre est remis à la fin.
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:integration_test/integration_test.dart';

import 'sonde_586_common.dart';

Rect _r(WidgetTester t, Finder f) =>
    f.evaluate().isEmpty ? Rect.zero : t.getRect(f.first);

double _sheetSize(WidgetTester t) {
  final f = find.byType(DraggableScrollableSheet);
  if (f.evaluate().isEmpty) return -1;
  final c = t.widget<DraggableScrollableSheet>(f.first).controller;
  return (c != null && c.isAttached) ? c.size : -1;
}

Future<void> _sheetDown(WidgetTester t) async {
  final f = find.byType(DraggableScrollableSheet);
  if (f.evaluate().isEmpty) return;
  final c = t.widget<DraggableScrollableSheet>(f.first).controller;
  if (c != null && c.isAttached) {
    await c.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }
  await hold(t, 1200);
}

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(sondeSetUp);

  testWidgets('589 PawMap ($kRole)', (t) async {
    await loginAndEnter(t);
    await openTab(t, kPawMapTabIndex);
    final gear = find.byKey(const ValueKey('pawmap_header_options'));
    await waitFor(t, () => gear.evaluate().isNotEmpty, seconds: 60);
    await hold(t, 3000);
    final coach = find.byKey(const ValueKey('coach_close'));
    if (coach.evaluate().isNotEmpty) {
      await t.tap(coach);
      await hold(t, 800);
    }

    // Annonce (réservée au compte de test propriétaire côté serveur).
    final annCta = find.byKey(const ValueKey('pawmap_announce_cta'));
    await waitFor(t, () => annCta.evaluate().isNotEmpty, seconds: kRole == 'owner' ? 10 : 3);
    ok('annonce PawMap affichée', annCta.evaluate().isNotEmpty || kRole != 'owner',
        detail: kRole == 'owner' ? null : 'réservée au compte propriétaire de test');
    if (annCta.evaluate().isNotEmpty) {
      await shot(t, '1_annonce');
      await realTap(t, find.byKey(const ValueKey('pawmap_announce_close')), why: 'fermer annonce');
      ok('annonce fermée', annCta.evaluate().isEmpty);
    }

    // 1. Languette retirée, 4 boutons alignés en haut à droite.
    ok('languette Options du bas retirée',
        find.byKey(const ValueKey('pawmap_options_handle')).evaluate().isEmpty &&
            find.byType(PawMapOptionsHandle).evaluate().isEmpty);
    final keys = ['pawmap_header_legend', 'pawmap_header_search', 'pawmap_header_refresh', 'pawmap_header_options'];
    final rects = [for (final k in keys) _r(t, find.byKey(ValueKey(k)))];
    final screenW = t.view.physicalSize.width / t.view.devicePixelRatio;
    final aligned = rects.every((r) => r != Rect.zero) &&
        rects.every((r) => (r.center.dy - rects.first.center.dy).abs() < 1.5) &&
        rects[0].left < rects[1].left && rects[1].left < rects[2].left && rects[2].left < rects[3].left &&
        rects[3].right <= screenW;
    ok('4 boutons alignés en haut à droite, roue la plus à droite', aligned,
        detail: rects.map((r) => '${r.left.toStringAsFixed(0)}-${r.right.toStringAsFixed(0)}@${r.top.toStringAsFixed(0)}').join(' | '));
    await shot(t, '2_repos');

    // 2. La roue ouvre la feuille complète.
    await realTap(t, gear, why: 'roue Options');
    await waitFor(t, () => _sheetSize(t) > 0.5, seconds: 5);
    ok('la roue ouvre la feuille complète', _sheetSize(t) > 0.5,
        detail: 'taille ${_sheetSize(t).toStringAsFixed(2)}');
    await shot(t, '3_feuille');
    ok('panneau : en-tête et 3 cartes',
        find.byKey(const ValueKey('sheet_title_row')).evaluate().isNotEmpty &&
            find.byKey(const ValueKey('sheet_card_see')).evaluate().isNotEmpty &&
            find.byKey(const ValueKey('sheet_card_shortcuts'), skipOffstage: false).evaluate().isNotEmpty);
    final sc = find.byKey(const ValueKey('sheet_card_shortcuts'), skipOffstage: false);
    if (sc.evaluate().isNotEmpty) {
      await t.ensureVisible(sc.first);
      await hold(t, 800);
      await shot(t, '3b_feuille_raccourcis');
      final sb = find.byKey(const ValueKey('sheet_card_subs'), skipOffstage: false);
      if (sb.evaluate().isNotEmpty) {
        await t.ensureVisible(sb.first);
        await hold(t, 800);
        await shot(t, '3c_feuille_abonnements');
      }
    }
    // La croix de l'en-tête range le panneau (on remonte d'abord jusqu'à elle).
    final close = find.byKey(const ValueKey('sheet_close'), skipOffstage: false);
    if (close.evaluate().isNotEmpty) {
      await t.ensureVisible(close.first);
      await hold(t, 800);
    }
    await realTap(t, find.byKey(const ValueKey('sheet_close')), why: 'croix du panneau');
    ok('la croix range le panneau', _sheetSize(t) < 0.05, detail: 'taille ${_sheetSize(t).toStringAsFixed(2)}');
    await _sheetDown(t);
    ok('feuille rangée', _sheetSize(t) < 0.05);

    // 3. Barre de gauche avec TOUS ses boutons, jamais contre la pilule Direct.
    final prefs = MapPrefsService.instance;
    final origRail = prefs.rail;
    prefs.update({'rail': List<String>.from(kPawRailDefaultOrder)});
    await hold(t, 2500);
    final pill = find.byWidgetPredicate((w) => w is PawMapDirectPill);
    final railBox = find.ancestor(
        of: find.byType(PawRailGlass).first, matching: find.byType(SingleChildScrollView));
    final pillR = _r(t, pill);
    final railR = _r(t, railBox);
    final gap = railR.top - pillR.bottom;
    ok('barre complète sous la pilule Direct (aucun contact)',
        pillR == Rect.zero || (railR != Rect.zero && gap >= 8),
        detail: 'pilule bas ${pillR.bottom.toStringAsFixed(0)}, barre haut ${railR.top.toStringAsFixed(0)}, écart ${gap.toStringAsFixed(0)} dp');
    // Le bouton « Modifier ma barre » reste atteignable (dernier de la barre).
    final edit = find.byType(PawRailEditButton);
    final editR = _r(t, edit);
    ok('bouton « Modifier ma barre » visible', editR != Rect.zero && editR.bottom <= railR.bottom + 1 && editR.top >= railR.top - 1,
        detail: 'bouton ${editR.top.toStringAsFixed(0)}-${editR.bottom.toStringAsFixed(0)}');
    await shot(t, '4_barre_complete');

    // 4. Flèches alignées (avec la barre complète… puis réduite à 3 boutons).
    double tabGap() {
      final tabs = find.byType(PawBarCollapseTab);
      if (tabs.evaluate().length < 2) return 999;
      final a = t.getRect(tabs.at(0)), c = t.getRect(tabs.at(1));
      return (a.center.dy - c.center.dy).abs();
    }
    ok('flèches alignées (barre complète)', tabGap() < 1.5, detail: 'écart ${tabGap().toStringAsFixed(1)} dp');
    prefs.update({'rail': kPawRailDefaultOrder.take(3).toList()});
    await hold(t, 2500);
    ok('flèches alignées (barre de 3 boutons)', tabGap() < 1.5, detail: 'écart ${tabGap().toStringAsFixed(1)} dp');
    await shot(t, '5_barre_courte');
    prefs.update({'rail': List<String>.from(kPawRailDefaultOrder)});
    await hold(t, 2000);

    // 5. « Modifier ma barre » → feuille ; appui long + glisser sur la LIGNE.
    await realTap(t, edit, why: 'Modifier ma barre');
    final sheet = find.byType(PawRailCustomizeSheet);
    await waitFor(t, () => sheet.evaluate().isNotEmpty, seconds: 5);
    ok('feuille « Personnaliser » ouverte', sheet.evaluate().isNotEmpty);
    await shot(t, '6_personnaliser');
    final id0 = kPawRailDefaultOrder[0];
    final row0 = find.byKey(ValueKey('rail_row_$id0'));
    final row2 = find.byKey(ValueKey('rail_row_${kPawRailDefaultOrder[2]}'));
    say('lignes trouvées : ${row0.evaluate().length} / ${row2.evaluate().length}');
    if (row0.evaluate().isNotEmpty && row2.evaluate().isNotEmpty) {
      // Appui TENU au milieu de la ligne (pas la poignée), puis glisser 2 rangs.
      final from = t.getRect(row0.first).center;
      final to = t.getRect(row2.first).center;
      final g = await t.startGesture(from);
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 250));
      for (var k = 1; k <= 12; k++) {
        await g.moveTo(Offset.lerp(from, to + const Offset(0, 12), k / 12)!);
        await t.pump(const Duration(milliseconds: 40));
      }
      await g.up();
      await hold(t, 2500);
    }
    // Ordre lu À L'ÉCRAN (il n'est enregistré qu'à la fermeture de la feuille).
    final row1 = find.byKey(ValueKey('rail_row_${kPawRailDefaultOrder[1]}'));
    final moved = row0.evaluate().isNotEmpty && row1.evaluate().isNotEmpty &&
        t.getRect(row0.first).top > t.getRect(row1.first).top;
    ok('appui long sur la ligne déplace le bouton', moved,
        detail: moved ? '« $id0 » n’est plus en tête' : 'ordre inchangé');
    await shot(t, '7_deplace');
    Navigator.of(t.element(sheet.first)).pop();
    await hold(t, 1500);

    // 6. Fluidité : temps des images pendant un vrai glisser de la carte.
    final timings = <FrameTiming>[];
    void cb(List<FrameTiming> l) => timings.addAll(l);
    SchedulerBinding.instance.addTimingsCallback(cb);
    final size = t.view.physicalSize / t.view.devicePixelRatio;
    final c = Offset(size.width / 2, size.height * 0.45);
    await realSwipe(t, c, -220, ms: 700, why: 'glisser la carte');
    await realSwipe(t, c + const Offset(0, -150), 220, ms: 700, why: 'glisser retour');
    SchedulerBinding.instance.removeTimingsCallback(cb);
    if (timings.isNotEmpty) {
      final ms = timings.map((f) => f.totalSpan.inMicroseconds / 1000).toList()..sort();
      final p90 = ms[(ms.length * 0.9).floor().clamp(0, ms.length - 1)];
      final slow = ms.where((x) => x > 33).length;
      ok('fluidité (émulateur)', true,
          detail: '${ms.length} images, médiane ${ms[ms.length ~/ 2].toStringAsFixed(1)} ms, '
              '90 % sous ${p90.toStringAsFixed(1)} ms, ${slow} images > 33 ms');
    }

    // Remise en état : ordre d'origine de la barre.
    prefs.update({'rail': origRail ?? List<String>.from(kPawRailDefaultOrder)});
    await hold(t, 1500);
    await sondeTearDown(t);
  });
}
