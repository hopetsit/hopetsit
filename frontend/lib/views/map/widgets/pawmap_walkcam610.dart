// 610 (PAM, 04/10/2026) — CAMÉRA DE BALADE « vue rue ».
//
// Daniel en Balade à Alhama de Murcia : « quand tu te mets en balade, ça
// devrait auto-zoomer sur ton profil, sinon faut zoomer à la main à chaque
// fois » + « il faut faire le truc street view pour la balade ».
//
// Version faisable avec le fond actuel (Google Maps + tuiles OSM) : la carte
// se penche (tilt) et tourne dans le sens de la marche (cap calculé entre deux
// positions GPS), au zoom de rue, comme une appli de navigation. La vraie
// photo Street View n'existe pas dans google_maps_flutter : chantier à part.
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Zoom de rue de la Balade (Daniel a zoomé à la main jusqu'à ~18).
const double kPawWalkZoom = 17.5;

/// Au-dessus de ce zoom, on garde le zoom choisi par la personne.
const double kPawWalkZoomKeepAbove = 16.5;

/// Inclinaison « vue rue » (Google Maps l'accepte jusqu'à ~67° à ce zoom).
const double kPawWalkTilt = 55;

/// Distance minimale entre deux points GPS pour croire au cap (bruit GPS).
const double kPawWalkHeadingMinMeters = 8;

/// Zoom à appliquer au départ / à la reprise d'une Balade.
double pawWalkZoomFor(double? currentZoom) {
  final z = currentZoom ?? 0;
  if (z >= kPawWalkZoomKeepAbove) return math.min(z, 19.5);
  return kPawWalkZoom;
}

double _rad(double d) => d * math.pi / 180;

/// Distance en mètres entre deux points.
double pawWalkMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final x = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(x.toDouble())));
}

/// Cap (0 = nord, 90 = est) de [from] vers [to], ou null si le déplacement
/// est trop court pour être fiable.
double? pawWalkBearing(LatLng? from, LatLng to) {
  if (from == null) return null;
  if (pawWalkMeters(from, to) < kPawWalkHeadingMinMeters) return null;
  final la1 = _rad(from.latitude);
  final la2 = _rad(to.latitude);
  final dLng = _rad(to.longitude - from.longitude);
  final y = math.sin(dLng) * math.cos(la2);
  final x = math.cos(la1) * math.sin(la2) -
      math.sin(la1) * math.cos(la2) * math.cos(dLng);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// Position de caméra de la Balade : sur moi, zoom de rue, penchée, tournée
/// dans le sens de la marche ([bearing] null = on garde [lastBearing]).
CameraPosition pawWalkCamera({
  required LatLng me,
  double? currentZoom,
  double? bearing,
  double lastBearing = 0,
  bool streetView = true,
}) {
  return CameraPosition(
    target: me,
    zoom: pawWalkZoomFor(currentZoom),
    tilt: streetView ? kPawWalkTilt : 0,
    bearing: streetView ? (bearing ?? lastBearing) : 0,
  );
}

/// Caméra « à plat » rendue à la fin de la Balade (même centre, même zoom).
CameraPosition pawWalkFlatCamera(LatLng center, double zoom) =>
    CameraPosition(target: center, zoom: zoom, tilt: 0, bearing: 0);
