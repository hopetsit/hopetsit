import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/payment/modern_card_payment_screen.dart';

class MapBoostPackage {
  final String tier;
  final double amount;
  final String currency;
  final int days;
  final String label;

  const MapBoostPackage({
    required this.tier,
    required this.amount,
    required this.currency,
    required this.days,
    required this.label,
  });

  factory MapBoostPackage.fromJson(Map<String, dynamic> j) => MapBoostPackage(
        tier: j['tier'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? 'EUR',
        days: (j['days'] as num).toInt(),
        label: (j['label'] as String?) ?? '',
      );

  double get pricePerDay => days == 0 ? 0 : amount / days;
}

class MapBoostStatus {
  final bool isActive;
  final String? tier;
  final DateTime? expiresAt;
  final int remainingDays;
  final int mapBoostCreditsRemaining;

  const MapBoostStatus({
    required this.isActive,
    this.tier,
    this.expiresAt,
    this.remainingDays = 0,
    this.mapBoostCreditsRemaining = 0,
  });

  factory MapBoostStatus.empty() => const MapBoostStatus(isActive: false);

  factory MapBoostStatus.fromJson(Map<String, dynamic> j) {
    return MapBoostStatus(
      isActive: j['isActive'] == true,
      tier: j['tier'] as String?,
      expiresAt: DateTime.tryParse(j['expiresAt']?.toString() ?? ''),
      remainingDays: ((j['remainingDays'] as num?) ?? 0).toInt(),
      mapBoostCreditsRemaining:
          ((j['mapBoostCreditsRemaining'] as num?) ?? 0).toInt(),
    );
  }
}

/// Controller for Couche 4 — Map Boost purchase flow.
///
/// Mirrors the pattern used by the profile boost (boostRoutes) and the
/// Premium subscription (subscriptionRoutes) so the UI can reuse components.
class MapBoostController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isPurchasing = false.obs;
  final Rxn<MapBoostStatus> status = Rxn<MapBoostStatus>();
  final RxList<MapBoostPackage> packages = <MapBoostPackage>[].obs;
  final RxString currency = CurrencyHelper.eur.obs;

  /// Session v15-4 — fallback displayed when `GET /map-boost/packages`
  /// fails (backend down, network off, etc.). Prices aligned on the new
  /// Map Boost identity: Découverte / Visible / Pin Doré / Map Premium.
  /// Real runtime prices still come from the backend — these are only a
  /// safety net so the shop never shows an empty list.
  static List<MapBoostPackage> _fallbackPackagesForCurrency(String cur) {
    return [
      MapBoostPackage(
          tier: 'bronze',
          amount: 1.99,
          currency: cur,
          days: 3,
          label: 'Découverte'),
      MapBoostPackage(
          tier: 'silver',
          amount: 4.99,
          currency: cur,
          days: 7,
          label: 'Visible'),
      MapBoostPackage(
          tier: 'gold',
          amount: 8.99,
          currency: cur,
          days: 15,
          label: 'Pin Doré'),
      MapBoostPackage(
          tier: 'platinum',
          amount: 14.99,
          currency: cur,
          days: 30,
          label: 'Map Premium'),
    ];
  }

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  Future<void> setCurrency(String next) async {
    final upper = next.toUpperCase();
    if (currency.value == upper) return;
    currency.value = upper;
    await loadPackages();
  }

  @override

  Future<void> refresh() async {
    isLoading.value = true;
    try {
      await Future.wait([loadPackages(), loadStatus()]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadPackages() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get(
        '/map-boost/packages',
        queryParameters: {'currency': currency.value},
      );
      final list = (data['packages'] as List?) ?? const [];
      final parsed = list
          .map((p) => MapBoostPackage.fromJson(p as Map<String, dynamic>))
          .toList();
      // If backend returns an empty list (broken config or currency with no
      // pricing), fall back so the shop is never blank — see v15-4 recap.
      if (parsed.isEmpty) {
        packages.value = _fallbackPackagesForCurrency(currency.value);
      } else {
        packages.value = parsed;
      }
    } catch (e) {
      debugPrint('[MapBoost] loadPackages error: $e — using fallback prices');
      packages.value = _fallbackPackagesForCurrency(currency.value);
    }
  }

  Future<void> loadStatus() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/map-boost/status', requiresAuth: true);
      status.value = MapBoostStatus.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[MapBoost] loadStatus error: $e');
      status.value = MapBoostStatus.empty();
    }
  }

  /// Launches Stripe PaymentSheet for the given tier and confirms on success.
  Future<bool> purchase(String tier) async {
    if (isPurchasing.value) return false;
    isPurchasing.value = true;
    try {
      final api = Get.find<ApiClient>();
      final piData = await api.post(
        '/map-boost/purchase',
        body: {'tier': tier, 'currency': currency.value},
        requiresAuth: true,
      ) as Map<String, dynamic>;

      final clientSecret = piData['clientSecret'] as String?;
      final paymentIntentId = piData['paymentIntentId'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('No client secret.');
      }

      final pk = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
      if (pk.isNotEmpty && Stripe.publishableKey.isEmpty) {
        Stripe.publishableKey = pk;
        await Stripe.instance.applySettings();
      }

      // In-app card screen replaces the native PaymentSheet (unreliable on
      // some Android devices — card number field wouldn't accept input).
      final pkg = packages.firstWhereOrNull((p) => p.tier == tier);
      final displayAmount = pkg?.amount ?? 0;

      // v18.9.8 — récupère les saved cards (endpoint role-aware : owner /
      // sitter / walker) pour proposer un paiement direct sans ressaisir.
      List<Map<String, dynamic>> savedCards = const [];
      try {
        final resp =
            await api.get('/owner/payments/methods', requiresAuth: true);
        if (resp is Map) {
          final list = resp['paymentMethods'];
          if (list is List) {
            savedCards = list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      } catch (_) {
        // Non bloquant : fallback vers saisie carte.
      }

      final ok = await Get.to<bool>(
        () => ModernCardPaymentScreen(
          clientSecret: clientSecret,
          amount: displayAmount,
          currency: currency.value,
          productLabel: 'Map Boost ${tier[0].toUpperCase()}${tier.substring(1)}',
          productSubtitle: pkg != null ? '${pkg.days} jours sur la map' : null,
          savedPaymentMethods: savedCards,
        ),
      );
      if (ok != true) return false;

      await api.post(
        '/map-boost/confirm',
        body: {
          'tier': tier,
          'paymentIntentId': paymentIntentId,
          'currency': currency.value,
        },
        requiresAuth: true,
      );

      await loadStatus();
      return true;
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) rethrow;
      return false;
    } finally {
      isPurchasing.value = false;
    }
  }

  /// Premium users redeem 1 monthly credit = 3 days of map-boost.
  Future<bool> claimPremiumCredit() async {
    try {
      final api = Get.find<ApiClient>();
      await api.post('/map-boost/claim-credit', requiresAuth: true);
      await loadStatus();
      return true;
    } catch (e) {
      debugPrint('[MapBoost] claimCredit error: $e');
      return false;
    }
  }
}
