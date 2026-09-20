// v573 — fiches de profil public (gardien / promeneur / propriétaire vus
// depuis une annonce).
//
// Ce test monte les widgets du kit SEULS — aucun contrôleur, aucun réseau — et
// vérifie, à 320 dp (le plus petit écran visé) en thème CLAIR et SOMBRE :
//   · l'en-tête héro, la rangée de 3 tuiles, une carte de section et la barre
//     d'action collante se construisent sans le moindre débordement, y compris
//     avec les libellés allemands et polonais (les plus longs) ;
//   · un tap sur l'action principale de la barre du bas déclenche bien son
//     callback ;
//   · l'avatar sans photo affiche l'initiale (et JAMAIS une image de
//     catalogue) ;
//   · le squelette de chargement et l'état d'erreur se construisent aussi.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/v565/profiles573_i18n.dart';
import 'package:hopetsit/views/service_provider/widgets/public_profile_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// Quelques clés déjà existantes dont le kit se sert (pastille de rôle, badge
/// vérifié) : on les fournit pour que le rendu testé soit celui de production.
const Map<String, Map<String, String>> _extraKeys = <String, Map<String, String>>{
  'fr': <String, String>{
    'role_sitter': 'Gardien',
    'kyc_badge_verified': 'Vérifié',
  },
  'en': <String, String>{
    'role_sitter': 'Sitter',
    'kyc_badge_verified': 'Verified',
  },
  'de': <String, String>{
    'role_sitter': 'Tierbetreuer',
    'kyc_badge_verified': 'Verifiziert',
  },
  'pl': <String, String>{
    'role_sitter': 'Opiekun',
    'kyc_badge_verified': 'Zweryfikowany',
  },
};

class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final Map<String, Map<String, String>> merged =
        <String, Map<String, String>>{};
    profiles573I18n.forEach((String lang, Map<String, String> m) {
      merged[lang] = Map<String, String>.of(m);
    });
    _extraKeys.forEach((String lang, Map<String, String> m) {
      (merged[lang] ??= <String, String>{}).addAll(m);
    });
    return merged;
  }
}

/// Écran de 320 dp de large (le plus étroit visé), remis à zéro après le test.
void _sizeTo320(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _harness(
  Widget home, {
  String lang = 'fr',
  Brightness brightness = Brightness.light,
}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: _T(),
      locale: Locale(lang),
      fallbackLocale: const Locale('en'),
      theme: ThemeData(brightness: brightness),
      home: home,
    ),
  );
}

/// Reproduit EXACTEMENT la structure d'une fiche publique : en-tête héro,
/// rangée de stats, cartes de section, barre d'action collante.
Widget _profilePage({
  required VoidCallback onMainAction,
  String name = 'Jean-Baptiste de la Tour-Maubourg',
  String? imageUrl,
  bool verified = true,
}) {
  const PublicProfilePalette palette = kSitterProfilePalette;
  return Scaffold(
    appBar: publicProfileAppBar(
      palette: palette,
      title: PoppinsText(
        text: name,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: <Widget>[
        PublicProfileBannerAction(
          icon: Icons.ios_share_rounded,
          tooltip: 'share',
          onTap: () {},
        ),
        PublicProfileBannerAction(
          icon: Icons.flag_outlined,
          tooltip: 'report',
          onTap: () {},
        ),
      ],
    ),
    body: Column(
      children: <Widget>[
        Expanded(
          child: PublicProfileBackground(
            accent: palette.accent,
            child: Builder(
              builder: (BuildContext context) => SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: publicProfileBottomPadding(
                    context,
                    hasActionBar: true,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PublicProfileHero(
                      palette: palette,
                      role: 'sitter',
                      name: name,
                      imageUrl: imageUrl,
                      verified: verified,
                      statusChip: const PublicProfileStatusPill(
                        icon: Icons.check_circle_rounded,
                        label: 'Disponible',
                        tone: Color(0xFF16A34A),
                      ),
                      location: 'Villeneuve-Saint-Georges, Île-de-France',
                      rating: null,
                    ),
                    SizedBox(height: 18.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          PublicProfileStatsRow(
                            accent: palette.accent,
                            stats: <PublicProfileStat>[
                              PublicProfileStat(
                                icon: Icons.star_rounded,
                                value: '4.8',
                                label: 'profiles573_stat_rating'.tr,
                              ),
                              PublicProfileStat(
                                icon: Icons.reviews_rounded,
                                value: '128',
                                label: 'profiles573_stat_reviews'.tr,
                              ),
                              PublicProfileStat(
                                icon: Icons.verified_user_rounded,
                                value: '42',
                                label: 'profiles573_stat_services'.tr,
                              ),
                            ],
                          ),
                          SizedBox(height: 14.h),
                          PublicProfileSection(
                            accent: palette.accent,
                            icon: Icons.payments_rounded,
                            title: 'Disponibilités et tarifs',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                PublicProfileRateRow(
                                  label: 'Prix par jour de garde à domicile',
                                  value: '1 250,00 €',
                                  accent: palette.accent,
                                ),
                                PublicProfileEmptyLine(
                                  text: 'profiles573_no_rates'.tr,
                                ),
                                SizedBox(height: 10.h),
                                Wrap(
                                  spacing: 8.w,
                                  runSpacing: 8.h,
                                  children: <Widget>[
                                    PublicProfileTag(
                                      label: 'Hundebetreuung zu Hause',
                                      accent: palette.accent,
                                    ),
                                    PublicProfileTag(
                                      label: 'Wyprowadzanie psów',
                                      accent: palette.accent,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                PublicProfileReviewCard(
                                  name: 'Marie-Christine',
                                  rating: 4.5,
                                  comment: 'Très bien passé, je recommande.',
                                  date: '12/03/2026',
                                  accent: palette.accent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        PublicProfileActionBar(
          secondary: <Widget>[
            PublicProfileRoundAction(
              icon: Icons.ios_share_rounded,
              tooltip: 'share',
              accent: palette.accent,
              onTap: () {},
            ),
          ],
          child: CustomButton(
            key: const ValueKey<String>('profiles573_main_action'),
            title: 'Démarrer le chat',
            bgColor: palette.accent,
            onTap: onMainAction,
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(() {
    // Hors réseau, google_fonts ne peut pas télécharger ses polices : on coupe
    // la récupération, la police par défaut prend le relais.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Fiche de profil public', () {
    testWidgets('320 dp, clair et sombre, fr/de/pl : aucun débordement',
        (WidgetTester tester) async {
      for (final Brightness b in <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        for (final String lang in <String>['fr', 'de', 'pl']) {
          _sizeTo320(tester);
          await tester.pumpWidget(_harness(
            _profilePage(onMainAction: () {}),
            lang: lang,
            brightness: b,
          ));
          await tester.pump(const Duration(milliseconds: 60));
          expect(tester.takeException(), isNull, reason: '$b / $lang');

          // Les 4 briques de la structure commune sont bien là.
          expect(find.byType(PublicProfileHero), findsOneWidget);
          expect(find.byType(PublicProfileStatsRow), findsOneWidget);
          expect(find.byType(PublicProfileSection), findsOneWidget);
          expect(find.byType(PublicProfileActionBar), findsOneWidget);
        }
      }
    });

    testWidgets('sans photo : initiale du nom, aucune image de catalogue',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(
        _profilePage(onMainAction: () {}, name: 'Sophie Marchand'),
      ));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      // L'avatar du héro retombe sur l'initiale…
      expect(find.text('S'), findsOneWidget);
      // …et aucune image d'asset n'est affichée sur la page.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('tap sur l\'action principale de la barre du bas',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      int taps = 0;
      await tester.pumpWidget(_harness(
        _profilePage(onMainAction: () => taps++),
      ));
      await tester.pump(const Duration(milliseconds: 60));
      // `warnIfMissed: false` : `CustomButton` s'ouvre sur un `AnimatedScale`
      // (RenderTransform), que le contrôleur de test ne reconnaît pas comme
      // cible du hit-test alors que le tap atteint bien l'InkWell — c'est le
      // compteur ci-dessous qui fait foi.
      await tester.tap(
        find.byKey(const ValueKey<String>('profiles573_main_action')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('les tuiles de stats affichent valeurs et libellés traduits',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(_harness(_profilePage(onMainAction: () {})));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Avis'), findsOneWidget);
      expect(find.text('Prestations'), findsOneWidget);
    });
  });

  group('États chargement / erreur', () {
    testWidgets('squelette : clair et sombre, sans exception',
        (WidgetTester tester) async {
      for (final Brightness b in <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        _sizeTo320(tester);
        await tester.pumpWidget(_harness(
          const Scaffold(
            body: PublicProfileSkeleton(palette: kSitterProfilePalette),
          ),
          brightness: b,
        ));
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.takeException(), isNull, reason: '$b');
        expect(find.byType(PublicProfileSkeleton), findsOneWidget);
      }
    });

    testWidgets('erreur : message + bouton Réessayer qui rappelle',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      int retries = 0;
      await tester.pumpWidget(_harness(
        Scaffold(
          body: PublicProfileErrorView(
            accent: kWalkerProfilePalette.accent,
            message: 'Impossible de charger ce profil pour le moment.',
            actionLabel: 'Réessayer',
            onRetry: () => retries++,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      expect(find.text('Réessayer'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(retries, 1);
    });
  });
}
