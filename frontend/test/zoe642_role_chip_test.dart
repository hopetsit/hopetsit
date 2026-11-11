// 642 (ZOE) — défaut 2 du contrôle 641 : la pastille de rôle déborde en
// polonais (« Wyprowadzacz psów », « Opiekun zwierząt »).
//   A. bandeau des 3 accueils (`HomeHero3110`) ;
//   B. barre de titre (`CustomAppBar`) : nom + pastille ;
//   C. en-tête de profil (`ProfileHero`) : pastille « verre ».
// 3 rôles × 9 langues × 320 / 360 / 393 dp × échelle de texte 1,0 / 1,3 / 1,6.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_hero.dart';
import 'package:hopetsit/views/shared/widgets/home_hero3110.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/widgets/role_chip.dart';

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
const List<String> kRoles = <String>['owner', 'sitter', 'walker'];
const List<double> kWidths = <double>[320, 360, 393];
const List<double> kScales = <double>[1.0, 1.3, 1.6];
const List<String> kNames = <String>['Léa', 'Maximilien-Alexandre de la Fontaine'];

void _phone(WidgetTester tester, double w, double scale) {
  lotdPhone(tester, width: w, height: 852 * w / 393);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Le libellé de rôle est entier (pas de « … », pas de ligne en trop) et dans
/// la fenêtre.
void _expectLabelWhole(WidgetTester tester, String label, double width, String why, {bool allowEllipsis = false}) {
  final Finder f = find.text(label);
  expect(f, findsWidgets, reason: '$why — libellé « $label » absent');
  for (final Element e in f.evaluate()) {
    final RenderObject? ro = e.renderObject;
    RenderParagraph? p;
    void visit(RenderObject o) {
      if (o is RenderParagraph) p = o;
      o.visitChildren(visit);
    }
    if (ro != null) visit(ro);
    expect(p, isNotNull, reason: why);
    if (!allowEllipsis) {
      expect(p!.didExceedMaxLines, isFalse, reason: '$why — libellé coupé');
    }
    final Rect r = MatrixUtils.transformRect(p!.getTransformTo(null), Offset.zero & p!.size);
    expect(r.left, greaterThanOrEqualTo(0), reason: why);
    expect(r.right, lessThanOrEqualTo(width + 0.5), reason: '$why — sort de l\'écran');
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await home640LoadIconFont();
  });

  group('A. bandeau des accueils', () {
    for (final String role in kRoles) {
      group(role, () {
      setUp(() async {
        await lotdSetUp(role: role);
        AppColors.activeRoleOverride = role;
        lotdResponder = (req) => <String, dynamic>{};
      });
      testWidgets('pastille de rôle « $role » : jamais de débordement, libellé entier', (tester) async {
        for (final double w in kWidths) {
          for (final double scale in kScales) {
            _phone(tester, w, scale);
            for (final Locale loc in kLocales) {
              for (final String name in kNames) {
                final String why = 'accueil $role ${loc.languageCode} largeur $w échelle $scale nom « $name »';
                await tester.pumpWidget(lotdApp(
                  Scaffold(
                    body: Align(
                      alignment: Alignment.topCenter,
                      child: HomeHero3110(
                        key: ValueKey<String>(why),
                        role: role,
                        name: name,
                        avatarUrl: '',
                        unreadCount: 2,
                        onRocket: () {},
                        onBell: () {},
                        child: const SizedBox(height: 20),
                      ),
                    ),
                  ),
                  locale: loc,
                ));
                await tester.pump(const Duration(milliseconds: 30));
                expect(tester.takeException(), isNull, reason: why);
                expect(Get.locale?.languageCode, loc.languageCode, reason: why);
                final String label = roleLabelKey(role).tr;
                _expectLabelWhole(tester, label, w, why);
                // La pastille ne passe pas sous les boutons ronds de droite.
                final Rect rocket = tester.getRect(find.byKey(const ValueKey<String>('home_hero_rocket')));
                final Rect lab = tester.getRect(find.text(label));
                expect(lab.right, lessThanOrEqualTo(rocket.left), reason: '$why — sous la fusée');
                expect(lab.height, greaterThanOrEqualTo(9), reason: '$why — libellé illisible');
              }
            }
          }
        }
      });
      });
    }
  });

  group('B. barre de titre', () {
    for (final String role in kRoles) {
      group(role, () {
      setUp(() async {
        await lotdSetUp(role: role);
        AppColors.activeRoleOverride = role;
        lotdResponder = (req) => <String, dynamic>{};
      });
      testWidgets('nom + pastille « $role » : jamais de débordement', (tester) async {
        for (final double w in kWidths) {
          for (final double scale in kScales) {
            _phone(tester, w, scale);
            for (final Locale loc in kLocales) {
              for (final String name in kNames) {
                final String why = 'barre $role ${loc.languageCode} largeur $w échelle $scale nom « $name »';
                await tester.pumpWidget(lotdApp(
                  Scaffold(
                    key: ValueKey<String>(why),
                    appBar: CustomAppBar(userName: name, userImage: '', role: role),
                    body: const SizedBox.shrink(),
                  ),
                  locale: loc,
                ));
                await tester.pump(const Duration(milliseconds: 30));
                expect(tester.takeException(), isNull, reason: why);
                final String label = roleLabelKey(role).tr;
                _expectLabelWhole(tester, label, w, why, allowEllipsis: true);
                // Le nom garde de la place à côté de la pastille.
                final Finder nameF = find.textContaining(name.substring(0, 3));
                expect(nameF, findsOneWidget, reason: why);
                final RenderParagraph np = tester.renderObject<RenderParagraph>(
                  find.descendant(of: nameF, matching: find.byType(RichText)).evaluate().isNotEmpty
                      ? find.descendant(of: nameF, matching: find.byType(RichText))
                      : nameF,
                );
                // Un nom coupé garde au moins de quoi lire quelques lettres.
                if (np.didExceedMaxLines) {
                  expect(np.size.width, greaterThanOrEqualTo(40), reason: '$why — nom écrasé');
                }
                final Rect chip = tester.getRect(find.byType(RoleChip));
                expect(chip.right, lessThanOrEqualTo(w), reason: why);
              }
            }
          }
        }
      });
      });
    }
  });

  group('C. en-tête de profil', () {
    for (final String role in kRoles) {
      group(role, () {
      setUp(() async {
        await lotdSetUp(role: role);
        AppColors.activeRoleOverride = role;
        lotdResponder = (req) => <String, dynamic>{};
      });
      testWidgets('pastille « verre » « $role » : jamais de débordement', (tester) async {
        for (final double w in kWidths) {
          for (final double scale in kScales) {
            _phone(tester, w, scale);
            for (final Locale loc in kLocales) {
              final String why = 'profil $role ${loc.languageCode} largeur $w échelle $scale';
              await tester.pumpWidget(lotdApp(
                Scaffold(
                  key: ValueKey<String>(why),
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: ProfileHero(
                      role: role,
                      userName: 'Maximilien-Alexandre'.obs,
                      profileImageUrl: ''.obs,
                      profile: Rxn<ProfileModel>(),
                      onCamera: () {},
                    ),
                  ),
                ),
                locale: loc,
              ));
              await tester.pump(const Duration(milliseconds: 30));
              expect(tester.takeException(), isNull, reason: why);
              final Rect chip = tester.getRect(find.byType(RoleChip));
              expect(chip.left, greaterThanOrEqualTo(0), reason: why);
              expect(chip.right, lessThanOrEqualTo(w), reason: why);
              _expectLabelWhole(tester, roleLabelKey(role).tr, w, why, allowEllipsis: true);
            }
          }
        }
      });
      });
    }
  });
}
