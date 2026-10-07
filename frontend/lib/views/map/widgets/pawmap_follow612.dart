// 612 (PAM, 05/10/2026) — LA BALADE SUIVIE EN DIRECT, propre et fluide.
//
// Retours de Daniel du 05/10 au soir (La Isla, Alhama de Murcia, 2 iPhone,
// app 611) : « au lieu de zoomer ça dézoome quand tu vises quelqu'un en
// direct », cercles violets géants, traits roses / violets / rouges partout,
// photos empilées, tracé en étoile autour du Mercadona, carte 3D chez l'un et
// à plat chez l'autre.
//
// Fonctions PURES, testées dans test/pam612_follow_test.dart :
//   · [pawFollowZoom] / [pawTapZoom] : viser ou suivre quelqu'un ne fait
//     JAMAIS dézoomer (avant : 16,5 / 16 / 18 en dur, quel que soit le zoom) ;
//   · [pawScreenDelta] : écart d'écran réel entre deux points quand la carte
//     est tournée (cap de marche) et penchée (vue rue) ;
//   · [pawShiftedAnchor612] : le décalage anti-chevauchement passe par
//     l'ANCRE (pixels) et non plus par la position (mètres) : pendant un zoom
//     la photo reste collée à son vrai point, elle ne saute plus ;
//   · [pawCleanTrail612] : tracé sans sauts GPS (allers-retours en étoile,
//     sauts isolés) puis lissé ;
//   · [pawAcceptGpsFix612] : un point GPS imprécis ou impossible (saut à
//     pied de 100 m en 2 s) n'est ni envoyé, ni dessiné.
import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect, Size;

import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 613 — phase FIXE de l'auréole violette de la personne suivie (sur
/// [kBoostPhases] = 4) : 1 → sin(π/2) = 1, halo à son plein, sans respiration.
const int kPawFollowHaloPhase613 = 1;

/// Zoom « rue » minimal quand on vise / suit une personne en direct.
const double kPawFollowStreetZoom = 17.5;

/// À partir de ce zoom, on est déjà au niveau de la rue : on GARDE le zoom.
const double kPawFollowKeepAbove = 16.9;

/// Plafond (Google Maps va jusqu'à ~21 ; au-delà de 20 la carte est floue).
const double kPawFollowMaxZoom = 20;

/// Zoom à appliquer quand on vise / suit / recentre sur quelqu'un : jamais
/// plus petit que le zoom courant s'il est déjà « rue ».
double pawFollowZoom(double current) {
  if (!current.isFinite) return kPawFollowStreetZoom;
  if (current >= kPawFollowKeepAbove) return math.min(current, kPawFollowMaxZoom);
  return kPawFollowStreetZoom;
}

/// 1er appui sur un rond : on se rapproche (+1,5, au moins 15, au plus 18)
/// mais on ne recule JAMAIS si l'on est déjà plus près.
double pawTapZoom(double current) {
  final double want = math.min(math.max(current + 1.5, 15.0), 18.0);
  return math.max(current, want);
}

/// Écart à l'ÉCRAN (px) correspondant à un écart Mercator [merc] (px, y vers
/// le bas, nord en haut) quand la carte est tournée de [bearingDeg] et
/// penchée de [tiltDeg]. Approximation locale (deux ronds voisins).
Offset pawScreenDelta(Offset merc, {double bearingDeg = 0, double tiltDeg = 0}) {
  final double t = -bearingDeg * math.pi / 180;
  final double x = merc.dx * math.cos(t) - merc.dy * math.sin(t);
  final double y = merc.dx * math.sin(t) + merc.dy * math.cos(t);
  final double c = math.cos(tiltDeg.clamp(0, 75) * math.pi / 180);
  return Offset(x, y * c);
}

/// Ancre d'un marqueur dont l'IMAGE est décalée de [shiftPx] (px d'écran)
/// par rapport à son vrai point : la position ne change pas.
Offset pawShiftedAnchor612(Offset base, Offset shiftPx,
    {required double width, required double height}) {
  if (shiftPx == Offset.zero || width <= 0 || height <= 0) return base;
  return Offset(base.dx - shiftPx.dx / width, base.dy - shiftPx.dy / height);
}

double pawMeters612(LatLng a, LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final x = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(x.toDouble())));
}

/// Tracé PROPRE :
///  1. retire les « pics » : B très loin de A et de C alors que A et C sont
///     proches (aller-retour en étoile d'un GPS qui saute dans un magasin) ;
///  2. retire un point isolé à plus de [maxJumpM] des deux voisins ;
///  3. lisse (Chaikin, 2 passes) en gardant le 1er et le dernier point.
List<LatLng> pawCleanTrail612(List<LatLng> raw,
    {double spikeM = 20, double maxJumpM = 60, int smoothPasses = 2}) {
  if (raw.length < 3) return List<LatLng>.of(raw);
  var pts = List<LatLng>.of(raw);
  // 1 + 2 — on recommence tant qu'un pic tombe (étoiles à plusieurs branches).
  var changed = true;
  var guard = 0;
  while (changed && pts.length >= 3 && guard++ < 8) {
    changed = false;
    final out = <LatLng>[pts.first];
    for (var i = 1; i < pts.length - 1; i++) {
      final a = out.last;
      final b = pts[i];
      final c = pts[i + 1];
      final ab = pawMeters612(a, b);
      final bc = pawMeters612(b, c);
      final ac = pawMeters612(a, c);
      final bool spike = ab > spikeM && bc > spikeM && ac < 0.5 * math.min(ab, bc);
      final bool jump = ab > maxJumpM && bc > maxJumpM && ac < math.max(ab, bc);
      if (spike || jump) {
        changed = true;
        continue;
      }
      out.add(b);
    }
    out.add(pts.last);
    pts = out;
  }
  // 3 — Chaikin : chaque segment donne deux points à 1/4 et 3/4.
  for (var p = 0; p < smoothPasses && pts.length >= 3; p++) {
    final s = <LatLng>[pts.first];
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      s.add(LatLng(0.75 * a.latitude + 0.25 * b.latitude,
          0.75 * a.longitude + 0.25 * b.longitude));
      s.add(LatLng(0.25 * a.latitude + 0.75 * b.latitude,
          0.25 * a.longitude + 0.75 * b.longitude));
    }
    s.add(pts.last);
    pts = s;
  }
  return pts;
}

/// Point GPS de MA balade : accepté ? Refusé s'il est imprécis
/// (> [maxAccuracyM]) ou s'il suppose une vitesse impossible à pied
/// (> [maxSpeedMs]) — mais seulement tant que le dernier bon point a moins
/// de [graceSeconds] : passé ce délai on reprend ce qui vient (jamais figé).
bool pawAcceptGpsFix612({
  required double accuracyM,
  required LatLng fix,
  LatLng? lastGood,
  DateTime? lastGoodAt,
  required DateTime now,
  double maxAccuracyM = 40,
  double maxSpeedMs = 9,
  int graceSeconds = 25,
}) {
  if (lastGood == null || lastGoodAt == null) return true;
  final double dt = now.difference(lastGoodAt).inMilliseconds / 1000.0;
  if (dt >= graceSeconds) return true;
  if (accuracyM.isFinite && accuracyM > maxAccuracyM) return false;
  final double d = pawMeters612(lastGood, fix);
  if (d > 25 && d / math.max(dt, 1.0) > maxSpeedMs) return false;
  return true;
}

/// Position affichée d'une photo qui GLISSE de [from] vers [to] (t ∈ 0..1,
/// adoucie) — la caméra du suivi glisse pendant la même durée.
LatLng pawGlide612(LatLng from, LatLng to, double t) {
  final double k = t <= 0 ? 0 : (t >= 1 ? 1 : 1 - math.pow(1 - t, 3).toDouble());
  return LatLng(from.latitude + (to.latitude - from.latitude) * k,
      from.longitude + (to.longitude - from.longitude) * k);
}

/// Peluche à moins de [px] de la photo suivie (pixels au même zoom) :
/// retirée pendant le suivi (critère 4 du §0).
bool pawPlushHiddenNearFollowed612(Offset plushPx, Offset followedPx,
        {double px = 60}) =>
    (plushPx - followedPx).distance < px;

/// Résultat de [pawFan612] : décalage (px d'écran) de « Moi » et de chaque
/// rond d'ami.
class PawFan612 {
  const PawFan612(this.me, this.friends);
  final Offset me;
  final List<Offset> friends;
}

/// 612 (captures 11-12 de Daniel) — anti-empilement des ronds « Moi » +
/// amis. RÈGLE : la personne SUIVIE ([followed]) n'est JAMAIS décalée (sa
/// photo est au bout de son tracé) ; « Moi » ne s'écarte que s'il la
/// recouvre ; les autres amis s'écartent de « Moi » (et de la personne
/// suivie). Le décalage est court (≤ [maxShift] px, sauf zone saturée).
PawFan612 pawFan612({
  required Offset? meAt,
  required Rect meBox,
  required List<Offset> friendsAt,
  required Rect friendBox,
  Set<int> followed = const <int>{},
  double maxShift = 90,
}) {
  if (meAt == null) {
    return PawFan612(Offset.zero, List<Offset>.filled(friendsAt.length, Offset.zero));
  }
  var me = Offset.zero;
  if (followed.isNotEmpty) {
    me = pawRepelBoxes([meAt], [meBox],
        [for (final f in followed) PawPlacedBox(friendsAt[f], friendBox)],
        maxShift: maxShift)[0];
  }
  final shifts = pawRepelBoxes(
    friendsAt,
    [for (final _ in friendsAt) friendBox],
    [PawPlacedBox(meAt + me, meBox)],
    movable: [for (var k = 0; k < friendsAt.length; k++) !followed.contains(k)],
    maxShift: maxShift,
  );
  return PawFan612(me, [
    for (var k = 0; k < friendsAt.length; k++)
      followed.contains(k) ? Offset.zero : shifts[k],
  ]);
}

/// 612 (Daniel, §7) — pendant le direct, seulement une COURTE TRAÎNE derrière
/// la photo : la fin du tracé, sur [maxMeters] au plus (≈ 2-3 minutes de
/// marche). Le 1er point est coupé pile à la bonne longueur.
const double kPawTrailMeters612 = 200;

List<LatLng> pawShortTrail612(List<LatLng> pts,
    {double maxMeters = kPawTrailMeters612}) {
  if (pts.length < 2) return List<LatLng>.of(pts);
  final out = <LatLng>[pts.last];
  var left = maxMeters;
  for (var i = pts.length - 1; i > 0 && left > 0; i--) {
    final a = pts[i];
    final b = pts[i - 1];
    final d = pawMeters612(a, b);
    if (d <= left) {
      out.add(b);
      left -= d;
    } else {
      final t = left / d;
      out.add(LatLng(a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t));
      left = 0;
    }
  }
  return out.reversed.toList();
}

/// Traîne qui S'ESTOMPE vers l'arrière : [parts] morceaux (du plus ancien au
/// plus récent) avec leur opacité (0,12 → 1). Chaque morceau reprend le
/// dernier point du précédent : aucun trou.
List<(List<LatLng>, double)> pawFadedTrail612(List<LatLng> pts, {int parts = 5}) {
  if (pts.length < 2) return const <(List<LatLng>, double)>[];
  final n = pts.length - 1; // segments
  final k = math.min(parts, n);
  final out = <(List<LatLng>, double)>[];
  for (var p = 0; p < k; p++) {
    final from = (n * p / k).floor();
    final to = (n * (p + 1) / k).floor();
    if (to <= from) continue;
    final double alpha = k == 1 ? 1 : 0.12 + 0.88 * (p / (k - 1));
    out.add((pts.sublist(from, to + 1), alpha));
  }
  return out;
}

/// 613 (captures 4-5 de Daniel : « Cam » collée sous « john ») — boîte
/// d'encombrement d'un rond d'AMI : le rond, + son étiquette dessous quand
/// elle est dessinée ([labelW] > 0, zoom rue), + 8 px au-dessus pour la
/// couronne. Avant : le rond seul → « Moi » se posait sur l'étiquette.
Rect pawFriendBox613(double r, {double labelW = 0}) {
  var box = pawPinBox(r, labelW: labelW, labelH: 16.3, labelGap: 3);
  box = box.expandToInclude(Rect.fromLTWH(-r, -r - 8, 2 * r, 8));
  return box;
}

/// 613 (Daniel, vocal 23 h 06 + capture 7 : « Itinéraire te sort SON trajet à
/// lui ») — le tracé de l'itinéraire n'avait AUCUN zIndex (0) : le fond
/// OpenStreetMap (TileOverlay, zIndex 0, opaque) passait PAR-DESSUS. On ne
/// voyait que le drapeau d'arrivée (un marqueur) et la traîne violette de
/// john (zIndex 2) → « son itinéraire ». L'itinéraire passe au-dessus du fond
/// ET de la traîne.
const int kPawRouteZ613 = 3;

Polyline pawRoutePolyline613(List<LatLng> points, Color color) => Polyline(
      polylineId: const PolylineId('pawspot_route'),
      points: points,
      color: color,
      width: 5,
      zIndex: kPawRouteZ613,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

/// 613 (§6 de Daniel : « Itinéraire te sort SON trajet ») — le calcul piéton
/// (Valhalla) ACCROCHE le départ et l'arrivée au sentier le plus proche :
/// quand john marche dans un champ à côté du chemin, l'itinéraire part du
/// sentier et s'arrête sur le sentier — pile sous SA traîne violette (zIndex
/// 2, au-dessus de l'ancien itinéraire en zIndex 0). On ne voyait plus que le
/// drapeau d'arrivée sur sa traîne. Désormais : l'itinéraire passe au-dessus
/// ([kPawRouteZ613]) et deux courts traits PLEINS relient MA photo au départ
/// et l'arrivée à la photo de la personne rejointe : un trait continu.
const double kPawRouteLeadMinM613 = 4;

Set<Polyline> pawRoutePolylines613(List<LatLng> points, Color color,
    {LatLng? from, LatLng? to}) {
  final out = <Polyline>{pawRoutePolyline613(points, color)};
  if (points.length < 2) return out;
  Polyline lead(String id, LatLng a, LatLng b) => Polyline(
        polylineId: PolylineId(id),
        points: [a, b],
        color: color,
        width: 5,
        zIndex: kPawRouteZ613,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      );
  if (from != null && pawMeters612(from, points.first) >= kPawRouteLeadMinM613) {
    out.add(lead('pawspot_route_in', from, points.first));
  }
  if (to != null && pawMeters612(points.last, to) >= kPawRouteLeadMinM613) {
    out.add(lead('pawspot_route_out', points.last, to));
  }
  return out;
}

/// 613 (BOB, capture « rejoindre ») — CADRAGE d'un itinéraire dans la zone
/// LIBRE de l'écran : [free] = rectangle (px logiques) entre les rails, le
/// bandeau du haut et la fiche du bas, sur un écran [screen]. Renvoie le
/// centre de caméra et le zoom pour que tous [pts] (Moi, john, le trajet)
/// tiennent dans [free] avec [inset] px de marge (rayon d'une photo +
/// étiquette). Mercator pur, pas de pente ni de rotation.
(LatLng, double) pawFrameInRect613(List<LatLng> pts, Size screen, Rect free,
    {double inset = 44, double maxZoom = 18.5, double minZoom = 3}) {
  double mx(double lng) => (lng + 180) / 360;
  double my(double lat) {
    final s = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
    return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
  }
  double x0 = double.infinity, x1 = -double.infinity, y0 = double.infinity, y1 = -double.infinity;
  for (final p in pts) {
    final x = mx(p.longitude), y = my(p.latitude);
    x0 = math.min(x0, x); x1 = math.max(x1, x);
    y0 = math.min(y0, y); y1 = math.max(y1, y);
  }
  final w = math.max(free.width - 2 * inset, 40.0);
  final h = math.max(free.height - 2 * inset, 40.0);
  final dx = math.max(x1 - x0, 1e-9), dy = math.max(y1 - y0, 1e-9);
  final z = (math.log(math.min(w / (dx * 256), h / (dy * 256))) / math.ln2).clamp(minZoom, maxZoom).toDouble();
  final world = 256 * math.pow(2, z);
  // centre des points → centre de la zone libre (décalé du centre de l'écran)
  final ox = free.center.dx - screen.width / 2, oy = free.center.dy - screen.height / 2;
  final cx = (x0 + x1) / 2 - ox / world, cy = (y0 + y1) / 2 - oy / world;
  final lng = cx * 360 - 180;
  final n = math.pi - 2 * math.pi * cy;
  final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  return (LatLng(lat, lng), z);
}
