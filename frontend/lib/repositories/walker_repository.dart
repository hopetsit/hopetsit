import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/walker_model.dart';
import 'package:hopetsit/utils/logger.dart';

/// Handles walker-related API interactions (third role: dog walkers).
///
/// Mirrors SitterRepository where relevant (profile, nearby lookup, rate
/// management) but operates against /walkers/* endpoints with walker-specific
/// payloads (walkRates array instead of hourlyRate/dailyRate/weeklyRate).
class WalkerRepository {
  WalkerRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /walkers/me — authenticated walker's own full profile.
  Future<WalkerModel> getMyWalkerProfile() async {
    AppLogger.logInfo('Fetching my walker profile');
    try {
      final response = await _apiClient.get(
        ApiEndpoints.walkersMe,
        requiresAuth: true,
      );
      final data = _asMap(response);
      final walkerJson = data['walker'];
      if (walkerJson is Map) {
        return WalkerModel.fromJson(Map<String, dynamic>.from(walkerJson));
      }
      // Some endpoints return the walker at the top level.
      return WalkerModel.fromJson(data);
    } catch (e) {
      AppLogger.logError('Failed to fetch my walker profile', error: e);
      rethrow;
    }
  }

  /// PATCH /walkers/me — update editable walker fields.
  Future<WalkerModel> updateMyWalkerProfile(Map<String, dynamic> updates) async {
    AppLogger.logInfo('Updating my walker profile', data: updates);
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.walkersMe,
        body: updates,
        requiresAuth: true,
      );
      final data = _asMap(response);
      final walkerJson = data['walker'];
      if (walkerJson is Map) {
        return WalkerModel.fromJson(Map<String, dynamic>.from(walkerJson));
      }
      return WalkerModel.fromJson(data);
    } catch (e) {
      AppLogger.logError('Failed to update my walker profile', error: e);
      rethrow;
    }
  }

  /// GET /walkers/me/rates — authenticated walker's walkRates array.
  Future<List<WalkRate>> getMyWalkerRates() async {
    AppLogger.logInfo('Fetching my walker rates');
    try {
      final response = await _apiClient.get(
        ApiEndpoints.walkersMyRates,
        requiresAuth: true,
      );
      final data = _asMap(response);
      final list = data['walkRates'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => WalkRate.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return <WalkRate>[];
    } catch (e) {
      AppLogger.logError('Failed to fetch my walker rates', error: e);
      rethrow;
    }
  }

  /// PUT /walkers/me/rates — replace the walker's walkRates array.
  Future<List<WalkRate>> updateMyWalkerRates(List<WalkRate> rates) async {
    AppLogger.logInfo('Updating my walker rates',
        data: {'count': rates.length});
    try {
      final response = await _apiClient.put(
        ApiEndpoints.walkersMyRates,
        body: {'walkRates': rates.map((r) => r.toJson()).toList()},
        requiresAuth: true,
      );
      final data = _asMap(response);
      final list = data['walkRates'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => WalkRate.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return <WalkRate>[];
    } catch (e) {
      AppLogger.logError('Failed to update my walker rates', error: e);
      rethrow;
    }
  }

  /// GET /walkers — public paginated listing of active walkers. The backend
  /// sorts by averageRating (desc) then createdAt (desc). Used by the owner
  /// home screen "Promeneurs" tab.
  Future<List<WalkerModel>> getAllWalkers({int page = 1, int limit = 20}) async {
    AppLogger.logInfo('Fetching all walkers', data: {'page': page, 'limit': limit});
    try {
      final response = await _apiClient.get(
        ApiEndpoints.walkers,
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );
      final data = _asMap(response);
      final list = data['walkers'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => WalkerModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return <WalkerModel>[];
    } catch (e) {
      AppLogger.logError('Failed to fetch walkers', error: e);
      rethrow;
    }
  }

  /// GET /walkers/nearby?lat=&lng=&radiusInMeters= — geospatial lookup.
  Future<List<WalkerModel>> getNearbyWalkers({
    required double lat,
    required double lng,
    int radiusInMeters = 10000,
  }) async {
    AppLogger.logInfo(
      'Fetching nearby walkers',
      data: {'lat': lat, 'lng': lng, 'radiusInMeters': radiusInMeters},
    );
    try {
      final response = await _apiClient.get(
        ApiEndpoints.walkersNearby,
        queryParameters: {
          'lat': lat.toString(),
          'lng': lng.toString(),
          'radiusInMeters': radiusInMeters.toString(),
        },
      );
      final data = _asMap(response);
      final list = data['walkers'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => WalkerModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return <WalkerModel>[];
    } catch (e) {
      AppLogger.logError('Failed to fetch nearby walkers', error: e);
      rethrow;
    }
  }

  /// GET /walkers/:id — public profile of a single walker.
  Future<WalkerModel> getWalkerProfile(String id) async {
    AppLogger.logInfo('Fetching walker profile', data: {'id': id});
    try {
      final response = await _apiClient.get('${ApiEndpoints.walkers}/$id');
      final data = _asMap(response);
      final walkerJson = data['walker'];
      if (walkerJson is Map) {
        return WalkerModel.fromJson(Map<String, dynamic>.from(walkerJson));
      }
      return WalkerModel.fromJson(data);
    } catch (e) {
      AppLogger.logError('Failed to fetch walker profile', error: e);
      rethrow;
    }
  }

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    throw ApiException('Unexpected walker response shape.', details: response);
  }
}
