// v587 (point 11) — COUCHE AMIS de la PawMap, placée depuis `GET /friends`.
//
// Décision écrite de Daniel (25/09, « Amis OK, je l'active ») :
//   · chaque ami est posé à sa position de PROFIL floutée ~1 km, renvoyée par
//     `/friends` (même floutage que la couche monde), SAUF s'il est « Masqué » ;
//   · s'il partage en direct, le rond « direct » (GPS exact) le remplace ;
//   · jamais dans un groupe, à tous les zooms (voir pawGroupKeepingFriends).
// Avant : un ami n'avait de position que s'il tombait dans la couche monde
// (plafonnée, sans comptes de test) → « aucun ami n'apparaît ».
//
// Fonctions PURES (testées dans test/pawmap587_friends_layer_test.dart).
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/views/map/pawmap_person.dart' show pawMapPersonIds;

String _norm(Object? v) => (v ?? '').toString().trim().toLowerCase();

/// Un point « membre » (même forme que la couche monde) par ami qui a une
/// position de profil et n'est pas « Masqué ».
List<Map<String, dynamic>> pawMapFriendPoints(Iterable<Friendship> friends) {
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final f in friends) {
    final o = f.other;
    if (f.status != 'accepted' || o == null || o.id.isEmpty) continue;
    if (!o.hasMapPosition) continue;
    final ids = <String>[o.id, ...o.personIds.where((x) => x != o.id)];
    if (ids.any((x) => seen.contains(_norm(x)))) continue;
    seen.addAll(ids.map(_norm));
    final role = o.model.toLowerCase();
    out.add(<String, dynamic>{
      'id': o.id,
      '_role': role,
      'role': role,
      'name': o.name,
      'avatar': o.avatar,
      'location': <String, dynamic>{
        'coordinates': <double>[o.mapLng!, o.mapLat!],
      },
      'approx': true,
      'approxKm': o.approxKm,
      'positionSource': o.positionSource,
      'personIds': ids,
      'isFriend': true,
      'isPremium': o.isPremium,
      'isOnline': o.isOnline,
      '_fromFriends': true,
    });
  }
  return out;
}

/// Résultat de [pawMapPlaceFriends].
class PawMapFriendsPlacement {
  final List<Map<String, dynamic>> nearby;
  final List<Map<String, dynamic>> world;
  final List<Map<String, dynamic>> extra;
  const PawMapFriendsPlacement(this.nearby, this.world, this.extra);
}

/// La position de `/friends` PRIME sur celle des couches « proches » et
/// « monde » pour un ami (même personne = n'importe lequel de ses ids) : le
/// point existant garde ses autres champs (rôles, note, tarif) mais prend la
/// position floutée et `isFriend`. Un ami absent des deux couches (au-delà du
/// plafond, compte de test…) est ajouté dans [PawMapFriendsPlacement.extra].
PawMapFriendsPlacement pawMapPlaceFriends({
  required List<Map<String, dynamic>> nearby,
  required List<Map<String, dynamic>> world,
  required List<Map<String, dynamic>> friendPoints,
}) {
  if (friendPoints.isEmpty) return PawMapFriendsPlacement(nearby, world, const []);
  final byId = <String, Map<String, dynamic>>{};
  for (final fp in friendPoints) {
    for (final id in pawMapPersonIds(fp)) {
      byId[_norm(id)] = fp;
    }
  }
  final used = <Map<String, dynamic>>{};
  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> list) {
    final out = <Map<String, dynamic>>[];
    for (final p in list) {
      Map<String, dynamic>? fp;
      for (final id in pawMapPersonIds(p)) {
        fp = byId[_norm(id)];
        if (fp != null) break;
      }
      if (fp == null) {
        out.add(p);
        continue;
      }
      // Une personne = UN point : un 2e point de la même personne est retiré.
      if (used.contains(fp)) continue;
      used.add(fp);
      final ids = <String>{...pawMapPersonIds(p), ...pawMapPersonIds(fp)}.toList();
      out.add(<String, dynamic>{
        ...p,
        'location': fp['location'],
        'approx': true,
        'approxKm': fp['approxKm'],
        'positionSource': fp['positionSource'],
        'personIds': ids,
        'isFriend': true,
        if ((p['avatar'] ?? '').toString().isEmpty) 'avatar': fp['avatar'],
      });
    }
    return out;
  }

  final n = apply(nearby);
  final w = apply(world);
  final extra = [
    for (final fp in friendPoints)
      if (!used.contains(fp)) fp,
  ];
  return PawMapFriendsPlacement(n, w, extra);
}
