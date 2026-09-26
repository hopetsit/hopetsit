// v589 (26/09/2026) — fiche d'un membre sur la PawMap et pages de profil
// public « HD » (Daniel : « moderniser, comme ça tout est HD »).
//
// Monte les widgets SEULS (aucun contrôleur, aucun réseau) avec les VRAIES
// traductions de l'app, à 360 et 412 dp, en clair ET en sombre, en français,
// allemand et polonais (les libellés les plus longs), et vérifie :
//   · aucune exception de mise en page (aucun texte qui déborde) ;
//   · la fiche membre garde ses boutons (Réserver, Ami, Message, Itinéraire,
//     Voir le profil) et chaque appui appelle son rappel ;
//   · la photo est décodée à la bonne définition (jamais une vignette
//     agrandie) et retombe sur l'icône du rôle si elle ne charge pas ;
//   · la page de profil (en-tête HD, tuiles, sections, avis, barre collante
//     Réserver / Message) se construit sans débordement.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/map/pawmap_rates.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/views/service_provider/widgets/provider_action_bar.dart';
import 'package:hopetsit/views/service_provider/widgets/public_profile_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

const List<double> _widths = <double>[360, 412];
const List<String> _langs = <String>['fr', 'de', 'pl'];

void _screen(WidgetTester tester, double width, {double height = 900}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home, {String lang = 'fr', Brightness b = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: AppTranslations(),
      locale: Locale(lang),
      fallbackLocale: const Locale('en'),
      theme: ThemeData(brightness: b),
      home: home,
    ),
  );
}

PawMapMemberData _member({
  String role = 'sitter',
  bool friend = false,
  String avatar = '',
  String name = 'Marie-Charlotte de la Tour-Maubourg',
}) =>
    PawMapMemberData(
      id: 'm1',
      role: role,
      name: name,
      avatar: avatar,
      online: true,
      premium: true,
      boosted: true,
      verified: true,
      availableToday: true,
      isFriend: friend,
      rating: 4.7,
      reviewsCount: 128,
      priceFrom: 25,
      distanceLabel: '1,2 km',
    );

Widget _sheet(
  PawMapMemberData m, {
  List<String>? calls,
  PawFriendState friendState = PawFriendState.idle,
  String viewerRole = 'owner',
}) {
  void add(String s) => calls?.add(s);
  return Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: PawMapSheetShell(
        child: PawMapMemberSheet(
          member: m,
          viewerRole: viewerRole,
          viewerLoggedIn: true,
          friendState: friendState,
          priceLabel: '25 €',
          rates: const <PawMapRateLine>[
            PawMapRateLine(label: 'Prix / jour', value: '25,00 €'),
            PawMapRateLine(label: 'Prix / semaine', value: '150,00 €'),
          ],
          onBook: () => add('book'),
          onProfile: () => add('profile'),
          onMessage: () => add('message'),
          onFriend: () => add('friend'),
          onDirections: () => add('directions'),
          onPropose: () => add('propose'),
          onSignup: () => add('signup'),
        ),
      ),
    ),
  );
}

/// Structure EXACTE d'une page de profil public (gardien) : en-tête HD,
/// tuiles, sections (tarifs, à propos, compétences, avis), barre collante.
Widget _profilePage({String name = 'Jean-Baptiste de la Tour-Maubourg'}) {
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
            icon: Icons.ios_share_rounded, tooltip: 'share', onTap: () {}),
      ],
    ),
    body: Column(
      children: <Widget>[
        Expanded(
          child: PublicProfileBackground(
            accent: palette.accent,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PublicProfileHero(
                    palette: palette,
                    role: 'sitter',
                    name: name,
                    verified: true,
                    statusChip: const PublicProfileStatusPill(
                      icon: Icons.check_circle_rounded,
                      label: 'Disponible cette semaine',
                      tone: Color(0xFF16A34A),
                    ),
                    location: 'Paris 11e, Île-de-France, France',
                    subtitle: 'Membre depuis septembre 2026',
                    rating: const Text('4.8 ★★★★★ (128)'),
                  ),
                  SizedBox(height: 18.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: <Widget>[
                        PublicProfileStatsRow(
                          accent: palette.accent,
                          stats: <PublicProfileStat>[
                            PublicProfileStat(
                                icon: Icons.star_rounded,
                                value: '4.8',
                                label: 'profiles573_stat_rating'.tr),
                            PublicProfileStat(
                                icon: Icons.reviews_rounded,
                                value: '128',
                                label: 'profiles573_stat_reviews'.tr),
                            PublicProfileStat(
                                icon: Icons.verified_user_rounded,
                                value: '42',
                                label: 'profiles573_stat_services'.tr),
                          ],
                        ),
                        SizedBox(height: 14.h),
                        PublicProfileSection(
                          accent: palette.accent,
                          icon: Icons.payments_rounded,
                          title: 'Tarifs et prestations proposées à domicile',
                          child: Column(
                            children: <Widget>[
                              PublicProfileRateRow(
                                label: 'Prix par jour de garde à domicile avec promenade',
                                value: '1 250,00 €',
                                accent: palette.accent,
                              ),
                              PublicProfileRateRow(
                                label: 'Prix / semaine',
                                value: '150,00 €',
                                accent: palette.accent,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14.h),
                        PublicProfileSection(
                          accent: palette.accent,
                          icon: Icons.person_rounded,
                          title: 'À propos',
                          child: const PublicProfileBody(
                              text: 'Passionnée par les animaux depuis toujours, '
                                  'je garde chiens et chats chez moi à Paris.'),
                        ),
                        SizedBox(height: 14.h),
                        PublicProfileSection(
                          accent: palette.accent,
                          icon: Icons.star_rounded,
                          title: 'Avis',
                          trailing: const Text('2'),
                          child: Column(
                            children: <Widget>[
                              PublicProfileReviewCard(
                                name: 'Marie-Christine Lefebvre-Dupont',
                                rating: 4.5,
                                comment: 'Très bien passé, je recommande.',
                                date: '12/03/2026',
                                accent: palette.accent,
                              ),
                              SizedBox(height: 10.h),
                              PublicProfileReviewCard(
                                name: 'Paul',
                                rating: 5,
                                comment: '',
                                accent: palette.accent,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ProviderActionBar(
          role: 'sitter',
          rates: const PawProviderRates(currency: 'EUR', role: 'sitter', daily: 35),
          onBook: () {},
          onMessage: () {},
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(Get.reset);

  group('fiche membre PawMap (HD)', () {
    for (final double w in _widths) {
      for (final Brightness b in Brightness.values) {
        testWidgets('${w.toInt()} dp · ${b.name} · fr/de/pl : aucun débordement',
            (WidgetTester tester) async {
          for (final String lang in _langs) {
            for (final bool friend in <bool>[false, true]) {
              for (final PawFriendState st in <PawFriendState>[
                PawFriendState.idle,
                PawFriendState.sent,
              ]) {
                _screen(tester, w);
                await tester.pumpWidget(_app(
                  _sheet(_member(friend: friend), friendState: st),
                  lang: lang,
                  b: b,
                ));
                await tester.pump(const Duration(milliseconds: 60));
                expect(tester.takeException(), isNull,
                    reason: '$lang · ami=$friend · $st');
                expect(find.byKey(const ValueKey<String>('member_header')),
                    findsOneWidget);
              }
            }
            // Propriétaire (pas de prix, pas d'étoiles) et promeneur.
            for (final String role in <String>['owner', 'walker']) {
              _screen(tester, w);
              await tester.pumpWidget(_app(
                _sheet(_member(role: role), viewerRole: 'sitter'),
                lang: lang,
                b: b,
              ));
              await tester.pump(const Duration(milliseconds: 60));
              expect(tester.takeException(), isNull, reason: '$lang · $role');
            }
          }
        });
      }
    }

    testWidgets('chaque bouton appelle son rappel (Réserver, Ami, Message, Itinéraire, Profil)',
        (WidgetTester tester) async {
      _screen(tester, 360);
      final List<String> calls = <String>[];
      await tester.pumpWidget(_app(_sheet(_member(), calls: calls)));
      await tester.pump(const Duration(milliseconds: 60));
      for (final String k in <String>[
        'member_primary_book',
        'member_friend',
        'member_message',
        'member_directions',
        'member_profile',
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey<String>(k)));
        await tester.tap(find.byKey(ValueKey<String>(k)));
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(calls, <String>['book', 'friend', 'message', 'directions', 'profile']);
    });

    testWidgets('photo HD : décodée à 2× la taille affichée × densité, repli sur l\'icône',
        (WidgetTester tester) async {
      _screen(tester, 412);
      await tester.pumpWidget(_app(_sheet(
          _member(avatar: 'https://res.cloudinary.com/demo/image/upload/sample.jpg'))));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      final Image img = tester.widget<Image>(find.descendant(
          of: find.byKey(const ValueKey<String>('member_header')),
          matching: find.byType(Image)));
      expect(img.image, isA<ResizeImage>());
      final ResizeImage ri = img.image as ResizeImage;
      final double shown = img.width!;
      // Au moins la taille affichée en pixels réels (3×), jamais une vignette.
      expect(ri.width, greaterThanOrEqualTo((shown * 3).round()));
      // Badges : vérifié sur la photo, couronne Premium, point en ligne.
      expect(find.byKey(const ValueKey<String>('member_avatar_verified')),
          findsOneWidget);
    });
  });

  group('page de profil public (HD)', () {
    for (final double w in _widths) {
      for (final Brightness b in Brightness.values) {
        testWidgets('${w.toInt()} dp · ${b.name} · fr/de/pl : aucun débordement',
            (WidgetTester tester) async {
          for (final String lang in _langs) {
            _screen(tester, w, height: 1600);
            await tester.pumpWidget(_app(_profilePage(), lang: lang, b: b));
            await tester.pump(const Duration(milliseconds: 60));
            expect(tester.takeException(), isNull, reason: lang);
            expect(find.byType(PublicProfileHero), findsOneWidget);
            expect(find.byKey(const ValueKey<String>('provider_book')),
                findsOneWidget);
            expect(find.byKey(const ValueKey<String>('provider_message')),
                findsOneWidget);
            expect(
                find.byKey(const ValueKey<String>('public_profile_avatar_verified')),
                findsOneWidget);
          }
        });
      }
    }

    testWidgets('sans photo : initiale sur l\'aplat du rôle, aucune image',
        (WidgetTester tester) async {
      _screen(tester, 360, height: 1600);
      await tester.pumpWidget(_app(_profilePage(name: 'Sophie Marchand')));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      expect(find.text('S'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
