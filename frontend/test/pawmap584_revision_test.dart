// v584 (révision PawMap du 25/09, retours de Daniel sur le build 583) —
// tests de widgets et de règles pures, point par point :
//   3  bouton principal (52 dp) qui répond au tap, pour les 3 rôles ;
//   4  état vrai d'un ami (en direct / signal perdu / vu il y a) ;
//   6  dialogue occupé : UNE seule roue ;
//   8  tarifs (3 devises × 2 rôles) + barre Réserver · dès X (9 langues, 320/375) ;
//   9  pilule et feuille de suivi (3 états), chaque bouton ;
//   12 puces d'état dans la feuille ;
//   13 découverte guidée : premier lancement seulement, croix « Ne plus montrer » ;
//   14 fiche d'un ami : « Suivre la balade » si partage actif, sinon « vu il y a » ;
//   15 liste d'un groupe ;
//   19 « Voir le profil » : 3 rôles de membre → la bonne fiche.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/pawmap_member_profile_route.dart';
import 'package:hopetsit/views/map/pawmap_rates.dart';
import 'package:hopetsit/views/map/widgets/pawmap_buttons.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/views/service_provider/owner_profile_view_screen.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/service_provider/walker_detail_screen.dart';
import 'package:hopetsit/views/service_provider/widgets/provider_action_bar.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';

const List<String> _langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

void _phone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget child, {String lang = 'fr', bool scroll = true}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: AppTranslations(),
      locale: Locale(lang),
      fallbackLocale: const Locale('en'),
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(
        body: scroll
            ? SingleChildScrollView(child: Align(alignment: Alignment.topLeft, child: child))
            : child,
      ),
    ),
  );
}

PawMapMemberData _member({String role = 'sitter', bool friend = false, String name = 'Léa Martin'}) =>
    PawMapMemberData(
      id: 'u1',
      role: role,
      name: name,
      avatar: '',
      online: true,
      isFriend: friend,
      priceFrom: 25,
      currency: 'EUR',
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(Get.reset);

  group('point 4 — état vrai d\'un ami (règle pure, même seuils que le serveur)', () {
    final now = DateTime(2026, 9, 25, 8);
    test('partage actif et < 2 min → en direct', () {
      expect(friendLiveState(sharing: true, seenAt: now.subtract(const Duration(seconds: 30)), now: now),
          FriendLiveState.live);
      expect(friendLiveState(sharing: true, seenAt: now.subtract(kFriendLiveFresh), now: now),
          FriendLiveState.live);
    });
    test('partage actif, 2 à 10 min → signal perdu', () {
      expect(friendLiveState(sharing: true, seenAt: now.subtract(const Duration(minutes: 5)), now: now),
          FriendLiveState.lost);
    });
    test('plus de 10 min, ou pas de partage → vu il y a (rien de « direct »)', () {
      expect(friendLiveState(sharing: true, seenAt: now.subtract(const Duration(minutes: 11)), now: now),
          FriendLiveState.seen);
      expect(friendLiveState(sharing: false, seenAt: now.subtract(const Duration(seconds: 5)), now: now),
          FriendLiveState.seen);
      expect(friendLiveState(sharing: false, seenAt: now.subtract(const Duration(days: 6)), now: now),
          FriendLiveState.seen);
      expect(friendLiveState(sharing: true, seenAt: null, now: now), FriendLiveState.seen);
    });
    test('FriendPosition lit `sharing` du serveur ; un serveur muet = pas de direct', () {
      final p = FriendPosition.fromJson({
        'userId': 'a', 'role': 'walker', 'lat': -35.0, 'lng': -30.0,
        'at': DateTime.now().toIso8601String(), 'sharing': true,
      });
      expect(p.isLive, isTrue);
      final q = FriendPosition.fromJson({
        'userId': 'b', 'role': 'walker', 'lat': -35.0, 'lng': -30.0,
        'at': DateTime.now().toIso8601String(),
      });
      expect(q.isLive, isFalse);
      expect(q.liveState, FriendLiveState.seen);
    });
  });

  group('point 13 — découverte guidée au PREMIER lancement seulement', () {
    test('règle pure : 1re ouverture → oui ; compte OU appareil l\'a vue → non ; retour d\'onglet → non', () {
      expect(shouldShowPawMapCoach(accountCount: 0, deviceCount: 0, shownThisSession: false), isTrue);
      expect(shouldShowPawMapCoach(accountCount: 1, deviceCount: 0, shownThisSession: false), isFalse);
      expect(shouldShowPawMapCoach(accountCount: 0, deviceCount: 1, shownThisSession: false), isFalse);
      expect(shouldShowPawMapCoach(accountCount: 0, deviceCount: 0, shownThisSession: true), isFalse);
      expect(shouldShowPawMapCoach(accountCount: 3, deviceCount: 3, shownThisSession: false), isFalse);
    });
    testWidgets('la croix « Ne plus montrer » ferme pour de bon', (tester) async {
      _phone(tester);
      var done = 0;
      var next = 0;
      await tester.pumpWidget(_app(
        Stack(children: [PawMapCoach(step: 0, onNext: () => next++, onDone: () => done++)]),
        scroll: false,
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey<String>('coach_close')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(done, 1);
      expect(next, 0);
    });
  });

  group('point 6 — dialogue occupé : UNE seule roue', () {
    testWidgets('bouton principal occupé → un seul CircularProgressIndicator, libellé conservé',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const AppDialogPrimaryButton(
        label: 'Continuer',
        onTap: null,
        busy: true,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
    });
  });

  group('point 8 — tarifs complets, dans la devise du prestataire', () {
    test('gardien : jour / semaine / mois (+ animal en plus), jamais de ligne à 0', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
      const r = PawProviderRates(currency: 'EUR', role: 'sitter', daily: 35, weekly: 220, monthly: 850, hourly: 0);
      final labels = r.lines.map((l) => l.label).toList();
      expect(labels, ['Prix / jour', 'Prix / semaine', 'Prix / mois']);
      expect(r.lines.first.value, contains('35'));
      expect(r.fromLabel, isNotNull);
      expect(r.fromLabel!, contains('35'));
      expect(r.fromLabel!, endsWith('/j'));
      const e = PawProviderRates(currency: 'EUR', role: 'sitter', daily: 30, extraPet: 5);
      expect(e.lines.length, 2);
      expect(e.lines.last.label, 'Animal supplémentaire');
    });
    test('promeneur : 30 min / 1 h / 2 h', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
      const r = PawProviderRates(currency: 'USD', role: 'walker', halfHour: 10, hourly: 18);
      expect(r.lines.map((l) => l.label).toList(), ['Balade 30 min', 'Balade 1 h']);
      expect(r.fromLabel, isNotNull);
      expect(r.fromLabel!, endsWith('/30 min'));
      expect(r.fromLabel!, contains('10'));
      expect(r.fromLabel!, contains('\$'));
    });
    test('3 devises : le symbole suit la devise du prestataire, jamais l\'euro par défaut', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
      for (final (cur, sym) in [('EUR', '€'), ('USD', '\$'), ('GBP', '£')]) {
        final r = PawProviderRates(currency: cur, role: 'sitter', daily: 40);
        expect(r.lines.single.value, contains(sym), reason: cur);
        expect(r.fromLabel!, contains(sym), reason: cur);
      }
    });
    test('aucun tarif → aucune ligne, pas de « dès »', () {
      const r = PawProviderRates(currency: 'EUR', role: 'walker');
      expect(r.isEmpty, isTrue);
      expect(r.fromLabel, isNull);
    });
  });

  group('point 8 — barre Réserver · dès X + Message (fiche gardien / promeneur)', () {
    for (final role in ['sitter', 'walker']) {
      testWidgets('$role : Réserver en premier avec le prix, Message en second ; chaque tap = son rappel',
          (tester) async {
        _phone(tester);
        var book = 0;
        var msg = 0;
        final rates = role == 'walker'
            ? const PawProviderRates(currency: 'GBP', role: 'walker', halfHour: 12)
            : const PawProviderRates(currency: 'EUR', role: 'sitter', daily: 35);
        await tester.pumpWidget(_app(ProviderActionBar(
          role: role,
          rates: rates,
          onBook: () => book++,
          onMessage: () => msg++,
        )));
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
        final book0 = find.byKey(const ValueKey<String>('provider_book'));
        expect(book0, findsOneWidget);
        expect(find.textContaining('Réserver'), findsOneWidget);
        expect(find.textContaining(role == 'walker' ? '12' : '35'), findsOneWidget);
        await tester.tap(book0);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const ValueKey<String>('provider_message')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(book, 1);
        expect(msg, 1);
      });
    }
    testWidgets('un gardien qui regarde un confrère : pas de Réserver, Message seul', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(ProviderActionBar(
        role: 'sitter',
        rates: const PawProviderRates(currency: 'EUR', role: 'sitter', daily: 35),
        canBook: false,
        onBook: () {},
        onMessage: () {},
      )));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(const ValueKey<String>('provider_book')), findsNothing);
      expect(find.byKey(const ValueKey<String>('provider_message')), findsOneWidget);
    });
    for (final width in [320.0, 375.0]) {
      testWidgets('9 langues à $width dp : rien ne déborde', (tester) async {
        for (final lang in _langs) {
          _phone(tester, width: width);
          await tester.pumpWidget(_app(
            ProviderActionBar(
              role: 'walker',
              rates: const PawProviderRates(currency: 'EUR', role: 'walker', halfHour: 10),
              onBook: () {},
              onMessage: () {},
            ),
            lang: lang,
          ));
          await tester.pump(const Duration(milliseconds: 80));
          expect(tester.takeException(), isNull, reason: '$lang @ $width');
          expect(find.byKey(const ValueKey<String>('provider_book')), findsOneWidget);
        }
      });
    }
  });

  group('point 9 — pilule et feuille de suivi (3 états)', () {
    for (final state in PawFollowState.values) {
      testWidgets('pilule ${state.name} : nom + état, un tap = rappel', (tester) async {
        _phone(tester);
        var taps = 0;
        await tester.pumpWidget(_app(PawMapFollowPill(
          name: 'Jose',
          avatar: '',
          role: 'walker',
          state: state,
          agoLabel: '12 s',
          onTap: () => taps++,
        )));
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
        expect(find.text('Jose'), findsOneWidget);
        final expected = switch (state) {
          PawFollowState.live => 'en direct',
          PawFollowState.lost => 'signal perdu',
          PawFollowState.paused => 'en pause',
        };
        expect(find.textContaining(expected), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey<String>('pawmap_follow_pill')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(taps, 1);
      });
    }
    testWidgets('feuille : Reprendre / Recentrer, Itinéraire, Message, Arrêter de suivre',
        (tester) async {
      _phone(tester);
      final calls = <String>[];
      await tester.pumpWidget(_app(PawMapFollowSheet(
        name: 'Jose',
        avatar: '',
        role: 'owner',
        state: PawFollowState.paused,
        agoLabel: '1 min',
        onResume: () => calls.add('resume'),
        onStop: () => calls.add('stop'),
        onDirections: () => calls.add('directions'),
        onMessage: () => calls.add('message'),
      )));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Reprendre le suivi'), findsOneWidget);
      expect(find.text('Arrêter de suivre'), findsOneWidget);
      for (final k in ['follow_sheet_resume', 'follow_sheet_directions', 'follow_sheet_message', 'follow_sheet_stop']) {
        await tester.ensureVisible(find.byKey(ValueKey<String>(k)));
        await tester.tap(find.byKey(ValueKey<String>(k)));
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(calls, ['resume', 'directions', 'message', 'stop']);
    });
  });

  group('point 12 — puces d\'état dans la feuille (jamais sur un bouton du haut)', () {
    testWidgets('« Amis seulement » et « En direct » répondent au tap', (tester) async {
      _phone(tester);
      var a = 0;
      var b = 0;
      await tester.pumpWidget(_app(Wrap(children: [
        PawMapStatusChip(
          key: const ValueKey<String>('c1'),
          label: 'Amis seulement',
          icon: Icons.visibility_off_rounded,
          color: PawMapLegend.ink,
          onTap: () => a++,
        ),
        PawMapStatusChip(
          key: const ValueKey<String>('c2'),
          label: 'En direct · 3h58',
          icon: Icons.podcasts_rounded,
          color: PawMapLegend.pawFollow,
          breathing: true,
          onTap: () => b++,
        ),
      ])));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byKey(const ValueKey<String>('c1')));
      await tester.tap(find.byKey(const ValueKey<String>('c2')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(a, 1);
      expect(b, 1);
    });
  });

  group('point 14 — fiche d\'un ami : suivre seulement si le partage est actif', () {
    testWidgets('ami en direct → « Suivre la balade · en direct » principal, Réserver en second', (tester) async {
      _phone(tester);
      final calls = <String>[];
      await tester.pumpWidget(_app(PawMapMemberSheet(
        member: _member(friend: true),
        viewerRole: 'owner',
        viewerLoggedIn: true,
        friendState: PawFriendState.friends,
        priceLabel: '25 €',
        liveState: PawFollowState.live,
        onFollow: () => calls.add('follow'),
        onBook: () => calls.add('book'),
        onProfile: () => calls.add('profile'),
        onMessage: () => calls.add('message'),
        onFriend: () => calls.add('friend'),
        onDirections: () => calls.add('directions'),
        onPropose: () => calls.add('propose'),
        onSignup: () => calls.add('signup'),
      )));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Suivre la balade · en direct'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('member_primary_follow')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.byKey(const ValueKey<String>('member_book_secondary')));
      await tester.tap(find.byKey(const ValueKey<String>('member_book_secondary')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, ['follow', 'book']);
    });
    testWidgets('ami sans partage → « Vu il y a 3 j · ne partage pas », explication, pas de Suivre',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(PawMapMemberSheet(
        member: _member(role: 'owner', friend: true, name: 'Jose'),
        viewerRole: 'owner',
        viewerLoggedIn: true,
        friendState: PawFriendState.friends,
        priceLabel: '',
        seenLabel: '3 j',
        onBook: () {},
        onProfile: () {},
        onMessage: () {},
        onFriend: () {},
        onDirections: null,
        onPropose: () {},
        onSignup: () {},
      )));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(const ValueKey<String>('member_seen_line')), findsOneWidget);
      expect(find.textContaining('Vu 3 j'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('member_primary_follow')), findsNothing);
    });
    testWidgets('gardien : les tarifs (jour / semaine) s\'affichent avant Réserver', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(PawMapMemberSheet(
        member: _member(),
        viewerRole: 'owner',
        viewerLoggedIn: true,
        friendState: PawFriendState.idle,
        priceLabel: '25 €',
        rates: const [
          PawMapRateLine(label: 'Prix / jour', value: '25,00 €'),
          PawMapRateLine(label: 'Prix / semaine', value: '150,00 €'),
        ],
        onBook: () {},
        onProfile: () {},
        onMessage: () {},
        onFriend: () {},
        onDirections: null,
        onPropose: () {},
        onSignup: () {},
      )));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(const ValueKey<String>('member_rates')), findsOneWidget);
      expect(find.text('Prix / semaine'), findsOneWidget);
      final ratesY = tester.getTopLeft(find.byKey(const ValueKey<String>('member_rates'))).dy;
      final bookY = tester.getTopLeft(find.byKey(const ValueKey<String>('member_primary_book'))).dy;
      expect(ratesY, lessThan(bookY), reason: 'les tarifs AVANT le bouton Réserver');
    });
  });

  group('point 7 — prénom court sous le rond (jamais un nom qui déborde)', () {
    test('premier mot, 12 caractères au plus, puis « … »', () {
      expect(pawMapShortName('Camille Durand'), 'Camille');
      expect(pawMapShortName('  Jose Martínez '), 'Jose');
      expect(pawMapShortName('dadaciao84+testwalker'), 'dadaciao84+…');
      expect(pawMapShortName('Anne-Sophie'), 'Anne-Sophie');
      expect(pawMapShortName('').length, 0);
    });
  });

  group('point 15 — liste d\'un groupe', () {
    testWidgets('un tap sur une ligne renvoie l\'élément', (tester) async {
      _phone(tester);
      PawMapClusterItem? opened;
      await tester.pumpWidget(_app(PawMapClusterList(
        title: '3 membres ici',
        items: const [
          PawMapClusterItem(id: 'm:1', title: 'Léa', subtitle: 'Gardien', color: PawMapLegend.sitter),
          PawMapClusterItem(id: 'm:2', title: 'Marc', subtitle: 'Promeneur', color: PawMapLegend.walker),
          PawMapClusterItem(id: 'm:3', title: 'Ana', subtitle: 'Propriétaire', color: PawMapLegend.owner),
        ],
        onOpen: (it) => opened = it,
      )));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byKey(const ValueKey<String>('cluster_item_m:2')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(opened?.title, 'Marc');
    });
  });

  group('point 19 — « Voir le profil » selon le rôle du membre (9 cas)', () {
    test('gardien → fiche gardien, promeneur → fiche promeneur, propriétaire / inconnu → fiche propriétaire',
        () {
      for (final viewer in ['owner', 'sitter', 'walker']) {
        // Le rôle du SPECTATEUR ne change rien : seul le rôle du membre compte.
        expect(pawMapMemberProfilePage(id: 'x', role: 'sitter', name: viewer), isA<ServiceProviderDetailScreen>());
        expect(pawMapMemberProfilePage(id: 'x', role: 'walker', name: viewer), isA<WalkerDetailScreen>());
        expect(pawMapMemberProfilePage(id: 'x', role: 'owner', name: viewer), isA<OwnerProfileViewScreen>());
      }
      expect(pawMapMemberProfilePage(id: 'x', role: ''), isA<OwnerProfileViewScreen>());
      expect(pawMapMemberProfilePage(id: 'x', role: 'Sitter'), isA<ServiceProviderDetailScreen>());
    });
  });

  group('point 3 — bouton principal de la feuille : 52 dp, répond au tap (3 rôles)', () {
    for (final role in ['owner', 'sitter', 'walker']) {
      testWidgets('$role : le bouton dans la feuille en position basse reçoit le tap', (tester) async {
        _phone(tester);
        final ctl = DraggableScrollableController();
        var taps = 0;
        final color = PawMapLegend.roleColor(role);
        await tester.pumpWidget(ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('fr'),
            home: Scaffold(
              body: LayoutBuilder(builder: (ctx, c) {
                return Stack(children: [
                  Positioned.fill(
                    child: PawMapSheet(
                      controller: ctl,
                      availableHeight: c.maxHeight,
                      peekHeight: 100.h,
                      header: SizedBox(
                        height: 52.h,
                        child: PawSignatureButton(
                          key: const ValueKey<String>('pawmap_primary'),
                          label: role == 'owner' ? 'Publier ma demande' : 'Partager ma balade en direct',
                          icon: Icons.campaign_rounded,
                          color: color,
                          onTap: () => taps++,
                        ),
                      ),
                      children: [for (var i = 0; i < 8; i++) SizedBox(height: 60.h)],
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 200));
        final btn = find.byKey(const ValueKey<String>('pawmap_primary'));
        expect(btn, findsOneWidget);
        final size = tester.getSize(btn);
        expect(size.height, lessThanOrEqualTo(56), reason: 'plus petit qu\'avant (≈ 52 dp)');
        expect(size.height, greaterThanOrEqualTo(48));
        await tester.tap(btn);
        await tester.pump(const Duration(milliseconds: 200));
        expect(taps, 1, reason: 'le tap doit ouvrir l\'action');
        // Le bouton est entier à l'écran (jamais sous le bord bas).
        final rect = tester.getRect(btn);
        expect(rect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
      });
    }
  });

  group('9 langues — toutes les clés 584b existent partout', () {
    test('pawmap584bI18n : mêmes clés dans les 9 langues', () {
      final all = AppTranslations().keys;
      final fr = all[all.keys.firstWhere((k) => k == 'fr' || k.startsWith('fr_'))]!;
      final keys = fr.keys.where((k) => k.startsWith('pawmap_follow_') || k.startsWith('pawmap584_') || k.startsWith('pawmap_rate_')).toList();
      expect(keys, isNotEmpty);
      for (final l in _langs) {
        final key = all.keys.firstWhere((k) => k == l || k.startsWith('${l}_'), orElse: () => '');
        final m = key.isEmpty ? null : all[key];
        expect(m, isNotNull, reason: l);
        for (final k in keys) {
          expect(m!.containsKey(k), isTrue, reason: '$l manque $k');
        }
      }
    });
  });
}
