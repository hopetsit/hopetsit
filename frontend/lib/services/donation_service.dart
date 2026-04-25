import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/payment/modern_card_payment_screen.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v20.1 — flux de don, dual-provider :
///   - backend renvoie `provider: 'airwallex'` → on ouvre le drop-in Airwallex
///   - sinon (défaut Stripe) → ancien flux ModernCardPaymentScreen
/// La bascule se fait via PAYMENT_PROVIDER côté Render. Stripe reste actif
/// par défaut pour zero-downtime rollback.
class DonationService {
  DonationService._();

  static Future<void> donate({
    required BuildContext context,
    required double amount,
    String currency = 'EUR',
    String? title,
    String? subtitle,
  }) async {
    try {
      final api = Get.find<ApiClient>();
      final resp = await api.post(
        '/donations/create-intent',
        body: {'amount': amount, 'currency': currency},
        requiresAuth: true,
      );
      final map = resp is Map<String, dynamic>
          ? resp
          : Map<String, dynamic>.from(resp as Map);

      final clientSecret    = map['clientSecret']?.toString() ?? '';
      final paymentIntentId = map['paymentIntentId']?.toString() ?? '';
      final provider        = (map['provider']?.toString() ?? 'stripe').toLowerCase();

      if (clientSecret.isEmpty) {
        throw Exception('Missing clientSecret in donation response.');
      }

      // ─── Branche Airwallex (v20.1) ──────────────────────────────────────
      if (provider == 'airwallex') {
        AppLogger.logInfo('[donation] using AIRWALLEX flow ($amount $currency)');
        final result = await AirwallexPaymentService.confirmPaymentIntent(
          intentId:     paymentIntentId,
          clientSecret: clientSecret,
          amount:       amount,
          currency:     currency,
        );
        // ignore: use_build_context_synchronously
        if (!context.mounted) return;
        if (result.isSuccess) {
          CustomSnackbar.showSuccess(
            title: 'donation_thanks_title'.tr,
            message: 'donation_thanks_message'.trParams({
              'amount': '${amount.toStringAsFixed(0)} $currency',
            }),
          );
        } else if (result.outcome == AirwallexPaymentOutcome.failed) {
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: result.errorMessage ?? 'common_error_message'.tr,
          );
        }
        // outcome == cancelled → silent (user closed the sheet on purpose).
        return;
      }

      // ─── Branche Stripe (défaut, rollback) ─────────────────────────────
      AppLogger.logInfo('[donation] using STRIPE flow ($amount $currency)');

      // Init Stripe si besoin.
      if (Stripe.publishableKey.isEmpty) {
        // L'app est censée avoir déjà init Stripe au boot (main.dart),
        // mais on garde une safety.
        await Stripe.instance.applySettings();
      }

      // Charge les saved cards pour payer en 1 tap.
      List<Map<String, dynamic>> savedCards = const [];
      try {
        final m = await api.get('/owner/payments/methods', requiresAuth: true);
        if (m is Map) {
          final list = m['paymentMethods'];
          if (list is List) {
            savedCards = list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      } catch (_) {}

      // ignore: use_build_context_synchronously
      if (!context.mounted) return;
      final ok = await Get.to<bool>(
        () => ModernCardPaymentScreen(
          clientSecret: clientSecret,
          amount: amount,
          currency: currency,
          productLabel: title ?? 'donation_payment_label'.tr,
          productSubtitle: subtitle ?? 'donation_payment_subtitle'.tr,
          savedPaymentMethods: savedCards,
        ),
      );
      if (ok == true) {
        CustomSnackbar.showSuccess(
          title: 'donation_thanks_title'.tr,
          message: 'donation_thanks_message'.trParams({
            'amount': '${amount.toStringAsFixed(0)} $currency',
          }),
        );
      }
    } catch (e) {
      AppLogger.logError('Donation failed', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_message'.tr,
      );
    }
  }
}
