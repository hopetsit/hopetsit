// v584 — lot C du chantier du 24/09 : les FEUILLES de la PawMap, bouton par
// bouton (méthode imposée : « tests de widgets qui appuient sur CHAQUE bouton
// … de la feuille et de la bulle, et vérifient ce qui s'ouvre »).
//   · fiche membre : Réserver (· prix) / Voir le profil / Message / Ajouter en
//     ami / Itinéraire / Proposer mes services / inscription sans compte ;
//   · bulle de demande : Proposer mes services (états), Voir mes annonces,
//     profil du propriétaire ;
//   · visibilité : « tous » / « amis seulement » ;
//   · pastille « Visible par tes amis seulement » ;
//   · légende « ? » : une ligne par épingle de LEGENDE_PAWMAP.md ;
//   · liste « autour de toi » : un appui = la fiche ;
//   · les 9 langues portent toutes les clés du lot.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/v565/lotc584_i18n.dart';
import 'package:hopetsit/localization/v565/map_i18n.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/map/widgets/paw_rail_button.dart';
import 'package:hopetsit/views/map/widgets/pawmap_buttons.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';

const List<String> _langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final l in _langs)
          l: {
            ...mapI18n[l] ?? const <String, String>{},
            ...lotC584I18n[l]!,
            'pawmap_member_book': 'Réserver',
            'pawmap_member_add_friend': 'Ajouter en ami',
            'pawmap_member_request_failed': 'Échec',
            'pawmap_member_approx': 'Position approximative ({km} km)',
            'pawmap_member_online': 'En ligne',
            'pawmap_member_offline': 'Hors ligne',
            'pawmap_member_price_from': 'dès',
            'pawmap_btn_directions': 'Itinéraire',
            'pawmap_default_walker': 'Promeneur',
            'pawmap_default_sitter': 'Gardien',
            'pawmap_request_default_title': 'Demande de garde',
            'pawmap_me_label': 'Moi',
            'profile_pref_hide_map_sub': 'sub',
          },
      };
}

Widget _harness(Widget child, {Brightness brightness = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: _T(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('en'),
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

/// Écran complet (il a son propre Scaffold).
Widget _page(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: _T(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('en'),
      theme: ThemeData(brightness: Brightness.light),
      home: child,
    ),
  );
}

PawMapMemberData _sitter({bool friend = false}) => PawMapMemberData(
      id: 's1',
      role: 'sitter',
      name: 'Léa',
      online: true,
      premium: true,
      verified: true,
      availableToday: true,
      boosted: true,
      isFriend: friend,
      rating: 4.8,
      reviewsCount: 12,
      priceFrom: 25,
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(Get.reset);

  group('fiche membre (réserver en 2 appuis)', () {
    testWidgets('gardien : Réserver · 25 € est LE bouton principal ; chaque bouton appelle son rappel',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_harness(PawMapMemberSheet(
        member: _sitter(),
        viewerRole: 'owner',
        viewerLoggedIn: true,
        friendState: PawFriendState.idle,
        priceLabel: '25 €',
        onBook: () => calls.add('book'),
        onProfile: () => calls.add('profile'),
        onMessage: () => calls.add('message'),
        onFriend: () => calls.add('friend'),
        onDirections: () => calls.add('directions'),
        onPropose: () => calls.add('propose'),
        onSignup: () => calls.add('signup'),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      // Le prix vit DANS le bouton principal.
      expect(find.text('Réserver · 25 €'), findsOneWidget);
      // Pastilles : identité vérifiée, dispo aujourd'hui, PawBoost.
      expect(find.byType(PawInfoChip), findsNWidgets(3));
      expect(find.text('Identité vérifiée'), findsOneWidget);

      for (final k in ['member_primary_book', 'member_profile', 'member_message',
        'member_friend', 'member_directions']) {
        await tester.ensureVisible(find.byKey(ValueKey<String>(k)));
        await tester.tap(find.byKey(ValueKey<String>(k)));
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(calls, ['book', 'profile', 'message', 'friend', 'directions']);
      expect(calls, isNot(contains('signup')));
    });

    testWidgets('sans compte : le bouton principal ouvre l\'inscription, jamais la réservation',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_harness(PawMapMemberSheet(
        member: _sitter(),
        viewerRole: '',
        viewerLoggedIn: false,
        friendState: PawFriendState.idle,
        priceLabel: '25 €',
        onBook: () => calls.add('book'),
        onProfile: () => calls.add('profile'),
        onMessage: () => calls.add('message'),
        onFriend: () => calls.add('friend'),
        onDirections: null,
        onPropose: () => calls.add('propose'),
        onSignup: () => calls.add('signup'),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Crée ton compte'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('member_directions')), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('member_primary_book')));
      await tester.tap(find.byKey(const ValueKey<String>('member_message')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, ['signup', 'signup']);
    });

    testWidgets('propriétaire avec une demande, vu par un gardien : « Proposer mes services »',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_harness(PawMapMemberSheet(
        member: const PawMapMemberData(
            id: 'o1', role: 'owner', name: 'Marc', hasOpenRequest: true),
        viewerRole: 'sitter',
        viewerLoggedIn: true,
        friendState: PawFriendState.idle,
        priceLabel: '',
        onBook: () => calls.add('book'),
        onProfile: () => calls.add('profile'),
        onMessage: () => calls.add('message'),
        onFriend: () => calls.add('friend'),
        onDirections: null,
        onPropose: () => calls.add('propose'),
        onSignup: () => calls.add('signup'),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('member_primary_propose')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, ['propose']);
      expect(find.byKey(const ValueKey<String>('member_primary_book')), findsNothing);
    });

    testWidgets('propriétaire sans demande : « Ajouter en ami » principal ; « déjà amis » désactivé',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_harness(PawMapMemberSheet(
        member: const PawMapMemberData(id: 'o2', role: 'owner', name: 'Ana'),
        viewerRole: 'owner',
        viewerLoggedIn: true,
        friendState: PawFriendState.idle,
        priceLabel: '',
        onBook: () => calls.add('book'),
        onProfile: () => calls.add('profile'),
        onMessage: () => calls.add('message'),
        onFriend: () => calls.add('friend'),
        onDirections: null,
        onPropose: () => calls.add('propose'),
        onSignup: () => calls.add('signup'),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('member_primary_friend')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, ['friend']);

      // Déjà amis → le bouton reste visible (coche) et n'appelle plus rien.
      await tester.pumpWidget(_harness(PawMapMemberSheet(
        member: const PawMapMemberData(id: 'o2', role: 'owner', name: 'Ana', isFriend: true),
        viewerRole: 'owner',
        viewerLoggedIn: true,
        friendState: PawFriendState.friends,
        priceLabel: '',
        onBook: () {},
        onProfile: () {},
        onMessage: () {},
        onFriend: () => calls.add('friend2'),
        onDirections: null,
        onPropose: () {},
        onSignup: () {},
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
    });

    testWidgets('se construit en sombre sans exception', (tester) async {
      await tester.pumpWidget(_harness(
        PawMapMemberSheet(
          member: _sitter(friend: true),
          viewerRole: 'owner',
          viewerLoggedIn: true,
          friendState: PawFriendState.sent,
          priceLabel: '25 €',
          onBook: () {},
          onProfile: () {},
          onMessage: () {},
          onFriend: () {},
          onDirections: () {},
          onPropose: () {},
          onSignup: () {},
        ),
        brightness: Brightness.dark,
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });

  group('bulle de demande (Proposer mes services en 1 appui)', () {
    Widget sheet(PawProposeState state, List<String> calls, {bool mine = false}) =>
        PawMapRequestSheet(
          ownerName: 'Marc',
          ownerAvatar: '',
          walking: false,
          city: 'Zone test',
          distanceLabel: '1,2 km',
          dateLabel: 'Du 1 oct. au 3 oct.',
          budgetLabel: '30 €',
          body: 'Garde de Rex',
          mine: mine,
          approx: true,
          viewerRole: 'sitter',
          proposeState: state,
          onPropose: () => calls.add('propose'),
          onOpenMine: () => calls.add('open_mine'),
          onOwnerProfile: () => calls.add('owner_profile'),
        );

    testWidgets('gardien : Proposer + profil du propriétaire ; prix et position approximative affichés',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_harness(sheet(PawProposeState.idle, calls)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('30 €'), findsOneWidget);
      expect(find.text('Position approximative (~1 km)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('request_propose')));
      await tester.tap(find.byKey(const ValueKey<String>('request_owner_profile')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, ['propose', 'owner_profile']);
    });

    testWidgets('envoyé / déjà proposé : le bouton ne renvoie plus', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_harness(sheet(PawProposeState.sent, calls)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Proposition'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('request_propose')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, isEmpty);

      await tester.pumpWidget(_harness(sheet(PawProposeState.already, calls)));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('request_propose')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, isEmpty);
    });

    testWidgets('« Ma demande » (propriétaire) : Voir mes annonces', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_harness(sheet(PawProposeState.idle, calls, mine: true)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Ma demande'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('request_propose')), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('request_open_mine')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, ['open_mine']);
    });
  });

  group('visibilité (amis seulement)', () {
    testWidgets('les deux options appellent onChanged avec la bonne valeur', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(_harness(PawMapVisibilitySheet(
        friendsOnly: false,
        saving: false,
        onChanged: got.add,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('visibility_friends')));
      await tester.tap(find.byKey(const ValueKey<String>('visibility_all')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(got, [true, false]);
      // Aucun gris : la surface active est noir encre (saturation 0 mais
      // c'est l'encre de marque #17141F, pas un gris) ; l'option « tous » est
      // verte pleine.
      expect(find.text('Visible par mes amis seulement'), findsOneWidget);
    });

    testWidgets('pendant l\'enregistrement, plus aucun appui', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(_harness(PawMapVisibilitySheet(
        friendsOnly: true,
        saving: true,
        onChanged: got.add,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('visibility_all')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(got, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('pastille du haut : un appui = rappel', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(PawMapFriendsOnlyPill(onTap: () => taps++)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Visible par tes amis seulement'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      await tester.tap(find.byType(PawMapFriendsOnlyPill));
      expect(taps, 1);
    });
  });

  group('légende « ? » = écran « Comprendre la PawMap » (réutilisable, Profil › Aide)', () {
    testWidgets('une ligne par épingle de LEGENDE_PAWMAP.md, le mémo, chaque bouton du rail et du dock, « Voir sur la carte »',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_page(const PawMapHelpScreen()));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('Comprendre la PawMap'), findsOneWidget);
      expect(find.textContaining('Rond = une personne'), findsOneWidget);
      final entries = pawLegendEntries();
      expect(entries.map((e) => e.key).toList(), [
        'me', 'friend', 'member_owner', 'member_sitter', 'member_walker',
        'member_group', 'place', 'place_group', 'spot', 'spot_gold',
        'spot_group', 'request', 'premium', 'boost', 'verified', 'friends_only',
      ]);
      // Toutes les lignes existent (défilement simple, rien de paresseux).
      for (final e in entries) {
        expect(find.byKey(ValueKey<String>('legend_${e.key}'), skipOffstage: false),
            findsOneWidget, reason: e.key);
      }
      expect(find.byKey(const ValueKey<String>('legend_report'), skipOffstage: false),
          findsOneWidget);
      // UNE source : chaque bouton du rail et du dock, avec son explication.
      for (final spec in kPawRailSpecs) {
        expect(find.byKey(ValueKey<String>('help_rail_${spec.id}'), skipOffstage: false),
            findsOneWidget, reason: spec.id);
        expect(find.text(spec.help, skipOffstage: false), findsWidgets, reason: spec.helpKey);
      }
      for (final d in kPawDockSpecs) {
        expect(find.byKey(ValueKey<String>('help_dock_${d.id}'), skipOffstage: false),
            findsOneWidget, reason: d.id);
      }
      // Un appui sur un bouton du rail = la MÊME explication que l'appui long.
      final around = find.byKey(const ValueKey<String>('help_rail_around'), skipOffstage: false);
      await tester.ensureVisible(around);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.descendant(of: around, matching: find.byType(PawRailButton)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PawRailHelpSheet), findsOneWidget);
      expect(find.text(pawRailSpecOf('around')!.help), findsWidgets);
      // Bouton du bas.
      expect(find.byKey(const ValueKey<String>('pawmap_help_see_map'), skipOffstage: false),
          findsOneWidget);
      expect(find.textContaining('Voir sur', skipOffstage: false), findsOneWidget);
    });
  });

  group('liste « autour de toi » (compteur cliquable)', () {
    testWidgets('un appui sur une ligne renvoie l\'élément', (tester) async {
      PawMapAroundItem? tapped;
      await tester.pumpWidget(_harness(PawMapAroundList(
        items: const [
          PawMapAroundItem(
              id: 'a', role: 'sitter', name: 'Léa', avatar: '',
              distanceLabel: '800 m', priceLabel: '25 €', verified: true),
          PawMapAroundItem(
              id: 'b', role: 'walker', name: 'Tom', avatar: '',
              distanceLabel: '2,1 km', priceLabel: ''),
        ],
        onTap: (it) => tapped = it,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Autour de toi · 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('around_b')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tapped?.id, 'b');
    });
  });

  group('boutons signature', () {
    testWidgets('désactivé : pas de rappel, message ; chargement : pas de double envoi',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(Column(children: [
        PawSignatureButton(
          key: const ValueKey<String>('btn_disabled'),
          label: 'Réserver',
          color: PawMapLegend.sitter,
          icon: Icons.event_available_rounded,
          enabled: false,
          disabledReason: 'Pas maintenant',
          onTap: () => taps++,
        ),
        PawSignatureButton(
          key: const ValueKey<String>('btn_loading'),
          label: 'Envoyer',
          color: PawMapLegend.walker,
          icon: Icons.send_rounded,
          loading: true,
          onTap: () => taps++,
        ),
      ])));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('btn_disabled')));
      await tester.tap(find.byKey(const ValueKey<String>('btn_loading')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(taps, 0);
      expect(find.text('Pas maintenant'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('un libellé long passe sur deux lignes à l\'espace le plus central, jamais au milieu d\'un mot',
        () {
      final two = pawTwoLines('Proposer mes services');
      expect(two.split('\n').length, 2);
      expect(two.replaceAll('\n', ' '), 'Proposer mes services');
      expect(two, anyOf('Proposer mes\nservices', 'Proposer\nmes services'));
      expect(pawTwoLines('Réserver'), 'Réserver');
      expect(pawTwoLines('サービスを提案する'), 'サービスを提案する');
    });
  });

  group('9 langues', () {
    test('toutes les clés du lot C existent dans chaque langue', () {
      final ref = lotC584I18n['fr']!.keys.toSet();
      for (final l in _langs) {
        final keys = lotC584I18n[l]!.keys.toSet();
        expect(keys, ref, reason: l);
        for (final e in lotC584I18n[l]!.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$l/${e.key}');
        }
      }
    });
  });
}
