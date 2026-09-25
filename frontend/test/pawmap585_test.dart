// v585 (25/09/2026) — retours de Daniel sur le build 584 (Samsung réel).
//   bug 1 — feuille PawMap : bouton principal et glissement, barre système
//           annoncée à 0 (Samsung bord à bord) ET à 48 (barre 3 boutons),
//           3 rôles, avec le VRAI menu du bas (PawTabBar) dans le Scaffold ;
//           l'en-tête (bouton + puce d'état) jamais coupé ni sous le menu.
//   bug 2 — ami reconnu sur tous les profils : drapeau serveur + personIds.
//   bug 4 — fiche d'un ami : « Message » en principal, jamais « Ajouter en ami ».
//   bug 5/7 — une personne à plusieurs rôles : une ligne par rôle ; un groupe
//           superposé ouvre la liste au lieu de zoomer.
//   bug 10 — garde-fou : aucune GoogleMap sans `mapToolbarEnabled: false`, et
//           aucun lien google.com/maps dans l'app.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_buttons.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';

Widget _app(Widget home) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('en'),
        theme: ThemeData(brightness: Brightness.light),
        home: home,
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() {
    Get.reset();
    debugBottomInsetForceAndroid = null;
  });

  group('bug 1 — feuille au-dessus du VRAI menu, barre système 0 et 48', () {
    for (final inset in [0.0, 48.0]) {
      for (final role in ['owner', 'sitter', 'walker']) {
        testWidgets('$role, inset $inset : bouton tapé, feuille glissée, en-tête entier',
            (tester) async {
          tester.view.physicalSize = const Size(412, 915); // Samsung A5x / S2x
          tester.view.devicePixelRatio = 1.0;
          tester.view.viewPadding = FakeViewPadding(bottom: inset, top: 24);
          tester.view.padding = FakeViewPadding(bottom: inset, top: 24);
          addTearDown(tester.view.reset);
          debugBottomInsetForceAndroid = true;
          final ctl = DraggableScrollableController();
          var taps = 0;
          var chipTaps = 0;
          final roleColor = PawMapLegend.roleColor(role);
          await tester.pumpWidget(_app(Builder(builder: (context) {
            final vp = MediaQuery.of(context).viewPadding.bottom;
            final menuH = pawTabBarTotalHeight(vp);
            return Scaffold(
              extendBody: true,
              body: LayoutBuilder(builder: (ctx, c) {
                final avail = c.maxHeight - menuH;
                return Stack(children: [
                  Positioned.fill(child: Container(color: const Color(0xFFDDEEDD))),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: menuH,
                    child: PawMapSheet(
                      controller: ctl,
                      availableHeight: avail,
                      // même calcul que l'écran (poignée + en-tête + air)
                      peekHeight: 8.h + 5.h + 10.h + 52.h + 40.h + 12.h,
                      header: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 52.h,
                            child: PawSignatureButton(
                              key: const ValueKey<String>('pawmap_primary'),
                              label: role == 'owner'
                                  ? 'Publier ma demande'
                                  : 'Partager ma balade en direct',
                              icon: Icons.campaign_rounded,
                              color: roleColor,
                              onTap: () => taps++,
                            ),
                          ),
                          SizedBox(
                            height: 40.h,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                key: const ValueKey<String>('pawmap_status_friends_only'),
                                onTap: () => chipTaps++,
                                child: const Chip(label: Text('Amis seulement')),
                              ),
                            ),
                          ),
                        ],
                      ),
                      children: [for (var i = 0; i < 10; i++) SizedBox(height: 60.h)],
                    ),
                  ),
                ]);
              }),
              bottomNavigationBar: PawTabBar(
                currentIndex: 2,
                onTap: (_) {},
                role: role == 'sitter'
                    ? PawNavRole.sitter
                    : (role == 'walker' ? PawNavRole.walker : PawNavRole.owner),
                systemInset: vp,
                labels: const ['Accueil', 'Chat', 'PawMap', 'Réservations', 'Profil'],
              ),
            );
          })));
          await tester.pump(const Duration(milliseconds: 300));
          final btn = find.byKey(const ValueKey<String>('pawmap_primary'));
          final chip = find.byKey(const ValueKey<String>('pawmap_status_friends_only'));
          final barTop = tester.getTopLeft(find.byType(PawTabBar)).dy;
          // L'en-tête est ENTIER au-dessus du menu (puce comprise).
          expect(tester.getRect(btn).bottom, lessThanOrEqualTo(barTop));
          expect(tester.getRect(chip).bottom, lessThanOrEqualTo(barTop),
              reason: 'la puce « Amis seulement » ne passe plus sous le menu');
          // Le menu n'intercepte rien au-dessus de sa pilule, hors patte.
          await tester.tapAt(tester.getRect(btn).bottomLeft + const Offset(40, -3));
          await tester.pump(const Duration(milliseconds: 200));
          expect(taps, 1, reason: 'bas du bouton, côté gauche');
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 200));
          expect(taps, 2);
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 200));
          expect(chipTaps, 1);
          // Glissement vers le haut depuis le bouton : la feuille monte.
          final before = ctl.size;
          await tester.drag(btn, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(ctl.size, greaterThan(before + 0.1), reason: 'la feuille glisse vers le haut');
        });
      }
    }
  });


  group('bug 1 — CAUSE : la PawMap se reconstruit PENDANT le glissement', () {
    for (final role in ['owner', 'sitter', 'walker']) {
      testWidgets('$role : 3 reconstructions pendant le geste, la feuille monte quand même',
          (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final ctl = DraggableScrollableController();
        late StateSetter rebuild;
        var n = 0;
        await tester.pumpWidget(_app(Scaffold(
          body: StatefulBuilder(builder: (ctx, setS) {
            rebuild = setS;
            n++;
            return LayoutBuilder(builder: (ctx, c) => Stack(children: [
                  Positioned.fill(
                    child: PawMapSheet(
                      controller: ctl,
                      availableHeight: c.maxHeight,
                      peekHeight: 120,
                      // Nouvelle instance à CHAQUE reconstruction, comme l'écran.
                      header: SizedBox(
                        height: 52,
                        child: PawSignatureButton(
                          key: const ValueKey<String>('pawmap_primary'),
                          label: 'Bouton $n',
                          icon: Icons.campaign_rounded,
                          color: PawMapLegend.roleColor(role),
                          onTap: () {},
                        ),
                      ),
                      children: [for (var i = 0; i < 10; i++) const SizedBox(height: 60)],
                    ),
                  ),
                ]));
          }),
        )));
        await tester.pump(const Duration(milliseconds: 200));
        final low = ctl.size;
        final g = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey<String>('pawmap_primary'))));
        for (var i = 0; i < 6; i++) {
          await g.moveBy(const Offset(0, -40));
          await tester.pump(const Duration(milliseconds: 16));
          if (i.isEven) rebuild(() {}); // marqueurs, sockets, seuil « bas »…
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await tester.pumpAndSettle();
        expect(ctl.size, greaterThan(low + 0.15),
            reason: 'avant v585 : retour au cran bas à chaque reconstruction');
      });
    }
  });


  group('bug 1 — cran au lâcher (dans le sens du geste)', () {
    final stops = pawMapSheetStops(0.14, 0.46, 0.86);
    test('un petit glissement vers le haut, lâché sans élan → cran du milieu', () {
      expect(pawMapSheetSettle(start: 0.14, now: 0.21, stops: stops), 0.46);
    });
    test('au-delà du milieu → en haut ; vers le bas → cran inférieur', () {
      expect(pawMapSheetSettle(start: 0.14, now: 0.7, stops: stops), 0.86);
      // Grand geste (> 25 %) : tout en haut d'un coup.
      expect(pawMapSheetSettle(start: 0.14, now: 0.42, stops: stops), 0.86);
      expect(pawMapSheetSettle(start: 0.86, now: 0.8, stops: stops), 0.46);
      expect(pawMapSheetSettle(start: 0.86, now: 0.2, stops: stops), 0.14);
    });
    test('un tap ne bouge rien', () {
      expect(pawMapSheetSettle(start: 0.14, now: 0.14, stops: stops), isNull);
    });
  });


  group('bug 1 — CAUSE : inset bas lu DANS le body d\'un Scaffold extendBody', () {
    testWidgets('barre à 3 boutons (48) : MediaQuery du body = 0, fenêtre = 48', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);
      double? mqBody;
      double? win;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: Builder(builder: (ctx) {
            mqBody = MediaQuery.of(ctx).viewPadding.bottom;
            win = windowBottomViewPadding(ctx);
            return const SizedBox.expand();
          }),
          bottomNavigationBar: const SizedBox(height: 189),
        ),
      ));
      expect(mqBody, 0, reason: 'ce que lisait la PawMap v584 (feuille 48 dp trop bas)');
      expect(win, 48, reason: 'ce que lit le menu du bas, et désormais la feuille');
    });
  });


  group('bug 1 — position HAUTE : le dernier bouton du dock est entier au-dessus du menu', () {
    for (final size in [const Size(320, 640), const Size(375, 812), const Size(412, 915)]) {
      for (final inset in [0.0, 48.0]) {
        testWidgets('${size.width.toInt()} dp, inset $inset', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          tester.view.viewPadding = FakeViewPadding(bottom: inset, top: 24);
          tester.view.padding = FakeViewPadding(bottom: inset, top: 24);
          addTearDown(tester.view.reset);
          final ctl = DraggableScrollableController();
          await tester.pumpWidget(_app(Builder(builder: (context) {
            final menuH = pawTabBarTotalHeight(windowBottomViewPadding(context));
            return Scaffold(
              extendBody: true,
              body: LayoutBuilder(builder: (ctx, c) => Stack(children: [
                    Positioned(
                      left: 0, right: 0, top: 0, bottom: menuH,
                      child: PawMapSheet(
                        controller: ctl,
                        availableHeight: c.maxHeight - menuH,
                        peekHeight: 130,
                        highFraction: 0.86,
                        header: const SizedBox(height: 52, child: Placeholder()),
                        children: [
                          for (var i = 0; i < 14; i++) const SizedBox(height: 60),
                          const SizedBox(
                              key: ValueKey<String>('dock_last'),
                              height: 56,
                              child: ColoredBox(color: Colors.orange)),
                        ],
                      ),
                    ),
                  ])),
              bottomNavigationBar: PawTabBar(
                currentIndex: 2,
                onTap: (_) {},
                role: PawNavRole.owner,
                systemInset: windowBottomViewPadding(context),
                labels: const ['A', 'B', 'C', 'D', 'E'],
              ),
            );
          })));
          await tester.pump(const Duration(milliseconds: 200));
          ctl.jumpTo(0.86);
          await tester.pumpAndSettle();
          // Défile la feuille jusqu'au bout.
          for (var i = 0; i < 6; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -400));
            await tester.pumpAndSettle();
          }
          final barTop = tester.getTopLeft(find.byType(PawTabBar)).dy;
          final last = tester.getRect(find.byKey(const ValueKey<String>('dock_last')));
          expect(last.bottom, lessThanOrEqualTo(barTop), reason: 'sous le menu');
          expect(last.top, greaterThanOrEqualTo(0));
        });
      }
    }
  });

  group('bug 2 — ami reconnu sur tous les profils', () {
    test('FriendProfile.matchesId : id de l\'amitié OU l\'un de ses autres rôles', () {
      final f = FriendProfile.fromJson({
        'id': 'john_owner',
        'model': 'Owner',
        'name': 'john C',
        'personIds': ['john_owner', 'john_sitter'],
      });
      expect(f.matchesId('john_owner'), isTrue);
      expect(f.matchesId('JOHN_SITTER'), isTrue);
      expect(f.matchesId('autre'), isFalse);
    });
    test('le drapeau serveur prime : jamais « Ajouter en ami » pour un ami', () {
      expect(
          pawMapRelationState(serverFriend: true, isFriend: false, sent: false, incoming: false),
          PawFriendState.friends);
      expect(
          pawMapRelationState(serverFriend: false, isFriend: false, sent: true, incoming: false),
          PawFriendState.sent);
      expect(
          pawMapRelationState(serverFriend: false, isFriend: false, sent: false, incoming: false),
          PawFriendState.idle);
    });
  });

  group('bug 4 — fiche courte d\'un membre', () {
    Future<List<String>> pump(WidgetTester tester, PawMapMemberData m, PawFriendState st,
        {bool directions = true}) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await tester.pumpWidget(_app(Scaffold(
          body: SingleChildScrollView(
              child: PawMapMemberSheet(
        member: m,
        viewerRole: 'walker',
        viewerLoggedIn: true,
        friendState: st,
        priceLabel: m.isProvider ? '25 €' : '',
        onBook: () => calls.add('book'),
        onProfile: () => calls.add('profile'),
        onMessage: () => calls.add('message'),
        onFriend: () => calls.add('friend'),
        onDirections: directions ? () => calls.add('directions') : null,
        onPropose: () => calls.add('propose'),
        onSignup: () => calls.add('signup'),
      )))));
      await tester.pump(const Duration(milliseconds: 100));
      return calls;
    }

    PawMapMemberData member(String role, {bool friend = false}) => PawMapMemberData(
          id: 'john_owner',
          role: role,
          name: 'john C',
          avatar: '',
          online: false,
          isFriend: friend,
          priceFrom: role == 'owner' ? 0 : 25,
          currency: 'EUR',
        );

    testWidgets('ami propriétaire : Message (principal) + Itinéraire + Voir le profil, pas d\'Ajouter en ami',
        (tester) async {
      final calls = await pump(tester, member('owner', friend: true), PawFriendState.friends);
      expect(find.text('Ajouter en ami'), findsNothing);
      expect(find.byKey(const ValueKey<String>('member_primary_message')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('member_message')), findsNothing,
          reason: 'pas deux boutons Message');
      await tester.tap(find.byKey(const ValueKey<String>('member_primary_message')));
      await tester.ensureVisible(find.byKey(const ValueKey<String>('member_directions')));
      await tester.tap(find.byKey(const ValueKey<String>('member_directions')));
      await tester.ensureVisible(find.byKey(const ValueKey<String>('member_profile')));
      await tester.tap(find.byKey(const ValueKey<String>('member_profile')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, ['message', 'directions', 'profile']);
    });
    testWidgets('inconnu propriétaire : Ajouter en ami + Message', (tester) async {
      await pump(tester, member('owner'), PawFriendState.idle);
      expect(find.byKey(const ValueKey<String>('member_primary_friend')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('member_message')), findsOneWidget);
    });
    testWidgets('gardien ami : Réserver + Déjà amis + Message + Itinéraire + Voir le profil',
        (tester) async {
      final calls = await pump(tester, member('sitter', friend: true), PawFriendState.friends);
      for (final k in ['member_primary_book', 'member_friend', 'member_message', 'member_directions', 'member_profile']) {
        expect(find.byKey(ValueKey<String>(k)), findsOneWidget, reason: k);
      }
      expect(find.text('Ajouter en ami'), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('member_primary_book')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, ['book']);
    });
  });

  group('bug 5/7 — une personne, plusieurs rôles', () {
    final john = <String, dynamic>{
      'id': 'john_sitter',
      '_role': 'sitter',
      'name': 'john C',
      'location': {'coordinates': [-1.13, 37.98]},
      'personIds': ['john_sitter', 'john_owner'],
      'roles': [
        {'id': 'john_sitter', 'role': 'sitter', 'priceFrom': 20},
        {'id': 'john_owner', 'role': 'owner', 'priceFrom': 0},
      ],
    };
    test('une ligne par rôle, fiche du bon rôle (id + rôle), jamais redéveloppée', () {
      final lines = pawMapExpandRoles(john);
      expect(lines.map((l) => '${l['id']}:${l['_role']}'), ['john_sitter:sitter', 'john_owner:owner']);
      expect(lines.first['priceFrom'], 20);
      expect(pawMapExpandRoles(lines.first), hasLength(1));
      expect(pawMapPersonIds(lines.last), containsAll(['john_sitter', 'john_owner']));
    });
    test('un seul rôle : inchangé', () {
      expect(pawMapExpandRoles({'id': 'a', '_role': 'walker'}), hasLength(1));
    });
    test('groupe superposé → la liste ; points séparés → le zoom', () {
      const a = LatLng(37.98, -1.13);
      expect(pawMapClusterIsStacked([a, const LatLng(37.98005, -1.13005)]), isTrue);
      expect(pawMapClusterIsStacked([a, const LatLng(37.99, -1.13)]), isFalse);
      // Même personne vue par deux couches, à 1 km : la liste quand même.
      final other = {...john, 'id': 'john_owner', 'personIds': ['john_owner', 'john_sitter']};
      expect(pawMapSamePerson([john, other]), isTrue);
      expect(pawMapSamePerson([john, {'id': 'x'}]), isFalse);
    });
  });

  group('bug 10 — Google Maps jamais ouvert depuis l\'app', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    test('toute GoogleMap( porte mapToolbarEnabled: false', () {
      final bad = <String>[];
      for (final f in files) {
        final src = f.readAsStringSync();
        var i = src.indexOf(RegExp(r'\bGoogleMap\('));
        while (i >= 0) {
          final lineStart = src.lastIndexOf('\n', i) + 1;
          final isComment = src.substring(lineStart, i).trim().startsWith('//');
          if (!isComment) {
            final window = src.substring(i, (i + 1500).clamp(0, src.length));
            if (!window.contains('mapToolbarEnabled: false')) bad.add('${f.path}@$i');
          }
          i = src.indexOf(RegExp(r'\bGoogleMap\('), i + 10);
        }
      }
      expect(bad, isEmpty, reason: 'barre native « ouvrir dans Google Maps »');
    });
    test('aucun lien google.com/maps dans l\'app', () {
      final bad = files
          .where((f) => f.readAsStringSync().contains('google.com/maps'))
          .map((f) => f.path)
          .toList();
      expect(bad, isEmpty);
    });
  });
}
