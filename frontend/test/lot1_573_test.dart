// v573 — lot 1 (entrée invité, inscription sociale, KYC) : mise au design de
// l'app des écrans classés « ancien design » par l'audit.
//
// Ce test monte SEULS les deux widgets réutilisables créés par le lot, sur un
// écran de 320 dp (le plus étroit visé) et dans les deux langues les plus
// longues (allemand, polonais) :
//   · `SignUpRoleCard` / `SignUpRoleIllustration` — les cartes de rôle de
//     l'écran « Je m'inscris en tant que… », dont les PNG marketing ont été
//     remplacés par une illustration vectorielle ;
//   · `GuestRoleTile` — les 4 tuiles de l'atterrissage invité, variante
//     « dégradé du rôle » et variante « Invité » posée sur la carte du thème.
//
// On vérifie : aucun débordement, le tap appelle bien le callback, et le rendu
// passe en mode SOMBRE (c'était le défaut n° 1 de l'atterrissage invité).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';
import 'package:hopetsit/views/guest/guest_landing_screen.dart';

Widget _harness(
  Widget child, {
  String lang = 'fr',
  Brightness brightness = Brightness.light,
}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      locale: Locale(lang),
      fallbackLocale: const Locale('en'),
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

  group('SignUpRoleCard', () {
    testWidgets('se construit à 320 dp en allemand, sans débordement',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(
        _harness(
          Column(
            children: const <Widget>[
              SignUpRoleCard(
                key: ValueKey<String>('role_owner'),
                titleKey: 'role_pet_owner',
                subtitleKey: 'role_pet_owner_desc',
                icon: Icons.pets_rounded,
                badgeIcon: Icons.home_rounded,
                gradient: kSignUpOwnerGradient,
                onTap: _noop,
              ),
              SizedBox(height: 16),
              SignUpRoleCard(
                titleKey: 'role_pet_sitter',
                subtitleKey: 'role_pet_sitter_desc',
                icon: Icons.night_shelter_rounded,
                badgeIcon: Icons.verified_rounded,
                gradient: kSignUpSitterGradient,
                onTap: _noop,
              ),
              SizedBox(height: 16),
              SignUpRoleCard(
                titleKey: 'role_pet_walker',
                subtitleKey: 'role_pet_walker_desc',
                icon: Icons.directions_walk_rounded,
                badgeIcon: Icons.near_me_rounded,
                gradient: kSignUpWalkerGradient,
                onTap: _noop,
              ),
            ],
          ),
          lang: 'de',
        ),
      );
      await tester.pump();

      expect(find.byType(SignUpRoleCard), findsNWidgets(3));
      expect(find.byType(SignUpRoleIllustration), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('un tap déclenche le callback', (WidgetTester tester) async {
      _sizeTo320(tester);
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          SignUpRoleCard(
            titleKey: 'role_pet_owner',
            subtitleKey: 'role_pet_owner_desc',
            icon: Icons.pets_rounded,
            gradient: kSignUpOwnerGradient,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(SignUpRoleCard));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
    });

    testWidgets('rend en mode sombre sans exception',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(
        _harness(
          const SignUpRoleIllustration(
            gradient: kSignUpWalkerGradient,
            icon: Icons.directions_walk_rounded,
            badgeIcon: Icons.near_me_rounded,
            size: 76,
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      expect(find.byType(SignUpRoleIllustration), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('GuestRoleTile', () {
    testWidgets('les deux variantes tiennent côte à côte à 320 dp (polonais)',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      var roleTaps = 0;
      var guestTaps = 0;
      await tester.pumpWidget(
        _harness(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: GuestRoleTile(
                  key: const ValueKey<String>('tile_owner'),
                  photo: 'assets/images/guest/prop-new.png',
                  gradient: const <Color>[
                    Color(0xFFE25822),
                    Color(0xFFC92A12),
                  ],
                  title: 'Właściciel zwierzaka',
                  subtitle: 'Znajdź opiekuna lub osobę do wyprowadzania psa',
                  onTap: () => roleTaps++,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GuestRoleTile(
                  key: const ValueKey<String>('tile_guest'),
                  photo: 'assets/images/guest/souris2.png',
                  accent: const Color(0xFFDB2777),
                  title: 'Gość',
                  subtitle: 'Przeglądaj bez zakładania konta',
                  onTap: () => guestTaps++,
                ),
              ),
            ],
          ),
          lang: 'pl',
        ),
      );
      await tester.pump();

      expect(find.byType(GuestRoleTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey<String>('tile_owner')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey<String>('tile_guest')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(roleTaps, 1);
      expect(guestTaps, 1);
    });

    testWidgets('la variante « Invité » rend en mode sombre',
        (WidgetTester tester) async {
      _sizeTo320(tester);
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 150,
            child: GuestRoleTile(
              photo: 'assets/images/guest/souris2.png',
              accent: const Color(0xFFDB2777),
              title: 'Invité',
              subtitle: 'Explorer sans compte',
              onTap: _noop,
            ),
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      expect(find.byType(GuestRoleTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop() {}
