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

/// v594 — Daniel (26/09) : couleurs des rôles dans un ordre FIXE, jamais
/// l'ordre de création : orange (propriétaire) → bleu (gardien) → vert
/// (promeneur). Deux personnes aux mêmes rôles ont le même liseré / bouton.
const List<String> kPawMapRoleOrder = <String>['owner', 'sitter', 'walker'];

/// Rôles connus, sans doublon, dans l'ordre fixe.
List<String> pawMapOrderedRoles(Iterable<String> roles) {
  final set = roles.map((r) => r.trim().toLowerCase()).toSet();
  return [for (final r in kPawMapRoleOrder) if (set.contains(r)) r];
}

/// Rôles d'une personne (`roles` du serveur, sinon son rôle seul), ordre fixe.
List<String> pawMapPersonRoles(Map p) {
  final out = <String>[];
  final roles = p['roles'];
  if (roles is List) {
    for (final r in roles) {
      if (r is Map) out.add((r['role'] ?? '').toString());
    }
  }
  if (out.isEmpty) out.add((p['_role'] ?? p['role'] ?? '').toString());
  return pawMapOrderedRoles(out);
}

/// v594 — bulle de prix d'une personne. Gardien ET promeneur visibles avec
/// un prix : bulle DUO « prixGardien|prixPromeneur » (rôle `duo`). Sinon le
/// prix du seul rôle visible, à sa couleur. null = pas de bulle.
/// [shows] (rôle du spectateur, rôle du membre) = règle du marché
/// (`pawMapShowsPriceBubble`) ; [shownRoles] = filtre de rôles de la carte.
({String text, String role})? pawMapPersonPriceBubble(
  List<Map<String, dynamic>> personRoles, {
  required bool Function(String targetRole) shows,
  required Set<String> shownRoles,
  required String Function(String currency, double price) format,
}) {
  final byRole = <String, String>{};
  for (final r in personRoles) {
    final role = (r['_role'] ?? r['role'] ?? '').toString().toLowerCase();
    if (role != 'sitter' && role != 'walker') continue;
    if (shownRoles.isNotEmpty && !shownRoles.contains(role)) continue;
    if (!shows(role)) continue;
    final price = (r['priceFrom'] as num?)?.toDouble() ?? 0;
    if (price <= 0 || byRole.containsKey(role)) continue;
    byRole[role] = format((r['currency'] ?? 'EUR').toString(), price);
  }
  if (byRole.containsKey('sitter') && byRole.containsKey('walker')) {
    return (text: '${byRole['sitter']}|${byRole['walker']}', role: 'duo');
  }
  if (byRole.isEmpty) return null;
  final e = byRole.entries.first;
  return (text: e.value, role: e.key);
}

/// v594 — distance à vol d'oiseau (km) entre deux points.
double pawMapDistanceKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final la1 = a.latitude * math.pi / 180;
  final la2 = b.latitude * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
}

/// v604 — Daniel (30/09) : « vérifie que les doubles et triples bulles
/// s'affichent avec les prix ». La couche « membres proches » (abonnés)
/// prime sur la couche monde, mais le serveur ≤ 603 n'y mettait AUCUN tarif :
/// un gardien + promeneur abonné n'avait ni bulle duo ni bulle simple. On
/// reprend les tarifs PAR RÔLE de la même personne dans la couche monde
/// quand ils manquent (un tarif présent n'est jamais écrasé ; un rôle sans
/// tarif n'efface pas les autres). Pure.
/// Index « id de rôle (minuscules) → personne » de la couche monde, construit
/// une fois par reconstruction des marqueurs.
Map<String, Map<String, dynamic>> pawMapWorldIndex(
    Iterable<Map<String, dynamic>> world) {
  final idx = <String, Map<String, dynamic>>{};
  for (final w in world) {
    for (final id in pawMapPersonIds(w)) {
      idx.putIfAbsent(id.toLowerCase(), () => w);
    }
  }
  return idx;
}

Map<String, dynamic> pawMapWithWorldPrices(
    Map<String, dynamic> p, Map<String, Map<String, dynamic>> worldIndex) {
  final ids = pawMapPersonIds(p).map((e) => e.toLowerCase());
  Map<String, dynamic>? twin;
  for (final id in ids) {
    twin = worldIndex[id];
    if (twin != null) break;
  }
  if (twin == null) return p;
  // Tarifs du jumeau, par id de rôle ET par rôle.
  final byId = <String, Map>{};
  final byRole = <String, Map>{};
  final tr = twin['roles'];
  if (tr is List) {
    for (final r in tr.whereType<Map>()) {
      final price = (r['priceFrom'] as num?)?.toDouble() ?? 0;
      if (price <= 0) continue;
      byId[(r['id'] ?? '').toString().toLowerCase()] = r;
      byRole.putIfAbsent((r['role'] ?? '').toString().toLowerCase(), () => r);
    }
  }
  bool has(Object? v) => ((v as num?)?.toDouble() ?? 0) > 0;
  final out = Map<String, dynamic>.from(p);
  final roles = p['roles'];
  if (roles is List) {
    out['roles'] = [
      for (final r in roles)
        if (r is Map && !has(r['priceFrom']))
          () {
            final src = byId[(r['id'] ?? '').toString().toLowerCase()] ??
                byRole[(r['role'] ?? '').toString().toLowerCase()];
            if (src == null) return r;
            return <String, dynamic>{
              ...Map<String, dynamic>.from(r),
              'priceFrom': src['priceFrom'],
              if (r['currency'] == null && src['currency'] != null)
                'currency': src['currency'],
            };
          }()
        else
          r,
    ];
  }
  if (!has(p['priceFrom'])) {
    final role = (p['_role'] ?? p['role'] ?? '').toString().toLowerCase();
    final src = byId[(p['id'] ?? '').toString().toLowerCase()] ?? byRole[role];
    if (src != null) {
      out['priceFrom'] = src['priceFrom'];
      out['currency'] ??= src['currency'];
    }
  }
  return out;
}
