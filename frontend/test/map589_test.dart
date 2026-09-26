// v589 — une personne = un rond ; annonces une fois par appareil.
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/map/widgets/pawmap_announcement.dart';

FriendPosition fp(String id, {List<String> ids = const [], double lat = 1}) =>
    FriendPosition(
      userId: id,
      role: 'owner',
      latitude: lat,
      longitude: 2,
      at: DateTime.utc(2026, 9, 26),
      personIds: ids,
    );

void main() {
  test('même personne sous un autre profil : même clé', () {
    final cur = {'dO': fp('dO', ids: ['dO', 'dS'])};
    expect(friendPositionKey(cur, fp('dS')), 'dO');
    expect(friendPositionKey(cur, fp('dS', ids: ['dS'])), 'dO');
  });

  test('clé retrouvée par les ids de la nouvelle position', () {
    final cur = {'dO': fp('dO')};
    expect(friendPositionKey(cur, fp('dS', ids: ['dO', 'dS'])), 'dO');
  });

  test('personne différente : sa propre clé', () {
    final cur = {'dO': fp('dO', ids: ['dO', 'dS'])};
    expect(friendPositionKey(cur, fp('zz', ids: ['zz'])), 'zz');
  });

  test('ids fusionnés', () {
    final m = mergedPersonIds(fp('dO', ids: ['dO']), fp('dS', ids: ['dS', 'dW']));
    expect(m.toSet(), {'dO', 'dS', 'dW'});
  });

  test('annonce : la première jamais vue', () {
    const a = PawAnnouncement(id: 'a', title: 'A', body: '', kind: 'info', url: '');
    const b = PawAnnouncement(id: 'b', title: 'B', body: '', kind: 'update', url: '');
    expect(pickUnseenAnnouncement([a, b], ['a'])?.id, 'b');
    expect(pickUnseenAnnouncement([a, b], ['a', 'b']), isNull);
    expect(pickUnseenAnnouncement(const [], const []), isNull);
  });

  test('annonce : lecture tolérante', () {
    expect(PawAnnouncement.fromJson({'id': 'x', 'title': ' Hi '})?.title, 'Hi');
    expect(PawAnnouncement.fromJson({'id': 'x'}), isNull);
    expect(PawAnnouncement.fromJson('nope'), isNull);
  });
}
