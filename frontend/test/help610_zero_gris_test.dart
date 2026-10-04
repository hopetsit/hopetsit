// 610 (03/10) — Daniel : « bouton gris » dans « Comprendre la PawMap ».
// Aucun rond d'icône de la page d'aide ne doit être gris (jour comme nuit).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hopetsit/views/map/pawmap_help_screen.dart';

import 'lotd_harness.dart';

/// Gris = couleur sans teinte, OU encre presque noire posée en voile léger
/// (c'était le cas : encre #231715 à 14 % → rond gris).
bool _grey(Color c) {
  if (c.a < 0.02) return false; // transparent
  final hsl = HSLColor.fromColor(c.withValues(alpha: 1));
  if (hsl.lightness > 0.95) return false; // blanc / crème
  if (hsl.lightness < 0.18 && c.a < 0.6) return true; // voile d'encre
  return hsl.saturation < 0.18;
}

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  for (final dark in const [false, true]) {
    testWidgets('ronds d\'icône sans gris (${dark ? 'nuit' : 'jour'})', (tester) async {
      tester.view.physicalSize = const Size(750, 1624);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(lotdApp(const PawMapHelpScreen(role: 'owner'),
          locale: const Locale('fr', 'FR'),
          brightness: dark ? Brightness.dark : Brightness.light));
      await tester.pump(const Duration(milliseconds: 100));
      final bad = <String>[];
      for (final w in tester.widgetList<Container>(
          find.byType(Container, skipOffstage: false))) {
        final d = w.decoration;
        if (d is! BoxDecoration || d.shape != BoxShape.circle) continue;
        final c = d.color;
        final b = d.border is Border ? (d.border as Border).top.color : null;
        if (c != null && _grey(c)) {
          bad.add('fond $c');
        }
        if (b != null && c != null && _grey(b)) bad.add('bord $b');
      }
      expect(bad, isEmpty, reason: bad.join('\n'));
    });
  }
}
