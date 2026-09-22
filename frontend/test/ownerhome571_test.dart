// v571 — widgets de présentation de l'accueil PROPRIÉTAIRE
// (`lib/views/pet_owner/home/widgets/owner_home_kit.dart`).
//
// Ce que ces tests garantissent, à 320 dp (le plus petit écran visé) :
//   · les 2 grandes cartes d'action se construisent SANS débordement, en
//     version haute comme en version basse, et chaque tap rappelle le bon
//     callback ;
//   · le bandeau de confiance ne déborde jamais, même avec les libellés
//     allemands et polonais (les plus longs des 9 langues) ;
//   · la carte « Publie ta première annonce » affiche ses 3 étapes et son
//     unique bouton, et ce bouton appelle bien l'action de publication.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/owner_home_kit.dart';

/// Écran de 320 dp de large, remis à zéro après le test.
void _sizeTo320(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _harness(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    // Hors réseau (CI / machine sans accès), google_fonts ne peut pas
    // télécharger ses polices : on coupe la récupération, la police par
    // défaut prend le relais. Aucun impact sur le code de prod.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('cartes d\'action', () {
    testWidgets('les 2 cartes tiennent à 320 dp (version haute)',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(
        OwnerActionCards(
          sittingTitle: 'Mein Tier betreuen lassen',
          walkingTitle: 'Meinen Hund ausführen lassen',
          onSitting: () {},
          onWalking: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(OwnerActionCard), findsNWidgets(2));
    });

    testWidgets('les 2 cartes tiennent à 320 dp (version basse)',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(
        OwnerActionCards(
          compact: true,
          sittingTitle: 'Zleć opiekę nad zwierzakiem',
          walkingTitle: 'Zleć spacer z psem',
          onSitting: () {},
          onWalking: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // La variante basse fait bien ~56 dp de haut (et pas 112).
      final Size size = tester.getSize(
        find.byKey(const ValueKey<String>('owner_action_sitting')),
      );
      expect(size.height, lessThan(80));
    });

    testWidgets('chaque carte rappelle son propre callback',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      int sitting = 0;
      int walking = 0;
      await tester.pumpWidget(_harness(
        OwnerActionCards(
          sittingTitle: 'Faire garder mon animal',
          walkingTitle: 'Faire promener mon chien',
          onSitting: () => sitting++,
          onWalking: () => walking++,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('owner_action_sitting')),
      );
      await tester.pumpAndSettle();
      expect(sitting, 1);
      expect(walking, 0);

      await tester.tap(
        find.byKey(const ValueKey<String>('owner_action_walking')),
      );
      await tester.pumpAndSettle();
      expect(sitting, 1);
      expect(walking, 1);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('bandeau de confiance : aucun débordement à 320 dp',
      (WidgetTester tester) async {
    _sizeTo320(tester);
    await tester.pumpWidget(_harness(
      const OwnerTrustRow(
        items: <OwnerTrustItem>[
          // Les libellés les plus longs des 9 langues (de / pl).
          OwnerTrustItem(icon: Icons.lock_rounded, label: 'Sichere Zahlung'),
          OwnerTrustItem(
            icon: Icons.verified_user_rounded,
            label: 'Zweryfikowana tożsamość',
          ),
          OwnerTrustItem(
            icon: Icons.undo_rounded,
            label: '72 h kostenlos stornierbar',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('owner_trust_row')),
      findsOneWidget,
    );
    // Le bandeau reste dans la largeur disponible (320 − 2 × 16).
    final Size size = tester.getSize(
      find.byKey(const ValueKey<String>('owner_trust_row')),
    );
    expect(size.width, lessThanOrEqualTo(288.0));
  });

  testWidgets('carte « première annonce » : 3 étapes + 1 bouton',
      (WidgetTester tester) async {
    _sizeTo320(tester);
    int published = 0;
    await tester.pumpWidget(_harness(
      OwnerFirstPostCard(
        title: 'Publie ta première annonce en 1 minute',
        steps: const <String>[
          'Tu publies ton annonce',
          'Les gardiens autour de toi te font une offre',
          'Tu paies en toute sécurité',
        ],
        ctaLabel: 'Publier mon annonce',
        onCta: () => published++,
      ),
    ));
    // v580 — le mégaphone de la carte est ANIMÉ en boucle : `pumpAndSettle`
    // attendrait la fin d'une animation qui ne s'arrête jamais et finirait en
    // délai dépassé. On avance donc d'un temps fixe, ce qui vérifie la même
    // chose (rendu complet, aucune exception).
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    expect(find.text('Publie ta première annonce en 1 minute'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Tu paies en toute sécurité'), findsOneWidget);

    await tester.tap(find.text('Publier mon annonce'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(published, 1);
  });
}
