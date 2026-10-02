// 607 (PAM, 01/10/2026) — PawMap : plus rien ne se chevauche.
//
// Captures de Daniel (iPhone, build 605/606, zoom pays sur l'Europe) :
//   · les pastilles de groupe « 35 », « 5 », « 4 », « 2 » se chevauchaient
//     entre elles : le regroupement se faisait par CASES de 44 px, alors
//     qu'une pastille mesure 44-47 px. Deux points à 1 px l'un de l'autre,
//     mais de part et d'autre d'une frontière de case, restaient séparés et
//     leurs ronds se recouvraient ;
//   · ces pastilles recouvraient aussi les photos des amis et « Moi » (les
//     amis ne sont jamais regroupés, règle v587) ;
//   · les étiquettes « Vu il y a 23 h » se posaient sur « Moi » et sur les
//     pastilles voisines.
//
// Trois fonctions PURES, en pixels d'écran (Web Mercator au zoom courant),
// testées dans test/pam607b_overlap_test.dart :
//   1. [pawMergeCloseGroups] fusionne tout groupe dont le centre est à moins
//      de [minPx] d'un autre (jusqu'à ce que plus aucun ne se touche) ;
//   2. [pawRepelShift] écarte une pastille de groupe des ronds qui ne se
//      regroupent jamais (Moi, amis) — décalage du DESSIN seulement (ancre),
//      la position reste celle du groupe ;
//   3. [pawPickLabelSide] place l'étiquette d'un ami dessous, sinon dessus,
//      sinon nulle part — jamais sur un autre rond ni sur « Moi ».
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// Pixels « monde » Web Mercator d'un point au [zoom] donné (256 px au zoom 0,
/// comme Google Maps) : la distance entre deux résultats = distance à l'écran.
Offset pawMercatorPx(double lat, double lng, double zoom) {
  final scale = 256.0 * math.pow(2.0, zoom).toDouble();
  final s = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
  final x = (lng + 180.0) / 360.0 * scale;
  final y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale;
  return Offset(x, y);
}

/// Écart minimal entre deux centres de pastilles / ronds membres : rond de
/// 46 px (pastille 44 + anneau ami 2,5) + 4 px d'air.
const double kPawGroupMinPx = 50;

/// Fusionne les groupes dont les centres (moyenne des pixels de leurs points)
/// sont à moins de [minPx] : on recommence tant qu'une fusion a eu lieu,
/// donc à la fin AUCUNE paire de groupes ne se chevauche. L'ordre des points
/// dans un groupe est conservé (le 1er groupe absorbe le 2e).
List<List<T>> pawMergeCloseGroups<T>(
  List<List<T>> groups,
  Offset Function(T) px, {
  double minPx = kPawGroupMinPx,
}) {
  final items = <_G<T>>[
    for (final g in groups)
      if (g.isNotEmpty) _G<T>(List<T>.of(g), g.map(px).toList()),
  ];
  if (items.length < 2) return [for (final g in items) g.members];
  final min2 = minPx * minPx;
  var merged = true;
  var guard = 0;
  while (merged && guard++ < 64) {
    merged = false;
    // Grille de [minPx] : on ne compare qu'aux 8 cases voisines.
    final cells = <int, List<int>>{};
    int keyOf(Offset c) =>
        (c.dx / minPx).floor() * 1000003 + (c.dy / minPx).floor();
    for (var i = 0; i < items.length; i++) {
      (cells[keyOf(items[i].center)] ??= <int>[]).add(i);
    }
    final dead = <int>{};
    for (var i = 0; i < items.length; i++) {
      if (dead.contains(i)) continue;
      final a = items[i];
      final cx = (a.center.dx / minPx).floor();
      final cy = (a.center.dy / minPx).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final list = cells[(cx + dx) * 1000003 + (cy + dy)];
          if (list == null) continue;
          for (final j in list) {
            if (j <= i || dead.contains(j)) continue;
            final b = items[j];
            final d = a.center - b.center;
            if (d.dx * d.dx + d.dy * d.dy < min2) {
              a.absorb(b);
              dead.add(j);
              merged = true;
            }
          }
        }
      }
    }
    if (dead.isNotEmpty) {
      final keep = <_G<T>>[];
      for (var i = 0; i < items.length; i++) {
        if (!dead.contains(i)) keep.add(items[i]);
      }
      items
        ..clear()
        ..addAll(keep);
    }
  }
  return [for (final g in items) g.members];
}

class _G<T> {
  _G(this.members, this.pts) : center = _mean(pts);
  final List<T> members;
  final List<Offset> pts;
  Offset center;
  void absorb(_G<T> o) {
    members.addAll(o.members);
    pts.addAll(o.pts);
    center = _mean(pts);
  }

  static Offset _mean(List<Offset> p) {
    var x = 0.0, y = 0.0;
    for (final o in p) {
      x += o.dx;
      y += o.dy;
    }
    return Offset(x / p.length, y / p.length);
  }
}

/// Décalage (en px) à appliquer au DESSIN d'une pastille de groupe posée en
/// [at] pour qu'elle ne recouvre aucun des ronds fixes [obstacles] (Moi,
/// amis), qui ne se regroupent jamais. Chaque obstacle repousse la pastille
/// jusqu'à [minPx] de son centre ; le décalage total est borné à [maxShift]
/// (la pastille reste près de son groupe). Zéro si rien ne la touche.
Offset pawRepelShift(
  Offset at,
  Iterable<Offset> obstacles, {
  double minPx = kPawGroupMinPx,
  double maxShift = kPawRepelMaxPx,
}) {
  var sx = 0.0, sy = 0.0;
  for (final o in obstacles) {
    var d = at - o;
    var dist = d.distance;
    if (dist >= minPx) continue;
    if (dist < 0.5) {
      // Pile dessus : on part vers le bas-droite (direction stable).
      d = const Offset(0.7071, 0.7071);
      dist = 1;
    }
    final push = minPx - dist;
    sx += d.dx / dist * push;
    sy += d.dy / dist * push;
  }
  final s = Offset(sx, sy);
  final len = s.distance;
  if (len == 0) return Offset.zero;
  if (len <= maxShift) return s;
  return s / len * maxShift;
}

/// 607 (02/10) — écart maximal d'une pastille poussée par « Moi » / un ami.
/// 28 px au 01/10 (« 45 » touchait encore « Moi »), 48 px demandés le 02/10 ;
/// MESURÉ au simulateur (Paris, zoom 12) : « Moi » fait 56 px + anneau et
/// une pastille 44 px — leurs centres doivent être à 56 px au moins pour ne
/// pas se toucher. Une pastille posée PILE sur « Moi » a donc besoin de
/// 56 px : le plafond est 60 (48 ne suffisait pas, la pastille restait à
/// moitié cachée sous la photo).
const double kPawRepelMaxPx = 60;

/// Air minimal entre deux ronds qui ne doivent pas se toucher (px).
const double kPawAirPx = 4;

/// 607 (02/10) — écarte les pastilles de groupe ([isGroup]) des ronds fixes
/// ([fixed] : Moi, amis ; rayons [fixedR]) jusqu'à ce que les DESSINS ne se
/// touchent plus (rayon de la pastille [atR] + rayon de l'obstacle + 4 px),
/// au plus [maxShift] px, SANS jamais rapprocher deux ronds à moins de
/// [minPx] (ni rapprocher une pastille d'un autre rond fixe sous sa propre
/// distance de sécurité). Si un écart gêne, il est divisé par 2 (6 fois au
/// plus), puis annulé. Renvoie le décalage de chaque entrée de [at].
/// Même règle à reprendre telle quelle sur le site (`pawmapOverlap607`).
List<Offset> pawRepelAll(
  List<Offset> at,
  List<bool> isGroup,
  List<Offset> fixed, {
  List<double>? fixedR,
  List<double>? atR,
  double minPx = kPawGroupMinPx,
  double maxShift = kPawRepelMaxPx,
}) {
  final n = at.length;
  final shift = List<Offset>.filled(n, Offset.zero);
  final pos = List<Offset>.of(at);
  double rOf(int i) => atR != null && i < atR.length ? atR[i] : 24.5;
  double fR(int k) => fixedR != null && k < fixedR.length ? fixedR[k] : 28;
  double clear(int i, int k) => rOf(i) + fR(k) + kPawAirPx;

  Offset push(int i) {
    var sx = 0.0, sy = 0.0;
    for (var k = 0; k < fixed.length; k++) {
      var d = at[i] - fixed[k];
      var dist = d.distance;
      final need = clear(i, k);
      if (dist >= need) continue;
      if (dist < 0.5) {
        d = const Offset(0.7071, 0.7071); // pile dessus : bas-droite (stable)
        dist = 1;
      }
      final p = need - dist;
      sx += d.dx / dist * p;
      sy += d.dy / dist * p;
    }
    final s = Offset(sx, sy);
    final len = s.distance;
    if (len == 0) return Offset.zero;
    return len <= maxShift ? s : s / len * maxShift;
  }

  bool ok(int i, Offset p) {
    for (var j = 0; j < n; j++) {
      if (j == i) continue;
      final before = (at[i] - pos[j]).distance;
      final after = (p - pos[j]).distance;
      if (after < minPx && after < before) return false;
    }
    for (var k = 0; k < fixed.length; k++) {
      final before = (at[i] - fixed[k]).distance;
      final after = (p - fixed[k]).distance;
      if (after < clear(i, k) && after < before - 0.01) return false;
    }
    return true;
  }

  for (var i = 0; i < n; i++) {
    if (!isGroup[i]) continue;
    var s = push(i);
    if (s == Offset.zero) continue;
    // 1) l'écart direct (à l'opposé des ronds qui la touchent)
    if (!ok(i, at[i] + s) || _stillTouches(at[i] + s, i, fixed, clear)) {
      // 2) sinon : on fait le TOUR de l'obstacle le plus gênant, tous les
      //    15°, et on garde la place libre la plus proche (bug mesuré au
      //    simulateur et par LEO : la pastille « 3 », poussée vers un ami,
      //    restait à 13 px sous « Moi »).
      Offset? best;
      for (final limit in <double>[maxShift, maxShift * 1.5]) {
        best = _aroundBest(i, at, fixed, clear, ok, limit);
        if (best != null) break;
      }
      s = best ?? Offset.zero;
    }
    shift[i] = s;
    pos[i] = at[i] + s;
  }
  return shift;
}

bool _stillTouches(Offset p, int i, List<Offset> fixed,
    double Function(int, int) clear) {
  for (var k = 0; k < fixed.length; k++) {
    if ((p - fixed[k]).distance < clear(i, k) - 0.5) return true;
  }
  return false;
}

/// Place libre la plus proche autour de l'obstacle le plus gênant (pas de
/// 15°), à moins de [limit] px de la position d'origine ; null sinon.
Offset? _aroundBest(int i, List<Offset> at, List<Offset> fixed,
    double Function(int, int) clear, bool Function(int, Offset) ok, double limit) {
  var worstK = -1;
  var worst = 0.0;
  for (var k = 0; k < fixed.length; k++) {
    final over = clear(i, k) - (at[i] - fixed[k]).distance;
    if (over > worst) {
      worst = over;
      worstK = k;
    }
  }
  if (worstK < 0) return null;
  final o = fixed[worstK];
  final rad = clear(i, worstK) + 0.5;
  Offset? best;
  var bestD = double.infinity;
  for (var deg = 0; deg < 360; deg += 15) {
    final a = deg * math.pi / 180;
    final p = Offset(o.dx + rad * math.cos(a), o.dy + rad * math.sin(a));
    final d = (p - at[i]).distance;
    if (d > limit || d >= bestD) continue;
    if (!ok(i, p) || _stillTouches(p, i, fixed, clear)) continue;
    best = p - at[i];
    bestD = d;
  }
  return best;
}

/// Inverse de [pawMercatorPx] : point (lat, lng) d'un pixel « monde ».
(double, double) pawMercatorToLatLng(Offset px, double zoom) {
  final scale = 256.0 * math.pow(2.0, zoom).toDouble();
  final lng = px.dx / scale * 360.0 - 180.0;
  final n = math.pi - 2.0 * math.pi * px.dy / scale;
  final lat = 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  return (lat, lng);
}

/// Où poser l'étiquette d'un ami (« Vu il y a 23 h », prénom).
enum PawLabelSide { below, above, none }

/// Rectangle (px) d'une étiquette de largeur [width] sous / au-dessus d'un
/// rond de rayon [r] centré en [c] — mêmes cotes que `_paintPhotoDotBody`
/// (3 px d'écart, pastille de 19,3 px).
Rect pawLabelRect(Offset c, double r, double width, PawLabelSide side,
    {double height = 19.3}) {
  final top = side == PawLabelSide.above ? c.dy - r - 3 - height : c.dy + r + 3;
  return Rect.fromLTWH(c.dx - width / 2, top, width, height);
}

/// Dessous si la place est libre, sinon dessus (si [allowAbove] : pas de
/// bulle de prix au-dessus), sinon aucune étiquette. [obstacles] = ronds
/// voisins, pastilles, « Moi » et son étiquette, étiquettes déjà posées.
PawLabelSide pawPickLabelSide({
  required Offset center,
  required double radius,
  required double width,
  required List<Rect> obstacles,
  bool allowAbove = true,
}) {
  bool free(PawLabelSide s) {
    final r = pawLabelRect(center, radius, width, s).inflate(1);
    for (final o in obstacles) {
      if (r.overlaps(o)) return false;
    }
    return true;
  }

  if (free(PawLabelSide.below)) return PawLabelSide.below;
  if (allowAbove && free(PawLabelSide.above)) return PawLabelSide.above;
  return PawLabelSide.none;
}

/// Rectangle d'un rond de rayon [r] centré en [c] (obstacle).
Rect pawCircleRect(Offset c, double r) => Rect.fromCircle(center: c, radius: r);

/// Une épingle seule a-t-elle la place pour sa bulle de prix au-dessus d'elle
/// (zoom ville) ? La bulle (≈ [bubbleW] × 30 px) ne doit toucher aucun autre
/// rond, pastille ou étiquette [others] (le rond lui-même exclu).
bool pawBubbleHasRoom(Offset c, double r, double bubbleW, List<Rect> others) {
  final bubble = Rect.fromLTWH(c.dx - bubbleW / 2, c.dy - r - 32, bubbleW, 30);
  for (final o in others) {
    if (bubble.overlaps(o)) return false;
  }
  return true;
}

// ─── 607 (02/10, retours de LEO sur le site) — RECTANGLES RÉELS ──────────
//
// La règle par cercles laissait 3 cas où quelque chose restait sous « Moi » :
//   1. Europe z3-5 : des AMIS à ~11 km de moi (jamais déplacés) cachés sous
//      ma photo ;
//   2. Paris z13-14 : le PRÉNOM sous un membre écarté touchait mon rond ;
//   3. Bondy z13 : prénom long + bulle de prix à 13-27 px de mon centre.
// Désormais chaque rond porte sa BOÎTE réelle (rond + prénom mesuré + bulle
// de prix), relative à son centre, et la collision se fait boîte contre
// boîte (4 px d'air). Les amis trop près de « Moi » sont décalés en éventail
// (un trait relie leur vraie position) — ils restent visibles et à part.

/// Boîte d'un rond de rayon [r] avec, en option, une étiquette dessous
/// ([labelW] × [labelH], posée à [labelGap] sous le bord) et une bulle
/// au-dessus ([bubbleW] × [bubbleH]). Coordonnées relatives au centre.
Rect pawPinBox(double r,
    {double labelW = 0,
    double labelH = 20,
    double labelGap = 4,
    double bubbleW = 0,
    double bubbleH = 30}) {
  var box = Rect.fromCircle(center: Offset.zero, radius: r);
  if (labelW > 0) {
    box = box.expandToInclude(
        Rect.fromLTWH(-labelW / 2, r + labelGap, labelW, labelH));
  }
  if (bubbleW > 0) {
    box = box.expandToInclude(
        Rect.fromLTWH(-bubbleW / 2, -r - bubbleH - 2, bubbleW, bubbleH));
  }
  return box;
}

/// Deux boîtes posées en [a] et [b] se touchent-elles (avec [air] px) ?
bool pawBoxesTouch(Offset a, Rect ra, Offset b, Rect rb, {double air = kPawAirPx}) =>
    ra.shift(a).inflate(air / 2).overlaps(rb.shift(b).inflate(air / 2));

/// Un objet posé (position écran + boîte relative).
class PawPlacedBox {
  const PawPlacedBox(this.at, this.box);
  final Offset at;
  final Rect box;
}

/// Décalage le plus PETIT qui libère la boîte [box] posée en [at] de tous les
/// [obstacles] : Offset.zero si elle est déjà libre ; sinon on cherche sur
/// des anneaux de 4 en 4 px (jusqu'à [maxShift]), tous les 15°, en commençant
/// par la direction opposée à l'obstacle le plus proche. Null si rien de
/// libre (le rond reste en place).
Offset? pawFreeSpot(Offset at, Rect box, List<PawPlacedBox> obstacles,
    {double maxShift = 90, double air = kPawAirPx}) {
  bool free(Offset p) {
    for (final o in obstacles) {
      if (pawBoxesTouch(p, box, o.at, o.box, air: air)) return false;
    }
    return true;
  }

  if (free(at)) return Offset.zero;
  // Direction préférée : à l'opposé du plus proche obstacle qui touche.
  var away = const Offset(0.7071, 0.7071);
  var best = double.infinity;
  for (final o in obstacles) {
    if (!pawBoxesTouch(at, box, o.at, o.box, air: air)) continue;
    final d = (at - o.at).distance;
    if (d < best) {
      best = d;
      away = d < 0.5 ? const Offset(0.7071, 0.7071) : (at - o.at) / d;
    }
  }
  final a0 = math.atan2(away.dy, away.dx);
  for (var d = 4.0; d <= maxShift; d += 4) {
    for (var k = 0; k <= 12; k++) {
      for (final sign in k == 0 ? const [1] : const [1, -1]) {
        final a = a0 + sign * k * 15 * math.pi / 180;
        final p = at + Offset(math.cos(a), math.sin(a)) * d;
        if (free(p)) return p - at;
      }
    }
  }
  return null;
}

/// Place, dans l'ordre donné, des ronds MOBILES ([at], [boxes]) pour qu'aucun
/// ne touche les [fixed] ni un rond mobile déjà posé. Renvoie le décalage de
/// chacun (zéro s'il était libre ou si aucune place n'existe).
List<Offset> pawRepelBoxes(
  List<Offset> at,
  List<Rect> boxes,
  List<PawPlacedBox> fixed, {
  List<bool>? movable,
  double maxShift = 90,
}) {
  final n = at.length;
  final shift = List<Offset>.filled(n, Offset.zero);
  final placed = <PawPlacedBox>[...fixed];
  // Les immobiles d'abord (ils comptent comme obstacles).
  for (var i = 0; i < n; i++) {
    if (movable != null && !movable[i]) placed.add(PawPlacedBox(at[i], boxes[i]));
  }
  // Puis les mobiles, du plus proche d'un obstacle au plus loin.
  final order = [
    for (var i = 0; i < n; i++)
      if (movable == null || movable[i]) i
  ]..sort((a, b) {
      double near(int i) => fixed.isEmpty
          ? 0
          : fixed.map((f) => (f.at - at[i]).distance).reduce(math.min);
      return near(a).compareTo(near(b));
    });
  for (final i in order) {
    // Plus loin seulement si rien n'est libre tout près (zone très chargée).
    final s = pawFreeSpot(at[i], boxes[i], placed, maxShift: maxShift) ??
        pawFreeSpot(at[i], boxes[i], placed, maxShift: maxShift * 2) ??
        Offset.zero;
    shift[i] = s;
    placed.add(PawPlacedBox(at[i] + s, boxes[i]));
  }
  return shift;
}
