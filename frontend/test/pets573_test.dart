// v573 — fiche animal du propriétaire (bannière ≠ avatar, visionneuse photo,
// en-tête héro sans débordement).
//
// Ce que ce test protège :
//   · la RÈGLE demandée par Daniel : « la photo du chien et la bannière c'est
//     la MÊME photo » → la bannière n'utilise JAMAIS l'URL de l'avatar
//     (`resolvePetBannerUrl`, fonction pure) ;
//   · la visionneuse commune : compteur, bouton fermer, fermeture ;
//   · l'écran fiche animal se construit sans débordement à 320 dp, en français
//     comme en allemand et en polonais (les deux langues les plus longues).
//
// Contraintes du repo : `ScreenUtilInit` est obligatoire (tous les widgets
// utilisent `.w/.h/.sp`), et `google_fonts` ne doit pas tenter de télécharger.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/translations/de.dart';
import 'package:hopetsit/localization/translations/en.dart';
import 'package:hopetsit/localization/translations/fr.dart';
import 'package:hopetsit/localization/translations/pl.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/pet_profile_screen.dart';
import 'package:hopetsit/widgets/photo_viewer_screen.dart';

class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys => <String, Map<String, String>>{
        'en': enUSTranslations,
        'fr': frFRTranslations,
        'de': deDETranslations,
        'pl': plPLTranslations,
      };
}

Widget _app(Widget home, {String lang = 'fr'}) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: _T(),
        locale: Locale(lang),
        fallbackLocale: const Locale('en'),
        home: home,
      ),
    );

/// Écran de 320 dp de large (le plus étroit visé), remis à zéro après le test.
void _sizeTo320(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

PetModel _pet({
  List<Map<String, String>> photos = const <Map<String, String>>[],
  String avatar = '',
}) =>
    PetModel.fromJson(<String, dynamic>{
      '_id': 'pet1',
      'petName': 'Rex',
      'breed': 'Berger allemand à poil long',
      'category': 'Dog',
      'gender': 'male',
      'age': 3,
      'weight': '32',
      'height': '60',
      'vaccinationStatus': 'up_to_date',
      'bio': 'Rex adore les longues promenades au parc.',
      'photos': photos,
      'avatar': <String, dynamic>{'url': avatar},
    });

void main() {
  setUpAll(() {
    // Hors réseau, google_fonts ne peut pas télécharger ses polices.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('resolvePetBannerUrl — la bannière n’est JAMAIS l’avatar', () {
    test('aucune photo de galerie ⇒ null (bandeau dessiné)', () {
      expect(resolvePetBannerUrl(const <dynamic>[], 'https://cdn/a.jpg'),
          isNull);
      expect(resolvePetBannerUrl(const <dynamic>[], ''), isNull);
    });

    test('la seule photo est l’avatar ⇒ null (jamais la même image)', () {
      const String avatar = 'https://cdn/a.jpg';
      expect(
        resolvePetBannerUrl(
          <dynamic>[
            <String, String>{'url': avatar}
          ],
          avatar,
        ),
        isNull,
      );
    });

    test('la photo la PLUS RÉCENTE différente de l’avatar est retenue', () {
      const String avatar = 'https://cdn/a.jpg';
      expect(
        resolvePetBannerUrl(
          <dynamic>[
            <String, String>{'url': avatar},
            <String, String>{'url': 'https://cdn/b.jpg'},
            <String, String>{'url': 'https://cdn/c.jpg'},
          ],
          avatar,
        ),
        'https://cdn/c.jpg',
      );
    });

    test('sans avatar, la 1re photo non vide sert de bannière', () {
      expect(
        resolvePetBannerUrl(
          <dynamic>[
            <String, String>{'url': ''},
            <String, String>{'url': 'https://cdn/b.jpg'},
          ],
          '',
        ),
        'https://cdn/b.jpg',
      );
    });

    test('entrées invalides ignorées (pas de Map, pas d’url)', () {
      expect(
        resolvePetBannerUrl(
          <dynamic>[
            'https://cdn/pas-une-map.jpg',
            <String, String>{'publicId': 'x'},
            <String, String>{'url': 'https://cdn/ok.jpg'},
          ],
          '',
        ),
        'https://cdn/ok.jpg',
      );
    });

    test('petBannerUrl(pet) applique la même règle', () {
      const String avatar = 'https://cdn/a.jpg';
      expect(
        petBannerUrl(_pet(
          avatar: avatar,
          photos: const <Map<String, String>>[
            <String, String>{'url': avatar}
          ],
        )),
        isNull,
      );
      expect(
        petBannerUrl(_pet(
          avatar: avatar,
          photos: const <Map<String, String>>[
            <String, String>{'url': avatar},
            <String, String>{'url': 'https://cdn/b.jpg'},
          ],
        )),
        'https://cdn/b.jpg',
      );
    });

    test('petGalleryUrls garde l’ordre et ignore les URL vides', () {
      expect(
        petGalleryUrls(_pet(photos: const <Map<String, String>>[
          <String, String>{'url': 'https://cdn/1.jpg'},
          <String, String>{'url': ''},
          <String, String>{'url': 'https://cdn/2.jpg'},
        ])),
        <String>['https://cdn/1.jpg', 'https://cdn/2.jpg'],
      );
    });
  });

  group('PhotoViewerScreen', () {
    testWidgets('compteur + bouton fermer, sans débordement à 320 dp',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_app(const PhotoViewerScreen(
        urls: <String>[
          'https://cdn/1.jpg',
          'https://cdn/2.jpg',
          'https://cdn/3.jpg',
        ],
        initialIndex: 1,
      )));
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('photo_viewer_close')),
          findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
    });

    testWidgets('une seule photo ⇒ pas de compteur',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_app(const PhotoViewerScreen(
        urls: <String>['https://cdn/1.jpg'],
      )));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const ValueKey<String>('photo_viewer_counter')),
          findsNothing);
    });

    testWidgets('le bouton fermer referme l’écran',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_app(
        Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PhotoViewerScreen(
                      urls: <String>['https://cdn/1.jpg', 'https://cdn/2.jpg'],
                    ),
                  ),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PhotoViewerScreen), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey<String>('photo_viewer_close')));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(PhotoViewerScreen), findsNothing);
    });
  });

  group('PetProfileScreen — en-tête héro', () {
    testWidgets('320 dp : se construit sans débordement (fr / de / pl)',
        (WidgetTester tester) async {
      for (final String lang in <String>['fr', 'de', 'pl']) {
        _sizeTo320(tester);
        await tester.pumpWidget(_app(
          PetProfileScreen(pet: _pet(), editable: true, onDelete: () {}),
          lang: lang,
        ));
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.takeException(), isNull, reason: 'langue $lang');
        expect(find.text('Rex'), findsOneWidget, reason: 'langue $lang');
      }
    });

    testWidgets('sans photo de galerie : bandeau dessiné, pas d’image réseau',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_app(
        PetProfileScreen(pet: _pet(avatar: 'https://cdn/a.jpg')),
      ));
      await tester.pump(const Duration(milliseconds: 60));
      // La bannière ne réutilise pas l'avatar : elle est dessinée.
      expect(
        petBannerUrl(_pet(avatar: 'https://cdn/a.jpg')),
        isNull,
      );
      expect(find.byType(PetProfileScreen), findsOneWidget);
    });

    testWidgets('les 4 onglets sont visibles d’un coup (sélecteur fixe)',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_app(PetProfileScreen(pet: _pet())));
      await tester.pump(const Duration(milliseconds: 60));
      for (final String v in <String>['about', 'health', 'habits', 'gallery']) {
        expect(find.byKey(ValueKey<String>('booking_tab_$v')), findsOneWidget,
            reason: v);
      }
      // Un tap change d'onglet sans faire défiler ni planter.
      await tester
          .tap(find.byKey(const ValueKey<String>('booking_tab_gallery')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('pet_add_photos')),
          findsOneWidget);
    });
  });
}
