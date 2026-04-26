import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v21.1.1 — flux de don pure Airwallex. Stripe purgé.
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

      if (clientSecret.isEmpty) {
        throw Exception('Missing clientSecret in donation response.');
      }

      AppLogger.logInfo('[donation] AIRWALLEX flow ($amount $currency)');
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
    } catch (e) {
      AppLogger.logError('Donation failed', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_message'.tr,
      );
    }
  }
}
