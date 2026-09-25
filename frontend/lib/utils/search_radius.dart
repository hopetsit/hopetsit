/// Lot D (25/09/2026) — RAYON DE RECHERCHE : la règle unique du côté app,
/// identique à celle du serveur (`backend/src/utils/searchRadius.js`).
///
/// Demande de Daniel : « la valeur affichée = la valeur appliquée » et « un
/// prestataire à 4 km apparaît à 5 km et disparaît à 3 km ». Avant, l'accueil
/// gardien/promeneur calculait sa distance avec `Geolocator.distanceBetween`
/// (borne stricte, pas de tolérance) alors que le serveur filtrait à sa
/// façon : deux règles, deux résultats possibles pour le même km.
///
/// Fonctions pures, sans Flutter : testées par `test/lotd_radius_test.dart`.
library;

import 'dart:math' as math;

const double kEarthRadiusKm = 6371;

double _toRad(double deg) => deg * math.pi / 180;

/// Distance orthodromique (haversine) en km.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return kEarthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Borne INCLUSIVE, tolérante aux arrondis flottants (1 m) — comme le serveur.
bool withinRadiusKm(double distanceKm, double radiusKm) {
  if (distanceKm.isNaN || radiusKm.isNaN) return false;
  return distanceKm <= radiusKm + 0.001;
}

/// Le rayon tel qu'il est AFFICHÉ, ENVOYÉ et MÉMORISÉ : un entier de km,
/// borné aux limites du curseur. `fallback` sert quand la valeur est absente
/// ou invalide (NaN).
double clampRadiusKm(double? km, {required double min, required double max, double? fallback}) {
  final v = (km == null || km.isNaN) ? (fallback ?? min) : km;
  return v.clamp(min, max).roundToDouble();
}
