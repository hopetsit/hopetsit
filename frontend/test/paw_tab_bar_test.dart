// v570 — barre d'onglets « PawMap » (variante 12d).
//
// Ce test monte la barre SEULE (390 px de large) et vérifie :
//   · elle se construit sans exception pour chaque onglet actif 0..4 ;
//   · les doigts sont à opacité 0 quand PawMap est inactif, 1 quand il l'est ;
//   · un tap sur chaque onglet rappelle bien le bon index ;
//   · la saillie de la patte n'intercepte AUCUN tap en dehors de sa zone
//     (consigne n°1 de Daniel : « le nouveau menu ne doit gêner aucun bouton »).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';

const List<String> _labels = <String>[
  'Accueil',
  'Chat',
  'PawMap',
  'Réservations',
  'Profil',
];

Widget _harness({
  required int index,
  required ValueChanged<int> onTap,
  List<Widget> behind = const <Widget>[],
}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      home: Scaffold(
        extendBody: true,
        body: Stack(children: behind),
        bottomNavigationBar: PawTabBar(
          currentIndex: index,
          onTap: onTap,
          role: PawNavRole.owner,
          systemInset: 0,
          labels: _labels,
        ),
      ),
    ),
  );
}

/// Écran de 390 px de large (mesures du handoff), remis à zéro après le test.
void _sizeTo390(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double _toeOpacity(WidgetTester tester, int i) {
  final Opacity o = tester.widget<Opacity>(
    find.byKey(ValueKey<String>('paw_toe_$i')),
  );
  return o.opacity;
}

void main() {
  setUpAll(() {
    // Hors réseau (CI / machine sans accès), google_fonts ne peut pas
    // télécharger Manrope : on coupe la récupération, la police par défaut
    // prend le relais. Aucun impact sur le code de prod.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('se construit pour chaque onglet actif 0..4', (tester) async {
    _sizeTo390(tester);
    for (int i = 0; i < 5; i++) {
      await tester.pumpWidget(_harness(index: i, onTap: (_) {}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'onglet actif $i');
      expect(find.byType(PawTabBar), findsOneWidget);
      // Les 4 doigts sont toujours présents dans l'arbre.
      for (int t = 0; t < 4; t++) {
        expect(find.byKey(ValueKey<String>('paw_toe_$t')), findsOneWidget);
      }
    }
  });

  testWidgets('doigts rétractés (opacité 0) quand PawMap est inactif',
      (tester) async {
    _sizeTo390(tester);
    await tester.pumpWidget(_harness(index: 0, onTap: (_) {}));
    await tester.pumpAndSettle();
    for (int i = 0; i < 4; i++) {
      expect(_toeOpacity(tester, i), 0.0);
    }
  });

  testWidgets('doigts sortis (opacité 1) quand PawMap est actif',
      (tester) async {
    _sizeTo390(tester);
    await tester.pumpWidget(_harness(index: 2, onTap: (_) {}));
    await tester.pumpAndSettle();
    for (int i = 0; i < 4; i++) {
      expect(_toeOpacity(tester, i), 1.0);
    }
  });

  testWidgets('les doigts sortent quand on passe sur PawMap', (tester) async {
    _sizeTo390(tester);
    int index = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => _harness(
          index: index,
          onTap: (int i) => setState(() => index = i),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_toeOpacity(tester, 0), 0.0);

    await tester.tap(find.byKey(const ValueKey<String>('paw_tab_2')));
    await tester.pumpAndSettle();
    expect(index, 2);
    for (int i = 0; i < 4; i++) {
      expect(_toeOpacity(tester, i), 1.0);
    }
  });

  testWidgets('un tap sur chaque onglet rappelle le bon index',
      (tester) async {
    _sizeTo390(tester);
    for (final int i in <int>[0, 1, 2, 3, 4]) {
      int? tapped;
      await tester.pumpWidget(
        _harness(index: 0, onTap: (int v) => tapped = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey<String>('paw_tab_$i')));
      await tester.pumpAndSettle();
      expect(tapped, i, reason: 'tap sur l\'onglet $i');
    }
  });

  testWidgets('la saillie de la patte n\'intercepte pas les taps voisins',
      (tester) async {
    _sizeTo390(tester);
    final List<String> hits = <String>[];
    // Deux boutons juste AU-DESSUS de la pilule (haut de pilule = 76 px),
    // à gauche et à droite de la zone de la patte (84 px centrés).
    Widget btn(String id, {double? left, double? right}) => Positioned(
          left: left,
          right: right,
          bottom: 90,
          child: SizedBox(
            width: 60,
            height: 40,
            child: ElevatedButton(
              key: ValueKey<String>(id),
              onPressed: () => hits.add(id),
              child: const SizedBox.shrink(),
            ),
          ),
        );

    await tester.pumpWidget(_harness(
      index: 2, // PawMap actif : patte montée, doigts sortis
      onTap: (_) => hits.add('nav'),
      behind: <Widget>[btn('left_btn', left: 16), btn('right_btn', right: 16)],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('left_btn')));
    await tester.tap(find.byKey(const ValueKey<String>('right_btn')));
    await tester.pumpAndSettle();

    expect(hits, <String>['left_btn', 'right_btn']);
  });
}
