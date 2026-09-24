// v585 (lot D) — image de référence du FOND « À MON ANIMAL » (NORME_DESIGN.md) :
// propriétaire + chien (orange pâle, os / balle / laisse), propriétaire + chat
// (poisson / pelote / lune), gardien sans animal (bleu pâle, maisons),
// PROMENEUR sans animal (VERT pâle, arbres), en clair et en sombre.
// Régénérer après un changement VOULU : `flutter test
// test/lotd_wallpaper_golden_test.dart --update-goldens` puis RELIRE l'image.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

const _owner = Color(0xFFC92A12);
const _sitter = Color(0xFF2563EB);
const _walker = Color(0xFF16A34A);

Widget _tile(Color role, Set<PawMotif> motifs, String label, Brightness b) => SizedBox(
      width: 240,
      height: 300,
      child: Theme(
        data: ThemeData(brightness: b),
        child: PawPatternBackground(
          color: role,
          motifs: motifs,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: b == Brightness.dark ? const Color(0xFF2D1F1B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: b == Brightness.dark ? Colors.white : const Color(0xFF231715))),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('fond à mon animal — ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(1000, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      PawWallpaperPrefs.debugMode = 'auto';
      PawWallpaperPrefs.debugSpecies = ['dog'];
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const ValueKey('wp'),
          child: Row(children: [
            _tile(_owner, PawWallpaperPrefs.motifs(), 'Propriétaire · chien', b),
            _tile(_owner, const {PawMotif.paw, PawMotif.heart, PawMotif.fish, PawMotif.yarn, PawMotif.moon}, 'Propriétaire · chat', b),
            _tile(_sitter, const {PawMotif.paw, PawMotif.heart, PawMotif.house}, 'Gardien', b),
            _tile(_walker, const {PawMotif.paw, PawMotif.heart, PawMotif.tree}, 'Promeneur', b),
          ]),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('wp')), matchesGoldenFile('goldens/wallpaper/wallpaper_${b.name}.png'));
    });
  }

  testWidgets('le fond ne capte aucun tap et le contenu reste cliquable', (tester) async {
    int taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: PawPatternBackground(
        color: _owner,
        motifs: const {PawMotif.paw, PawMotif.bone},
        child: Center(child: ElevatedButton(onPressed: () => taps++, child: const Text('ok'))),
      ),
    ));
    await tester.tap(find.text('ok'));
    expect(taps, 1);
  });
}
