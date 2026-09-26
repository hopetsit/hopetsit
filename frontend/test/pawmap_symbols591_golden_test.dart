// v591 — les icônes de la PawMap passent par la police FIGÉE `PawSymbols`
// (assets/pawsymbols). Le 590 affichait des boutons vides : la police variable
// Material Symbols était abîmée par la réduction du build release. Cette
// planche dessine CHAQUE icône dans son bouton bijou avec la vraie police :
// une icône vide ou manquante se voit ici. Régénérer après un changement
// VOULU : `flutter test test/pawmap_symbols591_golden_test.dart --update-goldens`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_jewel.dart';

void main() {
  testWidgets('les 19 icônes PawMap se dessinent (police figée)', (tester) async {
    final loader = FontLoader('PawSymbols')
      ..addFont(rootBundle.load('assets/pawsymbols/PawSymbolsRounded.ttf'));
    await loader.load();
    tester.view.physicalSize = const Size(560, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const icons = <IconData>[
      PawSymbols.chat, PawSymbols.photo, PawSymbols.spots, PawSymbols.tag,
      PawSymbols.feed, PawSymbols.report, PawSymbols.friends, PawSymbols.route,
      PawSymbols.around, PawSymbols.help, PawSymbols.search, PawSymbols.refresh,
      PawSymbols.settings, PawSymbols.publish, PawSymbols.requests, PawSymbols.walk,
      PawSymbols.home, PawSymbols.close, PawSymbols.chevronRight,
    ];
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(560, 300),
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: RepaintBoundary(
            key: const ValueKey('sheet'),
            child: Wrap(
              children: [
                for (final i in icons)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: PawJewel(
                      palette: kJewelHeader, icon: i, label: '', size: 44, onTap: () {}),
                  ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await expectLater(find.byKey(const ValueKey('sheet')),
        matchesGoldenFile('goldens/icons/pawmap_symbols591.png'));
  });
}
