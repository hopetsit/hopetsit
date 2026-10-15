// 616 (PAM, 15/10/2026) — PawMap : ronds de regroupement et épingles pendant
// un zoom / dézoom RAPIDE (captures de Daniel des 14 et 15/10), et point
// « en ligne / hors ligne » à jour sans relancer l'app (demande du 10/10).
//
// Fonctions PURES, testées dans test/pam616_zoom_test.dart :
//   · [pawMapRecalcDuringMove616] : pendant un pincement, les épingles sont
//     recalculées dès que le zoom s'écarte d'un demi-niveau de celui des
//     épingles posées, au plus toutes les 120 ms — avant, tout attendait
//     l'ARRÊT de la caméra + 450 ms : les ronds restaient groupés comme à
//     l'ancien zoom, se recouvraient en dézoomant, puis sautaient d'un coup ;
//   · [pawClusterKey616] : identifiant STABLE d'un rond de groupe (le plus
//     petit id de ses membres) — avant, l'id portait la position et
//     l'effectif du groupe, donc chaque recalcul retirait et recréait TOUS
//     les ronds côté Google Maps (une création + une destruction par rond à
//     chaque demi-niveau de zoom) ; avec une clé stable, Google Maps met le
//     rond à jour en place (position, image) ;
//   · [pawPersonPresence616] : présence d'une PERSONNE à partir de ses ids
//     de rôle ;
//   · [pawPresenceIdsToPoll616] : ids à sonder sur
//     GET /friends/members/presence (membres proches, position exacte).
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Écart de zoom à partir duquel les épingles sont recalculées en plein geste.
const double kPawZoomRecalcStep616 = 0.5;

/// Délai minimal entre deux recalculs pendant un geste (ms).
const int kPawZoomRecalcMinMs616 = 120;

/// Faut-il recalculer les épingles maintenant ? [zoom] = zoom courant de la
/// caméra, [pinZoom] = zoom auquel les épingles posées ont été calculées,
/// [lastAt] = dernier recalcul en plein geste (null = jamais).
bool pawMapRecalcDuringMove616({
  required double zoom,
  required double pinZoom,
  required DateTime? lastAt,
  required DateTime now,
  double step = kPawZoomRecalcStep616,
  int minMs = kPawZoomRecalcMinMs616,
}) {
  if ((zoom - pinZoom).abs() < step) return false;
  if (lastAt == null) return true;
  return now.difference(lastAt).inMilliseconds >= minMs;
}

/// Identifiant stable d'un groupe : le plus petit id (ordre des chaînes) de
/// ses membres, '' si aucun id.
String pawClusterKey616(Iterable<String> ids) {
  String? best;
  for (final raw in ids) {
    final id = raw.trim();
    if (id.isEmpty) continue;
    if (best == null || id.compareTo(best) < 0) best = id;
  }
  return best ?? '';
}

/// Présence d'une personne : un de ses ids en ligne → true ; tous les ids
/// connus hors ligne → false ; aucun id connu → null (l'appelant garde la
/// valeur chargée avec la liste).
bool? pawPersonPresence616(
    Iterable<String> ids, bool? Function(String id) lookup) {
  bool? out;
  for (final id in ids) {
    final v = lookup(id);
    if (v == true) return true;
    if (v == false) out = false;
  }
  return out;
}

/// Ids de rôle à sonder : membres à position EXACTE seulement (la couche
/// monde floutée ne montre jamais de point de statut), tous les ids de la
/// personne, dédoublonnés, [max] au plus (l'URL reste courte).
List<String> pawPresenceIdsToPoll616(Iterable<Map<String, dynamic>> members,
    {int max = 120}) {
  final out = <String>[];
  final seen = <String>{};
  for (final m in members) {
    if (m['approx'] == true) continue;
    final ids = <String>[
      (m['id'] ?? m['_id'] ?? '').toString(),
      if (m['personIds'] is List)
        ...(m['personIds'] as List).map((e) => e.toString()),
    ];
    for (final raw in ids) {
      final id = raw.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(id);
      if (out.length >= max) return out;
    }
  }
  return out;
}

/// Applique une réponse `{ id: bool }` à la table de présence ; renvoie le
/// nombre d'entrées qui ont CHANGÉ (0 = rien à redessiner).
int pawApplyPresence616(Map<String, bool> presence, Map<dynamic, dynamic> online) {
  var changed = 0;
  online.forEach((k, v) {
    final id = k.toString().trim();
    if (id.isEmpty || v is! bool) return;
    if (presence[id] != v) {
      presence[id] = v;
      changed++;
    }
  });
  return changed;
}

/// Marqueurs d'un même id entre deux images : la POSITION d'une personne ne
/// change jamais pendant un zoom (seuls les ronds de groupe bougent, par
/// construction). Renvoie les ids qui ont bougé de plus de [tolDeg] degrés.
List<String> pawMovedPersonIds616(
    Map<String, LatLng> before, Map<String, LatLng> after,
    {double tolDeg = 1e-7}) {
  final out = <String>[];
  for (final e in after.entries) {
    final id = e.key;
    if (!(id.startsWith('nearby_') || id.startsWith('friend_') || id == 'me')) {
      continue;
    }
    final prev = before[id];
    if (prev == null) continue;
    if ((prev.latitude - e.value.latitude).abs() > tolDeg ||
        (prev.longitude - e.value.longitude).abs() > tolDeg) {
      out.add(id);
    }
  }
  return out;
}
