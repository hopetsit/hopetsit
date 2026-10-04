// 610 (03/10) — Daniel : « quand la personne est en direct, le bouton vert
// doit marcher ». Règle de la pastille verte de la liste des conversations.
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/chat_shared/chat_peer_map605.dart';

FriendPosition _fp(String id, {required bool sharing, required Duration age,
        List<String> personIds = const <String>[]}) =>
    FriendPosition(
      userId: id,
      role: 'owner',
      latitude: 48.85,
      longitude: 2.35,
      at: DateTime.now().subtract(age),
      sharing: sharing,
      personIds: personIds,
    );

void main() {
  test('en direct (partage actif, récent) → vert', () {
    expect(chatPeerIsLive('a', {'a': _fp('a', sharing: true, age: const Duration(seconds: 20))}), isTrue);
  });
  test('signal perdu (< 10 min) → toujours vert : le suivi reste possible', () {
    expect(chatPeerIsLive('a', {'a': _fp('a', sharing: true, age: const Duration(minutes: 5))}), isTrue);
  });
  test('partage coupé → pas vert', () {
    expect(chatPeerIsLive('a', {'a': _fp('a', sharing: false, age: const Duration(seconds: 20))}), isFalse);
  });
  test('direct lancé sous un autre rôle de la même personne → vert', () {
    expect(chatPeerIsLive('sitterId', {
      'ownerId': _fp('ownerId', sharing: true, age: const Duration(seconds: 10),
          personIds: const ['ownerId', 'sitterId']),
    }), isTrue);
  });
  test('inconnu ou id vide → pas vert', () {
    expect(chatPeerIsLive('', const {}), isFalse);
    expect(chatPeerIsLive('x', const {}), isFalse);
  });
}
