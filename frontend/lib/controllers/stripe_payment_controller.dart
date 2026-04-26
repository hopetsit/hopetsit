import 'dart:developer';

import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/payment/payment_result_screen.dart';
import 'package:hopetsit/controllers/loyalty_controller.dart';

/// v21.1.1 — Stripe purgé. Pure Airwallex.
/// Le nom de classe est conservé pour ne pas casser les imports existants.
class StripePaymentController extends GetxController {
  final BookingModel booking;
  final double totalAmount;
  final String currency;

  StripePaymentController({
    required this.booking,
    required this.totalAmount,
    this.currency = 'EUR',
    OwnerRepository? ownerRepository,
  }) : _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final OwnerRepository _ownerRepository;

  final RxBool isProcessing = false.obs;
  String? _paymentIntentId;
  String? _clientSecret;

  /// v21.1.1 — Flux unifié pure Airwallex.
  ///   1. POST /create-payment-intent (loyalty flag included)
  ///   2. Airwallex HPP webview confirme le paiement
  ///   3. POST /confirm-payment (server-side finalisation)
  ///   4. Navigate to PaymentResultScreen
  ///
  /// Le paramètre billingDetails est conservé pour compat API mais ignoré
  /// (Airwallex collecte les infos billing dans son propre HPP).
  Future<void> initiateAndConfirmPayment({
    dynamic billingDetails, // ignoré, kept for API compat
  }) async {
    if (isProcessing.value) return;

    // Airwallex minimum amount = 0.50 EUR cents — same as Stripe ;
    // backend already enforces this server-side.
    const minAmount = 0.50;
    if (totalAmount < minAmount) {
      CustomSnackbar.showError(
        title: 'payment_invalid_amount_title'.tr,
        message: 'payment_min_amount_message'.tr,
      );
      return;
    }

    isProcessing.value = true;

    try {
      AppLogger.logUserAction(
        'Creating Payment Intent (Airwallex)',
        data: {'bookingId': booking.id, 'amount': totalAmount},
      );

      final useLoyaltyCredit = Get.isRegistered<LoyaltyController>()
          ? Get.find<LoyaltyController>().useLoyaltyCreditForNextPayment.value
          : false;
      final paymentIntentResponse = await _ownerRepository.createPaymentIntent(
        bookingId: booking.id,
        useLoyaltyCredit: useLoyaltyCredit,
      );
      if (Get.isRegistered<LoyaltyController>()) {
        Get.find<LoyaltyController>().useLoyaltyCreditForNextPayment.value = false;
      }

      _clientSecret =
          paymentIntentResponse['clientSecret'] as String? ??
          paymentIntentResponse['client_secret'] as String?;
      _paymentIntentId =
          paymentIntentResponse['paymentIntentId'] as String? ??
          paymentIntentResponse['payment_intent_id'] as String?;

      if (_clientSecret == null || _clientSecret!.isEmpty) {
        throw ApiException('payment_error_client_secret_missing'.tr);
      }

      AppLogger.logUserAction(
        'Payment Intent Created (Airwallex)',
        data: {'bookingId': booking.id, 'paymentIntentId': _paymentIntentId},
      );
      log('[booking] AIRWALLEX flow (€$totalAmount) — pi=$_paymentIntentId');

      final result = await AirwallexPaymentService.confirmPaymentIntent(
        intentId: _paymentIntentId ?? '',
        clientSecret: _clientSecret!,
        amount: totalAmount,
        currency: currency,
      );
      if (result.isSuccess) {
        AppLogger.logUserAction(
          'Airwallex Payment Confirmed',
          data: {'bookingId': booking.id, 'paymentIntentId': _paymentIntentId},
        );
        if (_paymentIntentId != null && _paymentIntentId!.isNotEmpty) {
          await confirmPayment(paymentIntentId: _paymentIntentId!);
        } else {
          Get.off(
            () => PaymentResultScreen(
              isSuccess: true,
              message: 'payment_success_message'.tr,
              amount: totalAmount,
              currency: currency,
              booking: booking,
              onContinue: () => Get.until((route) => route.isFirst),
            ),
          );
          isProcessing.value = false;
        }
      } else if (result.outcome == AirwallexPaymentOutcome.failed) {
        AppLogger.logError('Airwallex payment failed', error: result.errorMessage);
        CustomSnackbar.showError(
          title: 'payment_failed_title'.tr,
          message: result.errorMessage ?? 'common_error_message'.tr,
        );
        isProcessing.value = false;
      } else {
        // outcome == cancelled → silent (user closed the sheet on purpose).
        isProcessing.value = false;
      }
    } on ApiException catch (error) {
      AppLogger.logError('Payment initiation failed', error: error.message);

      String errorMessage = error.message;
      String errorTitle = 'payment_error_title'.tr;

      final lowered = error.message.toLowerCase();
      if (lowered.contains('amount must be at least') ||
          lowered.contains('min_amount') ||
          lowered.contains('trop petit') ||
          (lowered.contains('amount') && lowered.contains('50'))) {
        errorTitle = 'payment_invalid_amount_title'.tr;
        errorMessage = 'payment_min_amount_message'.tr;
      } else if (lowered.contains('amount') || lowered.contains('price')) {
        errorTitle = 'payment_invalid_amount_title'.tr;
        errorMessage = 'payment_invalid_amount_message'.tr;
      }

      CustomSnackbar.showError(title: errorTitle, message: errorMessage);
      isProcessing.value = false;
    } catch (e) {
      AppLogger.logError('Payment initiation failed', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'payment_initiate_error'.tr,
      );
      isProcessing.value = false;
    }
  }

  /// v21.1.1 — Saved-card flow. Avec Airwallex le paiement par carte
  /// sauvegardée passe par PaymentConsent (à venir v22). Pour l'instant on
  /// fallback sur le HPP standard où le user re-saisit la carte. Migration
  /// transparente côté API : on garde la signature de la méthode pour ne
  /// pas casser les call sites.
  Future<void> initiateAndConfirmPaymentWithSavedMethod({
    required String paymentMethodId,
  }) async {
    // Pour l'instant on délègue au flow standard. Le paymentMethodId n'est
    // pas encore exploité (TODO v22 : Airwallex PaymentConsent).
    return initiateAndConfirmPayment();
  }

  /// Confirms payment with backend after successful payment.
  Future<void> confirmPayment({required String paymentIntentId}) async {
    try {
      await _ownerRepository.confirmPayment(
        bookingId: booking.id,
        paymentIntentId: paymentIntentId,
      );

      AppLogger.logUserAction(
        'Payment Confirmed',
        data: {'bookingId': booking.id, 'paymentIntentId': paymentIntentId},
      );

      Get.off(
        () => PaymentResultScreen(
          isSuccess: true,
          message: 'payment_success_message'.tr,
          transactionId: paymentIntentId,
          amount: totalAmount,
          currency: currency,
          booking: booking,
          onContinue: () => Get.until((route) => route.isFirst),
        ),
      );
    } on ApiException catch (error) {
      AppLogger.logError('Payment confirmation failed', error: error.message);
      Get.off(
        () => PaymentResultScreen(
          isSuccess: false,
          message: error.message.isNotEmpty
              ? error.message
              : 'payment_confirmation_failed_retry'.tr,
          transactionId: paymentIntentId,
          amount: totalAmount,
          currency: currency,
          booking: booking,
          onContinue: () => Get.back(),
        ),
      );
    } catch (error) {
      AppLogger.logError('Payment confirmation failed', error: error);
      Get.off(
        () => PaymentResultScreen(
          isSuccess: false,
          message: 'payment_unexpected_error_retry'.tr,
          transactionId: paymentIntentId,
          amount: totalAmount,
          currency: currency,
          booking: booking,
          onContinue: () => Get.back(),
        ),
      );
    } finally {
      isProcessing.value = false;
    }
  }
}
