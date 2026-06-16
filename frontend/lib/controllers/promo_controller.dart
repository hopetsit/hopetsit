import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/promo_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/post_purchase_refresh.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// État de l'écran de saisie d'un code promo.
enum PromoStatus { idle, checking, redeeming, success, error }

/// Pilote la saisie + validation + consommation d'un code promo, branché sur
/// les endpoints additifs `/promo/check` et `/promo/redeem` (modèle `PromoCode`
/// émis par l'admin via l'onglet Promotions).
///
/// Flux :
///   1. [check] prévisualise la récompense (sans consommer) pour afficher à
///      l'utilisateur ce que le code débloque ;
///   2. [redeem] consomme le code et active la récompense côté serveur :
///      - `free_subscription` → l'abo est crédité directement par le backend ;
///         on déclenche [refreshAfterPurchase] pour propager les flags dans
///         toute l'app (badges Premium/PawFollow/PawSpot, porte signalements…).
///      - `percent_discount`  → on persiste la réduction localement
///         ([redeemedPromoDiscount]) pour pré-remplir la boutique.
class PromoController extends GetxController {
  PromoController({PromoRepository? repository, GetStorage? storage})
      : _repository = repository ??
            PromoRepository(
              Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient(),
            ),
        _storage = storage ?? GetStorage();

  final PromoRepository _repository;
  final GetStorage _storage;

  final Rx<PromoStatus> status = PromoStatus.idle.obs;

  /// Message d'erreur traduit à afficher sous le champ (clé i18n résolue).
  final RxString errorMessage = ''.obs;

  /// Résultat courant (preview après [check], récompense après [redeem]).
  final Rxn<PromoResult> result = Rxn<PromoResult>();

  bool get isBusy =>
      status.value == PromoStatus.checking || status.value == PromoStatus.redeeming;

  /// Réinitialise l'état (à l'ouverture de l'écran ou après modification du champ).
  void reset() {
    status.value = PromoStatus.idle;
    errorMessage.value = '';
    result.value = null;
  }

  /// Prévisualise un code sans le consommer. Renvoie true si valide.
  Future<bool> check(String code) async {
    if (isBusy) return false;
    final cleaned = code.trim();
    if (cleaned.isEmpty) {
      _fail('promo_error_empty'.tr);
      return false;
    }
    status.value = PromoStatus.checking;
    errorMessage.value = '';
    try {
      final res = await _repository.check(cleaned);
      result.value = res;
      status.value = res.valid ? PromoStatus.idle : PromoStatus.error;
      if (!res.valid) errorMessage.value = 'promo_error_invalid'.tr;
      return res.valid;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  /// Consomme un code et active la récompense. Renvoie true en cas de succès.
  Future<bool> redeem(String code) async {
    if (isBusy) return false;
    final cleaned = code.trim();
    if (cleaned.isEmpty) {
      _fail('promo_error_empty'.tr);
      return false;
    }
    status.value = PromoStatus.redeeming;
    errorMessage.value = '';
    try {
      final res = await _repository.redeem(cleaned);
      result.value = res;
      if (!res.valid) {
        _fail('promo_error_invalid'.tr);
        return false;
      }
      // Réduction % : on persiste localement pour pré-remplir la boutique.
      if (res.isPercentDiscount && res.discountPercent > 0) {
        _persistDiscount(cleaned.toUpperCase(), res.discountPercent, res.plan);
      } else {
        // Abonnement offert crédité par le serveur → propage les flags partout.
        try {
          await refreshAfterPurchase();
        } catch (_) {/* best-effort */}
      }
      status.value = PromoStatus.success;
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  void _persistDiscount(String code, int percent, String plan) {
    try {
      _storage.write(
        StorageKeys.redeemedPromoDiscount,
        jsonEncode({'code': code, 'discountPercent': percent, 'plan': plan}),
      );
    } catch (e) {
      AppLogger.logError('PromoController._persistDiscount failed', error: e);
    }
  }

  void _fail(String message) {
    status.value = PromoStatus.error;
    errorMessage.value = message;
  }

  void _handleError(Object e) {
    AppLogger.logError('PromoController error', error: e);
    if (e is ApiException) {
      // 409 = déjà utilisé ; 404 = invalide / expiré ; reste = message brut.
      if (e.statusCode == 409) {
        _fail('promo_error_already_used'.tr);
        return;
      }
      if (e.statusCode == 404) {
        _fail('promo_error_invalid'.tr);
        return;
      }
      _fail(e.message.isNotEmpty ? e.message : 'promo_error_generic'.tr);
      return;
    }
    if (e is NetworkUnreachableException || e is ApiTimeoutException) {
      _fail('promo_error_network'.tr);
      return;
    }
    _fail('promo_error_generic'.tr);
  }
}
