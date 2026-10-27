// COPIE FIGÉE du build 624 (commit 1acd43e3) — sert de référence « avant » au test pam625.
// 622 (PAM, 25/10/2026) — PawMap : « aucune bulle ne chevauche une autre ».
//
// Captures de Daniel (app 621, Europe / France / Benelux) : des pastilles de
// groupe et des épingles seules se recouvraient encore. Le regroupement 607
// fusionnait les centres à moins de 50 px, puis l'écartement (pawRepelBoxes)
// cherchait une place libre à 90 / 180 px ; dans une zone dense (Benelux,
// Paris + demandes), il n'en trouvait pas et laissait la bulle EN PLACE,
// posée sur sa voisine — et les demandes n'étaient même pas dans la passe.
// Ici, UNE simulation pour TOUT ce qui se pose (membres + demandes) : tant
// que deux bulles visibles se touchent, ou qu'une bulle visible ne tient pas
// entière à l'écran, on la FUSIONNE avec sa voisine de même nature (le chiffre
// augmente) et on recommence. Les décalages renvoyés sont ceux de la
// dernière passe : la carte pose exactement ce qui a été vérifié.
// Fonctions PURES, testées (test/pam622_test.dart).
import 'dart:ui' show Offset, Rect;

import 'overlap607_624.dart';

/// Résultat : les groupes (ordre stable) et le décalage écran de chacun.
class PawPlacement622<T> {
  const PawPlacement622(this.groups, this.shifts, [this.compact = const <bool>[]]);
  final List<List<T>> groups;
  final List<Offset> shifts;
  /// Vrai : la bulle a REPLIÉ son prix (place trop juste) — règle du site.
  final List<bool> compact;
  bool isCompact(int i) => i < compact.length && compact[i];
}

/// Regroupe et place jusqu'à ce que toutes les bulles VISIBLES ([screen])
/// tiennent sans contact (entre elles et avec les [fixed] : Moi, amis,
/// barres), entières dans [bounds].
///   · [px] : pixels d'écran d'un point (relatifs au centre de la carte) ;
///   · [boxOf] : boîte visible d'un groupe relative à son centre ;
///   · [movable] : faux pour un groupe qui ne bouge ni ne se fond (un ami) ;
///   · [canMerge] : deux groupes peuvent-ils se fondre (même nature) ?
PawPlacement622<T> pawPlace622<T>(
  List<List<T>> groups,
  Offset Function(T) px, {
  required Rect Function(List<T> g) boxOf,
  /// Boîte quand la bulle replie son prix (null : jamais de repli).
  Rect Function(List<T> g)? compactBoxOf,
  List<PawPlacedBox> fixed = const <PawPlacedBox>[],
  bool Function(List<T> g)? movable,
  bool Function(List<T> a, List<T> b)? canMerge,
  Rect? bounds,
  Rect? screen,
  int maxRounds = 12,
}) {
  var cur = <List<T>>[
    for (final g in groups)
      if (g.isNotEmpty) List<T>.of(g),
  ];
  var compact = List<bool>.filled(cur.length, false);
  var shifts = List<Offset>.filled(cur.length, Offset.zero);
  for (var round = 0; round < maxRounds; round++) {
    final at = <Offset>[for (final g in cur) _center(g, px)];
    final boxes = <Rect>[
      for (var i = 0; i < cur.length; i++)
        (compact[i] && compactBoxOf != null) ? compactBoxOf(cur[i]) : boxOf(cur[i]),
    ];
    final mov = <bool>[for (final g in cur) movable == null || movable(g)];
    shifts = pawRepelBoxes(at, boxes, fixed,
        movable: mov, bounds: bounds, screen: screen);
    if (cur.length < 2 || round == maxRounds - 1) break;
    final placed = <Offset>[for (var i = 0; i < at.length; i++) at[i] + shifts[i]];
    bool visible(int i) =>
        screen == null || boxes[i].shift(placed[i]).overlaps(screen);
    bool merges(int i, int j) =>
        mov[i] && mov[j] && (canMerge == null || canMerge(cur[i], cur[j]));
    final parent = List<int>.generate(cur.length, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    var merged = false;
    var folded = false;
    // 622 (règle du site, LEO) — avant de fondre deux bulles, celle qui porte
    // un prix le REPLIE (la bulle rétrécit) : on garde le plus de bulles
    // séparées possible.
    bool fold(int i) {
      if (compactBoxOf == null || compact[i] || !mov[i]) return false;
      final small = compactBoxOf(cur[i]);
      if (small == boxes[i]) return false;
      compact[i] = true;
      folded = true;
      return true;
    }

    void union(int i, int j) {
      final a = find(i), b = find(j);
      if (a != b) {
        parent[b] = a;
        merged = true;
      }
    }

    int nearestCompatible(int i, {int except = -1}) {
      var best = -1;
      var bestD = double.infinity;
      for (var k = 0; k < cur.length; k++) {
        if (k == i || k == except || !merges(i, k)) continue;
        final d = (at[k] - at[i]).distanceSquared;
        if (d < bestD) {
          bestD = d;
          best = k;
        }
      }
      return best;
    }

    // 1. Deux bulles visibles qui se touchent encore : même nature → elles
    //    se fondent ; natures différentes (un membre et une demande) → l'une
    //    des deux rejoint sa voisine de même nature, ce qui libère la place.
    for (var i = 0; i < cur.length; i++) {
      if (!visible(i)) continue;
      for (var j = i + 1; j < cur.length; j++) {
        if (!visible(j)) continue;
        if (!pawBoxesTouch(placed[i], boxes[i], placed[j], boxes[j], air: 0)) continue;
        // La plus large replie d'abord son prix, sinon l'autre.
        final wideFirst = boxes[i].width * boxes[i].height >= boxes[j].width * boxes[j].height;
        if (wideFirst ? (fold(i) || fold(j)) : (fold(j) || fold(i))) continue;
        if (merges(i, j)) {
          union(i, j);
          continue;
        }
        final ki = mov[i] ? nearestCompatible(i, except: j) : -1;
        if (ki >= 0) {
          union(i, ki);
          continue;
        }
        final kj = mov[j] ? nearestCompatible(j, except: i) : -1;
        if (kj >= 0) union(j, kj);
      }
    }
    // 2. Une bulle visible sans place (coupée, ou posée sur un obstacle
    //    fixe) : elle rejoint sa plus proche voisine de même nature.
    for (var i = 0; i < cur.length; i++) {
      if (!visible(i) || !mov[i]) continue;
      final bool cut = bounds != null && !pawBoxInside(placed[i], boxes[i], bounds);
      var onFixed = false;
      for (final f in fixed) {
        if (pawBoxesTouch(placed[i], boxes[i], f.at, f.box, air: 0)) {
          onFixed = true;
          break;
        }
      }
      if (!cut && !onFixed) continue;
      if (fold(i)) continue;
      final best = nearestCompatible(i);
      if (best >= 0) union(i, best);
    }
    if (!merged && !folded) break;
    if (!merged) continue; // seulement des replis : on replace, mêmes groupes
    final byRoot = <int, List<T>>{};
    final foldOf = <int, bool>{};
    final sizeOf = <int, int>{};
    final order = <int>[];
    for (var i = 0; i < cur.length; i++) {
      final r = find(i);
      if (!byRoot.containsKey(r)) order.add(r);
      (byRoot[r] ??= <T>[]).addAll(cur[i]);
      foldOf[r] = (foldOf[r] ?? true) && compact[i];
      sizeOf[r] = (sizeOf[r] ?? 0) + 1;
    }
    cur = [for (final r in order) byRoot[r]!];
    // Un groupe neuf (fusion) repart avec son prix ; un groupe inchangé
    // garde son repli.
    compact = [for (final r in order) sizeOf[r] == 1 && foldOf[r]!];
  }
  return PawPlacement622<T>(cur, shifts, compact);
}

/// Groupes seuls (voir [pawPlace622]) ; [mergeable] faux = ni bouge ni fond.
List<List<T>> pawMergeUntilPlaced622<T>(
  List<List<T>> groups,
  Offset Function(T) px, {
  required Rect Function(List<T> g) boxOf,
  List<PawPlacedBox> fixed = const <PawPlacedBox>[],
  bool Function(List<T> g)? mergeable,
  Rect? bounds,
  Rect? screen,
  int maxRounds = 8,
}) =>
    pawPlace622<T>(groups, px,
            boxOf: boxOf,
            fixed: fixed,
            movable: mergeable,
            bounds: bounds,
            screen: screen,
            maxRounds: maxRounds)
        .groups;

Offset _center<T>(List<T> g, Offset Function(T) px) {
  var x = 0.0, y = 0.0;
  for (final it in g) {
    final p = px(it);
    x += p.dx;
    y += p.dy;
  }
  return Offset(x / g.length, y / g.length);
}
