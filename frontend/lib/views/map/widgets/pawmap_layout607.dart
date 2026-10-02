// 607 (PAM, 02/10/2026) — PawMap : UNE passe de mise en page déterministe,
// toutes couches confondues (ordre de Daniel : « les bulles apparaissent
// toujours mal, fais un vrai travail de fond »).
//
// Avant : chaque couche (membres, lieux, PawSpots, signalements, demandes)
// regroupait ses points DE SON CÔTÉ. Les ronds des membres ne se touchaient
// plus entre eux (607b), mais un carré « 5 » de lieux pouvait se poser sur la
// pastille « 2 » des membres (vu au simulateur, Bondy zoom 12) et, sur un vrai
// iPhone, un carré blanc à bord bleu-vert finissait coupé net contre une
// pastille (capture de Daniel du 02/10 ; « 35 » rogné du 01/10).
//
// Ici, après la construction des marqueurs, on calcule en PIXELS D'ÉCRAN le
// rectangle VISIBLE de chacun (image moins sa marge transparente, bulle et
// étiquette comprises), puis on résout les collisions par PRIORITÉ :
//   Moi > amis (direct ou profil) > peluches > membres seuls > groupes de
//   membres > demandes > signalements > PawSpots > groupes de PawSpots >
//   lieux > groupes de lieux.
// Les couches « secondaires » (lieux, PawSpots, signalements et leurs
// groupes) qui touchent un marqueur plus prioritaire NE SONT PAS POSÉES : on
// les retrouve en zoomant. Les personnes (Moi, amis, membres, groupes de
// membres) et les demandes ne sont JAMAIS retirées : leur propre règle
// (fusion sous 50 px, écart de 48 px, étiquettes) les sépare déjà.
//
// Fonctions PURES, testées dans test/pam607c_plush_test.dart.
import 'dart:ui' show Offset, Rect, Size;

/// Couche d'un marqueur, déduite de son identifiant (`MarkerId`).
enum PawLayer {
  me,
  friend,
  plush,
  member,
  memberGroup,
  request,
  report,
  spot,
  spotGroup,
  place,
  placeGroup,
  other,
}

PawLayer pawLayerOf(String id) {
  if (id == 'me' || id.startsWith('me_')) return PawLayer.me;
  if (id.startsWith('friend_')) return PawLayer.friend;
  if (id.startsWith('plush_')) return PawLayer.plush;
  if (id.startsWith('nearby_')) return PawLayer.member;
  if (id.startsWith('mcluster_')) return PawLayer.memberGroup;
  if (id.startsWith('req_') || id.startsWith('myreq_')) return PawLayer.request;
  if (id.startsWith('report_')) return PawLayer.report;
  if (id.startsWith('pawspot_')) return PawLayer.spot;
  if (id.startsWith('scluster_')) return PawLayer.spotGroup;
  if (id.startsWith('poi_')) return PawLayer.place;
  if (id.startsWith('pcluster_')) return PawLayer.placeGroup;
  return PawLayer.other;
}

/// Plus grand = plus prioritaire.
int pawLayerPriority(PawLayer l) => switch (l) {
      PawLayer.me => 100,
      PawLayer.friend => 90,
      PawLayer.plush => 85,
      PawLayer.member => 80,
      PawLayer.memberGroup => 75,
      PawLayer.request => 70,
      PawLayer.report => 50,
      PawLayer.spot => 45,
      PawLayer.spotGroup => 40,
      PawLayer.place => 35,
      PawLayer.placeGroup => 30,
      PawLayer.other => 60,
    };

/// Les couches qu'on peut retirer d'une vue chargée (jamais une personne).
bool pawLayerDroppable(PawLayer l) =>
    l == PawLayer.report ||
    l == PawLayer.spot ||
    l == PawLayer.spotGroup ||
    l == PawLayer.place ||
    l == PawLayer.placeGroup;

/// Marge TRANSPARENTE (px logiques) autour du dessin dans l'image de chaque
/// couche — ombres et halos compris dans l'image mais pas dans le visible.
double pawLayerMargin(PawLayer l) => switch (l) {
      PawLayer.me || PawLayer.friend => 11,
      PawLayer.member => 11, // 607 — marge adaptée (11 / 17 / 22) : la plus petite
      PawLayer.memberGroup => 6,
      PawLayer.placeGroup => 12,
      PawLayer.spotGroup => 10,
      PawLayer.place || PawLayer.spot => 12,
      PawLayer.report => 4,
      PawLayer.request => 8,
      PawLayer.plush => 4,
      PawLayer.other => 0,
    };

/// Un marqueur à poser : position écran (px du point d'ancrage), taille de
/// son image (px logiques), ancre (0..1).
class PawPlaced {
  const PawPlaced({
    required this.id,
    required this.at,
    required this.size,
    this.anchor = const Offset(0.5, 0.5),
  });
  final String id;
  final Offset at;
  final Size size;
  final Offset anchor;

  PawLayer get layer => pawLayerOf(id);

  /// Rectangle VISIBLE à l'écran (image moins sa marge transparente).
  Rect get visible {
    final left = at.dx - anchor.dx * size.width;
    final top = at.dy - anchor.dy * size.height;
    final r = Rect.fromLTWH(left, top, size.width, size.height);
    final m = pawLayerMargin(layer);
    if (r.width <= 2 * m || r.height <= 2 * m) return r;
    // Personnes : la BULLE de prix occupe le haut de l'image (presque sans
    // marge) — on ne rogne le haut que de 4 px, sinon la bulle « 10 € »
    // passait pour vide et un carré de lieux restait posé dessus (Bondy).
    final bool person = layer == PawLayer.me ||
        layer == PawLayer.friend ||
        layer == PawLayer.member;
    return Rect.fromLTRB(r.left + m, r.top + (person ? 4 : m), r.right - m, r.bottom - m);
  }
}

/// Recouvrement toléré entre deux rectangles visibles (fraction de l'aire du
/// plus petit) : au-delà, le moins prioritaire n'est pas posé.
const double kPawOverlapTolerance = 0.12;

double _overlapRatio(Rect a, Rect b) {
  final i = a.intersect(b);
  if (i.width <= 0 || i.height <= 0) return 0;
  final small = (a.width * a.height) < (b.width * b.height) ? a : b;
  final area = small.width * small.height;
  return area <= 0 ? 0 : (i.width * i.height) / area;
}

/// La passe : renvoie les identifiants à NE PAS poser. Déterministe (ordre
/// = priorité, puis identifiant), indépendante de l'ordre d'entrée.
Set<String> pawResolveCollisions(Iterable<PawPlaced> items,
    {double tolerance = kPawOverlapTolerance}) {
  final list = items.toList()
    ..sort((a, b) {
      final p = pawLayerPriority(b.layer).compareTo(pawLayerPriority(a.layer));
      return p != 0 ? p : a.id.compareTo(b.id);
    });
  final kept = <Rect>[];
  final hidden = <String>{};
  for (final it in list) {
    final r = it.visible;
    if (pawLayerDroppable(it.layer)) {
      var clash = false;
      for (final k in kept) {
        if (_overlapRatio(r, k) > tolerance) {
          clash = true;
          break;
        }
      }
      if (clash) {
        hidden.add(it.id);
        continue;
      }
    }
    kept.add(r);
  }
  return hidden;
}

/// 607 (PAM, 02/10, mesuré au simulateur) — BUDGET DE TEXTURES (iOS).
/// Le SDK Google Maps iOS range chaque image de marqueur dans un nombre
/// limité d'atlas (journal « Reached the max number of texture atlases »).
/// À Bondy, en dézoomant (lieux + groupes + membres avec bulles), la réserve
/// a débordé : des épingles sortaient ROGNÉES et « Moi » a DISPARU — et il
/// ne revenait pas en rezoomant (son image ne change pas, le plugin ne la
/// renvoie pas). Mesures précédentes : 3,84 Mpx = 0 débordement sur 10
/// ouvertures, 6,49 Mpx = débordement ; et au SAUT de ville (Dallas →
/// Paris) l'ancienne et la nouvelle série coexistent un instant (mesuré :
/// 6 échecs avec 3,0 Mpx). Budget 2,2 Mpx = 2 séries tiennent. On plafonne :
/// par ordre de priorité, les couches RETIRABLES (lieux, spots, alertes)
/// au-delà du budget ne sont pas posées. Jamais une personne ni une peluche.
const double kPawIosTextureBudgetPx = 2.2e6;

Set<String> pawTextureBudget(
  Iterable<PawPlaced> items, {
  required double budgetPx,
  required double Function(PawPlaced) areaOf,
  Set<String> alreadyHidden = const <String>{},
  Rect? keepArea,
}) {
  // [keepArea] = zone (px écran) que la caméra peut montrer sans que la
  // liste soit recalculée. Ce qui est HORS de cette zone passe après, et peut
  // être retiré quelle que soit sa couche (sauf Moi et mes amis) : au
  // dézoom, des centaines de membres « monde » hors écran mangeaient tout le
  // budget et plus aucun lieu ne s'affichait.
  bool inView(PawPlaced p) => keepArea == null || keepArea.overlaps(p.visible);
  final list = items.where((p) => !alreadyHidden.contains(p.id)).toList()
    ..sort((a, b) {
      final v = (inView(b) ? 1 : 0).compareTo(inView(a) ? 1 : 0);
      if (v != 0) return v;
      final p = pawLayerPriority(b.layer).compareTo(pawLayerPriority(a.layer));
      return p != 0 ? p : a.id.compareTo(b.id);
    });
  var used = 0.0;
  final hidden = <String>{};
  for (final it in list) {
    final a = areaOf(it);
    final keep = it.layer == PawLayer.me || it.layer == PawLayer.friend;
    final droppable = !keep && (!inView(it) || pawLayerDroppable(it.layer));
    if (used + a > budgetPx && droppable) {
      hidden.add(it.id);
      continue;
    }
    used += a;
  }
  return hidden;
}
