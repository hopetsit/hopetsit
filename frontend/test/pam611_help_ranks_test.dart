// 611 (PAM, 04/10/2026) — « Comprendre la PawMap » : ligne « Les rangs »
// (Chiot → Légende, seuils, aucun avantage payant), avec les PawPoints.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';

import 'lotd_harness.dart';

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  for (final w in const [375.0, 768.0]) {
    testWidgets('${w.toInt()} px : ligne « Les rangs » sous les PawPoints', (t) async {
      t.view.physicalSize = Size(w * 2, 1624);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(lotdApp(const PawMapHelpScreen(role: 'owner'), locale: const Locale('fr', 'FR')));
      await t.pump(const Duration(milliseconds: 100));
      final row = find.byKey(const ValueKey<String>('help611_ranks'), skipOffstage: false);
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Les rangs'), skipOffstage: false), findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('Jeune chien (150)'), skipOffstage: false), findsOneWidget);
      final pts = find.byKey(const ValueKey<String>('help607_pawpoints'), skipOffstage: false);
      // 612 — section « Les rangs » : la règle, PUIS comment gagner des points.
      expect(t.getTopLeft(row).dy, lessThan(t.getTopLeft(pts).dy));
      expect(t.takeException(), isNull);
    });
  }
}
