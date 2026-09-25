// v588 (25/09/2026) — Daniel : « dans la liste d'amis de l'app, quand je
// clique sur sa photo, ça ne me renvoie pas vers lui sur la map ».
//
//   · appui sur la PHOTO ou la LIGNE d'un ami → ONGLET PawMap (menu conservé,
//     `requestedTab`) + cible confiée à la carte (`pawMapPendingFriend`) :
//     direct s'il partage, sinon position de profil (couche amis 587) ;
//   · ami « Masqué » ou sans position → pastille « Cet ami n'est pas visible
//     sur la carte », aucun changement d'onglet ;
//   · « Profil » reste un bouton séparé (fiche complète) ;
//   · 9 langues pour les nouvelles phrases.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/localization/v565/friends588_i18n.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/friends/tabs/family_tab.dart';
import 'package:hopetsit/views/friends/tabs/my_friends_tab.dart';
import 'package:hopetsit/views/map/pawmap_friend_focus.dart';
import 'package:hopetsit/views/map/widgets/pawmap_signal.dart';

import 'lotd_harness.dart';

const _langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const _notOnMapFr = "Cet ami n'est pas visible sur la carte";

Friendship _friend(String id, String name,
        {List<double>? at, String vis = 'all', String model = 'Walker'}) =>
    Friendship.fromJson(<String, dynamic>{
      'id': 'fs-$id',
      'status': 'accepted',
      'initiatedByMe': true,
      'mySharePosition': true,
      'theirSharePosition': true,
      'other': <String, dynamic>{
        'id': id,
        'model': model,
        'name': name,
        'avatar': '',
        'personIds': <String>[id],
        'mapVisibility': vis,
        'location': at == null ? null : <String, dynamic>{'coordinates': at},
        'approx': true,
        'approxKm': 1,
        'positionSource': at == null ? null : 'home',
      },
    });

FriendPosition _live(String id, {bool sharing = true, Duration ago = Duration.zero}) =>
    FriendPosition(
      userId: id,
      role: 'walker',
      latitude: 45.76,
      longitude: 4.83,
      at: DateTime.now().subtract(ago),
      lastSeenAt: DateTime.now().subtract(ago),
      sharing: sharing,
    );

void _resetMapState() {
  requestedTab.value = -1;
  pawMapPendingFriend.value = null;
  navWrapperMounted.value = false;
  PawSignal.hide();
}

void main() {
  group('cible de l\'ami (fonction pure, couche amis 587)', () {
    test('position de profil floutée quand il ne partage pas', () {
      final f = pawMapFriendFocusFor(_friend('w-ana', 'Ana', at: <double>[2.40, 48.84]).other!)!;
      expect(f.lat, 48.84);
      expect(f.lng, 2.40);
      expect(f.live, isFalse);
      expect(f.role, 'walker');
      expect(kPawMapFriendFocusZoom, 16);
    });

    test('le direct prime (partage actif) → suivi', () {
      final f = pawMapFriendFocusFor(_friend('w-ana', 'Ana', at: <double>[2.40, 48.84]).other!,
          live: _live('w-ana'))!;
      expect(f.live, isTrue);
      expect(f.lat, 45.76);
      expect(f.lng, 4.83);
    });

    test('une vieille position sans partage ne compte pas comme direct', () {
      final f = pawMapFriendFocusFor(_friend('w-ana', 'Ana', at: <double>[2.40, 48.84]).other!,
          live: _live('w-ana', sharing: false, ago: const Duration(minutes: 30)))!;
      expect(f.live, isFalse);
      expect(f.lat, 48.84);
    });

    test('Masqué ou sans position → null', () {
      expect(pawMapFriendFocusFor(_friend('s-hid', 'Hid', at: <double>[2.3, 48.8], vis: 'hidden').other!), isNull);
      expect(pawMapFriendFocusFor(_friend('s-none', 'None').other!), isNull);
    });
  });

  group('écran Mes amis : appui sur un ami', () {
    setUp(() async {
      await lotdSetUp(role: 'owner');
      lotdResponder = (http.Request req) => const <String, dynamic>{};
      _resetMapState();
    });
    tearDown(_resetMapState);

    Future<void> pumpCard(WidgetTester tester, Friendship f) async {
      lotdPhone(tester);
      final c = Get.put(FriendController());
      await tester.pumpWidget(lotdApp(Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: FriendCard(
            friendship: f,
            controller: c,
            accent: const Color(0xFFF06AA0),
            isFamily: false,
            online: false,
          ),
        ),
      )));
      await lotdSettle(tester, frames: 2);
    }

    testWidgets('photo d\'un ami avec position → onglet PawMap + cible', (tester) async {
      navWrapperMounted.value = true;
      await pumpCard(tester, _friend('w-ana', 'Ana', at: <double>[2.40, 48.84]));
      await tester.tap(find.byKey(const ValueKey('friend_photo_w-ana')));
      await tester.pump();
      expect(requestedTab.value, kPawMapTabIndex);
      final target = pawMapPendingFriend.value;
      expect(target, isNotNull);
      expect(target!.userId, 'w-ana');
      expect(target.lat, 48.84);
      expect(target.lng, 2.40);
      expect(find.text(_notOnMapFr), findsNothing);
    });

    testWidgets('appui sur la ligne (nom) → même chose', (tester) async {
      navWrapperMounted.value = true;
      await pumpCard(tester, _friend('w-ana', 'Ana', at: <double>[2.40, 48.84]));
      await tester.tap(find.text('Ana'));
      await tester.pump();
      expect(requestedTab.value, kPawMapTabIndex);
      expect(pawMapPendingFriend.value?.userId, 'w-ana');
    });

    testWidgets('ami Masqué → pastille, pas de changement d\'onglet', (tester) async {
      navWrapperMounted.value = true;
      await pumpCard(tester, _friend('s-hid', 'Hid', at: <double>[2.3, 48.8], vis: 'hidden'));
      await tester.tap(find.byKey(const ValueKey('friend_photo_s-hid')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(_notOnMapFr), findsOneWidget);
      expect(requestedTab.value, -1);
      expect(pawMapPendingFriend.value, isNull);
      await tester.pump(const Duration(seconds: 3)); // la pastille s'efface
      await tester.pumpAndSettle();
    });

    testWidgets('« Profil » reste un bouton séparé (pas la carte)', (tester) async {
      navWrapperMounted.value = true;
      await pumpCard(tester, _friend('w-ana', 'Ana', at: <double>[2.40, 48.84]));
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('PawFamily : photo d\'un membre ami → onglet PawMap', (tester) async {
      navWrapperMounted.value = true;
      lotdPhone(tester);
      final c = Get.put(FriendController());
      await tester.pumpWidget(lotdApp(Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: FamilyMemberCard(
            member: const <String, dynamic>{'id': 'o-mum', 'name': 'Maman', 'role': 'owner'},
            controller: c,
            isHolder: false,
            online: null,
          ),
        ),
      )));
      await lotdSettle(tester, frames: 2);
      // Après le chargement initial du contrôleur (réponse vide du faux serveur).
      c.friends.assignAll(<Friendship>[_friend('o-mum', 'Maman', at: <double>[2.35, 48.85], model: 'Owner')]);
      await tester.tap(find.byKey(const ValueKey('friend_photo_o-mum')));
      await tester.pump();
      expect(requestedTab.value, kPawMapTabIndex);
      expect(pawMapPendingFriend.value?.lat, 48.85);
    });
  });

  test('9 langues : toutes les clés, aucune vide, aucun anglais recopié', () {
    final en = friends588I18n['en']!;
    for (final l in _langs) {
      final m = friends588I18n[l];
      expect(m, isNotNull, reason: l);
      expect(m!.keys.toSet(), en.keys.toSet(), reason: l);
      for (final k in m.keys) {
        expect(m[k]!.trim(), isNotEmpty, reason: '$l $k');
        if (l != 'en') expect(m[k] == en[k], isFalse, reason: '$l $k');
      }
    }
  });

  test('la PawMap écoute la demande et la feuille « Amis en direct » vole aussi', () {
    final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
    expect(src.contains('ever<PawMapFriendFocus?>(pawMapPendingFriend'), isTrue);
    expect(src.contains('CameraUpdate.newLatLngZoom(at, kPawMapFriendFocusZoom)'), isTrue);
    final sheet = src.substring(src.indexOf('Widget _liveFriendRow('));
    expect(sheet.substring(0, 3000).contains('_focusFriend(focus)'), isTrue);
    // Plus aucun écran PawMap empilé depuis la liste d'amis.
    final ui = File('lib/views/friends/tabs/friends_ui.dart').readAsStringSync();
    expect(ui.contains('Get.off(() => PawMapScreen('), isFalse);
  });
}
