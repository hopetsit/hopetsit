import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';

/// Résultat de prévisualisation / consommation d'un code promo.
///
/// Mappe la réponse des endpoints additifs `/promo/check` (preview) et
/// `/promo/redeem` (consommation), eux-mêmes adossés au modèle `PromoCode`
/// émis par l'admin (onglet Promotions).
///
/// `rewardType` :
///   - `free_subscription` → un abonnement offert (`plan` + `intervalDays`,
///     éventuellement un `boostTier` pour PawBoost) ;
///   - `percent_discount`  → une réduction en pourcentage (`discountPercent`)
///     à appliquer aux achats boutique.
class PromoResult {
  const PromoResult({
    required this.valid,
    this.rewardType = '',
    this.plan = '',
    this.intervalDays = 0,
    this.boostTier = '',
    this.discountPercent = 0,
    this.campaign = '',
  });

  final bool valid;
  final String rewardType;
  final String plan;
  final int intervalDays;
  final String boostTier;
  final int discountPercent;
  final String campaign;

  bool get isPercentDiscount => rewardType == 'percent_discount';
  bool get isFreeSubscription => rewardType == 'free_subscription';

  factory PromoResult.fromCheck(dynamic response) {
    if (response is Map) {
      return PromoResult(
        valid: response['valid'] == true,
        rewardType: (response['rewardType'] ?? '').toString(),
        plan: (response['plan'] ?? '').toString(),
        intervalDays: _toInt(response['intervalDays']),
        boostTier: (response['boostTier'] ?? '').toString(),
        discountPercent: _toInt(response['discountPercent']),
        campaign: (response['campaign'] ?? '').toString(),
      );
    }
    return const PromoResult(valid: false);
  }

  /// La réponse de `/promo/redeem` est `{ ok, reward: {...} }`. Le détail de la
  /// récompense varie selon le type ; on normalise vers la même forme que
  /// `check` pour réutiliser l'affichage côté UI.
  factory PromoResult.fromRedeem(dynamic response) {
    if (response is Map) {
      final reward = response['reward'];
      if (reward is Map) {
        final kind = (reward['kind'] ?? '').toString();
        if (kind == 'percent_discount') {
          return PromoResult(
            valid: response['ok'] == true,
            rewardType: 'percent_discount',
            plan: (reward['plan'] ?? '').toString(),
            discountPercent: _toInt(reward['discountPercent']),
          );
        }
        if (kind == 'pawboost') {
          return PromoResult(
            valid: response['ok'] == true,
            rewardType: 'free_subscription',
            plan: 'pawboost',
            boostTier: (reward['tier'] ?? '').toString(),
          );
        }
        // kind == 'subscription'
        return PromoResult(
          valid: response['ok'] == true,
          rewardType: 'free_subscription',
          plan: (reward['plan'] ?? '').toString(),
          intervalDays: _toInt(reward['intervalDays']),
        );
      }
      return PromoResult(valid: response['ok'] == true);
    }
    return const PromoResult(valid: false);
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// Adosse les endpoints promo additifs côté backend (déjà déployés) :
///   POST /promo/check  { code } → prévisualise (404 si invalide/expiré).
///   POST /promo/redeem { code } → consomme (404 invalide, 409 déjà utilisé).
class PromoRepository {
  PromoRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Prévisualise un code sans le consommer. Lève [ApiException] (404) si le
  /// code est invalide / expiré / quota atteint.
  Future<PromoResult> check(String code) async {
    final cleaned = code.trim().toUpperCase();
    if (cleaned.isEmpty) {
      throw ApiException('Code requis.');
    }
    final response = await _apiClient.post(
      ApiEndpoints.promoCheck,
      body: {'code': cleaned},
      requiresAuth: true,
    );
    return PromoResult.fromCheck(response);
  }

  /// Consomme un code et active la récompense. Lève [ApiException] avec
  /// `statusCode` 404 (invalide) ou 409 (déjà utilisé) selon le cas.
  Future<PromoResult> redeem(String code) async {
    final cleaned = code.trim().toUpperCase();
    if (cleaned.isEmpty) {
      throw ApiException('Code requis.');
    }
    final response = await _apiClient.post(
      ApiEndpoints.promoRedeem,
      body: {'code': cleaned},
      requiresAuth: true,
    );
    return PromoResult.fromRedeem(response);
  }
}
