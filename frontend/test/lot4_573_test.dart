// v573 — lot 4 : fiche animal (vue prestataire) et visionneuse photo.
//
// Ce que ce test protège, dans l'ordre d'importance :
//
//  1. `PetDetailScreen` n'affiche PLUS `AppImages.placeholderImage` quand la
//     photo de l'animal manque ou échoue. C'était une illustration marketing
//     de la boutique présentée comme la photo réelle de l'animal. Le repli est
//     désormais un aplat neutre + une patte teintée, et il n'y a AUCUN
//     `Image.asset` dans l'arbre d'une fiche sans photo.
//  2. La page ne déborde pas à 320 dp, avec des valeurs volontairement longues
//     (allemand / polonais) dans toutes les sections.
//  3. Le mode sombre se peint sans exception.
//  4. La visionneuse commune `PhotoViewerScreen` affiche son bouton fermer
//     rond et son compteur « 1 / 3 » (c'est elle que la carte d'annonce ouvre
//     désormais, à la place d'un `Scaffold` noir coiffé d'une `AppBar` noire).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_detail_screen.dart';
import 'package:hopetsit/widgets/photo_viewer_screen.dart';

Widget _harness(Widget child, {Brightness brightness = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      theme: ThemeData(brightness: brightness),
      home: child,
    ),
  );
}

/// Écran de 320 dp de large (le plus étroit visé), remis à zéro après le test.
void _sizeTo320(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Fiche animal SANS aucune photo : c'est le cas qui affichait l'illustration
/// marketing. Valeurs longues = allemand / polonais.
PetDetailScreen _petWithoutPhotos() => const PetDetailScreen(
      petName: 'Bartholomäus',
      breed: 'Berner Sennenhund',
      age: '3 Jahre',
      gender: 'male',
      weight: '42 kg',
      height: '68 cm',
      description:
          'Sehr freundlicher Hund, braucht lange Spaziergänge am Morgen und '
          'am Abend. Verträgt sich gut mit anderen Hunden.',
      vaccinations: <String>['up to date', 'partial'],
      galleryImages: <String>[],
      petImages: <String>[],
      ownerName: 'Krzysztof Wiśniewski',
      ownerCity: 'Warszawa-Śródmieście',
      passportNumber: 'PL-2026-0001',
      chipNumber: '981098106123456',
      medicationAllergies: 'Keine bekannten Allergien',
      category: 'dog',
    );

void main() {
  setUpAll(() {
    // Hors réseau, google_fonts ne peut pas télécharger ses polices : on coupe
    // la récupération, la police par défaut prend le relais.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PetDetailScreen — plus d’image marketing en repli', () {
    testWidgets('fiche sans photo : aucun Image.asset dans l’arbre',
        (tester) async {
      await tester.pumpWidget(_harness(_petWithoutPhotos()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PetDetailScreen), findsOneWidget);
      // Le repli est un aplat + une patte : aucune image d’asset.
      expect(find.byType(Image), findsNothing);
      // La patte teintée est bien là (hero + section galerie vide).
      expect(find.byIcon(Icons.pets_rounded), findsWidgets);
      // Plus aucun spinner nu : le chargement d’une photo respire.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('320 dp + textes longs : aucun débordement', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(_petWithoutPhotos()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mode sombre : se peint sans exception', (tester) async {
      await tester.pumpWidget(
        _harness(_petWithoutPhotos(), brightness: Brightness.dark),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('PhotoViewerScreen — visionneuse commune', () {
    testWidgets('bouton fermer rond + compteur « 1 / 3 »', (tester) async {
      await tester.pumpWidget(
        _harness(
          const PhotoViewerScreen(
            urls: <String>[
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
              'https://example.com/c.jpg',
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Plus d’AppBar noire sur fond noir.
      expect(find.byType(AppBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('photo_viewer_close')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('photo_viewer_counter')),
        findsOneWidget,
      );
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('une seule photo : pas de compteur', (tester) async {
      await tester.pumpWidget(
        _harness(
          const PhotoViewerScreen(urls: <String>['https://example.com/a.jpg']),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const ValueKey<String>('photo_viewer_counter')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('photo_viewer_close')),
        findsOneWidget,
      );
    });
  });
}
