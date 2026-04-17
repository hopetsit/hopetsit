import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/map_poi_model.dart';

/// PawMap controller — loads nearby POIs and exposes filter state for the
/// PawMap screen. Reports (Couche 2) are handled by a separate controller
/// once Phase 3 lands.
class PawMapController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxList<MapPOI> pois = <MapPOI>[].obs;

  /// Currently enabled categories. Empty = show all.
  final RxSet<String> enabledCategories = <String>{}.obs;

  /// Center of the last query — used to decide whether to re-query on map move.
  final Rxn<LatLng> lastQueryCenter = Rxn<LatLng>();

  /// Radius in meters.
  int maxDistanceMeters = 5000;

  bool categoryActive(String c) =>
      enabledCategories.isEmpty || enabledCategories.contains(c);

  void toggleCategory(String c) {
    if (enabledCategories.contains(c)) {
      enabledCategories.remove(c);
    } else {
      enabledCategories.add(c);
    }
  }

  void clearFilters() => enabledCategories.clear();

  /// Fetch POIs within `maxDistanceMeters` of the given point.
  Future<void> loadNearby(LatLng center, {String? category}) async {
    isLoading.value = true;
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get(
        '/map-pois/nearby',
        queryParameters: {
          'lat': center.latitude,
          'lng': center.longitude,
          'maxDistance': maxDistanceMeters,
          if (category != null) 'category': category,
        },
        requiresAuth: true,
      );

      final list = (data['pois'] as List?) ?? const [];
      pois.value = list
          .map((p) => MapPOI.fromJson(p as Map<String, dynamic>))
          .toList();
      lastQueryCenter.value = center;
    } catch (e) {
      debugPrint('[PawMap] loadNearby error: $e');
      pois.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// Submit a new POI (starts in 'pending' for admin moderation).
  Future<bool> submitPoi({
    required String title,
    required String category,
    required double lat,
    required double lng,
    String? description,
    String? address,
    String? city,
    String? country,
    String? phone,
    String? website,
    String? openingHours,
  }) async {
    try {
      final api = Get.find<ApiClient>();
      await api.post(
        '/map-pois',
        body: {
          'title': title,
          'category': category,
          'lat': lat,
          'lng': lng,
          if (description != null) 'description': description,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (country != null) 'country': country,
          if (phone != null) 'phone': phone,
          if (website != null) 'website': website,
          if (openingHours != null) 'openingHours': openingHours,
        },
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      debugPrint('[PawMap] submitPoi error: $e');
      return false;
    }
  }

  /// Filters the in-memory `pois` list by currently enabled categories.
  List<MapPOI> get visiblePois {
    if (enabledCategories.isEmpty) return pois.toList();
    return pois.where((p) => enabledCategories.contains(p.category)).toList();
  }
}
