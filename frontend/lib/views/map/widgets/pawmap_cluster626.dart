// 626 (PAM, 27/10/2026) — PawMap : regroupement STABLE et hiérarchique.
//
// Bug de Daniel (27/10, app 625) : « le zoom dézoom bug, des fois ça apparaît
// les groupes d'autres fois pas, après ça ouvre les gens dans l'eau ».
// Causes MESURÉES (couche monde réelle, 271 membres, test local) :
//   1. les groupes étaient calculés au zoom CONTINU (cases de 44 pt puis
//      fusion à 56 pt) : de 4,3 à 5,3 sur la même vue Europe, le grand groupe
//      passait de 114 à 101 membres, le 2e de 22 à 26, le 3e de 16 à 8 ; deux
//      chemins qui finissent à 4,48 et 4,52 ne montraient pas la même carte ;
//   2. la passe de placement MASQUAIT des groupes (jusqu'à 9 groupes /
//      21 membres) touchant un bord, un rail, Moi ou un ami ;
//   3. toucher un groupe de ≤ 45 membres l'« éclatait » en anneaux FIXES de
//      72 / 132 / 192 pt autour de son centre, au zoom +1,5 : dézoomé, 192 pt
//      = des centaines de km, d'où les gens en plein Atlantique.
// Règle 626 (même règle sur le site, écrite pour LEO dans PAM_rapport.md) :
//   · niveau de regroupement Z = partie entière du zoom (0 à [kPawClusterMaxZoom626]) :
//     entre deux niveaux entiers, les groupes ne changent pas ;
//   · hiérarchie : au niveau Z, on regroupe les groupes du niveau Z+1 (en
//     partant de chaque membre seul au niveau max + 1) → un groupe se divise
//     en ses enfants quand on zoome, ils se recomposent quand on dézoome ;
//   · ordre fixe (plus gros d'abord, puis identifiant le plus petit) : le
//     résultat ne dépend ni de l'ordre de chargement ni du chemin suivi ;
//   · un groupe est posé sur son membre le plus central (médoïde, règle 625) ;
//   · deux positions affichées à moins de 56 pt au niveau Z fusionnent,
//     jusqu'à ce qu'aucune ne le soit plus → à l'écran, écart ≥ 56 pt
//     (car zoom ≥ Z).
// Fonctions PURES, testées (test/pam626_cluster_test.dart).
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'pawmap_anchor625.dart';
import 'pawmap_overlap607.dart' show pawMercatorPx;

/// Dernier niveau où des points peuvent encore être groupés (au-delà, tout
/// est seul). Zoom 20 : 56 pt ≈ 8 m — seuls les points quasi superposés.
const int kPawClusterMaxZoom626 = 20;

/// Niveau de regroupement d'un zoom de caméra (partie entière, bornée).
int pawClusterLevel626(double zoom) {
  if (zoom.isNaN) return 0;
  return zoom.floor().clamp(0, kPawClusterMaxZoom626 + 1);
}

/// Un groupe au niveau Z : ses éléments (ordre stable) et son ancre.
class PawCluster626<T> {
  PawCluster626(this.items, this.pts, this.ids)
      : anchor = pts[pawMedoidIndex625(pts)],
        minId = ids.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final List<T> items;
  /// Positions Mercator au zoom 0 (pt), une par élément.
  final List<Offset> pts;
  final List<String> ids;
  /// Position affichée (zoom 0) : celle du membre le plus central.
  Offset anchor;
  String minId;
  int get length => items.length;

  /// Élément sur lequel le groupe est posé (un vrai point, jamais la moyenne).
  T get anchorItem => items[pawMedoidIndex625(pts)];

  void absorb(PawCluster626<T> o) {
    items.addAll(o.items);
    pts.addAll(o.pts);
    ids.addAll(o.ids);
    anchor = pts[pawMedoidIndex625(pts)];
    if (o.minId.compareTo(minId) < 0) minId = o.minId;
  }

  PawCluster626<T> copy() => PawCluster626<T>(
      List<T>.of(items), List<Offset>.of(pts), List<String>.of(ids));
}

int _order<T>(PawCluster626<T> a, PawCluster626<T> b) {
  final c = b.length.compareTo(a.length);
  return c != 0 ? c : a.minId.compareTo(b.minId);
}

/// Index hiérarchique de regroupement (calculé une fois par jeu de données).
class PawClusterIndex626<T> {
  PawClusterIndex626._(this._levels, this.signature);

  /// [radiusAt] : écart minimal (pt) entre deux positions affichées au niveau Z.
  factory PawClusterIndex626(
    List<T> items, {
    required String Function(T) idOf,
    required ({double lat, double lng}) Function(T) posOf,
    double Function(int level)? radiusAt,
    String signature = '',
  }) {
    final rad = radiusAt ?? (_) => kPawAnchorMinPx625;
    final sorted = List<T>.of(items)..sort((a, b) => idOf(a).compareTo(idOf(b)));
    var cur = <PawCluster626<T>>[
      for (final it in sorted)
        () {
          final p = posOf(it);
          return PawCluster626<T>(<T>[it], <Offset>[pawMercatorPx(p.lat, p.lng, 0)],
              <String>[idOf(it)]);
        }(),
    ];
    final levels = List<List<PawCluster626<T>>>.filled(
        kPawClusterMaxZoom626 + 2, const [], growable: false);
    levels[kPawClusterMaxZoom626 + 1] = cur;
    for (var z = kPawClusterMaxZoom626; z >= 0; z--) {
      final r0 = rad(z) / math.pow(2.0, z); // rayon en unités du zoom 0
      cur = _clusterLevel<T>(cur, r0);
      levels[z] = cur;
    }
    return PawClusterIndex626<T>._(levels, signature);
  }

  final List<List<PawCluster626<T>>> _levels;
  /// Empreinte des données qui ont servi à construire l'index.
  final String signature;

  /// Groupes au zoom [zoom] (niveau = partie entière).
  List<PawCluster626<T>> clustersAt(double zoom) => _levels[pawClusterLevel626(zoom)];

  /// Plus petit niveau où les éléments de [ids] ne forment plus UN seul
  /// groupe (null : encore ensemble au niveau max — points superposés ou à
  /// quelques mètres : on ouvre la liste au lieu de zoomer).
  int? expansionLevel(Iterable<String> ids, {required double fromZoom}) {
    final want = ids.toSet();
    if (want.length < 2) return null;
    for (var z = pawClusterLevel626(fromZoom) + 1; z <= kPawClusterMaxZoom626; z++) {
      final holders = <int>{};
      final lv = _levels[z];
      for (var i = 0; i < lv.length && holders.length < 2; i++) {
        for (final id in lv[i].ids) {
          if (want.contains(id)) {
            holders.add(i);
            break;
          }
        }
      }
      if (holders.length >= 2) return z;
    }
    return null;
  }
}

List<PawCluster626<T>> _clusterLevel<T>(List<PawCluster626<T>> prev, double r) {
  final src = [for (final c in prev) c]..sort(_order);
  // 1. Graines : chaque groupe (plus gros d'abord) absorbe les groupes encore
  //    libres dont l'ancre est à moins de r de la sienne.
  final cell = r;
  String key(Offset p) => '${(p.dx / cell).floor()}:${(p.dy / cell).floor()}';
  final grid = <String, List<int>>{};
  for (var i = 0; i < src.length; i++) {
    (grid[key(src[i].anchor)] ??= <int>[]).add(i);
  }
  final taken = List<bool>.filled(src.length, false);
  final out = <PawCluster626<T>>[];
  final r2 = r * r;
  for (var i = 0; i < src.length; i++) {
    if (taken[i]) continue;
    taken[i] = true;
    final seed = src[i];
    final c = seed.copy();
    final cx = (seed.anchor.dx / cell).floor(), cy = (seed.anchor.dy / cell).floor();
    final near = <int>[];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final j in grid['${cx + dx}:${cy + dy}'] ?? const <int>[]) {
          if (!taken[j] && (src[j].anchor - seed.anchor).distanceSquared < r2) near.add(j);
        }
      }
    }
    near.sort();
    for (final j in near) {
      taken[j] = true;
      c.absorb(src[j]);
    }
    out.add(c);
  }
  // 2. Les ancres (médoïdes) ont pu se rapprocher : on fusionne toute paire
  //    à moins de r, la plus proche d'abord, jusqu'à ce qu'il n'y en ait plus.
  return _mergeClose<T>(out, r);
}

List<PawCluster626<T>> _mergeClose<T>(List<PawCluster626<T>> cs, double r) {
  final r2 = r * r;
  var cur = cs..sort(_order);
  for (var guard = 0; guard < 10000; guard++) {
    final grid = <String, List<int>>{};
    String k(int x, int y) => '$x:$y';
    for (var i = 0; i < cur.length; i++) {
      final a = cur[i].anchor;
      (grid[k((a.dx / r).floor(), (a.dy / r).floor())] ??= <int>[]).add(i);
    }
    var bi = -1, bj = -1;
    var bd = double.infinity;
    for (var i = 0; i < cur.length; i++) {
      final a = cur[i].anchor;
      final cx = (a.dx / r).floor(), cy = (a.dy / r).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final j in grid[k(cx + dx, cy + dy)] ?? const <int>[]) {
            if (j <= i) continue;
            final d = (cur[j].anchor - a).distanceSquared;
            if (d < r2 && d < bd) {
              bd = d;
              bi = i;
              bj = j;
            }
          }
        }
      }
    }
    if (bi < 0) break;
    cur[bi].absorb(cur[bj]);
    cur.removeAt(bj);
    cur = cur..sort(_order);
  }
  return cur;
}

/// Empreinte bon marché d'un jeu de points (ids + positions arrondies au m).
String pawClusterSignature626<T>(
  Iterable<T> items,
  String Function(T) idOf,
  ({double lat, double lng}) Function(T) posOf,
) {
  var h = 0;
  var n = 0;
  for (final it in items) {
    final p = posOf(it);
    final s = '${idOf(it)}@${(p.lat * 1e5).round()},${(p.lng * 1e5).round()}';
    h = (h + s.hashCode * 0x9E3779B1) & 0x3fffffffffff; // somme : ordre indifférent
    h ^= s.length;
    n++;
  }
  return '$n:$h';
}

/// Zoom qui montre TOUS les points [pts] (Mercator zoom 0) dans une zone
/// utile [w] × [h] pt, et le centre (zoom 0) de leur emprise.
({double zoom, Offset center}) pawFitZoom626(List<Offset> pts, double w, double h) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in pts) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  final dx = math.max(maxX - minX, 1e-9), dy = math.max(maxY - minY, 1e-9);
  final z = math.log(math.min(w / dx, h / dy)) / math.ln2;
  return (zoom: z, center: Offset((minX + maxX) / 2, (minY + maxY) / 2));
}

/// Inverse de [pawMercatorPx] au zoom 0 : (lat, lng).
({double lat, double lng}) pawMercatorInverse0(Offset p) {
  final lng = p.dx / 256.0 * 360.0 - 180.0;
  final n = math.pi - 2 * math.pi * p.dy / 256.0;
  final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  return (lat: lat, lng: lng);
}

/// Cible de caméra quand on touche un groupe : le zoom qui montre tous ses
/// membres (zone utile [w] × [h]) et, s'il ne suffit pas à le diviser, son
/// niveau d'éclatement [expansionLevel] (+ 0,05). Null : rien à zoomer
/// (points superposés ou zoom max atteint) → la liste du groupe.
({double zoom, ({double lat, double lng}) center})? pawClusterTapTarget626({
  required List<Offset> pts,
  required double w,
  required double h,
  required double currentZoom,
  required int? expansionLevel,
  double maxZoom = 20,
}) {
  if (pts.length < 2 || expansionLevel == null) return null;
  final fit = pawFitZoom626(pts, w, h);
  var z = fit.zoom;
  if (z < expansionLevel) z = expansionLevel + 0.05;
  if (z > maxZoom) {
    if (expansionLevel > maxZoom) return null;
    z = maxZoom;
  }
  if (z <= currentZoom + 0.05) z = math.min(maxZoom, currentZoom + 1);
  return (zoom: z, center: pawMercatorInverse0(fit.center));
}
