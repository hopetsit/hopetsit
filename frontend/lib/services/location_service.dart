import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:hopetsit/utils/logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  /// v573 — raison du dernier échec de [getCurrentLocation], pour que l'écran
  /// puisse AFFICHER pourquoi « Me localiser » n'a rien donné (avant : silence
  /// total). Valeurs : '' (ok) | 'service_off' | 'denied' | 'denied_forever' |
  /// 'timeout'.
  String lastFailure = '';

  /// 624 — sondes d'intégration seulement : jamais la fenêtre système de
  /// position (elle couvre les captures et ne peut pas être touchée par un
  /// test). Jamais vrai dans une app de store.
  static bool skipPromptForTests = false;

  /// 625 — (tests, mode debug) déroulé horodaté de chaque demande de
  /// position : sert à mesurer ce qui se passe sur un téléphone donné.
  static final List<String> debugTrace625 = <String>[];

  /// 625 — délai de 3 s sur un appel du système qui peut ne jamais répondre
  /// (sauf dans les tests unitaires : pas de minuterie laissée en suspens).
  static final bool _inUnitTests625 = Platform.environment.containsKey('FLUTTER_TEST');
  static Future<T> _guard625<T>(Future<T> f, T Function() onTimeout) =>
      _inUnitTests625 ? f : f.timeout(const Duration(seconds: 3), onTimeout: onTimeout);
  static final Stopwatch _sw625 = Stopwatch()..start();
  static void _t(String s) {
    if (kDebugMode && debugTrace625.length < 80) {
      debugTrace625.add('${_sw625.elapsedMilliseconds}ms $s');
    }
  }

  /// Request location permission and get current position
  /// [openSettingsIfBlocked] : 625 — faux pour les demandes AUTOMATIQUES
  /// (ouverture de la PawMap) ; MESURÉ au simulateur : position refusée →
  /// chaque ouverture de la PawMap envoyait l'utilisateur dans les Réglages
  /// du téléphone. Vrai seulement quand l'utilisateur touche un bouton.
  Future<Position?> getCurrentLocation({bool openSettingsIfBlocked = true}) async {
    try {
      // Check if location services are enabled
      lastFailure = '';
      _t('debut');
      // 625 — MESURÉ (émulateur Android, position approximative) : cet appel
      // n'a jamais répondu, et chaque demande de position partait au délai
      // de l'appelant (8 s puis 15 s). Sans réponse en 3 s : on continue.
      bool serviceEnabled = await _guard625(Geolocator.isLocationServiceEnabled(), () {
        _t('service: pas de reponse en 3 s');
        return true;
      });
      _t('service=$serviceEnabled');
      if (!serviceEnabled) {
        AppLogger.logError('Location services are disabled.');
        lastFailure = 'service_off';
        return null;
      }

      // Check and request location permission
      LocationPermission permission = await _guard625(Geolocator.checkPermission(), () {
        _t('permission: pas de reponse en 3 s');
        return LocationPermission.whileInUse; // on tente quand même
      });
      _t('permission=$permission');
      if (permission == LocationPermission.denied) {
        if (skipPromptForTests) {
          lastFailure = 'denied';
          return null;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.logError('Location permissions are denied');
          lastFailure = 'denied';
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, open app settings
        _t('permission refusee definitivement');
        if (openSettingsIfBlocked) await Geolocator.openLocationSettings();
        // v23.1 part 252 — meme si denied forever, on tente la derniere
        // position connue (souvent dispo du cache OS) pour que la PawMap
        // n'ouvre pas sur Paris.
        return await Geolocator.getLastKnownPosition();
      }

      // v23.1 part 252 — Daniel : "la pawmap arrete de souvrir sur paris
      // quel souvrs sur ma position". Root cause : getCurrentPosition avec
      // accuracy.best est LENT (GPS froid) et sans timeLimit interne ; sur
      // un fix lent il timeout cote appelant (8s) → null → fallback Paris.
      //
      // Fix robuste :
      //   1. On tente d'abord getLastKnownPosition() (INSTANTANE, cache OS).
      //      Si dispo, on la retourne immediatement → la carte ouvre pres
      //      de l'user tout de suite.
      //   2. En parallele, getCurrentPosition avec accuracy MEDIUM (bien
      //      plus rapide a obtenir un 1er fix que best) + timeLimit 6s.
      //   3. Si getCurrentPosition reussit, sa valeur est plus fraiche, on
      //      la prefere ; sinon on garde la last-known.
      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
        _t('derniere_connue=${lastKnown != null}');
      } catch (e) {
        _t('derniere_connue erreur ${e.runtimeType}');
      }

      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
        _t('moyenne OK');
        return fresh;
      } catch (e) {
        _t('moyenne erreur ${e.runtimeType}');
        // getCurrentPosition lent/echoue → on retombe sur la last-known
        // (peut etre null si l'OS n'a jamais eu de fix, mais c'est mieux
        // que Paris quand elle existe).
        if (lastKnown != null) return lastKnown;
      }
      // 625 (Oppo / ColorOS, position « approximative ») — dernier essai en
      // précision BASSE (réseau / antennes), qui répond là où le GPS se tait.
      try {
        final low = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _t('basse OK');
        return low;
      } catch (e) {
        _t('basse erreur ${e.runtimeType}');
        return null;
      }
    } catch (e) {
      AppLogger.logError('Error getting location', error: e);
      // Ultime fallback : last-known position.
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Get city name from coordinates using reverse geocoding
  Future<String?> getCityFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding
          .placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        // Try to get city name in this order: locality -> administrativeArea -> country
        String? city =
            placemarks.first.locality ??
            placemarks.first.administrativeArea ??
            placemarks.first.country;
        return city;
      }
      return null;
    } catch (e) {
      AppLogger.logError('Error getting city from coordinates', error: e);
      return null;
    }
  }

  /// Get full address from coordinates
  Future<Map<String, dynamic>?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // 1) Géocodeur natif du téléphone. Sur beaucoup d'Android (Samsung
    //    compris) il échoue ou renvoie une fiche sans ville : on n'abandonne
    //    plus, on passe au secours.
    try {
      List<geocoding.Placemark> placemarks = await geocoding
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 6));

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final String city =
            (placemark.locality ?? '').trim().isNotEmpty
                ? placemark.locality!.trim()
                : (placemark.subAdministrativeArea ?? '').trim().isNotEmpty
                    ? placemark.subAdministrativeArea!.trim()
                    : (placemark.administrativeArea ?? '').trim();
        if (city.isNotEmpty) {
          return {
            'city': city,
            'country': placemark.country,
            'countryCodeIso': placemark.isoCountryCode,
            'street': placemark.street,
            'postalCode': placemark.postalCode,
            'administrativeArea': placemark.administrativeArea,
            'latitude': latitude,
            'longitude': longitude,
          };
        }
      }
    } catch (e) {
      AppLogger.logError('Native reverse geocoding failed', error: e);
    }
    // 2) v573 — secours OpenStreetMap (Nominatim), le service déjà utilisé par
    //    la recherche de ville de l'app.
    return _reverseWithNominatim(latitude, longitude);
  }

  Future<Map<String, dynamic>?> _reverseWithNominatim(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$latitude&lon=$longitude'
        '&format=json&addressdetails=1&zoom=18'
        '&accept-language=${Get.locale?.languageCode ?? 'fr'}',
      );
      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': 'HoPetSit/20.0 (contact@hopetsit.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final dynamic body = json.decode(res.body);
      if (body is! Map) return null;
      final Map addr = (body['address'] as Map?) ?? const {};
      String pick(List<String> keys) {
        for (final k in keys) {
          final v = (addr[k] ?? '').toString().trim();
          if (v.isNotEmpty) return v;
        }
        return '';
      }

      final city = pick(
        ['city', 'town', 'village', 'municipality', 'suburb', 'county', 'state'],
      );
      if (city.isEmpty) return null;
      final road = pick(['road', 'pedestrian', 'footway', 'neighbourhood']);
      final number = pick(['house_number']);
      final street = road.isEmpty
          ? ''
          : (number.isEmpty ? road : '$number $road');
      final code = pick(['country_code']).toUpperCase();
      return {
        'city': city,
        'country': pick(['country']),
        'countryCodeIso': code.isEmpty ? null : code,
        'street': street,
        'postalCode': pick(['postcode']),
        'administrativeArea': pick(['state', 'region']),
        'latitude': latitude,
        'longitude': longitude,
      };
    } catch (e) {
      AppLogger.logError('Nominatim reverse geocoding failed', error: e);
      return null;
    }
  }

  Future<Position?> getCoordinatesFromCity(String cityName) async {
    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(
        cityName,
      );

      if (locations.isNotEmpty) {
        final location = locations.first;
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      return null;
    } catch (e) {
      AppLogger.logError('Error getting coordinates from city', error: e);
      return null;
    }
  }

  /// Calculate distance between two coordinates in kilometers
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) /
        1000; // Convert to km
  }

  /// Get current user location and city in one call
  Future<Map<String, dynamic>?> getUserLocationWithCity() async {
    try {
      Position? position = await getCurrentLocation();
      if (position == null) return null;

      Map<String, dynamic>? address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return {
        ...?address,
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      AppLogger.logError('Error getting user location with city', error: e);
      return null;
    }
  }
}
