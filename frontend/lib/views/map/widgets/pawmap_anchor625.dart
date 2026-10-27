// 625 (PAM, 27/10/2026) — PawMap : « les marqueurs ne sont pas à leur place ».
//
// Capture d'un utilisateur espagnol (26/10, 22 h 18) : groupes posés en mer
// (Atlantique, Manche), ronds décalés de leurs villes. Causes (même mesure
// que LEO sur le site, commit c0fe532c) :
//   1. un groupe était posé sur la MOYENNE de ses membres → entre deux côtes,
//      la moyenne tombe dans l'eau ;
//   2. la passe anti-chevauchement (pawmap_layout622 / pawmap_overlap607)
//      DÉPLAÇAIT ronds et groupes de 90 px, puis 180 px, pour qu'ils ne se
//      touchent pas.
// Règle (parité site, `mergeAnchored2610` + `ANCHORED_2610`) :
//   · deux positions affichées à moins de 56 pt (rond 50 + air 6) sont
//     FUSIONNÉES (le chiffre augmente), en recommençant par la paire la plus
//     proche jusqu'à ce qu'aucune ne le soit plus ;
//   · un groupe est posé sur la position de son membre le plus central
//     (médoïde), JAMAIS sur la moyenne ;
//   · ronds de personnes et groupes : glissement ≤ 12 pt ; sans place, la
//     bulle se replie puis le rond s'efface (« Moi » et les amis jamais) ;
//     seuls les demandes et les lieux s'écartent plus loin.
// Fonctions PURES, testées (test/pam625_placement_test.dart).
import 'dart:ui' show Offset;

/// Écart minimal entre deux positions affichées (pt) : rond 50 + air 6.
const double kPawAnchorMinPx625 = 56;

/// Glissement maximal d'un rond de personne ou d'un groupe (pt) : ½ rond.
const double kPawAnchorMaxShift625 = 12;

/// Index du membre le plus proche du centre (moyenne) de [pts] : le groupe
/// est posé SUR lui (une vraie position, jamais la moyenne).
int pawMedoidIndex625(List<Offset> pts) {
  if (pts.length < 2) return 0;
  var mx = 0.0, my = 0.0;
  for (final p in pts) {
    mx += p.dx;
    my += p.dy;
  }
  mx /= pts.length;
  my /= pts.length;
  var best = 0;
  var bd = double.infinity;
  for (var i = 0; i < pts.length; i++) {
    final dx = pts[i].dx - mx, dy = pts[i].dy - my;
    final d = dx * dx + dy * dy;
    if (d < bd) {
      bd = d;
      best = i;
    }
  }
  return best;
}

/// Le membre sur lequel le groupe [g] est posé.
T pawAnchorOf625<T>(List<T> g, Offset Function(T) px) =>
    g[pawMedoidIndex625([for (final it in g) px(it)])];

/// Position (mêmes unités que [px]) où le groupe [g] est posé.
Offset pawAnchorPx625<T>(List<T> g, Offset Function(T) px) =>
    g.length == 1 ? px(g.first) : px(pawAnchorOf625(g, px));

/// Regroupement ANCRÉ : fusionne la paire de groupes dont les positions
/// affichées (médoïdes) sont les plus proches, tant qu'elle est à moins de
/// [minPx] ; recommence jusqu'à ce qu'aucune paire ne le soit. L'ordre des
/// membres est conservé (le 1er groupe absorbe le 2e, à sa place).
List<List<T>> pawMergeAnchored625<T>(
  List<List<T>> groups,
  Offset Function(T) px, {
  double minPx = kPawAnchorMinPx625,
}) {
  final gs = <_A<T>>[
    for (final g in groups)
      if (g.isNotEmpty) _A<T>(List<T>.of(g), [for (final it in g) px(it)]),
  ];
  final min2 = minPx * minPx;
  for (var guard = 0; guard < 4000 && gs.length > 1; guard++) {
    var bi = -1, bj = -1;
    var bd = double.infinity;
    for (var i = 0; i < gs.length; i++) {
      final pi = gs[i].at;
      for (var j = i + 1; j < gs.length; j++) {
        final d = (pi - gs[j].at).distanceSquared;
        if (d < min2 && d < bd) {
          bd = d;
          bi = i;
          bj = j;
        }
      }
    }
    if (bi < 0) break;
    gs[bi].absorb(gs[bj]);
    gs.removeAt(bj);
  }
  return [for (final g in gs) g.items];
}

class _A<T> {
  _A(this.items, this.pts) : at = pts[pawMedoidIndex625(pts)];
  final List<T> items;
  final List<Offset> pts;
  Offset at;
  void absorb(_A<T> o) {
    items.addAll(o.items);
    pts.addAll(o.pts);
    at = pts[pawMedoidIndex625(pts)];
  }
}
