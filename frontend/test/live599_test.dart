// v599 (29/09/2026) — nom + photo dans les positions en direct (rond vide
// « Po de la Isla ») et compteur « amis en balade » (point vert du menu).
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/services/live_map_service.dart';

FriendPosition _pos(String id, {bool sharing = true, int ageSec = 10, String name = '', String avatar = ''}) =>
    FriendPosition(
      userId: id,
      role: 'walker',
      latitude: -35.2,
      longitude: -30.4,
      at: DateTime.now(),
      lastSeenAt: DateTime.now().subtract(Duration(seconds: ageSec)),
      sharing: sharing,
      name: name,
      avatar: avatar,
    );

void main() {
  test('fromJson lit name + avatar envoyés par le serveur 599', () {
    final p = FriendPosition.fromJson({
      'userId': 'po', 'role': 'sitter', 'lat': -35.2, 'lng': -30.4,
      'at': DateTime.now().toIso8601String(), 'sharing': true, 'ageMs': 1000,
      'name': 'Po de la Isla', 'avatar': 'https://cdn.test/po.jpg',
    });
    expect(p.name, 'Po de la Isla');
    expect(p.avatar, 'https://cdn.test/po.jpg');
    // Serveur d'avant : champs absents → vides, jamais d'erreur.
    final q = FriendPosition.fromJson({'userId': 'x', 'lat': 1, 'lng': 2});
    expect(q.name, '');
    expect(q.avatar, '');
  });

  test('copyWith garde name + avatar (fusion socket sans ces champs)', () {
    final prev = _pos('po', name: 'Po', avatar: 'a.jpg');
    final next = _pos('po');
    final merged = next.copyWith(
        name: next.name.isNotEmpty ? next.name : prev.name,
        avatar: next.avatar.isNotEmpty ? next.avatar : prev.avatar);
    expect(merged.name, 'Po');
    expect(merged.avatar, 'a.jpg');
  });

  test('liveFriendsCount : en direct + signal perdu comptent, « vu il y a » non', () {
    Get.testMode = true;
    final svc = LiveMapService();
    svc.friendPositions['a'] = _pos('a'); // live
    svc.friendPositions['b'] = _pos('b', ageSec: 5 * 60); // lost (2–10 min)
    svc.friendPositions['c'] = _pos('c', ageSec: 30 * 60); // seen
    svc.friendPositions['d'] = _pos('d', sharing: false); // pas de partage
    svc.recountLiveFriends();
    expect(svc.liveFriendsCount.value, 2);
    expect(svc.singleLiveFriend, isNull);
    svc.friendPositions.remove('b');
    svc.recountLiveFriends();
    expect(svc.liveFriendsCount.value, 1);
    expect(svc.singleLiveFriend?.userId, 'a');
    svc.friendPositions['a'] = svc.friendPositions['a']!.copyWith(sharing: false, stale: true);
    svc.recountLiveFriends();
    expect(svc.liveFriendsCount.value, 0);
    expect(svc.singleLiveFriend, isNull);
  });
}
