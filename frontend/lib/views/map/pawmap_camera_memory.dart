// v584 (lot C du chantier du 24/09) — mémoire de la caméra de la PawMap.
//
// Règles validées par Daniel le 23/09 (LEGENDE_PAWMAP.md, « Ouverture de la
// carte ») :
//   · au lancement : ma position (le GPS recentre dès qu'il répond) ;
//   · GPS refusé : le dernier endroit regardé ;
//   · le ZOOM est retenu avec le centre (avant, seul le centre l'était) ;
//   · on n'enregistre que quand la carte S'ARRÊTE, pas à chaque image.
// Et un repli sain avant toute position connue : la ville du profil (les
// coordonnées enregistrées à l'inscription) — jamais « Paris » en dur pour
// quelqu'un qui vit à Dallas. Paris ne reste que si le profil n'a rien.
//
// Fonctions PURES (aucun accès au stockage) : l'écran leur passe ce qu'il a
// lu dans GetStorage, les tests leur passent des cartes en mémoire.

import 'package:google_maps_flutter/google_maps_flutter.dart';

class PawMapCameraMemory {
  PawMapCameraMemory._();

  /// Repli ultime (siège de l'app) — n'est atteint que sans mémoire ET sans
  /// coordonnées de profil.
  static const LatLng fallbackCenter = LatLng(48.8566, 2.3522);

  /// Zoom par défaut : échelle de quartier (on voit les gardiens autour).
  static const double defaultZoom = 14;

  static const double minZoom = 2;
  static const double maxZoom = 21;

  /// Centre à afficher au premier rendu : mémoire → profil → repli.
  static LatLng centerFrom(dynamic saved, Map<String, dynamic>? profile) {
    final fromSaved = _latLng(
      saved is Map ? saved['lat'] : null,
      saved is Map ? saved['lng'] : null,
    );
    if (fromSaved != null) return fromSaved;
    return profileCenter(profile) ?? fallbackCenter;
  }

  /// Coordonnées du profil (`location.coordinates` = [lng, lat] côté
  /// serveur, format GeoJSON) si l'app en a une copie locale.
  static LatLng? profileCenter(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final loc = profile['location'];
    if (loc is! Map) return null;
    final coords = loc['coordinates'];
    if (coords is List && coords.length >= 2) {
      return _latLng(coords[1], coords[0]);
    }
    // Certains profils portent lat / lng à plat.
    return _latLng(loc['lat'], loc['lng']);
  }

  /// Zoom retenu, borné aux valeurs que Google Maps accepte.
  static double zoomFrom(dynamic saved) {
    if (saved is Map) {
      final z = (saved['zoom'] as num?)?.toDouble();
      if (z != null && z >= minZoom && z <= maxZoom) return z;
    }
    return defaultZoom;
  }

  /// Valeur à écrire dans le stockage (et à envoyer au compte).
  static Map<String, double> encode(LatLng c, double zoom) => <String, double>{
        'lat': c.latitude,
        'lng': c.longitude,
        'zoom': zoom.clamp(minZoom, maxZoom).toDouble(),
      };

  /// Le zoom d'atterrissage au lancement : le zoom retenu, mais jamais plus
  /// large qu'une ville ni plus serré qu'une rue (sinon un dézoom mondial
  /// laissé la veille rouvrirait la carte sur un continent).
  static double launchZoom(double remembered) =>
      remembered.clamp(11.0, 18.0).toDouble();

  static LatLng? _latLng(dynamic lat, dynamic lng) {
    final la = (lat is num) ? lat.toDouble() : double.tryParse('$lat');
    final ln = (lng is num) ? lng.toDouble() : double.tryParse('$lng');
    if (la == null || ln == null) return null;
    if (la.abs() > 90 || ln.abs() > 180) return null;
    if (la == 0 && ln == 0) return null;
    return LatLng(la, ln);
  }
}
