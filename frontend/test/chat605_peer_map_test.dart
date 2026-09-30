// v605 (ZOE, 30/09/2026) — Daniel (vocal) : « quand je suis dans le chat, si
// je clique sur ton nom, si je suis ton ami, que je puisse voir ta position en
// direct sur la carte ».
//
// Les VRAIS écrans de discussion (propriétaire `IndividualChatScreen`,
// gardien / promeneur `SitterIndividualChatScreen`) sont montés ; on touche le
// NOM puis la PHOTO de l'en-tête et on lit la demande confiée à la PawMap
// (`pawMapPendingFriend`, onglet `requestedTab`) :
//   · ami EN DIRECT (partage actif, y compris sous un autre de ses rôles)
//     → onglet PawMap + cible `live: true` à sa position directe (la carte le
//     suit) ;
//   · ami PAS en direct → cible `live: false` à sa position de PROFIL floutée ;
//   · ami « Masqué » → pastille « pas visible sur la carte », rien d'envoyé ;
//   · PAS ami → fiche v569 « Ajouter en ami / Bloquer », rien d'envoyé.
// Plus : la liste d'amis pas encore chargée est lue avant de décider.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/chat_shared/chat_peer_map605.dart';
import 'package:hopetsit/views/map/widgets/pawmap_signal.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';

import 'lotd_harness.dart';

const _conv = 'conv-605';
const _notOnMapFr = "Cet ami n'est pas visible sur la carte";

Map<String, dynamic> _friendJson(String id, String name,
        {List<double>? at,
        String vis = 'all',
        String model = 'Walker',
        List<String>? personIds}) =>
    <String, dynamic>{
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
        'personIds': personIds ?? <String>[id],
        'mapVisibility': vis,
        'location': at == null ? null : <String, dynamic>{'coordinates': at},
        'approx': true,
        'approxKm': 1,
        'positionSource': at == null ? null : 'home',
      },
    };

FriendPosition _live(String id) => FriendPosition(
      userId: id,
      role: 'walker',
      latitude: 48.8606,
      longitude: 2.3376,
      at: DateTime.now(),
      lastSeenAt: DateTime.now(),
      sharing: true,
    );

void _resetMapState() {
  requestedTab.value = -1;
  pawMapPendingFriend.value = null;
  pawMapPendingIntent.value = null;
  navWrapperMounted.value = false;
  PawSignal.hide();
}

/// Réponses du faux serveur : la liste d'amis [friends] sur GET /friends.
void _serve(List<Map<String, dynamic>> friends) {
  lotdResponder = (http.Request req) {
    if (req.method == 'GET' && req.url.path.endsWith('/friends')) {
      return <String, dynamic>{'friends': friends};
    }
    return const <String, dynamic>{};
  };
}

enum _Screen { owner, provider }

Future<void> _pumpChat(WidgetTester tester, _Screen s,
    {required String peerId, required String peerRole}) async {
  lotdPhone(tester);
  if (s == _Screen.provider && !Get.isRegistered<SitterChatController>()) {
    // Posé par le menu du gardien / promeneur dans l'app (sitter_nav_wrapper).
    Get.put(SitterChatController(Get.find<ChatRepository>(),
        storage: Get.find<GetStorage>()));
  }
  final Widget screen = s == _Screen.owner
      ? const IndividualChatScreen(
          conversationId: _conv, contactName: 'Ana Lopez', contactImage: '')
      : const SitterIndividualChatScreen(
          conversationId: _conv, contactName: 'Ana Lopez', contactImage: '');
  await tester.pumpWidget(lotdApp(screen));
  await lotdSettle(tester, frames: 3);
  // Le correspondant de la conversation (comme la liste des conversations
  // du serveur le fournit : contactId + contactRole).
  if (s == _Screen.owner) {
    Get.find<ChatController>().conversations.assignAll(<ChatConversation>[
      ChatConversation(
        id: _conv,
        contactName: 'Ana Lopez',
        contactImage: '',
        lastMessage: '',
        lastMessageTime: DateTime.now(),
        isOnline: false,
        unreadCount: 0,
        contactId: peerId,
        contactRole: peerRole,
      ),
    ]);
  } else {
    Get.find<SitterChatController>().conversations.assignAll(<SitterChatConversation>[
      SitterChatConversation(
        id: _conv,
        contactName: 'Ana Lopez',
        contactImage: '',
        lastMessage: '',
        lastMessageTime: DateTime.now(),
        isOnline: false,
        unreadCount: 0,
        contactId: peerId,
        contactRole: peerRole,
      ),
    ]);
  }
  await tester.pump();
}

Finder _headerName() => find.descendant(
    of: find.byType(AppBar), matching: find.text('Ana Lopez'));

Finder _headerAvatar() => find.descendant(
    of: find.byType(AppBar), matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'ChatAvatar'));

void main() {
  test('règle pure : ami accepté reconnu sous n\'importe lequel de ses rôles', () {
    final list = <Friendship>[
      Friendship.fromJson(_friendJson('w-ana', 'Ana',
          at: <double>[2.35, 48.85], personIds: <String>['w-ana', 'o-ana'])),
    ];
    expect(chatPeerFriend(list, 'w-ana')?.id, 'w-ana');
    expect(chatPeerFriend(list, 'O-ANA')?.id, 'w-ana'); // autre rôle, casse
    expect(chatPeerFriend(list, 's-bob'), isNull);
    expect(chatPeerFriend(list, ''), isNull);
    final pending = Friendship.fromJson(
        <String, dynamic>{..._friendJson('s-bob', 'Bob'), 'status': 'pending'});
    expect(chatPeerFriend(<Friendship>[pending], 's-bob'), isNull);
  });

  for (final s in _Screen.values) {
    final String role = s == _Screen.owner ? 'owner' : 'sitter';
    group('écran de discussion ${s.name} ($role) : appui sur le nom / la photo', () {
      setUp(() async {
        await lotdSetUp(role: role);
        _resetMapState();
        Get.put<LiveMapService>(LiveMapService());
      });
      tearDown(_resetMapState);

      testWidgets('ami EN DIRECT → onglet PawMap, la carte le suit à sa position directe',
          (tester) async {
        navWrapperMounted.value = true;
        _serve(<Map<String, dynamic>>[
          _friendJson('w-ana', 'Ana', at: <double>[2.40, 48.84]),
        ]);
        await _pumpChat(tester, s, peerId: 'w-ana', peerRole: 'walker');
        Get.find<LiveMapService>().friendPositions['w-ana'] = _live('w-ana');
        await tester.tap(_headerName());
        await lotdSettle(tester, frames: 2);
        expect(requestedTab.value, kPawMapTabIndex);
        final f = pawMapPendingFriend.value;
        expect(f, isNotNull);
        expect(f!.userId, 'w-ana');
        expect(f.live, isTrue, reason: 'en direct → la carte le suit');
        expect(f.lat, 48.8606);
        expect(f.lng, 2.3376);
        expect(find.text('Ajouter en ami'), findsNothing);
      });

      testWidgets('ami en direct sous un AUTRE de ses rôles → toujours suivi',
          (tester) async {
        navWrapperMounted.value = true;
        _serve(<Map<String, dynamic>>[
          _friendJson('w-ana', 'Ana',
              at: <double>[2.40, 48.84], personIds: <String>['w-ana', 'o-ana']),
        ]);
        // La conversation est avec son profil PROPRIÉTAIRE, elle diffuse en
        // tant que promeneuse.
        await _pumpChat(tester, s, peerId: 'o-ana', peerRole: 'owner');
        Get.find<LiveMapService>().friendPositions['w-ana'] = _live('w-ana');
        await tester.tap(_headerAvatar());
        await lotdSettle(tester, frames: 2);
        expect(requestedTab.value, kPawMapTabIndex);
        expect(pawMapPendingFriend.value?.live, isTrue);
        expect(pawMapPendingFriend.value?.personIds, contains('o-ana'));
      });

      testWidgets('ami PAS en direct → centrée sur sa position de profil floutée, pas de suivi',
          (tester) async {
        navWrapperMounted.value = true;
        _serve(<Map<String, dynamic>>[
          _friendJson('w-ana', 'Ana', at: <double>[2.40, 48.84]),
        ]);
        await _pumpChat(tester, s, peerId: 'w-ana', peerRole: 'walker');
        await tester.tap(_headerAvatar());
        await lotdSettle(tester, frames: 2);
        expect(requestedTab.value, kPawMapTabIndex);
        final f = pawMapPendingFriend.value!;
        expect(f.live, isFalse);
        expect(f.lat, 48.84);
        expect(f.lng, 2.40);
        expect(f.approxKm, 1, reason: 'position de profil = floutée (~1 km)');
      });

      testWidgets('ami « Masqué » hors direct → pastille, aucune demande à la carte',
          (tester) async {
        navWrapperMounted.value = true;
        _serve(<Map<String, dynamic>>[
          _friendJson('w-ana', 'Ana', at: <double>[2.40, 48.84], vis: 'hidden'),
        ]);
        await _pumpChat(tester, s, peerId: 'w-ana', peerRole: 'walker');
        await tester.tap(_headerName());
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_notOnMapFr), findsOneWidget);
        expect(requestedTab.value, -1);
        expect(pawMapPendingFriend.value, isNull);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      });

      testWidgets('PAS ami → fiche v569 « Ajouter en ami / Bloquer », pas de carte',
          (tester) async {
        navWrapperMounted.value = true;
        _serve(<Map<String, dynamic>>[
          _friendJson('w-zoe', 'Zoé', at: <double>[2.30, 48.80]),
        ]);
        await _pumpChat(tester, s, peerId: 's-bob', peerRole: 'sitter');
        await tester.tap(_headerName());
        await lotdSettle(tester, frames: 3);
        expect(requestedTab.value, -1);
        expect(pawMapPendingFriend.value, isNull);
        expect(pawMapPendingIntent.value, isNull);
        expect(find.text('Ajouter en ami'), findsOneWidget);
        expect(find.text('Bloquer'), findsWidgets);
      });

      testWidgets('liste d\'amis vide au moment du tap → relue avant de décider',
          (tester) async {
        navWrapperMounted.value = true;
        _serve(const <Map<String, dynamic>>[]);
        await _pumpChat(tester, s, peerId: 'w-ana', peerRole: 'walker');
        final fc = Get.isRegistered<FriendController>()
            ? Get.find<FriendController>()
            : Get.put(FriendController());
        await lotdSettle(tester, frames: 2);
        fc.friends.clear();
        // Le serveur connaît l'amitié : la relecture la trouve.
        _serve(<Map<String, dynamic>>[
          _friendJson('w-ana', 'Ana', at: <double>[2.40, 48.84]),
        ]);
        await tester.tap(_headerName());
        await lotdSettle(tester, frames: 3);
        expect(pawMapPendingFriend.value?.userId, 'w-ana');
        expect(find.text('Ajouter en ami'), findsNothing);
      });
    });
  }
}
