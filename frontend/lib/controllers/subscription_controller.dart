import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/payment/modern_card_payment_screen.dart';

/// Single plan description as returned by GET /subscriptions/plans.
class SubscriptionPlan {
  final String plan; // 'monthly' | 'yearly'
  final double amount;
  final String currency;
  final int intervalDays;
  final String label;

  const SubscriptionPlan({
    required this.plan,
    required this.amount,
    required this.currency,
    required this.intervalDays,
    required this.label,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
        plan: j['plan'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? 'EUR',
        intervalDays: (j['intervalDays'] as num).toInt(),
        label: (j['label'] as String?) ?? j['plan'] as String,
      );

  double get amountPerDay => intervalDays == 0 ? 0 : amount / intervalDays;
}

/// Snapshot of the current user's subscription, returned by /subscriptions/status.
class SubscriptionStatus {
  final String plan; // 'none' | 'monthly' | 'yearly'
  final String status; // 'active' | 'expired' | 'canceled' | 'none' | 'pending'
  final bool isPremium;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final int mapBoostCreditsRemaining;
  final Map<String, dynamic> features;

  const SubscriptionStatus({
    required this.plan,
    required this.status,
    required this.isPremium,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.mapBoostCreditsRemaining = 0,
    this.features = const {},
  });

  factory SubscriptionStatus.empty() => const SubscriptionStatus(
        plan: 'none',
        status: 'none',
        isPremium: false,
      );

  factory SubscriptionStatus.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return SubscriptionStatus(
      plan: (j['plan'] as String?) ?? 'none',
      status: (j['status'] as String?) ?? 'none',
      isPremium: j['isPremium'] == true,
      currentPeriodEnd: parseDate(j['currentPeriodEnd']),
      cancelAtPeriodEnd: j['cancelAtPeriodEnd'] == true,
      mapBoostCreditsRemaining: (j['mapBoostCreditsRemaining'] as num?)?.toInt() ?? 0,
      features: (j['features'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  int get remainingDays {
    if (currentPeriodEnd == null) return 0;
    final diff = currentPeriodEnd!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}

/// GetX controller: manages the Premium subscription state and purchase flow.
///
/// Usage:
///   - Call Get.put(SubscriptionController()) at app bootstrap or lazily
///   - Read `controller.isPremium.value` in UI to gate features
///   - Call `controller.purchase('monthly')` to launch Stripe PaymentSheet
class SubscriptionController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isPurchasing = false.obs;
  final Rxn<SubscriptionStatus> status = Rxn<SubscriptionStatus>();
  final RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;
  final RxList<String> supportedCurrencies =
      <String>['EUR', 'GBP', 'CHF', 'USD'].obs;

  /// Currency the user is paying with. Defaults to EUR but the UI should
  /// call `setCurrency()` once it knows the user's country (or let them pick).
  final RxString currency = CurrencyHelper.eur.obs;

  /// Shortcut accessor — the UI reads this to decide whether to show Premium features.
  bool get isPremium => status.value?.isPremium ?? false;

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  /// Swap currency and reload plan pricing from the backend.
  Future<void> setCurrency(String next) async {
    final upper = next.toUpperCase();
    if (!supportedCurrencies.contains(upper)) return;
    if (currency.value == upper) return;
    currency.value = upper;
    await loadPlans();
  }

  Future<void> refresh() async {
    isLoading.value = true;
    try {
      await Future.wait([loadPlans(), loadStatus()]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadPlans() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get(
        '/subscriptions/plans',
        queryParameters: {'currency': currency.value},
      );
      final list = (data['plans'] as List?) ?? const [];
      plans.value = list
          .map((p) => SubscriptionPlan.fromJson(p as Map<String, dynamic>))
          .toList();
      final supported = (data['supportedCurrencies'] as List?)?.cast<String>();
      if (supported != null && supported.isNotEmpty) {
        supportedCurrencies.value = supported;
      }
    } catch (e) {
      debugPrint('[Subscription] loadPlans error: $e');
    }
  }

  Future<void> loadStatus() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/subscriptions/status', requiresAuth: true);
      status.value = SubscriptionStatus.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      debugPrint('[Subscription] loadStatus API error: ${e.message}');
      status.value = SubscriptionStatus.empty();
    } catch (e) {
      debugPrint('[Subscription] loadStatus error: $e');
      status.value = SubscriptionStatus.empty();
    }
  }

  /// Launches the in-app modern card screen for the given plan and confirms
  /// the subscription on success. Returns true if the purchase was fully
  /// completed and status refreshed.
  ///
  /// Replaces the former Stripe PaymentSheet flow (was unreliable on some
  /// Android devices — card number field wouldn't accept input).
  Future<bool> purchase(String plan) async {
    if (isPurchasing.value) return false;
    isPurchasing.value = true;
    try {
      final api = Get.find<ApiClient>();

      // 1. Create PaymentIntent server-side.
      final piData = await api.post(
        '/subscriptions/subscribe',
        body: {'plan': plan, 'currency': currency.value},
        requiresAuth: true,
      ) as Map<String, dynamic>;

      final clientSecret = piData['clientSecret'] as String?;
      final paymentIntentId = piData['paymentIntentId'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Failed to create subscription payment intent.');
      }

      // 2. Ensure Stripe publishable key is set (defensive — main.dart
      //    already inits at boot but we keep this as a fallback).
      final pk = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
      if (pk.isNotEmpty && Stripe.publishableKey.isEmpty) {
        Stripe.publishableKey = pk;
        await Stripe.instance.applySettings();
      }

      // 3. Resolve display amount for the chosen plan+currency.
      final planRow = plans.firstWhereOrNull((p) => p.plan == plan);
      final displayAmount = planRow?.amount ?? 0;

      // 4. Push the in-app card screen. Returns true only on confirmed
      //    payment, false on cancel / error.
      final ok = await Get.to<bool>(
        () => ModernCardPaymentScreen(
          clientSecret: clientSecret,
          amount: displayAmount,
          currency: currency.value,
          productLabel:
              plan == 'yearly' ? 'Premium Annuel' : 'Premium Mensuel',
          productSubtitle: plan == 'yearly'
              ? '1 an — 35% off vs mensuel'
              : 'Renouvellement mensuel',
        ),
      );

      if (ok != true) return false; // user cancelled or payment failed

      // 5. Confirm subscription on backend.
      await api.post(
        '/subscriptions/confirm',
        body: {
          'plan': plan,
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

  Future<void> cancelAtPeriodEnd() async {
    try {
      final api = Get.find<ApiClient>();
      await api.post('/subscriptions/cancel', requiresAuth: true);
      await loadStatus();
    } catch (e) {
      debugPrint('[Subscription] cancel error: $e');
      rethrow;
    }
  }

  Future<void> resume() async {
    try {
      final api = Get.find<ApiClient>();
      await api.post('/subscriptions/resume', requiresAuth: true);
      await loadStatus();
    } catch (e) {
      debugPrint('[Subscription] resume error: $e');
      rethrow;
    }
  }
}
