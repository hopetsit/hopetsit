// 631 (PAM-C, 31/10/2026) — bouton « Balade rapide » seul :
//   · caché / visible selon la préférence, côté droite / gauche ;
//   · au repos : 1 toucher = le callback de démarrage (le même flux que
//     « Démarrer ma balade »), jamais l'arrêt ;
//   · en balade : chrono « 12 min », 1 toucher = le callback d'arrêt (feuille
//     « En direct »), jamais le démarrage ;
//   · `positioned` : à droite ou à gauche au-dessus de la barre d'onglets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/services/open_on_prefs_3110.dart';
import 'package:hopetsit/widgets/quick_walk_button_3110.dart';

import 'lotd_harness.dart';

void main() {
  setUp(() async {
    await lotdSetUp(role: 'walker');
    OpenOnPrefs3110.resetForTest();
  });

  Widget host(Widget child) => lotdApp(Scaffold(body: Center(child: child)));

  testWidgets('caché quand la préférence est OFF, visible quand ON', (t) async {
    final visible = false.obs;
    await t.pumpWidget(host(QuickWalkButton3110(
      visible: visible,
      broadcasting: false.obs,
      startedAt: Rxn<DateTime>(),
    )));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('quick_walk_3110_tap')), findsNothing);
    visible.value = true;
    await t.pump();
    expect(find.byKey(const ValueKey<String>('quick_walk_3110_tap')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('côté : droite par défaut, gauche pour les gauchers', (t) async {
    final side = QuickWalkSide3110.right.obs;
    await t.pumpWidget(host(QuickWalkButton3110(
      visible: true.obs,
      side: side,
      broadcasting: false.obs,
      startedAt: Rxn<DateTime>(),
    )));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('quick_walk_3110_right')), findsOneWidget);
    side.value = QuickWalkSide3110.left;
    await t.pump();
    expect(find.byKey(const ValueKey<String>('quick_walk_3110_left')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('quick_walk_3110_right')), findsNothing);
  });

  testWidgets('au repos : 1 toucher = démarrer (jamais arrêter), 62 pt', (t) async {
    int starts = 0, stops = 0;
    await t.pumpWidget(host(QuickWalkButton3110(
      visible: true.obs,
      broadcasting: false.obs,
      startedAt: Rxn<DateTime>(),
      onStart: () async => starts++,
      onStop: (_) async => stops++,
    )));
    await t.pump();
    final tap = find.byKey(const ValueKey<String>('quick_walk_3110_tap'));
    final size = t.getSize(tap);
    expect(size.width, kQuickWalkSize3110);
    expect(size.height, kQuickWalkSize3110);
    expect(find.byKey(const ValueKey<String>('quick_walk_3110_chrono')), findsNothing);
    await t.tap(tap);
    await t.pump();
    expect(starts, 1);
    expect(stops, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('en balade : chrono « 12 min », 1 toucher = arrêter (jamais démarrer)', (t) async {
    int starts = 0, stops = 0;
    final now = DateTime(2026, 10, 31, 16, 12);
    final broadcasting = true.obs;
    await t.pumpWidget(host(QuickWalkButton3110(
      visible: true.obs,
      broadcasting: broadcasting,
      startedAt: Rxn<DateTime>(now.subtract(const Duration(minutes: 12))),
      now: () => now,
      onStart: () async => starts++,
      onStop: (_) async => stops++,
    )));
    await t.pump();
    final chrono = find.byKey(const ValueKey<String>('quick_walk_3110_chrono'));
    expect(chrono, findsOneWidget);
    expect(t.widget<Text>(chrono).data, contains('12'));
    await t.tap(find.byKey(const ValueKey<String>('quick_walk_3110_tap')));
    await t.pump();
    expect(stops, 1);
    expect(starts, 0);

    // La balade s'arrête (le service passe à faux) → retour au repos.
    broadcasting.value = false;
    await t.pump();
    expect(chrono, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('positioned : bas droite / bas gauche au-dessus de la barre', (t) async {
    lotdPhone(t, width: 393, height: 852);
    OpenOnPrefs3110.quickWalkSide.value = QuickWalkSide3110.right;
    await t.pumpWidget(lotdApp(Scaffold(
      body: Builder(builder: (ctx) => Stack(children: [
        const SizedBox.expand(),
        QuickWalkButton3110.positioned(ctx),
      ])),
    )));
    await t.pump();
    final tap = find.byKey(const ValueKey<String>('quick_walk_3110_tap'));
    final r = t.getRect(tap);
    final screen = t.getSize(find.byType(Scaffold));
    expect(screen.width - r.right, kQuickWalkSideMargin3110);
    expect(screen.height - r.bottom, greaterThanOrEqualTo(kQuickWalkAboveBar3110));
    OpenOnPrefs3110.quickWalkSide.value = QuickWalkSide3110.left;
    await t.pump();
    expect(t.getRect(tap).left, kQuickWalkSideMargin3110);
    expect(t.takeException(), isNull);
  });
}
