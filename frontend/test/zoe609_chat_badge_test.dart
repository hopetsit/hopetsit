// 609 (ZOE, 02/10/2026) — pastille Chat « en retard » (Daniel). Mesuré sur le
// simulateur : app tuée, un message arrive, relance → pastille à 0 pendant 30 s et
// plus alors que le serveur compte 1. Et après une coupure de la prise, rien n'était
// recalé avant le retour au premier plan. Désormais : recalage au démarrage ET à
// chaque (re)connexion de la prise.
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/services/socket_service.dart';

import 'lotd_harness.dart';

class _HookSocket extends SocketService {
  _HookSocket({super.storage});
  final List<void Function()> hooks = [];
  @override
  Future<void> connect({String? tokenOverride}) async {}
  @override
  void addOnConnectedHook(void Function() cb) {
    hooks.add(cb);
    super.addOnConnectedHook(cb);
  }
}

int unread = 0;

void main() {
  setUp(() async {
    await lotdSetUp(role: 'walker');
    await Get.delete<SocketService>(force: true);
    Get.put<SocketService>(_HookSocket(storage: Get.find<GetStorage>()), permanent: true);
    unread = 3;
    lotdResponder = (req) {
      if (req.url.path.endsWith('/conversations/list')) {
        return <String, dynamic>{
          'conversations': [
            {'_id': 'c1', 'otherParty': {'id': 'a'}, 'unreadCount': unread, 'lastMessageAt': '2026-10-02T10:00:00Z'},
            {'_id': 'c2', 'otherParty': {'id': 'b'}, 'unreadCount': 0, 'lastMessageAt': '2026-10-02T09:00:00Z'},
          ],
        };
      }
      return const <String, dynamic>{};
    };
  });

  Future<void> settle() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('démarrage (app relancée) : pastille = vérité serveur, sans attendre', () async {
    final nc = Get.put(NotificationsController());
    await settle();
    expect(lotdRequests.where((r) => r.path.endsWith('/conversations/list')), isNotEmpty);
    expect(nc.unreadChat.value, 3);
  });

  test('reconnexion de la prise : pastille recalée (messages reçus pendant la coupure)', () async {
    final nc = Get.put(NotificationsController());
    await settle();
    expect(nc.unreadChat.value, 3);
    unread = 5; // 2 messages arrivés pendant la coupure
    lotdRequests.clear();
    final sock = Get.find<SocketService>() as _HookSocket;
    expect(sock.hooks, isNotEmpty);
    for (final h in sock.hooks) {
      h();
    }
    await settle();
    expect(nc.unreadChat.value, 5);
    // lu ailleurs puis reconnexion : jamais de chiffre résiduel
    unread = 0;
    for (final h in sock.hooks) {
      h();
    }
    await settle();
    expect(nc.unreadChat.value, 0);
  });
}
