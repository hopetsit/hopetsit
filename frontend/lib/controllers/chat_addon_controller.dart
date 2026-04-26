import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';

/// Pricing snapshot from GET /chat-addon/plans.
class ChatAddonPlan {
  final double amount;
  final String currency;
  final int intervalDays;
  final String label;

  const ChatAddonPlan({
    required this.amount,
    required this.currency,
    required this.intervalDays,
    required this.label,
  });

  factory ChatAddonPlan.empty() =>
      const ChatAddonPlan(amount: 0, currency: 'EUR', intervalDays: 30, label: '');

  factory ChatAddonPlan.fromJson(Map<String, dynamic> j) => ChatAddonPlan(
        amount: ((j['amount'] as num?) ?? 0).toDouble(),
        currency: (j['currency'] as String?) ?? 'EUR',
        intervalDays: ((j['intervalDays'] as num?) ?? 30).toInt(),
        label: (j['label'] as String?) ?? 'Chat add-on',
      );
}

class ChatAddonStatus {
  final bool isActive;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  const ChatAddonStatus({
    required this.isActive,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  factory ChatAddonStatus.empty() => const ChatAddonStatus(isActive: false);

  factory ChatAddonStatus.fromJson(Map<String, dynamic> j) => ChatAddonStatus(
        isActive: j['isActive'] == true,
        currentPeriodEnd:
            DateTime.tryParse(j['currentPeriodEnd']?.toString() ?? ''),
        cancelAtPeriodEnd: j['cancelAtPeriodEnd'] == true,
      );
}

/// Controller for the cheap Chat add-on — session v3.2.
///
/// Unlocks chat between accepted friends for free users. Premium users
/// already have chat with everyone so they don't need this.
class ChatAddonController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isPurchasing = false.obs;
  final Rxn<ChatAddonPlan> plan = Rxn<ChatAddonPlan>();
  final Rxn<ChatAddonStatus> status = Rxn<ChatAddonStatus>();
  final RxString currency = CurrencyHelper.eur.obs;

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  Future<void> setCurrency(String next) async {
    final upper = next.toUpperCase();
    if (currency.value == upper) return;
    currency.value = upper;
    await loadPlan();
  }

  @override

  Future<void> refresh() async {
    isLoading.value = true;
    try {
      await Future.wait([loadPlan(), loadStatus()]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadPlan() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get(
        '/chat-addon/plans',
        queryParameters: {'currency': currency.value},
      );
      plan.value = ChatAddonPlan.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ChatAddon] loadPlan error: $e');
      plan.value = ChatAddonPlan.empty();
    }
  }

  Future<void> loadStatus() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/chat-addon/status', requiresAuth: true);
      status.value = ChatAddonStatus.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ChatAddon] loadStatus error: $e');
      status.value = ChatAddonStatus.empty();
    }
  }

  /// Launches the in-app card screen and, on success, activates the add-on.
  Future<bool> purchase() async {
    if (isPurchasing.value) return false;
    isPurchasing.value = true;
    try {
      final api = Get.find<ApiClient>();
      final piData = await api.post(
        '/chat-addon/subscribe',
        body: {'currency': currency.value},
        requiresAuth: true,
      ) as Map<String, dynamic>;

      final clientSecret = piData['clientSecret'] as String?;
      final paymentIntentId = piData['paymentIntentId'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('No client secret.');
      }

      final currentPlan = plan.value;
      final displayAmount = currentPlan?.amount ?? 0;

      // v21.1.1 — Stripe purgé. Pure Airwallex.
      AppLogger.logInfo('[chat-addon] AIRWALLEX flow ($displayAmount $currency)');
      final result = await AirwallexPaymentService.confirmPaymentIntent(
        intentId: paymentIntentId ?? '',
        clientSecret: clientSecret,
        amount: displayAmount,
        currency: currency.value,
      );
      if (result.isSuccess) {
        await api.post(
          '/chat-addon/confirm',
          body: {
            'paymentIntentId': paymentIntentId,
            'currency': currency.value,
          },
          requiresAuth: true,
        );
        await loadStatus();
        return true;
      } else if (result.outcome == AirwallexPaymentOutcome.failed) {
        AppLogger.logError('[chat-addon] Airwallex failed', error: result.errorMessage);
        return false;
      }
      // outcome == cancelled → silent (user closed the sheet on purpose).
      return false;
    } finally {
      isPurchasing.value = false;
    }
  }
}
