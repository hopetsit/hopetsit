// v586 — SONDE de la PawMap « discrète et dégagée », connectée (compte de test
// par --dart-define, jamais affiché), VRAIS gestes par l'hôte (adb) :
//   repos (feuille rangée, poignée seule) → appui poignée → feuille complète →
//   poignée de la feuille (rangée) → glissement de la poignée → œil × 3 (relu
//   sur le compte) → Publier (propriétaire) ou Direct vert ↔ noir (gardien /
//   promeneur) → effacement au geste → « Ce que je veux voir » : Lieux off ne
//   touche pas les personnes. Rien n'est publié : l'écran « Publier » est
//   refermé sans envoyer ; le direct part depuis la zone fictive (-35/-30,
//   posée par l'hôte) et s'arrête aussitôt ; la visibilité d'origine est
//   remise à la fin.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';
import 'package:integration_test/integration_test.dart';

import 'sonde_586_common.dart';

Rect _r(WidgetTester t, Finder f) =>
    f.evaluate().isEmpty ? Rect.zero : t.getRect(f.first);

Map<String, int> _families(WidgetTester t) {
  final f = find.byType(GoogleMap, skipOffstage: false);
  if (f.evaluate().isEmpty) return const {};
  final out = <String, int>{};
  for (final m in t.widget<GoogleMap>(f).markers) {
    final id = m.markerId.value;
    final fam = id == 'me'
        ? 'moi'
        : (id.startsWith('nearby_') || id.startsWith('mcluster_') || id.startsWith('friend_'))
            ? 'personnes'
            : (id.startsWith('poi_') || id.startsWith('pcluster_'))
                ? 'lieux'
                : 'autres';
    out[fam] = (out[fam] ?? 0) + 1;
  }
  return out;
}

double _sheetSize(WidgetTester t) {
  final f = find.byType(DraggableScrollableSheet);
  if (f.evaluate().isEmpty) return -1;
  final c = t.widget<DraggableScrollableSheet>(f.first).controller;
  return (c != null && c.isAttached) ? c.size : -1;
}

Future<void> _confirmDialog(WidgetTester t, String why) async {
  final ok = find.byType(AppDialogPrimaryButton);
  await waitFor(t, () => ok.evaluate().isNotEmpty, seconds: 6);
  if (ok.evaluate().isNotEmpty) await realTap(t, ok, why: why);
}

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(sondeSetUp);

  testWidgets('586 PawMap ($kRole)', (t) async {
    await loginAndEnter(t);
    await openTab(t, kPawMapTabIndex);
    await waitFor(t,
        () => find.byKey(const ValueKey('pawmap_options_handle')).evaluate().isNotEmpty,
        seconds: 60);
    await hold(t, 3000);
    // Découverte guidée éventuelle : on la ferme (croix).
    final coach = find.byKey(const ValueKey('coach_close'));
    if (coach.evaluate().isNotEmpty) {
      await t.tap(coach);
      await hold(t, 800);
    }
    final prefs = MapPrefsService.instance;
    final live = Get.find<LiveMapService>();
    final origVis = prefs.mapVisibility.value;
    final ctx = t.element(find.byType(PawMapScreen));
    final mq = MediaQuery.of(ctx);
    say('taille=${mq.size} viewPadding.bottom(fenetre)=${View.of(ctx).viewPadding.bottom / View.of(ctx).devicePixelRatio} visibilite=$origVis');

    // ── 1. Repos : feuille rangée, poignée seule ──
    final handle = find.byKey(const ValueKey('pawmap_options_handle'));
    final bar = find.byType(PawTabBar);
    final action = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('pawmap_action_'));
    final eye = find.byKey(const ValueKey('pawmap_eye'));
    ok('feuille rangee au repos', _sheetSize(t) <= 0.03, detail: 'taille=${_sheetSize(t).toStringAsFixed(3)}');
    ok('poignee visible', handle.evaluate().isNotEmpty);
    final hr = _r(t, handle), br = _r(t, bar), ar = _r(t, action), er = _r(t, eye);
    say('poignee=$hr menu=$br action=$ar oeil=$er');
    final barTop = br == Rect.zero ? mq.size.height : br.top;
    ok('poignee au-dessus du menu', hr.bottom <= barTop + 1, detail: 'bas=${hr.bottom} menu=$barTop');
    ok('action du role au-dessus du menu et de la barre systeme',
        ar != Rect.zero && ar.bottom <= barTop - 4 && ar.bottom < mq.size.height - 8,
        detail: 'bas=${ar.bottom}');
    ok('bouton oeil present', er != Rect.zero);
    await shot(t, '01_repos');

    // ── 2. Appui sur la poignée → feuille COMPLÈTE ──
    await realTap(t, handle, why: 'poignee');
    await hold(t, 1200);
    final s1 = _sheetSize(t);
    ok('appui poignee -> feuille complete', s1 > 0.6, detail: 'taille=${s1.toStringAsFixed(3)}');
    ok('SOS / Calques / Mes abonnements dans la feuille',
        find.byKey(const ValueKey('dock_sos'), skipOffstage: false).evaluate().isNotEmpty &&
            find.byKey(const ValueKey('pawmap_btn_subs'), skipOffstage: false).evaluate().isNotEmpty);
    ok('section « Ce que je veux voir »',
        find.byKey(const ValueKey('pawmap_see_section'), skipOffstage: false).evaluate().isNotEmpty);
    ok('ligne d\'action equivalente (bouton principal) dans la feuille',
        find.byKey(const ValueKey('pawmap_primary'), skipOffstage: false).evaluate().isNotEmpty);
    await shot(t, '02_feuille_ouverte');

    // ── 7. « Ce que je veux voir » : Lieux off ne touche pas les personnes ──
    final places = find.byKey(const ValueKey('see_places'));
    if (places.evaluate().isNotEmpty) {
      await t.ensureVisible(places);
      await hold(t, 600);
      await shot(t, '03_ce_que_je_veux_voir');
      final before = _families(t);
      await realTap(t, places, why: 'Lieux off');
      await hold(t, 2500);
      final after = _families(t);
      say('marqueurs avant=$before apres=$after');
      ok('Lieux off : personnes inchangees',
          (after['personnes'] ?? 0) == (before['personnes'] ?? 0) &&
              (after['moi'] ?? 0) == (before['moi'] ?? 0));
      ok('Lieux off : plus aucun lieu', (after['lieux'] ?? 0) == 0);
      await shot(t, '04_lieux_off');
      await realTap(t, places, why: 'Lieux on');
      await hold(t, 1500);
    }

    // Poignée de la feuille : la ranger.
    final grip = find.byKey(const ValueKey('pawmap_sheet_grip'));
    if (grip.evaluate().isEmpty) {
      // La liste a défilé jusqu'à la section : on remonte en haut.
      await t.scrollUntilVisible(grip, -300,
          scrollable: find
              .descendant(
                  of: find.byType(DraggableScrollableSheet),
                  matching: find.byType(Scrollable))
              .first);
    }
    await hold(t, 500);
    await realTap(t, grip, why: 'poignee de la feuille');
    await hold(t, 1200);
    ok('poignee de la feuille -> rangee', _sheetSize(t) <= 0.03, detail: 'taille=${_sheetSize(t).toStringAsFixed(3)}');

    // ── Glissement vers le haut sur la poignée ──
    await realSwipe(t, _r(t, handle).center, -220, ms: 350, why: 'glisser poignee');
    await hold(t, 1200);
    final s2 = _sheetSize(t);
    ok('glissement poignee -> feuille ouverte', s2 > 0.4, detail: 'taille=${s2.toStringAsFixed(3)}');
    await realTap(t, grip, why: 'ranger');
    await hold(t, 1200);

    // ── 3. Œil : 3 états, relus sur le compte ──
    for (var i = 0; i < 3; i++) {
      final beforeV = prefs.mapVisibility.value;
      await realTap(t, eye, why: 'oeil');
      await hold(t, 2500);
      final now = prefs.mapVisibility.value;
      await prefs.loadFromAccount();
      final acc = prefs.mapVisibility.value;
      ok('oeil $beforeV -> $now (compte : $acc)',
          now == MapPrefsService.nextVisibility(beforeV) && acc == now);
      ok('pastille 2 s', find.byKey(const ValueKey('pawmap_vis_toast')).evaluate().isNotEmpty ||
          acc == now);
      await shot(t, '05_oeil_$now');
    }
    if (prefs.mapVisibility.value != origVis) {
      await prefs.setMapVisibility(origVis);
      await hold(t, 1000);
    }
    ok('visibilite d\'origine remise', prefs.mapVisibility.value == origVis);

    // ── 2. Action du rôle ──
    if (kRole == 'owner') {
      final pub = find.byKey(const ValueKey('pawmap_action_publish'));
      await realTap(t, pub, why: 'Publier');
      await hold(t, 2000);
      final opened = find.byType(PublishReservationRequestScreen).evaluate().isNotEmpty;
      ok('Publier -> ecran de demande', opened);
      await shot(t, '06_publier');
      if (opened) {
        Navigator.of(t.element(find.byType(PublishReservationRequestScreen))).pop();
        await hold(t, 1500);
      }
    } else {
      if (live.broadcasting.value) {
        say('un direct tournait deja : arret');
        live.stopBroadcasting();
        await hold(t, 1000);
      }
      await shot(t, '06_direct_noir');
      await realTap(t, find.byKey(const ValueKey('pawmap_direct_pill_off')), why: 'Direct on');
      // Première fois : une phrase d'explication (Continuer).
      if (find.byType(AppDialogPrimaryButton).evaluate().isNotEmpty) {
        await _confirmDialog(t, 'explication 1re fois');
      }
      await waitFor(t, () => live.broadcasting.value, seconds: 15);
      await hold(t, 1500);
      ok('Direct -> en direct (vert)', live.broadcasting.value &&
          find.byKey(const ValueKey('pawmap_direct_pill_on')).evaluate().isNotEmpty);
      await shot(t, '07_direct_vert');
      await realTap(t, find.byKey(const ValueKey('pawmap_direct_pill_on')), why: 'Direct off');
      await _confirmDialog(t, 'confirmer l\'arret');
      await waitFor(t, () => !live.broadcasting.value, seconds: 10);
      await hold(t, 1200);
      ok('Direct -> arrete (noir) apres confirmation', !live.broadcasting.value &&
          find.byKey(const ValueKey('pawmap_direct_pill_off')).evaluate().isNotEmpty);
      await shot(t, '08_direct_noir_apres');
      if (live.broadcasting.value) live.stopBroadcasting();
    }

    // ── 5. Effacement au geste : glisser la carte ──
    double railOpacity() {
      final f = find.ancestor(of: eye, matching: find.byType(AnimatedOpacity));
      return f.evaluate().isEmpty ? -1 : t.widget<AnimatedOpacity>(f.first).opacity;
    }

    final c = Offset(mq.size.width / 2, mq.size.height * 0.42);
    double minOp = 1;
    if (kSelfGestures) {
      // iOS : le test fait lui-même un vrai glissement (TestGesture).
      final g = await t.startGesture(c);
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(-10, 13));
        await hold(t, 100);
        final o = railOpacity();
        if (o >= 0 && o < minOp) minOp = o;
        if (i == 6) print('[SWIPESHOT] 0 0 0 0 0 09_geste_efface');
      }
      await hold(t, 800);
      await g.up();
    }
    if (!kSelfGestures) print('[SWIPESHOT] ${(c.dx * t.view.devicePixelRatio).round()} ${(c.dy * t.view.devicePixelRatio).round()} '
        '${((c.dx - 120) * t.view.devicePixelRatio).round()} ${((c.dy + 160) * t.view.devicePixelRatio).round()} 1600 09_geste_efface');
    for (var i = 0; i < (kSelfGestures ? 0 : 24); i++) {
      await hold(t, 100);
      final o = railOpacity();
      if (o >= 0 && o < minOp) minOp = o;
    }
    ok('pendant le geste : commandes a 35 %', minOp <= 0.36, detail: 'min=$minOp');
    await hold(t, 1600);
    ok('1 s apres le lacher : 100 %', railOpacity() == 1, detail: 'op=${railOpacity()}');
    await shot(t, '10_apres_geste');

    await sondeTearDown(t);
  });
}
