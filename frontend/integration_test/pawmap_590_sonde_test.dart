// v590 — SONDE du handoff design « boutons et profil PawMap » : bijoux (4 en
// haut, 9 à gauche), barres de 50 dp symétriques, bouton Balade, pilule
// « Direct off », carte focus (1er appui) et ✕ qui la ferme. Compte de test
// par --dart-define (jamais affiché) — lanceur run_sonde.sh.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_focus_card.dart';
import 'package:hopetsit/views/map/widgets/pawmap_jewel.dart';
import 'package:integration_test/integration_test.dart';

import 'sonde_586_common.dart';

Rect _r(WidgetTester t, Finder f) =>
    f.evaluate().isEmpty ? Rect.zero : t.getRect(f.first);

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(sondeSetUp);

  testWidgets('590 PawMap design ($kRole)', (t) async {
    await loginAndEnter(t);
    await openTab(t, kPawMapTabIndex);
    final gear = find.byKey(const ValueKey('pawmap_header_options'));
    await waitFor(t, () => gear.evaluate().isNotEmpty, seconds: 60);
    await hold(t, 3000);
    for (final k in ['coach_close', 'pawmap_announce_close']) {
      final f = find.byKey(ValueKey(k));
      if (f.evaluate().isNotEmpty) {
        await t.tap(f.first);
        await hold(t, 800);
      }
    }

    final jewels = find.byType(PawJewel);
    ok('boutons bijou présents (4 en-tête + 9 barre + Balade)',
        jewels.evaluate().length >= 14,
        detail: '${jewels.evaluate().length}');
    final keys = ['pawmap_header_legend', 'pawmap_header_search', 'pawmap_header_refresh', 'pawmap_header_options'];
    final rects = [for (final k in keys) _r(t, find.byKey(ValueKey(k)))];
    final screenW = t.view.physicalSize.width / t.view.devicePixelRatio;
    ok('4 bijoux alignés en haut à droite, dans l\'écran',
        rects.every((r) => r != Rect.zero) &&
            rects.every((r) => (r.center.dy - rects.first.center.dy).abs() < 1.5) &&
            rects.last.right <= screenW,
        detail: rects.map((r) => '${r.left.toStringAsFixed(0)}-${r.right.toStringAsFixed(0)}').join(' | '));
    final walk = find.byKey(const ValueKey('pawmap_walk_btn'));
    ok('bouton Balade dans la barre droite', walk.evaluate().isNotEmpty);
    final rail = _r(t, find.byKey(const ValueKey('rail_around')));
    final walkR = _r(t, walk);
    ok('barres symétriques (écart au bord ~ égal)',
        rail != Rect.zero && walkR != Rect.zero &&
            ((rail.left) - (screenW - walkR.right)).abs() < 14,
        detail: 'g=${rail.left.toStringAsFixed(0)} d=${(screenW - walkR.right).toStringAsFixed(0)}');
    ok('pilule « Direct off »',
        find.byKey(const ValueKey('pawmap_direct_pill_off')).evaluate().isNotEmpty ||
            find.byKey(const ValueKey('pawmap_direct_pill_on')).evaluate().isNotEmpty);
    await shot(t, '1_repos');

    // Carte focus : 1er appui simulé sur une personne fictive.
    final st = t.state(find.byType(PawMapScreen)) as dynamic;
    var opened = 0;
    st.focusForTest(
      PawFocusInfo(
        key: 'sonde590',
        name: 'Léa Sonde',
        role: 'sitter',
        info: '25 € · 1,4 km',
        onOpen: () => opened++,
      ),
      const LatLng(-35.2, -30.4),
    );
    await hold(t, 1500);
    final card = find.byType(PawFocusCard);
    ok('carte focus affichée', card.evaluate().isNotEmpty);
    final cr = _r(t, card);
    ok('carte focus entre les barres, en haut',
        cr != Rect.zero && cr.left >= rail.right - 4 && cr.right <= walkR.left + 4,
        detail: '${cr.left.toStringAsFixed(0)}-${cr.right.toStringAsFixed(0)} @${cr.top.toStringAsFixed(0)}');
    await shot(t, '2_focus');
    await realTap(t, find.byKey(const ValueKey('pawmap_focus_open')), why: 'Profil ›');
    await hold(t, 600);
    ok('« Profil › » ouvre la fiche', opened == 1, detail: 'opened=$opened');
    await realTap(t, find.byKey(const ValueKey('pawmap_focus_close')), why: '✕');
    await hold(t, 1200);
    ok('✕ ferme la carte focus', find.byType(PawFocusCard).evaluate().isEmpty);
    await shot(t, '3_ferme');
  });
}
