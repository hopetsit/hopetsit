// 610 (PAM, 04/10/2026) — Daniel : « si j'ai une demande d'ami, que je puisse
// aussi la voir sur la PawMap » et « rechercher des amis sur la PawMap ».
//   · pastille = nombre de demandes reçues ;
//   · carte « X veut être ton ami » ; Accepter → elle disparaît et l'ami est
//     ajouté ; fermée → jamais rouverte dans la session ;
//   · loupe : 2 lettres → « Mes amis » puis « Membres » (dans cet ordre) ;
//     ami en direct → suivi ; ami masqué → pas de position ; membre → fiche ;
//   · 9 langues.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/localization/v565/pawmap610_i18n.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/pawmap_friend_focus.dart';
import 'package:hopetsit/views/map/widgets/pawmap_friends610.dart';

import 'lotd_harness.dart';

Friendship _fs(String id, String name,
        {String status = 'pending', bool mine = false, List<double>? at, String vis = 'all'}) =>
    Friendship.fromJson(<String, dynamic>{
      'id': 'fs-$id',
      'status': status,
      'initiatedByMe': mine,
      'other': <String, dynamic>{
        'id': id,
        'model': 'Walker',
        'name': name,
        'avatar': '',
        'city': 'Paris',
        'personIds': <String>[id],
        'mapVisibility': vis,
        'location': at == null ? null : <String, dynamic>{'coordinates': at},
        'approx': true,
        'approxKm': 1,
      },
    });

/// Le contrôleur des amis, sans réseau : Accepter fait passer la demande dans
/// « amis » (comme `refresh()` après `POST /friends/:id/accept`).
class _FakeFriends extends FriendController {
  final List<String> accepted = <String>[];
  final List<String> declined = <String>[];

  @override
  Future<bool> accept(String friendshipId, {bool deferRefresh = false}) async {
    accepted.add(friendshipId);
    final f = incomingRequests.firstWhere((x) => x.id == friendshipId);
    incomingRequests.remove(f);
    friends.add(Friendship.fromJson(<String, dynamic>{
      'id': f.id,
      'status': 'accepted',
      'initiatedByMe': false,
      'other': <String, dynamic>{'id': f.other!.id, 'model': 'Walker', 'name': f.other!.name},
    }));
    return true;
  }

  @override
  Future<bool> decline(String friendshipId, {bool deferRemove = false}) async {
    declined.add(friendshipId);
    incomingRequests.removeWhere((x) => x.id == friendshipId);
    return true;
  }
}

/// La carte de la PawMap, branchée comme dans `paw_map_screen.dart`.
class _MapCardHost extends StatefulWidget {
  const _MapCardHost(this.c);
  final _FakeFriends c;
  @override
  State<_MapCardHost> createState() => _MapCardHostState();
}

class _MapCardHostState extends State<_MapCardHost> {
  final RxInt rev = 0.obs;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Obx(() {
          rev.value;
          final req = pawNextFriendRequest610(widget.c.incomingRequests);
          final n = pawPendingFriendRequests610(widget.c.incomingRequests);
          return Column(children: [
            if (n > 0) PawFriendReqCountBadge610(count: n),
            if (req != null)
              PawFriendRequestCard610(
                request: req,
                onAccept: () async {
                  PawFriendReqSession610.handled.add(req.id);
                  rev.value++;
                  await widget.c.accept(req.id);
                },
                onDecline: () async {
                  PawFriendReqSession610.handled.add(req.id);
                  rev.value++;
                  await widget.c.decline(req.id);
                },
                onClose: () {
                  PawFriendReqSession610.closed = true;
                  rev.value++;
                },
              ),
          ]);
        }),
      );
}

void main() {
  setUp(() async {
    await lotdSetUp(role: 'owner');
    lotdResponder = (http.Request req) => const <String, dynamic>{};
    PawFriendReqSession610.resetForTests();
  });

  group('demandes d\'amis sur la carte', () {
    testWidgets('pastille = nombre, carte affichée, Accepter → disparaît et ami ajouté',
        (tester) async {
      lotdPhone(tester);
      final c = _FakeFriends();
      c.incomingRequests.assignAll([_fs('w-lea', 'Léa M.'), _fs('w-tom', 'Tom R.')]);
      await tester.pumpWidget(lotdApp(_MapCardHost(c)));
      await lotdSettle(tester);
      expect(find.byKey(const ValueKey<String>('pm610_rail_badge')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Léa veut être ton ami'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('pm610_req_accept')));
      await lotdSettle(tester, frames: 8);
      expect(c.accepted, ['fs-w-lea']);
      expect(c.friends.map((f) => f.other!.name), contains('Léa M.'));
      expect(find.text('Léa veut être ton ami'), findsNothing);
      // La suivante arrive, la pastille passe à 1.
      expect(find.text('Tom veut être ton ami'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Refuser → retirée, aucune amitié', (tester) async {
      lotdPhone(tester);
      final c = _FakeFriends();
      c.incomingRequests.assignAll([_fs('w-lea', 'Léa M.')]);
      await tester.pumpWidget(lotdApp(_MapCardHost(c)));
      await lotdSettle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('pm610_req_decline')));
      await lotdSettle(tester, frames: 8);
      expect(c.declined, ['fs-w-lea']);
      expect(c.friends, isEmpty);
      expect(find.byType(PawFriendRequestCard610), findsNothing);
      expect(find.byKey(const ValueKey<String>('pm610_rail_badge')), findsNothing);
    });

    testWidgets('fermée → jamais rouverte dans la session, même avec une nouvelle demande',
        (tester) async {
      lotdPhone(tester);
      final c = _FakeFriends();
      c.incomingRequests.assignAll([_fs('w-lea', 'Léa M.')]);
      await tester.pumpWidget(lotdApp(_MapCardHost(c)));
      await lotdSettle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('pm610_req_close')));
      await lotdSettle(tester);
      expect(find.byType(PawFriendRequestCard610), findsNothing);
      c.incomingRequests.add(_fs('w-tom', 'Tom R.'));
      await lotdSettle(tester);
      expect(find.byType(PawFriendRequestCard610), findsNothing);
      // La pastille, elle, reste (2 demandes toujours en attente).
      expect(find.text('2'), findsOneWidget);
    });

    test('demande sans profil ou déjà traitée : jamais montrée', () {
      final list = [_fs('w-lea', 'Léa M.')];
      PawFriendReqSession610.handled.add('fs-w-lea');
      expect(pawNextFriendRequest610(list), isNull);
      expect(pawPendingFriendRequests610(list), 0);
    });
  });

  group('loupe : chercher des personnes', () {
    Widget host({
      required String q,
      required List<Friendship> friends,
      required List<Map<String, dynamic>> members,
      void Function(Friendship)? onFriend,
      void Function(Map<String, dynamic>)? onMember,
    }) =>
        lotdApp(Scaffold(
          body: SingleChildScrollView(
            child: PawPeopleSearch610(
              query: q,
              friends: friends,
              searchMembers: (_) async => members,
              onFriendTap: onFriend ?? (_) {},
              onMemberTap: onMember ?? (_) {},
            ),
          ),
        ));

    testWidgets('2 lettres → « Mes amis » puis « Membres », dans cet ordre', (tester) async {
      lotdPhone(tester);
      Friendship? tappedFriend;
      Map<String, dynamic>? tappedMember;
      await tester.pumpWidget(host(
        q: 'ca',
        friends: [_fs('w-cam', 'Camille D.', status: 'accepted'), _fs('w-bob', 'Bob K.', status: 'accepted')],
        members: [
          <String, dynamic>{'id': 'o-car', 'role': 'owner', 'name': 'Carla P.', 'city': 'Lyon'},
          // déjà ami : jamais en double dans « Membres »
          <String, dynamic>{'id': 'w-cam', 'role': 'walker', 'name': 'Camille D.'},
        ],
        onFriend: (f) => tappedFriend = f,
        onMember: (m) => tappedMember = m,
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await lotdSettle(tester);
      final yFriends = tester.getTopLeft(find.byKey(const ValueKey<String>('pm610_sec_friends'))).dy;
      final yMembers = tester.getTopLeft(find.byKey(const ValueKey<String>('pm610_sec_members'))).dy;
      expect(yFriends, lessThan(yMembers));
      expect(find.text('Mes amis'), findsOneWidget);
      expect(find.text('Membres'), findsOneWidget);
      expect(find.text('Camille D.'), findsOneWidget); // une seule fois
      expect(find.text('Bob K.'), findsNothing);
      expect(find.text('Carla P.'), findsOneWidget);

      await tester.tap(find.text('Camille D.'));
      expect(tappedFriend?.other?.id, 'w-cam');
      await tester.tap(find.text('Carla P.'));
      expect(tappedMember?['id'], 'o-car');
    });

    testWidgets('1 lettre : rien (ni amis ni appel serveur)', (tester) async {
      lotdPhone(tester);
      var calls = 0;
      await tester.pumpWidget(lotdApp(Scaffold(
        body: PawPeopleSearch610(
          query: 'c',
          friends: [_fs('w-cam', 'Camille D.', status: 'accepted')],
          searchMembers: (_) async {
            calls++;
            return const [];
          },
          onFriendTap: (_) {},
          onMemberTap: (_) {},
        ),
      )));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 0);
      expect(find.text('Mes amis'), findsNothing);
    });

    test('filtre local tolérant aux accents et aux majuscules', () {
      final list = [_fs('a', 'Élodie Martin', status: 'accepted'), _fs('b', 'Eloise', status: 'accepted')];
      expect(pawFilterFriends610(list, 'elo').length, 2);
      expect(pawFilterFriends610(list, 'élo mar').single.other!.name, 'Élodie Martin');
      expect(pawFilterFriends610(list, ''), isEmpty);
    });

    test('ami en direct → suivi ; ami masqué → aucune position (pastille)', () {
      final live = FriendPosition(
        userId: 'w-cam',
        role: 'walker',
        latitude: -35,
        longitude: -30,
        at: DateTime.now(),
        lastSeenAt: DateTime.now(),
        sharing: true,
      );
      final cam = _fs('w-cam', 'Camille D.', status: 'accepted', at: <double>[-30.01, -35.01]).other!;
      final focus = pawMapFriendFocusFor(cam, live: pawMapLivePositionOf(cam, {'w-cam': live}))!;
      expect(focus.live, isTrue);
      expect(focus.lat, -35);
      final hidden = _fs('w-hid', 'Hid', status: 'accepted', at: <double>[-30, -35], vis: 'hidden').other!;
      expect(pawMapFriendFocusFor(hidden, live: pawMapLivePositionOf(hidden, const {})), isNull);
    });
  });

  test('9 langues, mêmes clés partout, variables @name intactes', () {
    const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    final keys = pawmap610I18n['en']!.keys.toSet();
    for (final l in langs) {
      expect(pawmap610I18n[l], isNotNull, reason: l);
      expect(pawmap610I18n[l]!.keys.toSet(), keys, reason: l);
      expect(pawmap610I18n[l]!['pm610_req_wants'], contains('@name'), reason: l);
      expect(pawmap610I18n[l]!['pm610_now_friends'], contains('@name'), reason: l);
    }
  });

  test('badge de l\'épingle à GAUCHE du rond (jamais sur la couronne ni la coche)', () {
    final a = pawFriendBadgeAnchor610(23);
    // ancre > 1 en x = l'image est posée à gauche du point de la carte
    expect(a.dx, greaterThan(1));
    expect(a.dy, closeTo(0.35, 0.01));
  });

  group('patte verte du menu : 0 / 1 / 3 amis en direct', () {
    PawTabLiveAction610 act(int n, {bool onMap = false, bool lost = false, bool declined = false, bool explicit = false}) =>
        pawTabLiveAction610(
            liveCount: n, myLiveLost: lost, onPawMapTab: onMap, explicitNow: explicit, singleDeclined: declined);

    test('0 ami en direct (contour blanc) : comportement inchangé', () {
      expect(act(0), PawTabLiveAction610.none);
      expect(act(0, onMap: true), PawTabLiveAction610.none);
    });
    test('1 ami : la carte file sur lui ; lâché → la liste, jamais suivi d\'office', () {
      expect(act(1), PawTabLiveAction610.focusOne);
      expect(act(1, declined: true), PawTabLiveAction610.showList);
    });
    test('3 amis : la liste ; déjà sur la carte : la liste rouvre', () {
      expect(act(3), PawTabLiveAction610.showList);
      expect(act(1, onMap: true), PawTabLiveAction610.showList);
      expect(act(3, onMap: true), PawTabLiveAction610.showList);
    });
    test('contour rouge (mon direct perdu) ou demande d\'un autre écran : inchangé', () {
      expect(act(3, lost: true), PawTabLiveAction610.none);
      expect(act(1, explicit: true), PawTabLiveAction610.none);
    });

    testWidgets('feuille « En direct maintenant » : 3 amis, « en balade · 12 min », appui = choix', (tester) async {
      lotdPhone(tester);
      final now = DateTime(2026, 10, 4, 15, 0);
      PawLiveNowEntry610? picked;
      await tester.pumpWidget(lotdApp(Scaffold(
        body: PawLiveNowSheet610(
          now: now,
          entries: [
            PawLiveNowEntry610(id: 'a', name: 'Ana', since: now.subtract(const Duration(minutes: 12))),
            const PawLiveNowEntry610(id: 'b', name: 'Bo'),
            const PawLiveNowEntry610(id: 'c', name: 'Cy', lost: true),
          ],
          onPick: (e) => picked = e,
        ),
      )));
      await lotdSettle(tester);
      expect(find.text('En direct maintenant'), findsOneWidget);
      expect(find.text('en balade · 12 min'), findsOneWidget);
      expect(find.text('en balade'), findsOneWidget);
      expect(find.text('signal perdu'), findsOneWidget);
      await tester.tap(find.text('Bo'));
      expect(picked?.id, 'b');
    });
  });
}
