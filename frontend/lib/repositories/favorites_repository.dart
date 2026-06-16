import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';

/// v444 — Favoris prestataires (cœur sur les cartes de recherche owner).
///
/// Adosse les 3 endpoints additifs côté backend :
///   GET    /users/me/favorites               → liste [{providerId, providerRole}]
///   POST   /users/me/favorites               → ajout idempotent
///   DELETE /users/me/favorites/:providerId   → suppression
///
/// Toutes les méthodes renvoient la liste fraîche renvoyée par le serveur
/// (source de vérité) afin que le contrôleur reste synchronisé.
class FavoritesRepository {
  FavoritesRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Normalise la réponse `{ favorites: [{providerId, providerRole}] }`.
  List<Map<String, String>> _parseFavorites(dynamic response) {
    if (response is Map) {
      final list = response['favorites'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map(
              (e) => <String, String>{
                'providerId': (e['providerId'] ?? '').toString(),
                'providerRole': (e['providerRole'] ?? '').toString(),
              },
            )
            .where((e) => (e['providerId'] ?? '').isNotEmpty)
            .toList();
      }
    }
    return const <Map<String, String>>[];
  }

  /// Loads the current owner's favorite providers.
  Future<List<Map<String, String>>> getFavorites() async {
    final response = await _apiClient.get(
      ApiEndpoints.myFavorites,
      requiresAuth: true,
    );
    return _parseFavorites(response);
  }

  /// Adds a provider to favorites (idempotent). Returns the fresh list.
  Future<List<Map<String, String>>> addFavorite({
    required String providerId,
    required String providerRole,
  }) async {
    if (providerId.trim().isEmpty) {
      throw ApiException('providerId is required to add a favorite.');
    }
    final response = await _apiClient.post(
      ApiEndpoints.myFavorites,
      body: {
        'providerId': providerId.trim(),
        'providerRole': providerRole.trim(),
      },
      requiresAuth: true,
    );
    return _parseFavorites(response);
  }

  /// Removes a provider from favorites (idempotent). Returns the fresh list.
  Future<List<Map<String, String>>> removeFavorite({
    required String providerId,
  }) async {
    if (providerId.trim().isEmpty) {
      throw ApiException('providerId is required to remove a favorite.');
    }
    final response = await _apiClient.delete(
      '${ApiEndpoints.myFavorites}/${Uri.encodeComponent(providerId.trim())}',
      requiresAuth: true,
    );
    return _parseFavorites(response);
  }
}
