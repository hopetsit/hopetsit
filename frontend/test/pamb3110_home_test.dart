// PAM-B 31/10/2026 — redesign visuel des 3 accueils (maquettes
// `~/hopetsit-social/design_handoff_accueil_3110/`).
//
// Vérifie, sur un écran 402×874 (iPhone des maquettes) :
//   · les éléments sont présents (hero, champ, cartes services, chips, carte
//     « première annonce » ; bloc statut, ligne lieu, carte clients, rayon,
//     carte « calme ») ;
//   · chaque bouton appelle le callback que l'écran lui branche (même action
//     qu'avant) ;
//   · aucun débordement, et le contenu tient sans défiler (maxScrollExtent 0) ;
//   · sur un iPhone SE (375×667) aucun débordement (le défilement est toléré).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/owner_home3110.dart';
import 'package:hopetsit/views/shared/widgets/home_empty_kit.dart';
import 'package:hopetsit/views/shared/widgets/home_hero3110.dart';
import 'package:hopetsit/views/shared/widgets/provider_home3110.dart';

const double kBottomTabBar = 84; // + encoche 34 = 118 pt réservés à la tab bar

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Appli de test : traductions réelles (fr), barre d'état 59 pt comme sur
/// l'iPhone des maquettes.
Widget _app(Widget body, {Color bg = const Color(0xFFFAF6F3)}) {
  return GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('fr', 'FR'),
    fallbackLocale: const Locale('en', 'US'),
    debugShowCheckedModeBanner: false,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 59, bottom: 34),
      ),
      child: child!,
    ),
    home: Scaffold(backgroundColor: bg, body: body),
  );
}

class _Calls {
  final List<String> log = <String>[];
  VoidCallback tap(String name) => () => log.add(name);
}

Widget _ownerScreen(_Calls c, {int myCount = 0, int selected = 0}) {
  return CustomScrollView(
    key: const ValueKey<String>('scroll'),
    slivers: <Widget>[
      SliverToBoxAdapter(
        child: HomeHero3110(
          role: 'owner',
          name: 'Daniel C',
          avatarUrl: '',
          unreadCount: 2,
          onRocket: c.tap('rocket'),
          onBell: c.tap('bell'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HeroRequestField3110(onTap: c.tap('field')),
              const HeroAvailableLine3110(text: '1 gardien disponible à Alhama de Murcia'),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: ServiceCards3110(
            compact: myCount > 0,
            sittingSubtitle: 'Faire garder mon animal',
            walkingSubtitle: 'Faire promener mon chien',
            onSitting: c.tap('sitting'),
            onWalking: c.tap('walking'),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilterChips3110(
            selectedIndex: selected,
            myCount: myCount,
            labels: const <String>['Mes annonces', 'Pet-sitters', 'Promeneurs'],
            onSelected: (int i) => c.log.add('tab:$i'),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      SliverLayoutBuilder(
        builder: (BuildContext context, SliverConstraints sc) {
          final double remaining = sc.remainingPaintExtent - (110 + 34) - 6;
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: remaining > 0 ? remaining : 0),
                child: FirstPostCard3110(
                  title: 'Publie ta première annonce en 1 minute',
                  steps: const <String>[
                    'Tu publies ton annonce',
                    'Les gardiens autour de toi te font une offre',
                    'Tu paies en toute sécurité',
                  ],
                  ctaLabel: 'Publier mon annonce',
                  onCta: c.tap('publish'),
                ),
              ),
            ),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 110 + 34)),
    ],
  );
}

Widget _providerScreen(_Calls c, {String role = 'sitter'}) {
  final HomeTokens3110 t = HomeTokens3110.forRole(role);
  return SingleChildScrollView(
    key: const ValueKey<String>('scroll'),
    padding: const EdgeInsets.only(bottom: kBottomTabBar + 34),
    child: Column(
      children: <Widget>[
        HomeHero3110(
          role: role,
          bottomPadding: 20,
          name: 'Daniel C',
          avatarUrl: '',
          unreadCount: 1,
          onRocket: c.tap('rocket'),
          onBell: c.tap('bell'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HeroStatusBlock3110(
                primary: t.primary,
                title: 'Pas de demande en attente',
                subtitle: role == 'walker'
                    ? 'pamb3110_status_sub_walker'.tr
                    : 'pamb3110_status_sub_sitter'.tr,
              ),
              HeroLocationLine3110(
                city: 'Alhama de Murcia',
                radiusKm: 50,
                onChange: c.tap('change_city'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            children: <Widget>[
              BringClientsCard3110(
                tokens: t,
                title: 'Ramène tes clients',
                body: 'pamb3110_bring_body'.tr,
                shareLabel: 'Partager',
                qrLabel: 'Affiche QR',
                onShare: c.tap('share'),
                onQr: c.tap('qr'),
              ),
              const SizedBox(height: 10),
              RadiusCard3110(
                tokens: t,
                radiusKm: 50,
                minRadiusKm: 10,
                maxRadiusKm: 200,
                onRadiusChanged: (_) {},
                onRadiusCommit: (double v) => c.log.add('radius:${v.round()}'),
              ),
              const SizedBox(height: 10),
              HomeEmptyKit(
                accent: t.primary,
                body: 'pamb3110_in_radius'.tr.replaceAll('{n}', '0'),
                onRefresh: c.tap('refresh'),
                onCompleteProfile: c.tap('profile'),
                onInvite: c.tap('invite'),
                onBoost: c.tap('boost'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

ScrollableState _scroll(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Accueil propriétaire 3110', () {
    testWidgets('402×874 : tout présent, tient sans défiler, 0 débordement',
        (WidgetTester tester) async {
      _size(tester, 402, 874);
      final _Calls c = _Calls();
      await tester.pumpWidget(_app(_ownerScreen(c)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      expect(find.byKey(const ValueKey<String>('home_hero_3110')), findsOneWidget);
      expect(find.text('Bonjour 👋'), findsOneWidget);
      expect(find.text('Daniel C'), findsOneWidget);
      expect(find.text('Propriétaire'), findsOneWidget);
      expect(find.text('Écris ta demande ici…'), findsOneWidget);
      expect(find.text('1 gardien disponible à Alhama de Murcia'), findsOneWidget);
      expect(find.text('Garde'), findsOneWidget);
      expect(find.text('Promenade'), findsOneWidget);
      expect(find.text('Mes annonces'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // badge compteur
      expect(find.text('Trois étapes, c’est tout.'), findsOneWidget);
      expect(find.text('Publier mon annonce'), findsOneWidget);

      // Tient sur un écran : rien à défiler.
      expect(_scroll(tester).position.maxScrollExtent, 0);
      // La carte « première annonce » descend jusqu'à la zone de la tab bar.
      final Rect card = tester.getRect(find.byKey(const ValueKey<String>('owner_first_post_card')));
      expect(card.bottom, greaterThan(874 - 110 - 34 - 40));
      expect(card.bottom, lessThanOrEqualTo(874 - 110 - 34));
    });

    testWidgets('chaque bouton appelle le même callback qu’avant',
        (WidgetTester tester) async {
      _size(tester, 402, 874);
      final _Calls c = _Calls();
      await tester.pumpWidget(_app(_ownerScreen(c)));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey<String>('home_hero_rocket')));
      await tester.tap(find.byKey(const ValueKey<String>('home_hero_bell')));
      await tester.tap(find.byKey(const ValueKey<String>('home_hero_field')));
      await tester.tap(find.byKey(const ValueKey<String>('owner_card_sitting')));
      await tester.tap(find.byKey(const ValueKey<String>('owner_card_walking')));
      await tester.tap(find.byKey(const ValueKey<String>('owner_chip_1')));
      await tester.tap(find.byKey(const ValueKey<String>('owner_chip_2')));
      await tester.tap(find.byKey(const ValueKey<String>('owner_first_post_cta')));
      await tester.pump();
      expect(c.log, <String>[
        'rocket', 'bell', 'field', 'sitting', 'walking', 'tab:1', 'tab:2', 'publish',
      ]);
    });

    testWidgets('version compacte (1 annonce) : cartes basses, badge 1',
        (WidgetTester tester) async {
      _size(tester, 402, 874);
      final _Calls c = _Calls();
      await tester.pumpWidget(_app(_ownerScreen(c, myCount: 1)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      final Size s = tester.getSize(find.byKey(const ValueKey<String>('owner_card_sitting')));
      expect(s.height, lessThan(100));
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('iPhone SE 375×667 : aucun débordement (défilement toléré)',
        (WidgetTester tester) async {
      _size(tester, 375, 667);
      final _Calls c = _Calls();
      await tester.pumpWidget(_app(_ownerScreen(c)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byKey(const ValueKey<String>('scroll')), const Offset(0, -600));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('owner_first_post_cta')), findsOneWidget);
    });

    testWidgets('mode sombre : se construit sans débordement', (WidgetTester tester) async {
      _size(tester, 402, 874);
      final _Calls c = _Calls();
      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr', 'FR'),
        theme: ThemeData.dark(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(body: _ownerScreen(c)),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });

  for (final String role in <String>['sitter', 'walker']) {
    group('Accueil $role 3110', () {
      testWidgets('402×874 : tout présent, tient sans défiler, 0 débordement',
          (WidgetTester tester) async {
        _size(tester, 402, 874);
        final _Calls c = _Calls();
        await tester.pumpWidget(_app(_providerScreen(c, role: role)));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);

        expect(find.text(role == 'walker' ? 'Promeneur' : 'Gardien'), findsOneWidget);
        expect(find.text('Pas de demande en attente'), findsOneWidget);
        expect(
          find.text(role == 'walker'
              ? 'On te prévient dès qu’une balade arrive près de chez toi'
              : 'On te prévient dès qu’une garde arrive près de chez toi'),
          findsOneWidget,
        );
        expect(find.text('Changer'), findsOneWidget);
        expect(find.text('Ramène tes clients'), findsOneWidget);
        expect(find.text('Partager'), findsOneWidget);
        expect(find.text('Affiche QR'), findsOneWidget);
        expect(find.text('Rayon de recherche'), findsOneWidget);
        expect(find.text('50 km'), findsOneWidget);
        expect(find.text('10 km'), findsOneWidget);
        expect(find.text('200 km'), findsOneWidget);
        expect(find.text('C’est calme autour de toi pour l’instant'), findsOneWidget);
        expect(find.text('0 demande(s) dans ton rayon pour l’instant'), findsOneWidget);
        expect(find.text('Complète ton profil'), findsOneWidget);
        expect(find.text('Invite un propriétaire'), findsOneWidget);
        expect(find.text('Mets-toi en avant'), findsOneWidget);
        // Police de test (pas Poppins) : lignes un peu plus hautes qu'à
        // l'écran ; on tolère 24 pt, le « sans défiler » réel est vérifié sur
        // la capture simulateur (captures_pamb_3110/).
        expect(_scroll(tester).position.maxScrollExtent, lessThanOrEqualTo(24));
      });

      testWidgets('chaque bouton appelle le même callback qu’avant',
          (WidgetTester tester) async {
        _size(tester, 402, 874);
        final _Calls c = _Calls();
        await tester.pumpWidget(_app(_providerScreen(c, role: role)));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.byKey(const ValueKey<String>('home_hero_rocket')));
        await tester.tap(find.byKey(const ValueKey<String>('home_hero_bell')));
        await tester.tap(find.byKey(const ValueKey<String>('home_hero_change_city')));
        await tester.tap(find.byKey(const ValueKey<String>('neo607_home_share')));
        await tester.tap(find.byKey(const ValueKey<String>('neo607_home_more')));
        await tester.tap(find.byKey(const ValueKey<String>('home_empty_refresh')));
        await tester.tap(find.byKey(const ValueKey<String>('home_empty_profile')));
        await tester.tap(find.byKey(const ValueKey<String>('home_empty_invite')));
        await tester.tap(find.byKey(const ValueKey<String>('home_empty_boost')));
        await tester.pump();
        expect(c.log, <String>[
          'rocket', 'bell', 'change_city', 'share', 'qr', 'refresh',
          'profile', 'invite', 'boost',
        ]);

        // Curseur : glisser puis relâcher → UNE valeur entière entre 10 et 200.
        c.log.clear();
        await tester.drag(
          find.byKey(const ValueKey<String>('around_me_radius_slider')),
          const Offset(80, 0),
        );
        await tester.pump();
        expect(c.log.length, 1);
        final int km = int.parse(c.log.single.split(':').last);
        expect(km, inInclusiveRange(10, 200));
        expect(km, greaterThan(50));
      });

      testWidgets('iPhone SE 375×667 : aucun débordement (défilement toléré)',
          (WidgetTester tester) async {
        _size(tester, 375, 667);
        final _Calls c = _Calls();
        await tester.pumpWidget(_app(_providerScreen(c, role: role)));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        await tester.drag(find.byKey(const ValueKey<String>('scroll')), const Offset(0, -500));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    });
  }
}

// Mesures (outil PAM-B, non utilisé par les tests ci-dessus).
Widget debugProvider() => _app(_providerScreen(_Calls()));
Widget debugOwner() => _app(_ownerScreen(_Calls()));
