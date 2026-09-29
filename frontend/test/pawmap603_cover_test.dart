// v603 (PAM, 29/09/2026) — photo PAR-DESSUS la carte au démarrage :
// plafond dur 800 ms (vrai Timer), retrait au geste, à la carte prête,
// fondu 120 ms, rien sans photo, rien de visible si l'onglet est caché.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/pawmap_snapshot.dart';

const _img = SizedBox.expand(
  key: ValueKey<String>('photo'),
  child: ColoredBox(color: Color(0xFFE8A07A)),
);

Future<void> _mount(WidgetTester tester, PawMapLaunchCover c) =>
    tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        Positioned.fill(child: PawMapLaunchCoverView(cover: c, image: _img)),
      ]),
    ));

double _opacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find.byKey(const ValueKey('pawmap_cover')))
    .opacity;

void main() {
  test('les chiffres imposés : plafond 800 ms, fondu 120 ms', () {
    expect(PawMapLaunchCover.kCap, const Duration(milliseconds: 800));
    expect(PawMapLaunchCover.kFade, const Duration(milliseconds: 120));
    expect(PawMapLaunchCover.kReadyGrace < PawMapLaunchCover.kCap, isTrue);
  });

  testWidgets('plafond dur : partie à 800 ms même si Google ne répond jamais',
      (tester) async {
    final c = PawMapLaunchCover();
    c.show();
    await _mount(tester, c);
    c.visible();
    expect(c.capRunning, isTrue);
    await tester.pump(const Duration(milliseconds: 799));
    expect(c.up, isTrue);
    expect(find.byKey(const ValueKey('photo')), findsOneWidget);
    expect(_opacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(c.up, isFalse);
    expect(c.reason, 'plafond');
    await tester.pump();
    expect(_opacity(tester), 0);
    // fondu de 120 ms, puis la photo quitte l'arbre
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byKey(const ValueKey('photo')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pump();
    expect(c.removed, isTrue);
    expect(find.byKey(const ValueKey('photo')), findsNothing);
    c.dispose();
  });

  testWidgets('premier geste : la photo part tout de suite', (tester) async {
    final c = PawMapLaunchCover();
    c.show();
    await _mount(tester, c);
    c.visible();
    await tester.pump(const Duration(milliseconds: 100));
    c.dismiss('geste');
    expect(c.reason, 'geste');
    expect(c.capRunning, isFalse);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('photo')), findsNothing);
    // le plafond ne relance rien après coup
    await tester.pump(const Duration(seconds: 1));
    expect(c.reason, 'geste');
    c.dispose();
  });

  testWidgets('carte prête : retrait après le court délai de peinture',
      (tester) async {
    final c = PawMapLaunchCover();
    c.show();
    await _mount(tester, c);
    c.visible();
    await tester.pump(const Duration(milliseconds: 200));
    c.mapReady();
    expect(c.up, isTrue);
    await tester.pump(PawMapLaunchCover.kReadyGrace);
    expect(c.up, isFalse);
    expect(c.reason, 'carte prête');
    c.dispose();
  });

  testWidgets('onglet caché (carte montée sous l\'accueil) : pas de plafond, '
      'et retirée sans fondu si la carte est prête avant', (tester) async {
    final c = PawMapLaunchCover();
    c.show();
    await _mount(tester, c);
    expect(c.capRunning, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(c.up, isTrue, reason: 'caché : rien ne presse');
    c.mapReady();
    await tester.pump(PawMapLaunchCover.kReadyGrace);
    await tester.pump();
    expect(c.removed, isTrue);
    expect(find.byKey(const ValueKey('photo')), findsNothing);
    // l'onglet s'ouvre ensuite : la vraie carte, directement
    c.visible();
    expect(c.capRunning, isFalse);
    c.dispose();
  });

  testWidgets('le plafond ne démarre qu\'à l\'ouverture de l\'onglet',
      (tester) async {
    final c = PawMapLaunchCover();
    c.show();
    await _mount(tester, c);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(c.up, isTrue);
    c.visible();
    await tester.pump(const Duration(milliseconds: 790));
    expect(c.up, isTrue);
    await tester.pump(const Duration(milliseconds: 10));
    expect(c.reason, 'plafond');
    c.dispose();
  });

  testWidgets('sans photo (1er lancement) : rien par-dessus', (tester) async {
    final c = PawMapLaunchCover();
    await _mount(tester, c);
    c.visible();
    c.mapReady();
    expect(c.capRunning, isFalse);
    expect(find.byKey(const ValueKey('pawmap_cover')), findsNothing);
    expect(find.byKey(const ValueKey('photo')), findsNothing);
    c.dispose();
  });

  testWidgets('la photo ne capte aucun toucher (le geste va à la carte)',
      (tester) async {
    final c = PawMapLaunchCover();
    c.show();
    var tapped = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => tapped++,
          ),
        ),
        Positioned.fill(child: PawMapLaunchCoverView(cover: c, image: _img)),
      ]),
    ));
    await tester.tapAt(const Offset(100, 100));
    expect(tapped, 1);
    c.dispose();
  });
}
