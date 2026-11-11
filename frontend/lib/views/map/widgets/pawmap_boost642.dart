// 642 (PAM, ordre de Daniel du 11/11 : « ceux qui ont PawBoost doivent être
// visibles, leur pastille, même en dézoomant ») — un profil boosté ne rentre
// JAMAIS dans un groupe, à tous les zooms. Mais à petit zoom il tombait SUR le
// rond du groupe de sa ville (compteur caché, boostés empilés : piège relevé
// par ZOE sur le site). Ici on calcule, en pixels d'écran, un petit décalage
// pour que chaque boosté se pose À CÔTÉ : autour du rond le plus proche, sur
// un cercle, sans toucher ni un groupe, ni une autre pastille, ni un autre
// boosté.
//
// Jumeau de `website/src/lib/pawmapBoost1111.ts` : même calcul, même ordre,
// mêmes arrondis (avec `gap: 36` il rend exactement les places du site —
// testé). Seul l'écart par défaut diffère : voir [kPawBoostGap642].
// Fonction pure : même zoom + mêmes données = mêmes places (ordre stable par
// identifiant). Aucun décalage quand la place est libre.
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:hopetsit/views/map/pawmap_person.dart';

/// Coupe-circuit (jumeau de `BOOST_SOLO_1111` du site). `false` = comme au
/// 641 : un boosté se fond dans les groupes (essai sans toucher au code :
/// `--dart-define=PAWMAP_BOOST_SOLO=false`).
const bool kPawBoostSolo642 =
    bool.fromEnvironment('PAWMAP_BOOST_SOLO', defaultValue: true);

/// Distance minimale entre deux centres SUR LE SITE (`BOOST_GAP_1111` :
/// pastille 32 px + lueur douce du boost).
const double kPawBoostGapWeb1111 = 36;

/// Distance minimale entre deux centres DANS L'APP. Le calcul est celui du
/// site, mais la pastille boostée de l'app porte un anneau turquoise NET de
/// 43 pt (2 × 21,5 — sur le site c'est une lueur douce autour de 32 px) : à
/// 36, deux boostés voisins se recouvraient de 7 pt et la fusée mordait sur
/// le rond du groupe (vu sur la planche de test). 44 = 43 + 1 : rien ne se
/// touche (groupe 16 + 21,5 ; ami 20,5 + 21,5 ; « Moi » 22 + 21,5).
const double kPawBoostGap642 = 44;

/// Déplacement MAXIMAL d'un boosté (pt) : au-delà il sautait sèchement d'un
/// zoom à l'autre (178-207 px relevés par ZOE). Sans place libre dans cette
/// limite, il reste à sa vraie position.
const double kPawBoostMaxShift642 = 60;

/// Nombre maximal de boostés tenus hors des groupes (les plus proches du
/// centre de l'écran) ; les autres rejoignent les groupes, comme au 641.
const int kPawBoostSoloMax642 = 24;

/// Identifiants (minuscules) de TOUTES les personnes boostées des couches
/// [layers] — construit UNE fois par reconstruction des marqueurs. Avant :
/// chaque test « cette personne est-elle boostée ? » reparcourait toutes les
/// couches (888 000 parcours pour 400 membres).
Set<String> pawBoostedIds642(Iterable<Iterable<Map>> layers) {
  final out = <String>{};
  for (final layer in layers) {
    for (final p in layer) {
      if (p['isBoosted'] != true) continue;
      for (final id in pawMapPersonIds(p)) {
        final k = id.trim().toLowerCase();
        if (k.isNotEmpty) out.add(k);
      }
    }
  }
  return out;
}

/// [p] est-il boosté ? (son drapeau, ou l'un de ses identifiants de rôle
/// dans [boostedIds]) — même réponse que l'ancien parcours des couches.
bool pawIsBoosted642(Map p, Set<String> boostedIds) {
  if (p['isBoosted'] == true) return true;
  if (boostedIds.isEmpty) return false;
  for (final id in pawMapPersonIds(p)) {
    if (boostedIds.contains(id.trim().toLowerCase())) return true;
  }
  return false;
}

/// Les boostés tenus hors des groupes : au plus [max], les plus proches du
/// centre ([dist2] = carré de la distance au centre de l'écran), ordre
/// stable (distance puis identifiant). Vide si le coupe-circuit est coupé.
Set<String> pawBoostSoloPick642(
  List<({String id, double dist2})> boosted, {
  int max = kPawBoostSoloMax642,
  bool enabled = kPawBoostSolo642,
}) {
  if (!enabled || boosted.isEmpty) return const <String>{};
  final sorted = [...boosted]..sort((a, b) {
      final c = a.dist2.compareTo(b.dist2);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  return <String>{for (final b in sorted.take(max)) b.id};
}

/// Un profil boosté : identifiant + position à l'écran.
typedef PawBoosted642 = ({String id, Offset px});

/// Un boosté est-il tenu HORS des groupes ? (toujours, sauf coupe-circuit).
bool pawBoostSolo642(bool boosted, {bool enabled = kPawBoostSolo642}) =>
    enabled && boosted;

/// Décalage (px d'écran) de chaque profil boosté, par identifiant — absent =
/// pas de décalage. [obstacles] = centres des groupes et des autres pastilles
/// déjà posées. [maxShift] = déplacement maximal ; [allowed] = la place
/// proposée est-elle acceptable (dans l'écran, hors des rails et du menu) ?
/// Une place trop loin ou refusée → on essaie la suivante ; aucune → vraie
/// position. (Le site : `maxShift` infini, pas de `allowed`.)
Map<String, Offset> pawBoostOffsets642(
  List<PawBoosted642> boosted,
  List<Offset> obstacles, {
  double gap = kPawBoostGap642,
  double maxShift = kPawBoostMaxShift642,
  bool Function(Offset place)? allowed,
}) {
  final out = <String, Offset>{};
  final taken = <Offset>[...obstacles];
  bool free(Offset p) {
    for (final t in taken) {
      if ((t - p).distance < gap) return false;
    }
    return true;
  }

  // ordre stable : comparaison par unités de code, comme `<` en JavaScript
  final sorted = [...boosted]..sort((a, b) => a.id.compareTo(b.id));
  for (final b in sorted) {
    if (free(b.px)) {
      taken.add(b.px);
      continue;
    }
    // le rond le plus proche : on tourne autour de lui, en partant de la
    // direction du boosté
    var near = taken.first;
    var best = double.infinity;
    for (final t in taken) {
      final d = (t - b.px).distance;
      if (d < best) {
        best = d;
        near = t;
      }
    }
    final double a0 = best > 0.5
        ? math.atan2(b.px.dy - near.dy, b.px.dx - near.dx)
        : -math.pi / 2;
    Offset? placed;
    for (var ring = 1; ring <= 4 && placed == null; ring++) {
      final double r = gap * ring + 2;
      final int n = 8 * ring;
      for (var k = 0; k < n && placed == null; k++) {
        // alterne à droite puis à gauche de la direction de départ
        final int step = ((k + 1) ~/ 2) * (k.isOdd ? 1 : -1);
        final double a = a0 + (step * 2 * math.pi) / n;
        final p = Offset(near.dx + r * math.cos(a), near.dy + r * math.sin(a));
        if ((p - b.px).distance > maxShift) continue;
        if (allowed != null && !allowed(p)) continue;
        if (free(p)) placed = p;
      }
    }
    // aucune place libre à 4 cercles : il reste à sa vraie position
    final at = placed ?? b.px;
    taken.add(at);
    if (placed != null) {
      out[b.id] = Offset(_jsRound(at.dx - b.px.dx), _jsRound(at.dy - b.px.dy));
    }
  }
  return out;
}

/// `Math.round` de JavaScript (demi vers +∞), pour rester le jumeau du site.
double _jsRound(double v) => (v + 0.5).floorToDouble();

/// Rayon dessiné d'une pastille boostée (anneau turquoise compris).
const double kPawBoostPinR642 = 21.5;

/// Test « la place est-elle acceptable ? » pour [pawBoostOffsets642] : la
/// pastille (rayon [r]) tient ENTIÈRE dans [bounds] (zone visible de la
/// carte : sous l'en-tête, au-dessus du menu, 6 pt des bords) et ne touche
/// aucun des [blocked] (rail gauche, capsule droite). `bounds` null (taille
/// d'écran inconnue) = pas de contrainte de bord.
bool Function(Offset) pawBoostAllowed642(Rect? bounds, List<Rect> blocked,
    {double r = kPawBoostPinR642}) {
  return (Offset p) {
    final box = Rect.fromCircle(center: p, radius: r);
    if (bounds != null &&
        (box.left < bounds.left ||
            box.right > bounds.right ||
            box.top < bounds.top ||
            box.bottom > bounds.bottom)) {
      return false;
    }
    for (final b in blocked) {
      if (b.overlaps(box)) return false;
    }
    return true;
  };
}
