// v585 (25/09/2026) — UNE PERSONNE, PLUSIEURS RÔLES sur la PawMap.
//
// Retours de Daniel sur le build 584 (Samsung réel) :
//   · « john C est mon ami, mais en gardien la fiche propose Ajouter en ami » :
//     une amitié vaut pour la PERSONNE (ses 3 profils) — le serveur renvoie
//     `isFriend` et `personIds` (tous les ids de rôle) ;
//   · « une pastille 2 : quand j'appuie, ça zoome et c'est tout ; il faut que
//     ça me montre les deux rôles » : une personne propriétaire + gardienne est
//     UN point (`roles`) au liseré partagé ; au tap, une ligne par rôle ; un
//     groupe dont les points sont superposés ouvre la liste au lieu de zoomer.
//
// Fonctions PURES (testées dans test/pawmap585_person_test.dart).
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart' show PawFriendState;

/// Tous les ids de rôle de la personne portée par ce point (id du point en
/// premier), sans doublon ni vide.
List<String> pawMapPersonIds(Map p) {
  final out = <String>[];
  void add(Object? v) {
    final s = (v ?? '').toString().trim();
    if (s.isNotEmpty && !out.contains(s)) out.add(s);
  }

  add(p['id'] ?? p['_id']);
  final ids = p['personIds'];
  if (ids is List) ids.forEach(add);
  final roles = p['roles'];
  if (roles is List) {
    for (final r in roles) {
      if (r is Map) add(r['id']);
    }
  }
  return out;
}

/// Une entrée par RÔLE de la personne (fiche du bon rôle au tap). Une personne
/// à un seul rôle → `[p]` tel quel.
List<Map<String, dynamic>> pawMapExpandRoles(Map p) {
  final base = Map<String, dynamic>.from(p);
  final roles = p['roles'];
  if (roles is! List) return [base];
  final valid = roles.whereType<Map>().where((r) =>
      (r['id'] ?? '').toString().isNotEmpty &&
      (r['role'] ?? '').toString().isNotEmpty);
  if (valid.length < 2) return [base];
  final ids = pawMapPersonIds(p);
  return [
    for (final r in valid)
      {
        ...base,
        'id': r['id'].toString(),
        '_role': r['role'].toString().toLowerCase(),
        'role': r['role'].toString().toLowerCase(),
        if (r['priceFrom'] is num) 'priceFrom': r['priceFrom'],
        if (r['rating'] is num) 'rating': r['rating'],
        if (r['reviewsCount'] is num) 'reviewsCount': r['reviewsCount'],
        if (r['currency'] != null) 'currency': r['currency'],
        // Déjà développée : jamais une 2e fois.
        'roles': null,
        'personIds': ids,
      },
  ];
}

/// Position d'un membre (`location.coordinates` = [lng, lat]).
LatLng? pawMapMemberLatLng(Map p) {
  final loc = p['location'] is Map ? p['location'] as Map : null;
  final c = loc != null && loc['coordinates'] is List
      ? loc['coordinates'] as List
      : null;
  if (c == null || c.length < 2 || c[0] is! num || c[1] is! num) return null;
  return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
}

/// Tous ces points appartiennent-ils à UNE même personne ?
bool pawMapSamePerson(List<Map> members) {
  if (members.length < 2) return members.isNotEmpty;
  Set<String> common = pawMapPersonIds(members.first).toSet();
  for (final m in members.skip(1)) {
    final ids = pawMapPersonIds(m).toSet();
    if (common.intersection(ids).isEmpty) return false;
    common = common.union(ids);
  }
  return true;
}

/// Un zoom séparerait-il ces points ? Non s'ils sont à moins de [meters]
/// les uns des autres (superposés) ou s'il s'agit d'une seule personne.
bool pawMapClusterIsStacked(List<LatLng> points,
    {bool samePerson = false, double meters = 40}) {
  if (samePerson) return true;
  if (points.length < 2) return false;
  double maxD = 0;
  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      maxD = math.max(maxD, _meters(points[i], points[j]));
    }
  }
  return maxD <= meters;
}

double _meters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final la1 = a.latitude * math.pi / 180;
  final la2 = b.latitude * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// v585 (bug 2) — état de la relation affiché dans la fiche : le drapeau du
/// serveur prime (un ami ne se voit JAMAIS proposer « Ajouter en ami »).
PawFriendState pawMapRelationState({
  required bool serverFriend,
  required bool isFriend,
  required bool sent,
  required bool incoming,
}) {
  if (serverFriend || isFriend) return PawFriendState.friends;
  if (sent) return PawFriendState.sent;
  if (incoming) return PawFriendState.incoming;
  return PawFriendState.idle;
}
