// 630 (PAM, 30/10/2026) — cas réel d'Agnès D. (Paris 15e) : le serveur renvoie
// 3 rôles dont owner ET sitter sous le MÊME id (6adea6cd…), walker sous un autre
// (6adea803…). Le site perdait la gardienne (dédoublonnage par id seul, LEO).
// Garde-fou app : les fonctions pures de la PawMap travaillent par RÔLE, jamais
// par id seul : 3 entrées, 3 couleurs, 3 onglets.
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';

void main() {
  const idWalker = '6adea80390a7ee40f6012f15';
  const idOwnerSitter = '6adea6cd90a7ee40f6011b58';
  final agnes = <String, dynamic>{
    'id': idWalker,
    'role': 'walker',
    'name': 'Agnès D.',
    'isBoosted': true,
    'location': {'coordinates': [2.30349, 48.84343]},
    'roles': [
      {'id': idWalker, 'role': 'walker', 'priceFrom': 20, 'priceUnit': 'walk', 'currency': 'EUR'},
      {'id': idOwnerSitter, 'role': 'owner', 'priceFrom': 0, 'currency': 'EUR'},
      {'id': idOwnerSitter, 'role': 'sitter', 'priceFrom': 50, 'priceUnit': 'day', 'currency': 'EUR'},
    ],
  };

  test('même id pour owner et sitter : 3 entrées de rôle, la gardienne n\'est PAS perdue', () {
    final entries = pawMapExpandRoles(agnes);
    expect(entries, hasLength(3));
    expect(entries.map((e) => e['_role']).toList(), ['walker', 'owner', 'sitter']);
    final sitter = entries.firstWhere((e) => e['_role'] == 'sitter');
    expect(sitter['id'], idOwnerSitter);
    expect(sitter['priceFrom'], 50, reason: 'tarif de la gardienne, pas celui du propriétaire');
    final owner = entries.firstWhere((e) => e['_role'] == 'owner');
    expect(owner['id'], idOwnerSitter);
    // Chaque entrée garde TOUS les ids de la personne (amitié, boost, rang).
    for (final e in entries) {
      expect(e['personIds'], [idWalker, idOwnerSitter]);
      expect(e['isBoosted'], isTrue);
    }
  });

  test('3 couleurs d\'anneau dans l\'ordre fixe propriétaire → gardien → promeneur', () {
    final roles = pawMapOrderedRoles(pawMapExpandRoles(agnes).map((e) => e['_role'].toString()));
    expect(roles, ['owner', 'sitter', 'walker']);
  });

  test('ids de la personne : 2 ids distincts (walker, owner=sitter), sans doublon', () {
    expect(pawMapPersonIds(agnes), [idWalker, idOwnerSitter]);
    expect(pawMapSamePerson([agnes, {'id': idOwnerSitter, 'role': 'sitter'}]), isTrue);
  });
}
