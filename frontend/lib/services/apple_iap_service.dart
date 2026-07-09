// v503 — Achat intégré Apple (StoreKit) pour la boutique iOS.
//
// Pourquoi : refus App Store build 502, règle 3.1.1 — tout abonnement /
// fonction NUMÉRIQUE vendu dans une app iOS doit passer par le paiement
// intégré Apple. La boutique reste AFFICHÉE et ACHETABLE sur iOS mais le
// flux carte Airwallex y est remplacé par StoreKit (package in_app_purchase).
// Android et le web ne changent PAS (Airwallex partout). Les réservations
// de services réels (garde/promenade) restent par carte (règle 3.1.5(a)).
//
// Flow :
//   1. Boutique iOS → AppleIapService.buy(productId) → feuille d'achat Apple.
//   2. purchaseStream émet purchased/restored → POST /apple-iap/validate
//      { productId, transactionId, originalTransactionId, jws } (le backend
//      vérifie via l'App Store Server API puis crédite UserSubscription
//      exactement comme après un paiement Airwallex réussi ; idempotent).
//   3. completePurchase(details) + refreshAfterPurchase() (badges, carte…).
//   4. Renouvellements / remboursements : App Store Server Notifications V2
//      → webhook backend, rien à faire côté app.
//
// Les Product IDs ci-dessous doivent correspondre EXACTEMENT aux produits
// créés dans App Store Connect (groupe d'abonnements « HoPetSit »).

import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/post_purchase_refresh.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class AppleIapService {
  AppleIapService._();

  // ── Product IDs App Store Connect ──────────────────────────────────────
  static const String pawFollowMonthly = 'hopetsit_pawfollow_monthly';
  static const String pawFollowYearly = 'hopetsit_pawfollow_yearly';
  static const String pawFamilyMonthly = 'hopetsit_pawfamily_monthly';
  static const String pawFamilyYearly = 'hopetsit_pawfamily_yearly';
  static const String pawSpotMonthly = 'hopetsit_pawspot_monthly';
  static const String pawSpotYearly = 'hopetsit_pawspot_yearly';
  static const String pawPremiumMonthly = 'hopetsit_pawpremium_monthly';
  static const String pawPremiumYearly = 'hopetsit_pawpremium_yearly';
  static const String pawBoostT1 = 'hopetsit_pawboost_t1';
  static const String pawBoostT2 = 'hopetsit_pawboost_t2';
  static const String pawBoostT3 = 'hopetsit_pawboost_t3';

  /// Abonnements auto-renouvelables → buyNonConsumable.
  static const Set<String> _subscriptionIds = {
    pawFollowMonthly,
    pawFollowYearly,
    pawFamilyMonthly,
    pawFamilyYearly,
    pawSpotMonthly,
    pawSpotYearly,
    pawPremiumMonthly,
    pawPremiumYearly,
  };

  /// PawBoost ponctuels (consommables) → buyConsumable.
  static const Set<String> _consumableIds = {pawBoostT1, pawBoostT2, pawBoostT3};

  static Set<String> get _allIds => {..._subscriptionIds, ..._consumableIds};

  // ── Mapping plans boutique → Product ID ────────────────────────────────

  /// Plans PawFollow/PawFamily (onglet 2, SubscriptionController) et
  /// PawPremium (onglet 4). Renvoie null si le plan n'a pas de produit Apple.
  static String? productForSubscriptionPlan(String plan) {
    switch (plan.toLowerCase()) {
      case 'monthly':
        return pawFollowMonthly;
      case 'yearly':
        return pawFollowYearly;
      case 'family':
      case 'famille':
        return pawFamilyMonthly;
      case 'family_yearly':
        return pawFamilyYearly;
      case 'premium_monthly':
        return pawPremiumMonthly;
      case 'premium_yearly':
        return pawPremiumYearly;
      default:
        return null;
    }
  }

  /// Plans PawSpot (onglet 3 — mêmes clés 'monthly'/'yearly' que PawFollow
  /// mais produits distincts, d'où un mapping séparé).
  static String? productForPawSpotPlan(String plan) {
    switch (plan.toLowerCase()) {
      case 'monthly':
        return pawSpotMonthly;
      case 'yearly':
        return pawSpotYearly;
      default:
        return null;
    }
  }

  /// Tiers PawBoost → 3 produits consommables App Store Connect.
  /// Le tier 'gold' (15 j) n'a pas de produit Apple → masqué sur iOS.
  static String? productForBoostTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return pawBoostT1;
      case 'silver':
        return pawBoostT2;
      case 'platinum':
        return pawBoostT3;
      default:
        return null;
    }
  }

  // ── État interne ────────────────────────────────────────────────────────
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static final Map<String, ProductDetails> _products = {};
  static bool _initStarted = false;
  static bool _available = false;

  /// Achat en cours : complété (true = validé backend) quand le
  /// purchaseStream a fini de traiter la transaction.
  static Completer<bool>? _pending;
  static String? _pendingProductId;

  static bool get isAvailable => _available;

  /// Idempotent. À appeler à l'ouverture de la boutique iOS (no-op ailleurs).
  static Future<void> init() async {
    if (!Platform.isIOS || _initStarted) return;
    _initStarted = true;
    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        AppLogger.logError('[iap] StoreKit indisponible sur cet appareil');
        return;
      }
      _sub ??= _iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object e) =>
            AppLogger.logError('[iap] purchaseStream error', error: e),
      );
      await loadProducts();
      AppLogger.logInfo('[iap] init OK — ${_products.length} produits chargés');
    } catch (e) {
      AppLogger.logError('[iap] init failed', error: e);
    }
  }

  /// Interroge App Store Connect pour les 11 produits. Les prix localisés
  /// (TVA/devise Apple) sont ensuite lus via [priceLabel].
  static Future<void> loadProducts() async {
    final resp = await _iap.queryProductDetails(_allIds);
    for (final p in resp.productDetails) {
      _products[p.id] = p;
    }
    if (resp.notFoundIDs.isNotEmpty) {
      // Produit pas encore créé/approuvé dans App Store Connect — l'achat
      // correspondant échouera avec un message clair.
      AppLogger.logError('[iap] produits introuvables : ${resp.notFoundIDs}');
    }
  }

  /// Prix localisé Apple (ex. « 4,99 € ») ou null si produit non chargé —
  /// l'appelant garde alors son affichage de prix habituel en fallback.
  static String? priceLabel(String? productId) =>
      productId == null ? null : _products[productId]?.price;

  /// Lance la feuille d'achat Apple pour [productId]. Résout true quand le
  /// backend a validé + crédité l'achat, false si annulation/échec.
  static Future<bool> buy(String productId) async {
    await init();
    if (!_available) {
      AppLogger.logError('[iap] buy($productId) — StoreKit indisponible');
      // v504 — refus 2.1(b) « unresponsive » : ne JAMAIS échouer en silence,
      // le testeur Apple doit voir une réaction à chaque tap.
      CustomSnackbar.showError(
          title: 'common_error'.tr, message: 'iap_unavailable_msg'.tr);
      return false;
    }
    if (_pending != null && !_pending!.isCompleted) {
      AppLogger.logInfo('[iap] achat déjà en cours, buy($productId) ignoré');
      return false;
    }
    var details = _products[productId];
    if (details == null) {
      await loadProducts();
      details = _products[productId];
    }
    if (details == null) {
      AppLogger.logError('[iap] produit $productId introuvable dans ASC');
      // v504 — même raison : produit pas encore chargeable (ASC/accord payé)
      // → message visible plutôt qu'un tap muet.
      CustomSnackbar.showError(
          title: 'common_error'.tr, message: 'iap_unavailable_msg'.tr);
      return false;
    }

    _pending = Completer<bool>();
    _pendingProductId = productId;
    final param = PurchaseParam(productDetails: details);
    try {
      final launched = _consumableIds.contains(productId)
          ? await _iap.buyConsumable(purchaseParam: param)
          : await _iap.buyNonConsumable(purchaseParam: param);
      if (!launched) {
        _resolvePending(productId, false);
      }
    } catch (e) {
      AppLogger.logError('[iap] buy($productId) exception', error: e);
      _resolvePending(productId, false);
    }
    // Garde-fou : si aucun événement stream n'arrive (cas dégénéré), on
    // libère le spinner au bout de 5 min plutôt que de bloquer la boutique.
    return _pending!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => false,
    );
  }

  /// Bouton « Restaurer mes achats » (obligatoire Apple). Les transactions
  /// restaurées arrivent dans le purchaseStream → re-validées backend
  /// (idempotent sur transactionId, donc sans double crédit).
  static Future<void> restorePurchases() async {
    await init();
    if (!_available) return;
    await _iap.restorePurchases();
  }

  // ── purchaseStream ──────────────────────────────────────────────────────

  static Future<void> _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final p in updates) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break; // feuille Apple ouverte — on attend l'issue.
        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          _resolvePending(p.productID, false);
          break;
        case PurchaseStatus.error:
          AppLogger.logError('[iap] achat ${p.productID} en erreur',
              error: p.error?.message);
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          _resolvePending(p.productID, false);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ok = await _validateWithBackend(p);
          // completePurchase APRÈS la validation : si l'app meurt entre les
          // deux, Apple re-livrera la transaction au prochain lancement et
          // le backend (idempotent) re-traitera sans double crédit.
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          if (ok) {
            await refreshAfterPurchase();
          }
          _resolvePending(p.productID, ok);
          break;
      }
    }
  }

  /// POST /apple-iap/validate — le backend vérifie la transaction via l'App
  /// Store Server API et crédite l'abonnement/boost (comme le webhook
  /// Airwallex). `jws` = serverVerificationData (token StoreKit signé) pour
  /// une vérification locale de signature côté serveur si souhaité.
  static Future<bool> _validateWithBackend(PurchaseDetails p) async {
    try {
      final api = Get.find<ApiClient>();
      final resp = await api.post(
        '/apple-iap/validate',
        body: {
          'productId': p.productID,
          'transactionId': p.purchaseID,
          // L'ID de transaction ORIGINALE (chaîne d'abonnement) n'est pas
          // exposé par l'API croisée in_app_purchase ; le backend le résout
          // via GET /inApps/v1/transactions/{transactionId} chez Apple.
          'originalTransactionId': null,
          'jws': p.verificationData.serverVerificationData,
          'source': p.status == PurchaseStatus.restored ? 'restore' : 'purchase',
        },
        requiresAuth: true,
      );
      if (resp is Map) {
        final map = Map<String, dynamic>.from(resp);
        final ok = map['ok'] == true ||
            map['success'] == true ||
            map['activated'] == true;
        if (!ok) {
          AppLogger.logError('[iap] validate ${p.productID} refusé : $map');
        }
        return ok;
      }
      return false;
    } catch (e) {
      AppLogger.logError('[iap] validate ${p.productID} failed', error: e);
      return false;
    }
  }

  static void _resolvePending(String productId, bool result) {
    if (_pending == null || _pending!.isCompleted) return;
    // On ne résout que si c'est bien l'achat en attente (les restaurations
    // multi-produits passent aussi par le stream).
    if (_pendingProductId == null || _pendingProductId == productId) {
      _pending!.complete(result);
      _pendingProductId = null;
    }
  }
}
