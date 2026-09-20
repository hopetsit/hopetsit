// v573 — « peaufine les boutons de la PawMap » (Daniel).
//
// Ce test monte SEULES les briques de bouton de la carte — le rail gauche
// (`PawRailButton`), la capsule droite (`PawGlassCapsule` / `PawCapsuleButton`)
// et la pilule du haut (`PawGlassPill`) — et vérifie ce qui doit rester vrai
// après le peaufinage :
//   · les boutons du rail ont TOUS exactement la même taille visuelle ;
//   · leur zone tactile fait au moins 44 dp, même sur un écran de 320 dp où
//     ScreenUtil rétrécit le rond en dessous ;
//   · un tap déclenche bien le callback (et l'animation de retour élastique
//     n'empêche pas d'en enchaîner un second) ;
//   · tout se construit en clair ET en sombre, sans exception ni débordement ;
//   · l'état actif se voit (anneau blanc plus épais + halo coloré) et passe
//     dans la sémantique (`selected`), pour le rail comme pour la capsule.
//
// ⚠️ `pump(Duration)` uniquement : `PawRailButton` termine son appui sur une
// courbe élastique et la capsule anime sa pastille — `pumpAndSettle` resterait
// correct ici, mais la règle du lot 571 est de ne jamais s'y fier sur ces
// widgets animés.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/pawmap_theme.dart';
import 'package:hopetsit/views/map/widgets/paw_rail_button.dart';

/// Les vraies couleurs du rail (violet « Autour de moi », vert itinéraire,
/// rose amis) — on ne les change pas, on vérifie juste qu'elles passent.
const Color _kViolet = Color(0xFF7C3AED);
const Color _kGreen = Color(0xFF26A65B);
const Color _kRose = Color(0xFFE0397F);

Widget _harness(Widget child, {Brightness brightness = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

/// Écran de 320 dp de large (le plus étroit visé), remis à zéro après le test.
void _sizeTo320(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Le `Container` rond qui porte le dégradé, à l'intérieur d'un bouton du rail
/// (le premier `Container` décoré en cercle sous ce bouton).
Finder _railDisc(Finder button) => find.descendant(
      of: button,
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle &&
          (w.decoration as BoxDecoration).gradient != null),
    );

BoxDecoration _railDecoration(WidgetTester tester, Finder button) =>
    tester.widget<Container>(_railDisc(button).first).decoration
        as BoxDecoration;

void main() {
  setUpAll(() {
    // Hors réseau, google_fonts ne peut pas télécharger ses polices.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PawRailButton — rail gauche', () {
    testWidgets('les boutons ont tous la même taille', (tester) async {
      await tester.pumpWidget(_harness(Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PawRailButton(
            key: const ValueKey<String>('rail_around'),
            color: _kViolet,
            label: 'Autour de moi',
            icon: Icons.navigation_rounded,
            onTap: () {},
          ),
          PawRailButton(
            key: const ValueKey<String>('rail_route'),
            color: _kGreen,
            label: 'Itinéraire',
            icon: Icons.directions_rounded,
            onTap: () {},
          ),
          // Même bouton, mais actif : l'anneau change, PAS la taille.
          PawRailButton(
            key: const ValueKey<String>('rail_friends'),
            color: _kRose,
            label: 'Amis en direct',
            icon: Icons.people_alt_rounded,
            active: true,
            onTap: () {},
          ),
        ],
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      final Size ref = tester.getSize(
          _railDisc(find.byKey(const ValueKey<String>('rail_around'))).first);
      expect(ref.width, ref.height, reason: 'le rond doit être carré');
      for (final String k in <String>['rail_route', 'rail_friends']) {
        expect(
          tester.getSize(_railDisc(find.byKey(ValueKey<String>(k))).first),
          ref,
          reason: k,
        );
      }
    });

    testWidgets('zone tactile ≥ 44 dp, y compris à 320 dp', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(PawRailButton(
        key: const ValueKey<String>('rail_tap_area'),
        color: _kViolet,
        label: 'Autour de moi',
        icon: Icons.navigation_rounded,
        onTap: () {},
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      // Le rond visuel est rétréci par ScreenUtil sur un écran étroit…
      final Size disc = tester.getSize(
          _railDisc(find.byKey(const ValueKey<String>('rail_tap_area'))).first);
      expect(disc.width, lessThan(PawMapTheme.railButtonSize));

      // … mais la boîte cliquable, elle, ne descend jamais sous 44 dp.
      final Size hit = tester
          .getSize(find.byKey(const ValueKey<String>('rail_tap_area')));
      expect(hit.width, greaterThanOrEqualTo(44.0));
      expect(hit.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('un tap déclenche le callback, deux taps aussi',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(_harness(PawRailButton(
        key: const ValueKey<String>('rail_report'),
        color: const Color(0xFFD63A28),
        label: 'Signaler',
        icon: Icons.add_moderator_rounded,
        onTap: () => taps++,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey<String>('rail_report')));
      // Retour élastique (320 ms) : on le laisse se jouer sans pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);

      await tester.tap(find.byKey(const ValueKey<String>('rail_report')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('état actif : anneau plus épais, halo, et sémantique',
        (tester) async {
      await tester.pumpWidget(_harness(Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PawRailButton(
            key: const ValueKey<String>('rail_idle'),
            color: _kRose,
            label: 'Amis en direct',
            icon: Icons.people_alt_rounded,
            onTap: () {},
          ),
          PawRailButton(
            key: const ValueKey<String>('rail_active'),
            color: _kRose,
            label: 'Amis en direct actif',
            icon: Icons.people_alt_rounded,
            active: true,
            onTap: () {},
          ),
        ],
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final BoxDecoration idle =
          _railDecoration(tester, find.byKey(const ValueKey<String>('rail_idle')));
      final BoxDecoration active = _railDecoration(
          tester, find.byKey(const ValueKey<String>('rail_active')));

      // Anneau blanc : plus épais et plus opaque quand le calque est allumé.
      expect(active.border!.top.width, greaterThan(idle.border!.top.width));
      expect(active.border!.top.color.a, greaterThan(idle.border!.top.color.a));
      // Halo : une ombre colorée de plus que l'état au repos.
      expect(active.boxShadow!.length, idle.boxShadow!.length + 1);
      // L'ombre reste COLORÉE (pas du noir dur) sous les deux états.
      expect(idle.boxShadow!.first.color.r, greaterThan(0.0));

      // Lecteur d'écran : le bouton actif est annoncé sélectionné, et son
      // libellé traduit est bien celui passé par l'appelant (aucune clé
      // inventée ici — la PawMap passe déjà des libellés traduits).
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.selected == true &&
            w.properties.label == 'Amis en direct actif'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.selected == false &&
            w.properties.label == 'Amis en direct'),
        findsOneWidget,
      );
    });

    testWidgets('se construit en clair ET en sombre', (tester) async {
      for (final Brightness b in <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        _sizeTo320(tester);
        await tester.pumpWidget(_harness(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PawRailButton(
                color: _kViolet,
                label: 'Autour de moi',
                icon: Icons.navigation_rounded,
                onTap: () {},
              ),
              PawRailButton(
                color: _kGreen,
                label: 'Itinéraire',
                icon: Icons.directions_rounded,
                active: true,
                onTap: () {},
              ),
            ],
          ),
          brightness: b,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: '$b');
        expect(find.byType(PawRailButton), findsNWidgets(2));
      }
    });
  });

  group('Capsule droite', () {
    testWidgets('se construit en clair et en sombre, tap et état actif',
        (tester) async {
      for (final Brightness b in <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        _sizeTo320(tester);
        int locate = 0;
        await tester.pumpWidget(_harness(
          PawGlassCapsule(
            children: <Widget>[
              PawCapsuleButton(
                key: const ValueKey<String>('cap_locate'),
                icon: Icons.my_location_rounded,
                label: 'Me localiser',
                onTap: () => locate++,
              ),
              PawCapsuleButton(
                key: const ValueKey<String>('cap_sat'),
                icon: Icons.satellite_alt_rounded,
                label: 'Satellite',
                secondary: true,
                active: true,
                tint: PawMapTheme.accent,
                onTap: () {},
              ),
            ],
          ),
          brightness: b,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: '$b');

        // L'onde d'appui est découpée en rond (pas le rectangle d'avant).
        final InkWell ink = tester.widget<InkWell>(find
            .descendant(
              of: find.byKey(const ValueKey<String>('cap_locate')),
              matching: find.byType(InkWell),
            )
            .first);
        expect(ink.customBorder, isA<CircleBorder>());

        await tester.tap(find.byKey(const ValueKey<String>('cap_locate')));
        await tester.pump(const Duration(milliseconds: 250));
        expect(locate, 1, reason: '$b');

        // Le bouton actif porte une pastille teintée à la couleur de marque.
        final BoxDecoration pill = tester
            .widget<AnimatedContainer>(find
                .descendant(
                  of: find.byKey(const ValueKey<String>('cap_sat')),
                  matching: find.byType(AnimatedContainer),
                )
                .first)
            .decoration as BoxDecoration;
        expect(pill.shape, BoxShape.circle);
        expect(pill.color, isNot(Colors.transparent));
        expect(pill.border, isNotNull);
      }
    });
  });

  group('PawGlassPill — pilules du haut', () {
    testWidgets('même hauteur, même rayon, même épaisseur de bord',
        (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(SizedBox(
        height: PawMapTheme.pillHeight,
        width: 300,
        child: Row(
          children: <Widget>[
            Expanded(
              child: PawGlassPill(
                key: const ValueKey<String>('pill_filters'),
                color: PawMapTheme.accent,
                height: double.infinity,
                child: const Icon(Icons.tune_rounded, size: 16),
              ),
            ),
            Expanded(
              child: PawGlassPill(
                key: const ValueKey<String>('pill_live'),
                color: PawMapTheme.ok,
                height: double.infinity,
                child: const Text('Partager', maxLines: 1),
              ),
            ),
            Expanded(
              child: PawGlassPill(
                key: const ValueKey<String>('pill_expand'),
                color: PawMapTheme.rose,
                height: double.infinity,
                child: const Text('Agrandir', maxLines: 1),
              ),
            ),
          ],
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      const List<String> keys = <String>[
        'pill_filters',
        'pill_live',
        'pill_expand',
      ];
      double? refHeight;
      for (final String k in keys) {
        final Finder box = find
            .descendant(
              of: find.byKey(ValueKey<String>(k)),
              matching: find.byType(Container),
            )
            .first;
        final BoxDecoration d =
            tester.widget<Container>(box).decoration as BoxDecoration;
        expect(d.border!.top.width, PawMapTheme.pillBorderWidth, reason: k);
        expect(
          d.borderRadius,
          BorderRadius.circular(PawMapTheme.pillRadius),
          reason: k,
        );
        final double h = tester.getSize(box).height;
        refHeight ??= h;
        expect(h, refHeight, reason: k);
      }
    });
  });
}
