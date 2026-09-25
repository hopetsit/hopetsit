// v587 — point 11 (décision écrite de Daniel du 25/09, « Amis OK, je l'active »).
//
// Couche amis de la PawMap placée depuis GET /friends :
//   · FriendProfile lit la position de profil floutée (location, approxKm,
//     positionSource, mapVisibility) ;
//   · un point par ami, « Masqué » absent ;
//   · la position de /friends prime sur les couches proches / monde, l'ami
//     hors couche (plafond, compte de test) est ajouté, une personne = un point ;
//   · retour de Daniel « connecté avec un autre profil, aucun ami » : la liste
//     vient maintenant de /friends (calculé sur la PERSONNE) → les MÊMES amis
//     et les MÊMES points depuis les 3 profils.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/views/map/pawmap_friends_layer.dart';

import 'lotd_harness.dart';

Map<String, dynamic> _friend(String id, String model, String name,
        {List<double>? at, String vis = 'all', List<String>? personIds}) =>
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

final _payload = <String, dynamic>{
  'friends': <Map<String, dynamic>>[
    _friend('o-john', 'Owner', 'John', at: <double>[2.34, 48.86], personIds: <String>['o-john', 's-john']),
    _friend('w-ana', 'Walker', 'Ana', at: <double>[2.40, 48.84], vis: 'friends'),
    _friend('s-hid', 'Sitter', 'Hid', vis: 'hidden'),
  ],
};

void main() {
  group('modèle + couche (fonctions pures)', () {
    final friends = [
      for (final f in _payload['friends'] as List)
        Friendship.fromJson(Map<String, dynamic>.from(f as Map)),
    ];

    test('FriendProfile lit la position floutée et l\'état', () {
      final john = friends[0].other!;
      expect(john.mapLng, 2.34);
      expect(john.mapLat, 48.86);
      expect(john.approxKm, 1.0);
      expect(john.positionSource, 'home');
      expect(john.hasMapPosition, isTrue);
      final hid = friends[2].other!;
      expect(hid.mapVisibility, 'hidden');
      expect(hid.hasMapPosition, isFalse);
    });

    test('un point par ami avec position, « Masqué » absent', () {
      final pts = pawMapFriendPoints(friends);
      expect(pts.map((p) => p['id']), <String>['o-john', 'w-ana']);
      expect(pts.every((p) => p['isFriend'] == true && p['approx'] == true), isTrue);
      expect(pts.first['personIds'], <String>['o-john', 's-john']);
    });

    test('/friends prime sur la couche monde ; hors couche ajouté ; un point par personne', () {
      final world = <Map<String, dynamic>>[
        // John vu par la couche monde sous son profil GARDIEN, ailleurs.
        {'id': 's-john', '_role': 'sitter', 'location': {'coordinates': <double>[2.30, 48.80]}, 'priceFrom': 22, 'approx': true},
        {'id': 'o-john', '_role': 'owner', 'location': {'coordinates': <double>[2.31, 48.81]}, 'approx': true},
        {'id': 'x-zed', '_role': 'sitter', 'location': {'coordinates': <double>[2.2, 48.7]}, 'approx': true},
      ];
      final placed = pawMapPlaceFriends(
        nearby: const <Map<String, dynamic>>[],
        world: world,
        friendPoints: pawMapFriendPoints(friends),
      );
      final johns = placed.world.where((p) => (p['personIds'] as List? ?? const []).contains('s-john')).toList();
      expect(johns, hasLength(1));
      expect(johns.single['location']['coordinates'], <double>[2.34, 48.86]);
      expect(johns.single['priceFrom'], 22); // garde ses champs
      expect(johns.single['isFriend'], isTrue);
      expect(placed.world.firstWhere((p) => p['id'] == 'x-zed')['location']['coordinates'], <double>[2.2, 48.7]);
      expect(placed.extra.map((p) => p['id']), <String>['w-ana']); // absente des couches → ajoutée
    });
  });

  group('FriendController — mêmes amis depuis les 3 profils', () {
    for (final role in <String>['owner', 'sitter', 'walker']) {
      test('connecté en $role : liste lue sur /friends, mêmes amis, mêmes points', () async {
        await lotdSetUp(role: role);
        lotdResponder = (http.Request req) {
          if (req.url.path.endsWith('/friends')) return _payload;
          return const <String, dynamic>{};
        };
        final c = Get.put(FriendController());
        await c.loadFriends();
        expect(c.friends.map((f) => f.other!.name).toList(), <String>['John', 'Ana', 'Hid']);
        expect(lotdRequests.any((r) => r.path.endsWith('/friends')), isTrue);
        final pts = pawMapFriendPoints(c.friends);
        expect(jsonEncode(pts.map((p) => p['location']).toList()),
            jsonEncode(<Object>[
              {'coordinates': <double>[2.34, 48.86]},
              {'coordinates': <double>[2.40, 48.84]},
            ]));
        expect(c.isFriendWithAny(<String>['s-john']), isTrue); // autre profil de John
      });
    }
  });
}
