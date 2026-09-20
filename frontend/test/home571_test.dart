// v571 — accueil gardien / promeneur : carte « Autour de moi » redessinée et
// kit d'état vide.
//
// Ce test monte les deux widgets SEULS sur un écran étroit (320 dp, le plus
// petit que Daniel puisse avoir en main) et vérifie :
//   · la carte « Autour de moi » se construit sans débordement, y compris avec
//     une ville très longue et les libellés allemands/polonais ;
//   · un tap sur la pastille de ville appelle bien `onTapCity` ;
//   · le kit d'état vide affiche ses 3 cartes d'action + « Rafraîchir » et
//     chaque tap déclenche le bon callback.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/v565/home571_i18n.dart';
import 'package:hopetsit/views/shared/widgets/around_me_search_bar.dart';
import 'package:hopetsit/views/shared/widgets/home_empty_kit.dart';

const Color _kSitterAccent = Color(0xFF2563EB);

/// Traductions réelles du lot (permet de vérifier au passage que les clés
/// existent dans la langue testée).
class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys => home571I18n;
}

Widget _harness(Widget child, {String lang = 'fr'}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: _T(),
      locale: Locale(lang),
      fallbackLocale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
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

void main() {
  setUpAll(() {
    // Hors réseau, google_fonts ne peut pas télécharger ses polices : on coupe
    // la récupération, la police par défaut prend le relais.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AroundMeSearchBar', () {
    testWidgets('320 dp : se construit sans débordement', (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(AroundMeSearchBar(
        accent: _kSitterAccent,
        cityLabel: 'Villeneuve-Saint-Georges, France',
        radiusKm: 50,
        minRadiusKm: 50,
        maxRadiusKm: 500,
        onTapCity: () {},
        onRadiusChanged: (_) {},
        onRadiusCommit: (_) {},
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byType(AroundMeSearchBar), findsOneWidget);
      expect(find.text('50 km'), findsWidgets);
      expect(find.text('Villeneuve-Saint-Georges, France'), findsOneWidget);
      expect(find.text('Changer'), findsOneWidget);
    });

    testWidgets('320 dp : libellés longs (de / pl) sans débordement',
        (tester) async {
      for (final String lang in <String>['de', 'pl']) {
        _sizeTo320(tester);
        await tester.pumpWidget(_harness(
          AroundMeSearchBar(
            accent: _kSitterAccent,
            cityLabel:
                'Mönchengladbach-Rheydt, Nordrhein-Westfalen, Deutschland',
            radiusKm: 500,
            minRadiusKm: 50,
            maxRadiusKm: 500,
            onTapCity: () {},
            onRadiusChanged: (_) {},
            onRadiusCommit: (_) {},
          ),
          lang: lang,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: 'langue $lang');
      }
    });

    testWidgets('un tap sur la ville appelle onTapCity', (tester) async {
      _sizeTo320(tester);
      int taps = 0;
      await tester.pumpWidget(_harness(AroundMeSearchBar(
        accent: _kSitterAccent,
        cityLabel: 'Paris, France',
        radiusKm: 120,
        minRadiusKm: 50,
        maxRadiusKm: 500,
        onTapCity: () => taps++,
        onRadiusChanged: (_) {},
        onRadiusCommit: (_) {},
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(
        find.byKey(const ValueKey<String>('around_me_city_button')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, 1);
    });
  });

  group('HomeEmptyKit', () {
    testWidgets('affiche ses cartes et le tap les déclenche', (tester) async {
      _sizeTo320(tester);
      final List<String> hits = <String>[];
      await tester.pumpWidget(_harness(HomeEmptyKit(
        accent: _kSitterAccent,
        onRefresh: () => hits.add('refresh'),
        onCompleteProfile: () => hits.add('profile'),
        onInvite: () => hits.add('invite'),
        onBoost: () => hits.add('boost'),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      // Titre + texte rassurant.
      expect(find.text('C’est calme autour de toi pour l’instant'),
          findsOneWidget);
      // Les 3 cartes d'action + le bouton Rafraîchir.
      for (final String k in <String>[
        'home_empty_profile',
        'home_empty_invite',
        'home_empty_boost',
        'home_empty_refresh',
      ]) {
        expect(find.byKey(ValueKey<String>(k)), findsOneWidget, reason: k);
      }

      await tester.tap(
        find.byKey(const ValueKey<String>('home_empty_profile')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('home_empty_invite')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('home_empty_boost')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('home_empty_refresh')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(hits, <String>['profile', 'invite', 'boost', 'refresh']);
    });

    testWidgets('une action sans callback n\'est pas affichée',
        (tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(HomeEmptyKit(
        accent: _kSitterAccent,
        onRefresh: () {},
        onCompleteProfile: () {},
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey<String>('home_empty_profile')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('home_empty_invite')),
          findsNothing);
      expect(find.byKey(const ValueKey<String>('home_empty_boost')),
          findsNothing);
    });
  });

  group('HomeRadiusHintCard', () {
    testWidgets('bouton « Élargir » présent puis masqué au maximum',
        (tester) async {
      _sizeTo320(tester);
      int expands = 0;
      await tester.pumpWidget(_harness(HomeRadiusHintCard(
        accent: _kSitterAccent,
        currentKm: 50,
        suggestedKm: 90,
        onExpand: () => expands++,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('Rien dans un rayon de 50 km'), findsOneWidget);
      expect(find.text('Élargir à 90 km'), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey<String>('home_expand_radius')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(expands, 1);

      // Rayon déjà au maximum : la carte reste informative, sans bouton.
      await tester.pumpWidget(_harness(const HomeRadiusHintCard(
        accent: _kSitterAccent,
        currentKm: 500,
        suggestedKm: 500,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey<String>('home_expand_radius')),
          findsNothing);
    });
  });
}
