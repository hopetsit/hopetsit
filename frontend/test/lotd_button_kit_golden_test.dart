// v585 (lot D) — image de référence du KIT DE BOUTONS signature
// (NORME_DESIGN.md) : principal / secondaire / lien / produit / danger, avec
// prix, désactivé, chargement, compact, en clair ET en sombre, pour les 3
// rôles. Un build qui casse l'habillage échoue ici. Régénérer après un
// changement VOULU : `flutter test test/lotd_button_kit_golden_test.dart
// --update-goldens` puis RELIRE `test/goldens/buttons/*.png`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

const _owner = Color(0xFFC92A12);
const _sitter = Color(0xFF2563EB);
const _walker = Color(0xFF16A34A);

Widget _sheet(Brightness b) {
  Widget col(Color role, String name) => SizedBox(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PawButton(label: 'Réserver Léa', price: '25 €', color: role, icon: PawIcon.paw, onTap: () {}, action: PawButtonAction.book, earns: true),
            const SizedBox(height: 8),
            PawButton(label: 'Proposer mes services', color: role, icon: PawIcon.house, kind: PawButtonKind.secondary, onTap: () {}),
            const SizedBox(height: 8),
            PawButton(label: 'Voir le profil', color: role, icon: PawIcon.user, kind: PawButtonKind.link, onTap: () {}),
            const SizedBox(height: 8),
            PawButton(label: 'Publier ma demande', color: role, icon: PawIcon.send, onTap: null, enabled: false),
            const SizedBox(height: 8),
            PawButton(label: 'Envoi en cours', color: role, icon: PawIcon.send, onTap: () {}, loading: true),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: PawButton(label: 'Accepter', color: role, icon: PawIcon.check, onTap: () {}, compact: true)),
              const SizedBox(width: 8),
              Expanded(child: PawButton(label: 'Refuser', color: role, icon: PawIcon.close, onTap: () {}, compact: true, kind: PawButtonKind.secondary)),
            ]),
            const SizedBox(height: 8),
            PawButton(label: 'Supprimer mon compte', color: role, icon: PawIcon.trash, kind: PawButtonKind.danger, onTap: () {}),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              PawRoundButton(icon: PawIcon.locate, tooltip: 'Ma position', color: role, onTap: () {}),
              PawChoicePill(label: 'Gardiens', selected: true, color: role, icon: PawIcon.house, onTap: () {}),
              PawChoicePill(label: 'Promeneurs', selected: false, color: role, icon: PawIcon.walker, onTap: () {}),
            ]),
          ],
        ),
      );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: b, useMaterial3: true),
    home: ScreenUtilInit(
      designSize: const Size(1100, 620),
      builder: (_, __) => Scaffold(
        backgroundColor: b == Brightness.dark ? const Color(0xFF241916) : const Color(0xFFFFF1EC),
        body: RepaintBoundary(
          key: const ValueKey('kit'),
          child: Container(
            color: b == Brightness.dark ? const Color(0xFF241916) : const Color(0xFFFFF1EC),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                col(_owner, 'owner'),
                const SizedBox(width: 12),
                col(_sitter, 'sitter'),
                const SizedBox(width: 12),
                col(_walker, 'walker'),
                const SizedBox(width: 12),
                SizedBox(
                  width: 250,
                  child: Column(children: [
                    PawButton(label: 'Activer PawFollow', price: '4,99 €', color: PawProductColors.pawFollow, icon: PawIcon.route, kind: PawButtonKind.product, onTap: () {}),
                    const SizedBox(height: 8),
                    PawButton(label: 'Booster mon profil', color: PawProductColors.pawBoost, icon: PawIcon.rocket, kind: PawButtonKind.product, onTap: () {}),
                    const SizedBox(height: 8),
                    PawButton(label: 'Passer Premium', price: '9,99 €', color: PawProductColors.premiumInk, textColor: PawProductColors.premiumGold, icon: PawIcon.crown, kind: PawButtonKind.product, onTap: () {}),
                    const SizedBox(height: 8),
                    const PawButton(label: 'Meine Dienstleistungen anbieten', color: _sitter, icon: PawIcon.house, onTap: null, enabled: true),
                    const SizedBox(height: 8),
                    const PawButton(label: 'Zaproponuj swoje usługi teraz', color: _walker, icon: PawIcon.walker, kind: PawButtonKind.secondary, onTap: null, enabled: true),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    // Police EMBARQUÉE (assets/fonts/Poppins-Bold.ttf) chargée sous le nom
    // que google_fonts utilise : rendu identique seul ou dans la suite.
    GoogleFonts.config.allowRuntimeFetching = false;
    final fam = GoogleFonts.poppins(fontWeight: FontWeight.w700).fontFamily!;
    final loader = FontLoader(fam)..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await loader.load();
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('kit de boutons — ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(1100, 620);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_sheet(b));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('kit')),
        matchesGoldenFile('goldens/buttons/kit_${b.name}.png'),
      );
    });
  }

  testWidgets('un tap imprime une empreinte et appelle l’action une seule fois pendant le chargement', (tester) async {
    int calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: ScreenUtilInit(
        designSize: const Size(800, 600),
        builder: (_, __) => Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: PawButton(
                label: 'Envoyer',
                color: _owner,
                icon: PawIcon.send,
                action: PawButtonAction.send,
                onTap: () async {
                  calls++;
                  await Future<void>.delayed(const Duration(milliseconds: 300));
                },
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byType(PawButton));
    await tester.pump(const Duration(milliseconds: 50));
    // Pendant le chargement : rond de progression dans le bouton, libellé conservé.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Envoyer'), findsOneWidget);
    await tester.tap(find.byType(PawButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1, reason: 'pas de double envoi');
    // Succès : coche pendant 1 s puis retour.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('désactivé : teinte pâle, message quand on appuie quand même', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ScreenUtilInit(
        designSize: const Size(800, 600),
        builder: (_, __) => Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: PawButton(
                label: 'Payer',
                color: _owner,
                enabled: false,
                disabledReason: 'Ajoute une carte d’abord',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byType(PawButton));
    await tester.pump();
    expect(find.text('Ajoute une carte d’abord'), findsOneWidget);
    // La coque désactivée est PLEINE (pas d'opacité) et pâle.
    final container = tester.widget<Container>(find.descendant(
        of: find.byType(PawButton), matching: find.byType(Container)).first);
    final deco = container.decoration as BoxDecoration;
    expect(deco.gradient, isNull);
    final c = deco.color!;
    final hsl = HSLColor.fromColor(c);
    expect(hsl.saturation, greaterThan(0.25), reason: 'jamais gris');
    expect(hsl.lightness, greaterThan(0.85), reason: 'pâle');
  });
}
