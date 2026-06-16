import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/repositories/favorites_repository.dart';
import 'package:hopetsit/utils/logger.dart';

/// v444 — Favoris prestataires (cœur sur les cartes de recherche owner).
///
/// Charge la liste des favoris de l'owner à l'init et expose :
///   - [isFavorite] (réactif via [favoriteIds]) ;
///   - [toggle] qui appelle les endpoints add/remove avec mise à jour optimiste
///     (le cœur change immédiatement, on revient en arrière si l'API échoue).
///
/// Owner-only : pour les sitters/walkers la liste reste vide et toggle est
/// silencieusement no-op (le backend renverrait 403, mais le cœur n'est de
/// toute façon câblé que sur l'accueil owner).
class FavoritesController extends GetxController {
  FavoritesController({FavoritesRepository? repository})
      : _repository = repository ??
            FavoritesRepository(
              Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient(),
            );

  final FavoritesRepository _repository;

  /// Set réactif des `providerId` favoris (rôle agnostique côté lookup).
  final RxSet<String> favoriteIds = <String>{}.obs;

  /// Map providerId → providerRole, conservée pour les suppressions/affichage.
  final RxMap<String, String> _rolesById = <String, String>{}.obs;

  final RxBool isLoading = false.obs;

  /// providerId dont le toggle est en cours (désactive le bouton le temps de
  /// l'aller-retour réseau pour éviter les doubles taps).
  final RxSet<String> pending = <String>{}.obs;

  bool _loadedOnce = false;

  @override
  void onInit() {
    super.onInit();
    // Best-effort : on charge en arrière-plan, les erreurs (ex. 403 sitter)
    // laissent simplement la liste vide.
    load();
  }

  /// True quand le prestataire est dans les favoris de l'owner.
  bool isFavorite(String providerId) => favoriteIds.contains(providerId);

  /// Charge (ou recharge) la liste des favoris depuis le serveur.
  Future<void> load() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final favorites = await _repository.getFavorites();
      _applyServerList(favorites);
      _loadedOnce = true;
    } catch (e) {
      // Silencieux : favoris facultatifs, on n'affiche pas d'erreur bloquante.
      AppLogger.logError('FavoritesController.load failed', error: e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Recharge si on n'a jamais réussi à charger (ex. après login owner).
  Future<void> ensureLoaded() async {
    if (_loadedOnce) return;
    await load();
  }

  void _applyServerList(List<Map<String, String>> favorites) {
    final ids = <String>{};
    final roles = <String, String>{};
    for (final f in favorites) {
      final id = (f['providerId'] ?? '').trim();
      if (id.isEmpty) continue;
      ids.add(id);
      final role = (f['providerRole'] ?? '').trim();
      if (role.isNotEmpty) roles[id] = role;
    }
    favoriteIds
      ..clear()
      ..addAll(ids);
    _rolesById
      ..clear()
      ..addAll(roles);
  }

  /// Ajoute / retire un prestataire des favoris avec mise à jour optimiste.
  /// [role] = 'sitter' | 'walker'.
  Future<void> toggle(String providerId, String role) async {
    final id = providerId.trim();
    if (id.isEmpty || pending.contains(id)) return;

    final wasFavorite = favoriteIds.contains(id);
    pending.add(id);

    // Mise à jour optimiste.
    if (wasFavorite) {
      favoriteIds.remove(id);
      _rolesById.remove(id);
    } else {
      favoriteIds.add(id);
      if (role.trim().isNotEmpty) _rolesById[id] = role.trim();
    }

    try {
      final favorites = wasFavorite
          ? await _repository.removeFavorite(providerId: id)
          : await _repository.addFavorite(providerId: id, providerRole: role);
      // Source de vérité serveur.
      _applyServerList(favorites);
      _loadedOnce = true;
    } catch (e) {
      // Rollback en cas d'échec réseau / API.
      if (wasFavorite) {
        favoriteIds.add(id);
        if (role.trim().isNotEmpty) _rolesById[id] = role.trim();
      } else {
        favoriteIds.remove(id);
        _rolesById.remove(id);
      }
      AppLogger.logError('FavoritesController.toggle failed', error: e);
    } finally {
      pending.remove(id);
    }
  }
}
