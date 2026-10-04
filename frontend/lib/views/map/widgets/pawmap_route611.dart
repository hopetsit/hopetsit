// 611 (PAM, 04/10/2026) — Daniel : « as-tu vérifié qu'on peut se faire un
// itinéraire entre amis ? ». Règles (pures, testées) :
//   · ami hors direct → la VRAIE position que le serveur renvoie pour un ami
//     (règle A du 610, `approx:false`), jamais un point flouté resté en mémoire ;
//   · ami EN DIRECT → la position du direct, et l'itinéraire SUIT l'ami :
//     recalcul s'il s'est déplacé de plus de 50 m, ou de plus de 10 m après
//     30 s ; arrêt propre quand il coupe son direct ;
//   · non-ami (position floutée ~1 km) → pas d'itinéraire : un trajet vers
//     un point faux trompe la personne (choix le plus honnête et simple).
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

double _meters(LatLng a, LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(h));
}

/// Un itinéraire n'a de sens que vers une position EXACTE.
bool pawDirectionsAllowed611({required bool approx}) => !approx;

class PawRouteTarget611 {
  const PawRouteTarget611(this.dest, {this.followLive = false});
  final LatLng dest;
  final bool followLive;
}

/// Destination d'un itinéraire vers une personne ([personIds] = ses profils).
/// [live] = position de son direct en cours (ami), [world] = couches membres
/// chargées, [tapped] = point du marqueur touché ([tappedApprox] s'il est flouté).
PawRouteTarget611? pawRouteTarget611({
  required List<String> personIds,
  required List<Map<String, dynamic>> world,
  required LatLng? live,
  required LatLng? tapped,
  required bool tappedApprox,
}) {
  if (live != null) return PawRouteTarget611(live, followLive: true);
  final keys = personIds.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
  for (final m in world) {
    if (m['approx'] == true) continue;
    final ids = <String>{
      (m['id'] ?? m['_id'] ?? '').toString(),
      ...((m['personIds'] as List?) ?? const []).map((e) => e.toString()),
    }.map((e) => e.trim().toLowerCase());
    if (!ids.any(keys.contains)) continue;
    final c = (m['location'] as Map?)?['coordinates'];
    if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
      return PawRouteTarget611(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
    }
  }
  if (tapped != null && !tappedApprox) return PawRouteTarget611(tapped);
  return null;
}

/// Itinéraire vers un ami EN DIRECT : quand recalculer.
class PawRouteFollow611 {
  String? friendId;
  LatLng? _dest;
  DateTime? _at;

  static const double moveM = 50;
  static const double slowMoveM = 10;
  static const Duration every = Duration(seconds: 30);

  void start(String id, LatLng dest, DateTime now) {
    friendId = id;
    mark(dest, now);
  }

  void mark(LatLng dest, DateTime now) {
    _dest = dest;
    _at = now;
  }

  void stop() {
    friendId = null;
    _dest = null;
    _at = null;
  }

  bool shouldRecompute(LatLng pos, DateTime now) {
    if (friendId == null || _dest == null || _at == null) return false;
    final d = _meters(_dest!, pos);
    if (d >= moveM) return true;
    return now.difference(_at!) >= every && d >= slowMoveM;
  }
}
