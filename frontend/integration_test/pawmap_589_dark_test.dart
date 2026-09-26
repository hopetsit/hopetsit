// v589 — SONDE « mode sombre » de la PawMap et de « Comprendre la PawMap »
// (Daniel : « vérifie le dark mode »). Connectée (compte de test par
// --dart-define, jamais affiché), captures par l'hôte. Le thème d'origine est
// remis à la fin.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'sonde_586_common.dart';

double _sheetSize(WidgetTester t) {
  final f = find.byType(DraggableScrollableSheet);
  if (f.evaluate().isEmpty) return -1;
  final c = t.widget<DraggableScrollableSheet>(f.first).controller;
  return (c != null && c.isAttached) ? c.size : -1;
}

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(sondeSetUp);

  testWidgets('589 sombre ($kRole)', (t) async {
    await loginAndEnter(t);
    final theme = Get.find<ThemeController>();
    final orig = theme.themeMode.value;
    await theme.setMode(ThemeMode.dark);
    await hold(t, 1500);
    await openTab(t, kPawMapTabIndex);
    final gear = find.byKey(const ValueKey('pawmap_header_options'));
    await waitFor(t, () => gear.evaluate().isNotEmpty, seconds: 60);
    await hold(t, 3000);
    for (final k in const ['coach_close', 'pawmap_announce_close']) {
      final f = find.byKey(ValueKey(k));
      if (f.evaluate().isNotEmpty) {
        await t.tap(f.first);
        await hold(t, 800);
      }
    }
    ok('mode sombre actif', Theme.of(t.element(gear.first)).brightness == Brightness.dark);
    await shot(t, 'd1_carte');

    await realTap(t, gear, why: 'roue');
    await waitFor(t, () => _sheetSize(t) > 0.5, seconds: 5);
    await shot(t, 'd2_panneau');
    final sc = find.byKey(const ValueKey('sheet_card_shortcuts'), skipOffstage: false);
    if (sc.evaluate().isNotEmpty) {
      await t.ensureVisible(sc.first);
      await hold(t, 800);
      await shot(t, 'd3_panneau_bas');
    }
    {
      final f = find.byType(DraggableScrollableSheet);
      final c = t.widget<DraggableScrollableSheet>(f.first).controller;
      if (c != null && c.isAttached) {
        await c.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
      await hold(t, 1200);
    }

    // Barre de gauche : « Modifier ma barre » + feuille de personnalisation.
    await realTap(t, find.byKey(const ValueKey('rail_customize')), why: 'modifier ma barre');
    await shot(t, 'd4_personnaliser');
    Navigator.of(t.element(find.byKey(const ValueKey('rail_reset')).first)).pop();
    await hold(t, 1200);
    await shot(t, 'd4b_barre_droite');

    // Comprendre la PawMap (bouton « ? »).
    await realTap(t, find.byKey(const ValueKey('pawmap_header_legend')), why: 'aide');
    final help = find.byType(PawMapHelpScreen);
    await waitFor(t, () => help.evaluate().isNotEmpty, seconds: 8);
    ok('aide ouverte', help.evaluate().isNotEmpty);
    await shot(t, 'd5_aide_haut');
    for (final k in const ['help_x_refresh', 'help_sec_live', 'help_x_custom', 'help_faq']) {
      final f = find.byKey(ValueKey(k), skipOffstage: false);
      if (f.evaluate().isEmpty) continue;
      await t.ensureVisible(f.first);
      await hold(t, 900);
      await shot(t, 'd6_aide_$k');
    }
    ok('lignes Actualiser / roue / modifier ma barre présentes',
        find.byKey(const ValueKey('help_x_refresh'), skipOffstage: false).evaluate().isNotEmpty &&
            find.byKey(const ValueKey('help_x_options'), skipOffstage: false).evaluate().isNotEmpty &&
            find.byKey(const ValueKey('help_x_custom'), skipOffstage: false).evaluate().isNotEmpty);

    await theme.setMode(orig);
    await hold(t, 1000);
    await sondeTearDown(t);
  });
}
