// v600 (PAM, 29/09) — accueil invité : les titres ne sont JAMAIS coupés
// (NORME_DESIGN.md « titres jamais coupés », capture de Daniel « Garde
// d'anima… » sur iPhone). Les 4 tuiles de rôle sont montées en grille 2×2 avec
// les titres des 9 langues, sur 5 largeurs (320 dp = le plus étroit visé,
// 360 dp = Android courant, 375 = iPhone SE, 393 = iPhone 15, 440 = 17 Pro
// Max). Aucun « … », aucun paragraphe qui dépasse ses lignes, aucune exception.
// Même contrôle pour le titre héros (« compagnon ❤ ») dans une colonne étroite.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/guest/guest_landing_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';

/// Titres des tuiles dans les 9 langues (role_pet_owner / role_pet_sitter /
/// role_pet_walker / guest_role_guest), copiés des traductions.
const Map<String, List<String>> kRoleTitles = <String, List<String>>{
  'en': ['Pet Owner', 'Pet Sitter', 'Dog walker', 'Guest'],
  'fr': ['Propriétaire', "Garde d'animaux", 'Promeneur', 'Invité'],
  'de': ['Tierhalter', 'Tiersitter', 'Gassigeher', 'Gast'],
  'es': ['Dueño', 'Cuidador', 'Paseador', 'Invitado'],
  'it': ['Proprietario', 'Pet sitter', 'Dog walker', 'Ospite'],
  'pt': ['Dono', 'Pet sitter', 'Passeador', 'Convidado'],
  'pl': [
    'Właściciel zwierzaka',
    'Opiekun zwierząt',
    'Wyprowadzacz psów',
    'Gość',
  ],
  'ja': ['飼い主', 'ペットシッター', 'ドッグウォーカー', 'ゲスト'],
  'ko': ['반려인', '펫시터', '산책 도우미', '게스트'],
};

const Map<String, String> kHeroTitle2 = <String, String>{
  'en': 'companion',
  'fr': 'compagnon',
  'de': 'Gefährten',
  'es': 'compañero',
  'it': 'compagno',
  'pt': 'companheiro',
  'pl': 'towarzysza',
  'ja': '最高のケアを',
  'ko': '최고의 선택',
};

const List<double> kWidths = <double>[320, 360, 375, 393, 440];

Widget _harness(Widget child, {Brightness brightness = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    ),
  );
}

void _sizeTo(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Vérifie que chaque paragraphe rendu tient dans ses lignes et ne montre
/// aucun « … ».
void _expectNoCut(WidgetTester tester, String where) {
  final paragraphs = tester.allRenderObjects.whereType<RenderParagraph>();
  expect(paragraphs, isNotEmpty, reason: where);
  for (final RenderParagraph rp in paragraphs) {
    final String plain = rp.text.toPlainText();
    expect(
      plain.contains('…'),
      isFalse,
      reason: '$where : « … » dans "$plain"',
    );
    final double maxW = rp.constraints.maxWidth;
    final TextPainter tp = TextPainter(
      text: rp.text,
      textDirection: rp.textDirection,
      maxLines: rp.maxLines,
      textScaler: rp.textScaler,
    )..layout(maxWidth: maxW.isFinite ? maxW : double.infinity);
    expect(
      tp.didExceedMaxLines,
      isFalse,
      reason: '$where : "$plain" dépasse ${rp.maxLines} ligne(s) à $maxW px',
    );
    tp.dispose();
  }
}

GuestRoleTile _tile(
  String title,
  String sub, {
  List<Color>? g,
  Color? accent,
}) => GuestRoleTile(
  photo: 'assets/images/guest/prop-new.png',
  gradient: g,
  accent: accent,
  title: title,
  subtitle: sub,
  onTap: () {},
);

/// La grille 2×2 de l'accueil invité, telle qu'elle est montée dans l'écran.
Widget _grid(List<String> t) => Column(
  children: [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _tile(
            t[0],
            'sous-titre',
            g: const [Color(0xFFE25822), Color(0xFFC92A12)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _tile(
            t[1],
            'sous-titre',
            g: const [Color(0xFF2F6FD6), Color(0xFF1E4FB0)],
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _tile(
            t[2],
            'sous-titre',
            g: const [Color(0xFF2FAE4E), Color(0xFF15803D)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _tile(t[3], 'sous-titre', accent: const Color(0xFFDB2777)),
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('accueil invité v600 — titres jamais coupés', () {
    for (final double w in kWidths) {
      for (final MapEntry<String, List<String>> e in kRoleTitles.entries) {
        testWidgets('tuiles 2×2 en ${e.key} à ${w.toInt()} dp', (
          WidgetTester tester,
        ) async {
          _sizeTo(tester, w);
          await tester.pumpWidget(_harness(_grid(e.value)));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(GuestRoleTile), findsNWidgets(4));
          _expectNoCut(tester, '${e.key} @ $w');
        });
      }
    }

    for (final MapEntry<String, String> e in kHeroTitle2.entries) {
      testWidgets('titre héros « ${e.value} » dans une colonne étroite (SE)', (
        WidgetTester tester,
      ) async {
        _sizeTo(tester, 375);
        await tester.pumpWidget(
          _harness(
            Row(
              children: [
                Expanded(
                  flex: 11,
                  child: Row(
                    children: [
                      Flexible(
                        child: PawButtonLabel(
                          text: e.value,
                          textAlign: TextAlign.start,
                          style: GoogleFonts.poppins(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                          ).copyWith(fontFamilyFallback: cjkFontFallback),
                        ),
                      ),
                      const SizedBox(width: 26),
                    ],
                  ),
                ),
                const Expanded(flex: 9, child: SizedBox(height: 10)),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        _expectNoCut(tester, 'héros ${e.key}');
      });
    }

    testWidgets('mode sombre : grille française à 360 dp', (
      WidgetTester tester,
    ) async {
      _sizeTo(tester, 360);
      await tester.pumpWidget(
        _harness(_grid(kRoleTitles['fr']!), brightness: Brightness.dark),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      _expectNoCut(tester, 'sombre fr @ 360');
    });
  });

  test('Profil → Aide : les teintes des icônes sont saturées (zéro gris)', () {
    // L'encre « Conditions » et les accents de rôle doivent avoir une
    // saturation HSL ≥ 0,25 : à 12 % sur blanc, une teinte terne redevient
    // grise (l'ancien taupe #B69C96 était à 0,18).
    for (final Color c in <Color>[
      ProfileCategories.helpInk,
      const Color(0xFFC92A12),
      const Color(0xFF2563EB),
      const Color(0xFF16A34A),
    ]) {
      expect(
        HSLColor.fromColor(c).saturation,
        greaterThanOrEqualTo(0.25),
        reason: '$c',
      );
    }
    expect(
      HSLColor.fromColor(const Color(0xFFB69C96)).saturation,
      lessThan(0.25),
    );
  });
}
