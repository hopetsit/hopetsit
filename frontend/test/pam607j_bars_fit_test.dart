// 607 (PAM, 02/10/2026) — BOB, vu sur Android (1080×2340) : pendant une
// Balade, la barre de droite débordait (ligne « 0 min » en plus) et son
// bouton « Modifier » passait à moitié sous « Publier ». Règle : une barre
// trop haute RÉTRÉCIT d'abord (boutons entiers), ne défile qu'au-delà, et ne
// dépasse jamais sa hauteur utile. Barre de gauche : 10 boutons (PawPoints).
// Hauteurs utiles = hauteur d'écran − (en-tête + pilule + menu + marges)
// ≈ hauteur − 330 dp, mesurée sur l'émulateur et l'iPhone.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/map/widgets/paw_rail_button.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';

const _screens = <Size>[Size(360, 640), Size(360, 780), Size(393, 852), Size(440, 956)];

Widget _app(Size s, Widget child) => MediaQuery(
      data: MediaQueryData(size: s),
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => GetMaterialApp(
          home: Scaffold(body: Align(alignment: Alignment.bottomRight, child: child)),
        ),
      ),
    );

/// La barre de droite telle que l'écran la construit (fixes + 5 boutons
/// personnalisables + Balade avec son libellé + Modifier + action du rôle).
Widget _capsule(double maxH, {required bool walking, required String role}) {
  Widget b(String k) => PawCapsuleButton(
      key: ValueKey<String>(k), icon: Icons.circle, label: k, onTap: () {});
  return PawGlassCapsule(
    width: 50,
    maxHeight: maxH,
    leading: [b('locate'), b('in'), b('out')],
    children: [
      b('satellite'),
      b('everyone'),
      b('feed'),
      Column(mainAxisSize: MainAxisSize.min, children: [
        b('balade'),
        Text(walking ? '12 min' : 'Balade', style: const TextStyle(fontSize: 9.5)),
      ]),
      b('eye'),
      const SizedBox(key: ValueKey<String>('customize'), width: 38, height: 28),
    ],
    footer: PawCapsuleRoleAction(
      kind: role == 'owner' ? PawRoleActionKind.publish : PawRoleActionKind.requests,
      live: false,
      showLabel: true,
      onTap: () {},
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('échelle : tient = 1, un peu trop = rétrécit, beaucoup trop = défile', () {
    expect(pawFitScale(300, 400), 1);
    expect(pawFitScale(400, 330), closeTo(0.825, 0.001));
    expect(pawFitScale(600, 300), isNull);
  });

  for (final s in _screens) {
    for (final walking in [false, true]) {
      for (final role in ['owner', 'sitter', 'walker']) {
        testWidgets('barre de droite ${s.width.toInt()}×${s.height.toInt()} '
            '${walking ? 'en Balade' : 'hors Balade'} $role : aucun bouton coupé', (t) async {
          t.view.physicalSize = s;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final maxH = s.height - 330;
          await t.pumpWidget(_app(s, _capsule(maxH, walking: walking, role: role)));
          await t.pump();
          await t.pump(); // mesure → décision
          expect(t.takeException(), isNull);
          final cap = t.getRect(find.byType(PawGlassCapsule));
          expect(cap.height, lessThanOrEqualTo(maxH + 0.5));
          if (find.byKey(const ValueKey<String>('paw_fit_or_scroll_scroll')).evaluate().isEmpty) {
            // Rétrécie ou à l'aise : le bouton « Modifier » est ENTIER au-dessus
            // du trait de l'action du rôle.
            final edit = t.getRect(find.byKey(const ValueKey<String>('customize')));
            final trait = t.getRect(find.byKey(const ValueKey<String>('pawmap_capsule_trait')));
            expect(edit.bottom, lessThanOrEqualTo(trait.top + 0.5),
                reason: 'Modifier coupé par Publier');
          }
        });
      }
    }
  }

  for (final s in _screens) {
    testWidgets('barre de gauche ${s.width.toInt()}×${s.height.toInt()} : 10 boutons entiers', (t) async {
      t.view.physicalSize = s;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final maxH = s.height - 300;
      await t.pumpWidget(_app(
          s,
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: PawFitOrScroll(
              reverse: true,
              alignment: Alignment.bottomCenter,
              child: PawMapRail(
                order: kPawRailDefaultOrder,
                onTap: (_) {},
                onLongPress: (_) {},
                onCustomize: () {},
                gap: 0,
              ),
            ),
          )));
      await t.pump();
      await t.pump();
      expect(t.takeException(), isNull);
      expect(kPawRailDefaultOrder.length, 9 + 0, reason: '9 bijoux + Modifier = 10 boutons');
      final box = t.getRect(find.byType(PawFitOrScroll));
      expect(box.height, lessThanOrEqualTo(maxH + 0.5));
      if (find.byKey(const ValueKey<String>('paw_fit_or_scroll_scroll')).evaluate().isEmpty) {
        for (final id in kPawRailDefaultOrder) {
          final r = t.getRect(find.byKey(ValueKey<String>('rail_$id')));
          expect(r.top, greaterThanOrEqualTo(box.top - 0.5), reason: '$id coupé en haut');
          expect(r.bottom, lessThanOrEqualTo(box.bottom + 0.5), reason: '$id coupé en bas');
        }
      }
    });
  }
}
