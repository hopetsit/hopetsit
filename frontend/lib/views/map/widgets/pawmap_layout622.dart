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

import 'pawmap_anchor625.dart';
import 'pawmap_overlap607.dart';

/// Résultat : les groupes (ordre stable) et le décalage écran de chacun.
class PawPlacement622<T> {
  const PawPlacement622(this.groups, this.shifts,
      [this.compact = const <bool>[], this.hidden = const <bool>[]]);
  final List<List<T>> groups;
  final List<Offset> shifts;
  /// Vrai : la bulle a REPLIÉ son prix (place trop juste) — règle du site.
  final List<bool> compact;
  /// 625 — vrai : pas de place à ≤ 12 pt de sa position → NON dessiné (on
  /// le retrouve en zoomant). Jamais « Moi » ni un ami.
  final List<bool> hidden;
  bool isCompact(int i) => i < compact.length && compact[i];
  bool isHidden(int i) => i < hidden.length && hidden[i];
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
  /// 625 (parité site) — vrai pour un rond de personne / un groupe : il reste
  /// SUR sa position (glissement ≤ [kPawAnchorMaxShift625]) ; sans place, il
  /// replie sa bulle puis est masqué. Null : comportement 622 (tout glisse).
  bool Function(List<T> g)? anchored,
  /// 626 — vrai : un groupe ancré (rond de personne, groupe de membres) n'est
  /// JAMAIS masqué ni fondu par la passe : il reste affiché sur sa position
  /// (glissement ≤ 12 pt, prix replié si la place manque). Le regroupement
  /// hiérarchique stable (pawmap_cluster626) a déjà garanti ≥ 56 pt entre
  /// deux groupes ; masquer au bord, sous un rail ou sous Moi faisait
  /// apparaître / disparaître des groupes selon le chemin suivi.
  bool keepAnchored = false,
}) {
  var cur = <List<T>>[
    for (final g in groups)
      if (g.isNotEmpty) List<T>.of(g),
  ];
  var compact = List<bool>.filled(cur.length, false);
  var shifts = List<Offset>.filled(cur.length, Offset.zero);
  var hidden = List<bool>.filled(cur.length, false);
  for (var round = 0; round < maxRounds; round++) {
    // 625 — un groupe est posé sur son membre le plus central (médoïde),
    // jamais sur la moyenne (moyenne de deux côtes = en mer).
    final at = <Offset>[for (final g in cur) pawAnchorPx625(g, px)];
    final boxes = <Rect>[
      for (var i = 0; i < cur.length; i++)
        (compact[i] && compactBoxOf != null) ? compactBoxOf(cur[i]) : boxOf(cur[i]),
    ];
    final mov = <bool>[for (final g in cur) movable == null || movable(g)];
    final anc = <bool>[for (final g in cur) anchored != null && anchored(g)];
    final unplaced = <int>{};
    shifts = pawRepelBoxes(at, boxes, fixed,
        movable: mov,
        bounds: bounds,
        screen: screen,
        anchored: anc,
        anchorMax: kPawAnchorMaxShift625,
        unplaced: unplaced);
    hidden = List<bool>.filled(cur.length, false);
    final bool lastRound = round == maxRounds - 1;
    final placed = <Offset>[for (var i = 0; i < at.length; i++) at[i] + shifts[i]];
    bool visible(int i) =>
        !hidden[i] && (screen == null || boxes[i].shift(placed[i]).overlaps(screen));
    // 625 — masquer (jamais un immobile : Moi, ami) : sans place, le rond
    // ancré ne part pas loin, il s'efface et réapparaît en zoomant.
    var hid = false;
    bool hide(int i) {
      if (!mov[i] || hidden[i] || (keepAnchored && anc[i])) return false;
      hidden[i] = true;
      hid = true;
      return true;
    }
    bool merges(int i, int j) =>
        mov[i] && mov[j] &&
        !(keepAnchored && (anc[i] || anc[j])) &&
        (canMerge == null || canMerge(cur[i], cur[j]));
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
      if (lastRound) return; // dernière passe : plus de fusion, on masque
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
        if (merges(i, j) && !lastRound) {
          union(i, j);
          continue;
        }
        if (anc[i] || anc[j]) {
          // 625 — un rond ancré ne rejoint JAMAIS un voisin lointain à cause
          // d'une demande : c'est l'autre (non ancré) qui se fond avec sa
          // voisine de même nature, sinon s'efface ; deux ancrés de natures
          // différentes (ami / membre) : le mobile s'efface.
          final o = anc[i] && !anc[j] ? j : (anc[j] && !anc[i] ? i : (mov[j] ? j : i));
          final k = (!anc[o] && mov[o] && !lastRound)
              ? nearestCompatible(o, except: o == i ? j : i)
              : -1;
          if (k >= 0) {
            union(o, k);
          } else if (!hide(o)) {
            hide(o == i ? j : i);
          }
          continue;
        }
        if (lastRound) {
          if (!hide(j)) hide(i);
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
      if (anc[i] || lastRound) {
        // 625 — ancré sans place (sous Moi, un rail, coupé au bord) : masqué.
        hide(i);
        continue;
      }
      final best = nearestCompatible(i);
      if (best >= 0) union(i, best);
    }
    // 625 — ancré resté sans place à ≤ 12 pt (déjà replié) : masqué.
    for (final i in unplaced) {
      if (hidden[i] || !visible(i)) continue;
      var touches = false;
      for (var j = 0; j < cur.length && !touches; j++) {
        if (j != i && visible(j) &&
            pawBoxesTouch(placed[i], boxes[i], placed[j], boxes[j], air: 0)) {
          touches = true;
        }
      }
      for (final f in fixed) {
        if (touches) break;
        if (pawBoxesTouch(placed[i], boxes[i], f.at, f.box, air: 0)) touches = true;
      }
      if (touches && !fold(i)) hide(i);
    }
    if (cur.length < 2 && !hid && !folded) break;
    if (lastRound) break;
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
    hidden = List<bool>.filled(cur.length, false);
  }
  return PawPlacement622<T>(cur, shifts, compact, hidden);
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
