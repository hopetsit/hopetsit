// 642 (ZOE) — défaut 3 du contrôle 641 : textes coupés sur petits écrans en
// gros caractères (échelle de texte 1,3 et 1,6) :
//   A. la carte « Publie ta première annonce » de l'accueil propriétaire ;
//   B. le bandeau de l'accueil gardien / promeneur (bloc d'état + ligne lieu).
// 320 / 360 / 393 dp × échelle 1,0 / 1,3 / 1,6 × 9 langues : aucun texte coupé
// (ni « … », ni ligne en trop), aucun débordement, rien hors de son bloc.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_owner/home/home_screen.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/owner_home3110.dart';
import 'package:hopetsit/views/shared/widgets/home640_kit.dart';
import 'package:hopetsit/views/shared/widgets/home_hero3110.dart';

import 'home640_harness.dart';
import 'lotd_harness.dart';

const List<Locale> kLocales = <Locale>[
  Locale('fr', 'FR'),
  Locale('en', 'US'),
  Locale('es', 'ES'),
  Locale('de', 'DE'),
  Locale('it', 'IT'),
  Locale('pt', 'PT'),
  Locale('ko', 'KR'),
  Locale('ja', 'JP'),
  Locale('pl', 'PL'),
];
const List<double> kWidths = <double>[320, 360, 393];
const List<double> kScales = <double>[1.0, 1.3, 1.6];

void _phone(WidgetTester tester, double w, double scale) {
  lotdPhone(tester, width: w, height: 1400); // haut : tout le bloc à l'écran
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Tous les textes sous [root] sont entiers et restent dans [root].
int _expectNothingClipped(WidgetTester tester, Finder root, String why) {
  final Rect box = tester.getRect(root);
  int n = 0;
  for (final Element e in find.descendant(of: root, matching: find.byType(RichText)).evaluate()) {
    final RenderParagraph p = e.renderObject! as RenderParagraph;
    final String txt = p.text.toPlainText();
    if (txt.trim().length < 2 && txt.runes.every((int r) => r > 0xE000)) continue; // icône
    if (txt.trim().isEmpty) continue;
    // Le nom vient du compte (longueur libre) : « … » admis, contrôlé ailleurs.
    if (e.findAncestorWidgetOfExactType<Text>()?.key == const ValueKey<String>('home_hero_name')) continue;
    n++;
    expect(p.didExceedMaxLines, isFalse, reason: '$why — coupé : « $txt »');
    final Rect r = MatrixUtils.transformRect(p.getTransformTo(null), Offset.zero & p.size);
    expect(r.left, greaterThanOrEqualTo(box.left - 0.5), reason: '$why — « $txt » sort à gauche');
    expect(r.right, lessThanOrEqualTo(box.right + 0.5), reason: '$why — « $txt » sort à droite');
    expect(r.top, greaterThanOrEqualTo(box.top - 0.5), reason: '$why — « $txt » sort en haut');
    expect(r.bottom, lessThanOrEqualTo(box.bottom + 0.5), reason: '$why — « $txt » sort en bas');
  }
  return n;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await home640LoadIconFont();
  });

  group('A. carte « première annonce » (propriétaire)', () {
    setUp(() async => lotdSetUp(role: 'owner'));

    testWidgets('aucun texte coupé, 320/360/393 × 1,0/1,3/1,6 × 9 langues', (tester) async {
      final Set<String> titles = <String>{};
      for (final double w in kWidths) {
        for (final double scale in kScales) {
          _phone(tester, w, scale);
          for (final Locale loc in kLocales) {
            final String why = 'première annonce ${loc.languageCode} largeur $w échelle $scale';
            await tester.pumpWidget(lotdApp(
              Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    // Même marge que l'écran.
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Builder(
                      key: ValueKey<String>(why),
                      builder: (BuildContext context) => FirstPostCard3110(
                        title: 'ownerhome571_first_title'.tr,
                        steps: <String>[
                          'ownerhome571_first_step1'.tr,
                          'ownerhome571_first_step2'.tr,
                          'ownerhome571_first_step3'.tr,
                        ],
                        ctaLabel: 'ownerhome571_first_cta'.tr,
                        onCta: () {},
                      ),
                    ),
                  ),
                ),
              ),
              locale: loc,
            ));
            await tester.pump(const Duration(milliseconds: 30));
            expect(tester.takeException(), isNull, reason: why);
            expect(Get.locale?.languageCode, loc.languageCode, reason: why);
            final Finder card = find.byKey(const ValueKey<String>('owner_first_post_card'));
            // Titre + sous-titre + bouton + 3 numéros + 3 étapes.
            expect(_expectNothingClipped(tester, card, why), 9, reason: why);
            expect(find.text('ownerhome571_first_cta'.tr), findsOneWidget, reason: why);
            expect(
              tester.getSize(find.byKey(const ValueKey<String>('owner_first_post_cta'))).height,
              greaterThanOrEqualTo(48),
              reason: '$why — cible tactile',
            );
            titles.add('ownerhome571_first_title'.tr);
          }
        }
      }
      expect(titles.length, 9, reason: 'les 9 langues ont été rendues : $titles');
    });
  });

  for (final String role in <String>['sitter', 'walker']) {
    group('B. bandeau de l\'accueil $role', () {
      setUp(() async => lotdSetUp(role: role));

      testWidgets('aucun texte coupé, 320/360/393 × 1,0/1,3/1,6 × 9 langues', (tester) async {
        final HomeTokens3110 t = HomeTokens3110.forRole(role);
        final Set<String> subs = <String>{};
        for (final double w in kWidths) {
          for (final double scale in kScales) {
            _phone(tester, w, scale);
            for (final Locale loc in kLocales) {
              final String why = 'bandeau $role ${loc.languageCode} largeur $w échelle $scale';
              await tester.pumpWidget(lotdApp(
                Scaffold(
                  body: SingleChildScrollView(
                    child: Builder(
                      key: ValueKey<String>(why),
                      // Même montage que `SitterHomescreen`.
                      builder: (BuildContext context) => HomeHero3110(
                        role: role,
                        bottomPadding: 20,
                        name: 'Camille Durand',
                        avatarUrl: '',
                        unreadCount: 0,
                        onRocket: () {},
                        onBell: () {},
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            HeroStatusBlock640(
                              primary: t.primary,
                              title: 'quick_action_title_provider'.tr,
                              subtitle: role == 'walker'
                                  ? 'pamb3110_status_sub_walker'.tr
                                  : 'pamb3110_status_sub_sitter'.tr,
                              deco: role == 'walker' ? HomeDeco640.dogOnLeash : HomeDeco640.dogAndCat,
                            ),
                            HeroLocationLine3110(city: 'Zone test', radiusKm: 30, onChange: () {}),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                locale: loc,
              ));
              await tester.pump(const Duration(milliseconds: 30));
              expect(tester.takeException(), isNull, reason: why);
              expect(Get.locale?.languageCode, loc.languageCode, reason: why);
              final Finder status = find.byKey(const ValueKey<String>('home_hero_status'));
              // Titre + sous-titre du bloc d'état.
              expect(_expectNothingClipped(tester, status, why), 2, reason: why);
              // Ligne lieu : ville · rayon + « Changer », entiers, dans le bandeau.
              final Finder hero = find.byKey(const ValueKey<String>('home_hero_3110'));
              _expectNothingClipped(tester, hero, why);
              expect(find.text('home571_change'.tr), findsOneWidget, reason: why);
              subs.add(role == 'walker' ? 'pamb3110_status_sub_walker'.tr : 'pamb3110_status_sub_sitter'.tr);
            }
          }
        }
        expect(subs.length, 9, reason: 'les 9 langues ont été rendues');
      });
    });
  }

  // ── VRAIS écrans (faux serveur du harnais lot D, données fictives) ──────
  Future<void> profile(String role) async {
    await GetStorage().write(StorageKeys.userProfile, <String, dynamic>{
      'id': 'u-test',
      '_id': 'u-test',
      'name': 'Camille Durand',
      'email': 'camille@example.test',
      'role': role,
      'city': 'Zone test',
      'location': <String, dynamic>{'city': 'Zone test', 'country': 'Test', 'lat': -35.2, 'lng': -30.4},
    });
    const geo = MethodChannel('flutter.baseflow.com/geolocator');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geo, (MethodCall c) async => throw MissingPluginException(c.method));
    lotdResponder = (req) => <String, dynamic>{
          'pets': <Map<String, dynamic>>[],
          'posts': <Map<String, dynamic>>[],
          'sitters': <Map<String, dynamic>>[],
          'walkers': <Map<String, dynamic>>[],
          'notifications': <Map<String, dynamic>>[],
          'blocks': <Map<String, dynamic>>[],
          'bookings': <Map<String, dynamic>>[],
          'applications': <Map<String, dynamic>>[],
          'conversations': <Map<String, dynamic>>[],
          'count': 0,
        };
  }

  const List<Locale> realLocales = <Locale>[Locale('fr', 'FR'), Locale('de', 'DE'), Locale('pl', 'PL'), Locale('ja', 'JP')];

  for (final String role in <String>['owner', 'sitter', 'walker']) {
    group('C. vrai accueil $role, petit écran, gros caractères', () {
      setUp(() async {
        await lotdSetUp(role: role);
        await profile(role);
      });
      for (final double w in <double>[320, 360]) {
        for (final double scale in <double>[1.3, 1.6]) {
          for (final Locale loc in realLocales) {
            testWidgets('largeur $w, échelle $scale, ${loc.languageCode} : aucune exception, aucun texte coupé',
                (tester) async {
              final String why = 'vrai accueil $role ${loc.languageCode} largeur $w échelle $scale';
              // Fenêtre haute à l'échelle d'un petit téléphone (voir `home640App`).
              const double h = 1800;
              lotdPhone(tester, width: w, height: h);
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
              await tester.pumpWidget(home640App(
                role == 'owner' ? const HomeScreen() : const SitterHomescreen(),
                designHeight: h * 852 / (w == 320 ? 568 : 640),
                locale: loc,
              ));
              await tester.pump(const Duration(seconds: 7));
              await lotdSettle(tester, frames: 8);
              expect(tester.takeException(), isNull, reason: why);
              expect(Get.locale?.languageCode, loc.languageCode, reason: why);
              final Finder hero = find.byKey(const ValueKey<String>('home_hero_3110'));
              expect(hero, findsOneWidget, reason: why);
              expect(_expectNothingClipped(tester, hero, why), greaterThanOrEqualTo(3), reason: why);
              if (role == 'owner') {
                final Finder card = find.byKey(const ValueKey<String>('owner_first_post_card'));
                expect(card, findsOneWidget, reason: why);
                expect(_expectNothingClipped(tester, card, why), 9, reason: why);
              } else {
                final Finder status = find.byKey(const ValueKey<String>('home_hero_status'));
                expect(_expectNothingClipped(tester, status, why), 2, reason: why);
              }
              await tester.pump(const Duration(seconds: 6)); // minuteries des bandeaux
            });
          }
        }
      }
    });
  }
}
