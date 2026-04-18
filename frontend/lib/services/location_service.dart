import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:hopetsit/utils/logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  /// Request location permission and get current position
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.logError('Location services are disabled.');
        return null;
      }

      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.logError('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, open app settings
        await Geolocator.openLocationSettings();
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.best),
      );

      return position;
    } catch (e) {
      AppLogger.logError('Error getting location', error: e);
      return null;
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
    try {
      List<geocoding.Placemark> placemarks = await geocoding
          .placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return {
          'city': placemark.locality ?? placemark.administrativeArea,
          'country': placemark.country,
          // Sprint 6.5 step 2 — ISO-2 country code (e.g. 'FR').
          'countryCodeIso': placemark.isoCountryCode,
          'street': placemark.street,
          'postalCode': placemark.postalCode,
          'administrativeArea': placemark.administrativeArea,
          'latitude': latitude,
          'longitude': longitude,
        };
      }
      return null;
    } catch (e) {
      AppLogger.logError('Error getting address from coordinates', error: e);
      return null;
    }
  }

  /// Get coordinates from city name
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
