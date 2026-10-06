// 612 (ZOE, 05/10/2026) — Daniel : « notification message dans le menu, surtout sur
// Apple, n'apparaît pas, que dans la cloche ».
// MESURÉ (backend/scripts/mesure_pastille_612.js) : l'app ne quittait jamais la salle
// temps réel d'un fil en revenant à la liste → le serveur le croyait « ouvert à
// l'écran » et ne faisait plus sonner le téléphone pour ce fil.
// Ici : l'écran de discussion masqué quitte la salle, réaffiché il y rentre, et une
// reconnexion de la prise ne remet JAMAIS l'app dans la salle d'un fil fermé.
// Puis la pastille : message reçu → 1, recalée sur le serveur, 0 après lecture.
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/services/socket_service.dart';

import 'lotd_harness.dart';

class _RoomSocket extends SocketService {
  _RoomSocket({super.storage});
  final List<String> log = <String>[];
  final List<void Function()> hooks = <void Function()>[];
  final List<void Function(Map<String, dynamic>)> msgListeners =
      <void Function(Map<String, dynamic>)>[];
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({String? tokenOverride}) async {}
  @override
  void joinConversation(String conversationId) => log.add('join:$conversationId');
  @override
  void leaveConversation(String conversationId) => log.add('leave:$conversationId');
  @override
  void markConversationRead(String conversationId) {}
  @override
  void addOnConnectedHook(void Function() cb) {
    hooks.add(cb);
    super.addOnConnectedHook(cb);
  }

  @override
  void addMessageNewListener(void Function(Map<String, dynamic>) cb) {
    if (!msgListeners.contains(cb)) msgListeners.add(cb);
    super.addMessageNewListener(cb);
  }
}

int serverUnread = 0;

Future<void> settle([int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late _RoomSocket sock;

  setUp(() async {
    await lotdSetUp(role: 'owner');
    await Get.delete<SocketService>(force: true);
    sock = _RoomSocket(storage: Get.find<GetStorage>());
    Get.put<SocketService>(sock, permanent: true);
    SocketService.visibleConversationId = '';
    serverUnread = 0;
    lotdResponder = (req) {
      if (req.url.path.endsWith('/conversations/list')) {
        return <String, dynamic>{
          'conversations': [
            {
              '_id': 'F1',
              'otherParty': {'id': 'cam', 'name': 'Cam'},
              'unreadCount': serverUnread,
              'lastMessageAt': '2026-10-05T20:00:00Z',
            },
          ],
        };
      }
      if (req.url.path.endsWith('/messages')) {
        return <String, dynamic>{'conversationId': 'F1', 'messages': <dynamic>[]};
      }
      return const <String, dynamic>{};
    };
  });

  test('propriétaire : écran masqué → quitte la salle ; réaffiché → y rentre', () async {
    final c = Get.put(ChatController(Get.find<ChatRepository>(), socketService: sock));
    await settle(5);
    sock.log.clear();
    c.setChatVisible('F1', true);
    expect(sock.log, contains('join:F1'));
    expect(SocketService.visibleConversationId, 'F1');
    sock.log.clear();
    c.setChatVisible('F1', false); // retour à la liste / autre onglet / arrière-plan
    expect(sock.log, <String>['leave:F1']);
    expect(SocketService.visibleConversationId, '');
    sock.log.clear();
    c.setChatVisible('F1', true, markRead: true); // retour au premier plan
    expect(sock.log, <String>['join:F1']);
  });

  test('gardien / promeneur : même règle', () async {
    final c = Get.put(SitterChatController(Get.find<ChatRepository>(), socketService: sock));
    await settle(5);
    sock.log.clear();
    c.setChatVisible('F1', true);
    c.setChatVisible('F1', false);
    expect(sock.log, <String>['join:F1', 'leave:F1']);
  });

  test('écran remplacé (fil A → fil B) : on quitte A sans jamais quitter B', () async {
    final c = Get.put(ChatController(Get.find<ChatRepository>(), socketService: sock));
    await settle(5);
    sock.log.clear();
    c.setChatVisible('A', true);
    c.setChatVisible('B', true); // le nouvel écran se monte…
    c.setChatVisible('A', false); // … puis l'ancien se démonte
    expect(sock.log, <String>['join:A', 'join:B', 'leave:A']);
    expect(SocketService.visibleConversationId, 'B');
  });

  test('reconnexion de la prise : fil FERMÉ jamais rejoint, fil à l’écran rejoint', () async {
    final c = Get.put(ChatController(Get.find<ChatRepository>(), socketService: sock));
    await settle(5);
    c.setChatVisible('F1', true);
    await c.loadChatMessages('F1', contactName: 'Cam');
    await settle(5);
    c.setChatVisible('F1', false); // retour à la liste : currentChatId reste « F1 »
    expect(c.currentChatId.value, 'F1');
    sock.log.clear();
    for (final h in List<void Function()>.of(sock.hooks)) {
      h();
    }
    expect(sock.log.where((e) => e.startsWith('join:')), isEmpty,
        reason: 'avant le 612 : join:F1 à chaque reconnexion, fil pourtant fermé');
    c.setChatVisible('F1', true);
    sock.log.clear();
    for (final h in List<void Function()>.of(sock.hooks)) {
      h();
    }
    expect(sock.log, contains('join:F1'));
  });

  test('pastille Chat : message reçu → 1, reste à 1 après recalage serveur, 0 une fois lu', () async {
    final nc = Get.put(NotificationsController());
    await settle();
    expect(nc.unreadChat.value, 0);
    // Le serveur compte désormais le message (correctif serveur 612).
    serverUnread = 1;
    expect(sock.msgListeners, isNotEmpty);
    for (final l in List<void Function(Map<String, dynamic>)>.of(sock.msgListeners)) {
      l(<String, dynamic>{
        'conversationId': 'F1',
        'triggeredBy': {'role': 'owner', 'userId': 'cam'},
        'message': {'_id': 'm1', 'id': 'm1', 'senderId': 'cam', 'body': 'coucou'},
        'sentMessage': {'_id': 'm1', 'id': 'm1', 'senderId': 'cam', 'body': 'coucou'},
      });
    }
    expect(nc.unreadChat.value, 1); // tout de suite
    await Future<void>.delayed(const Duration(milliseconds: 1800)); // recalage serveur (1,5 s)
    await settle();
    expect(nc.unreadChat.value, 1,
        reason: 'avant le correctif serveur, le compteur des fils entre amis valait 0 : la pastille s’effaçait ici');
    // Lecture du fil (ici ou sur un autre appareil) → le serveur revient à 0.
    serverUnread = 0;
    nc.scheduleChatBadgeResync(ms: 50);
    await settle();
    expect(nc.unreadChat.value, 0);
  });
}
