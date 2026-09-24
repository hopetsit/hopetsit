// v585 (lot D) — image de référence du JEU D'ICÔNES MAISON (NORME_DESIGN.md,
// « Icônes — une seule famille maison ») : chaque icône bicolore rendue
// deux fois (trait rôle sur fond clair · trait blanc sur fond du rôle).
// Une icône cassée par erreur échoue ici. Régénérer après un changement
// VOULU : `flutter test test/lotd_paw_icons_golden_test.dart --update-goldens`
// puis RELIRE l'image `test/goldens/icons/paw_icons_sheet.png`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

void main() {
  testWidgets('planche des icônes maison (clair + sur fond rôle)', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const owner = Color(0xFFC92A12);
    const sitter = Color(0xFF2563EB);
    const walker = Color(0xFF16A34A);
    final icons = PawIcon.values;

    Widget cell(PawIcon i, Color c, Color bg, Color? fill) => Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: PawIconWidget(i, size: 32, color: c, fill: fill)),
        );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: RepaintBoundary(
            key: const ValueKey('sheet'),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    children: [
                      for (final i in icons)
                        cell(i, i.index % 3 == 0 ? owner : (i.index % 3 == 1 ? sitter : walker),
                            const Color(0xFFFFF1EC), null),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    children: [
                      for (final i in icons)
                        cell(i, Colors.white,
                            i.index % 3 == 0 ? owner : (i.index % 3 == 1 ? sitter : walker),
                            Colors.white.withValues(alpha: 0.30)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(kPawIconBodies.length, PawIcon.values.length,
        reason: 'chaque icône de la famille a un tracé');
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/icons/paw_icons_sheet.png'),
    );
  });

  test('le SVG porte les deux couleurs (bicolore) et aucun placeholder', () {
    final s = pawIconSvg(PawIcon.house, color: const Color(0xFF2563EB));
    expect(s, contains('#2563eb'));
    expect(s, contains('rgba(37,99,235,0.180)'));
    expect(s, isNot(contains('{c}')));
    expect(s, isNot(contains('{f}')));
    expect(pawIconForRole('sitter'), PawIcon.house);
    expect(pawIconForRole('walker'), PawIcon.walker);
    expect(pawIconForRole('owner'), PawIcon.paw);
  });
}
