import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/payment/payment_result_screen.dart';
import 'package:hopetsit/controllers/loyalty_controller.dart';

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
  String? _publishableKey;

  /// v18.5 — #1/#8 : unified payment flow.
  ///
  /// Called once from the new StripePaymentScreen Pay button. Does the
  /// full pipeline in one call :
  ///   1. POST /create-payment-intent (loyalty flag included)
  ///   2. Stripe.instance.confirmPayment() with the inline card details
  ///   3. POST /confirm-payment (server-side finalisation)
  ///   4. Navigate to PaymentResultScreen
  ///
  /// Before v18.5 this was 2 calls (initiatePayment → ModernCardPaymentScreen
  /// → confirmPayment) which forced the owner through 2 screens. Now the
  /// card fields live on the same screen as the summary.
  Future<void> initiateAndConfirmPayment({
    required BillingDetails billingDetails,
  }) async {
    if (isProcessing.value) return;

    // v18.5 — Stripe minimum charge est 0.50 EUR (50 cents). Avant de tenter
    // la création du PaymentIntent (qui donnerait un 500 générique côté
    // backend), on check ici pour afficher un message clair.
    const minStripeAmount = 0.50; // EUR cents min
    if (totalAmount < minStripeAmount) {
      CustomSnackbar.showError(
        title: 'payment_invalid_amount_title'.tr,
        message: 'payment_min_amount_message'.tr,
      );
      return;
    }

    isProcessing.value = true;

    try {
      // Step 1: Create payment intent
      AppLogger.logUserAction(
        'Creating Payment Intent',
        data: {'bookingId': booking.id, 'amount': totalAmount},
      );

      // Sprint 7 step 1 — carry the owner's loyalty discount intent through.
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
      _publishableKey =
          paymentIntentResponse['publishableKey'] as String? ??
          paymentIntentResponse['publishable_key'] as String? ??
          dotenv.env['STRIPE_PUBLISHABLE_KEY'];
      final provider = (paymentIntentResponse['provider']?.toString() ?? 'stripe').toLowerCase();

      if (_clientSecret == null || _clientSecret!.isEmpty) {
        throw ApiException('payment_error_client_secret_missing'.tr);
      }

      AppLogger.logUserAction(
        'Payment Intent Created',
        data: {'bookingId': booking.id, 'paymentIntentId': _paymentIntentId, 'provider': provider},
      );

      log('clientSecret: $_clientSecret');
      log('paymentIntentId: $_paymentIntentId');
      log('provider: $provider');

      // ─── Branche Airwallex (v20.1) ──────────────────────────────────────
      if (provider == 'airwallex') {
        AppLogger.logInfo('[booking] using AIRWALLEX flow (€$totalAmount)');
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
          Get.off(
            () => PaymentResultScreen(
              isSuccess: true,
              message: 'payment_success_message'.tr,
              transactionId: _paymentIntentId,
              amount: totalAmount,
              currency: currency,
              booking: booking,
              onContinue: () {
                Get.until((route) => route.isFirst);
              },
            ),
          );
        } else if (result.outcome == AirwallexPaymentOutcome.failed) {
          AppLogger.logError('Airwallex payment failed', error: result.errorMessage);
          CustomSnackbar.showError(
            title: 'payment_failed_title'.tr,
            message: result.errorMessage ?? 'common_error_message'.tr,
          );
        }
        // outcome == cancelled → silent (user closed the sheet on purpose).
        isProcessing.value = false;
        return;
      }

      // ─── Branche Stripe (défaut, rollback) ─────────────────────────────
      AppLogger.logInfo('[booking] using STRIPE flow (€$totalAmount)');

      if (_publishableKey == null || _publishableKey!.isEmpty) {
        throw ApiException('payment_error_publishable_key_missing'.tr);
      }
      if (!_publishableKey!.startsWith('pk_')) {
        throw ApiException('payment_error_invalid_publishable_key'.tr);
      }

      Stripe.publishableKey = _publishableKey!;
      await Stripe.instance.applySettings();

      // Step 2 : Confirm Stripe payment inline (no screen detour).
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: _clientSecret!,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: billingDetails,
          ),
        ),
      );

      // Step 3 : Tell the backend the PI succeeded → mark booking paid.
      if (_paymentIntentId != null && _paymentIntentId!.isNotEmpty) {
        await confirmPayment(paymentIntentId: _paymentIntentId!);
      } else {
        AppLogger.logUserAction(
          'Payment Completed (no PI id)',
          data: {'bookingId': booking.id, 'clientSecret': _clientSecret},
        );
        Get.off(
          () => PaymentResultScreen(
            isSuccess: true,
            message: 'payment_success_message'.tr,
            amount: totalAmount,
            currency: currency,
            onContinue: () {
              Get.until((route) => route.isFirst);
            },
          ),
        );
        isProcessing.value = false;
      }
    } on StripeException catch (e) {
      AppLogger.logError('Stripe payment failed', error: e);

      // Check if user cancelled the payment sheet
      final errorCode = e.error.code.toString().toLowerCase();
      final errorMessage = e.error.message?.toLowerCase() ?? '';

      if (errorCode.contains('cancel') ||
          errorCode.contains('sheet') ||
          errorMessage.contains('cancel') ||
          errorMessage.contains('dismissed')) {
        // User cancelled the payment - don't show error, just reset and go back
        AppLogger.logUserAction(
          'Payment Cancelled by User',
          data: {'bookingId': booking.id},
        );
        isProcessing.value = false;
        Get.back(); // Go back to previous screen

        // Refresh bookings list for both owner and sitter to update payment status
        if (Get.isRegistered<BookingsController>()) {
          Get.find<BookingsController>().loadBookings();
        }
        if (Get.isRegistered<SitterBookingsController>()) {
          Get.find<SitterBookingsController>().loadBookings();
        }

        return; // Exit without showing error
      }

      // Other Stripe errors
      String displayMessage = 'payment_processing_failed'.tr;
      if (e.error.message != null && e.error.message!.isNotEmpty) {
        displayMessage = e.error.message!;
      }
      CustomSnackbar.showError(
        title: 'payment_failed_title'.tr,
        message: displayMessage,
      );
      isProcessing.value = false;
    } on ApiException catch (error) {
      AppLogger.logError('Payment initiation failed', error: error.message);

      // v18.5 — hold admin est en place : un provider sans IBAN/PayPal ne
      // bloque plus le paiement côté backend. On ne force plus l'ancien
      // message "Stripe non vérifié" qui n'est plus vrai. On affiche juste
      // le message backend tel quel (ou les messages "montant invalide"
      // / "Stripe minimum" si détectés).
      String errorMessage = error.message;
      String errorTitle = 'payment_error_title'.tr;

      final lowered = error.message.toLowerCase();
      if (lowered.contains('amount must be at least') ||
          lowered.contains('min_amount') ||
          lowered.contains('trop petit') ||
          (lowered.contains('amount') && lowered.contains('50'))) {
        // Stripe minimum EUR = 0.50. Le backend ou Stripe renvoie un texte
        // parlant de ce minimum — donner un message clair.
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

  /// v18.5 — #19 : paiement avec une carte DÉJÀ sauvegardée (PaymentMethod
  /// attaché au Customer Stripe de l'owner). Pas besoin de saisir la carte,
  /// on passe directement le pm_xxx à confirmPayment.
  ///
  /// Backend : createPaymentIntent doit être appelé avec le stripeCustomerId
  /// de l'owner (déjà le cas depuis v18.2). On réutilise la même méthode.
  Future<void> initiateAndConfirmPaymentWithSavedMethod({
    required String paymentMethodId,
  }) async {
    if (isProcessing.value) return;

    const minStripeAmount = 0.50;
    if (totalAmount < minStripeAmount) {
      CustomSnackbar.showError(
        title: 'payment_invalid_amount_title'.tr,
        message: 'payment_min_amount_message'.tr,
      );
      return;
    }

    isProcessing.value = true;

    try {
      final useLoyaltyCredit = Get.isRegistered<LoyaltyController>()
          ? Get.find<LoyaltyController>().useLoyaltyCreditForNextPayment.value
          : false;
      final piResponse = await _ownerRepository.createPaymentIntent(
        bookingId: booking.id,
        useLoyaltyCredit: useLoyaltyCredit,
      );
      if (Get.isRegistered<LoyaltyController>()) {
        Get.find<LoyaltyController>().useLoyaltyCreditForNextPayment.value = false;
      }

      _clientSecret =
          piResponse['clientSecret'] as String? ??
          piResponse['client_secret'] as String?;
      _paymentIntentId =
          piResponse['paymentIntentId'] as String? ??
          piResponse['payment_intent_id'] as String?;
      _publishableKey =
          piResponse['publishableKey'] as String? ??
          piResponse['publishable_key'] as String? ??
          dotenv.env['STRIPE_PUBLISHABLE_KEY'];
      final provider = (piResponse['provider']?.toString() ?? 'stripe').toLowerCase();

      if (_clientSecret == null || _clientSecret!.isEmpty) {
        throw ApiException('payment_error_client_secret_missing'.tr);
      }

      // ─── Branche Airwallex ──────────────────────────────────────────────
      if (provider == 'airwallex') {
        AppLogger.logInfo('[booking] using AIRWALLEX flow with saved card (€$totalAmount)');
        final result = await AirwallexPaymentService.confirmPaymentIntent(
          intentId: _paymentIntentId ?? '',
          clientSecret: _clientSecret!,
          amount: totalAmount,
          currency: currency,
        );
        if (result.isSuccess) {
          AppLogger.logUserAction(
            'Airwallex Payment (Saved Card) Confirmed',
            data: {'bookingId': booking.id, 'paymentIntentId': _paymentIntentId},
          );
          Get.off(
            () => PaymentResultScreen(
              isSuccess: true,
              message: 'payment_success_message'.tr,
              transactionId: _paymentIntentId,
              amount: totalAmount,
              currency: currency,
              booking: booking,
              onContinue: () {
                Get.until((route) => route.isFirst);
              },
            ),
          );
        } else if (result.outcome == AirwallexPaymentOutcome.failed) {
          AppLogger.logError('Airwallex payment (saved card) failed', error: result.errorMessage);
          CustomSnackbar.showError(
            title: 'payment_failed_title'.tr,
            message: result.errorMessage ?? 'common_error_message'.tr,
          );
        }
        isProcessing.value = false;
        return;
      }

      // ─── Branche Stripe (défaut) ────────────────────────────────────────
      AppLogger.logInfo('[booking] using STRIPE flow with saved card (€$totalAmount)');

      if (_publishableKey == null || _publishableKey!.isEmpty) {
        throw ApiException('payment_error_publishable_key_missing'.tr);
      }
      Stripe.publishableKey = _publishableKey!;
      await Stripe.instance.applySettings();

      // Confirm avec le PaymentMethod sauvegardé. Le backend a déjà attaché
      // le PM au Customer via ownerPaymentMethods, donc pas besoin de
      // billingDetails à ce moment-là.
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: _clientSecret!,
        data: PaymentMethodParams.cardFromMethodId(
          paymentMethodData: PaymentMethodDataCardFromMethod(
            paymentMethodId: paymentMethodId,
          ),
        ),
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
            onContinue: () => Get.until((route) => route.isFirst),
          ),
        );
        isProcessing.value = false;
      }
    } on StripeException catch (e) {
      AppLogger.logError('Stripe payment (saved card) failed', error: e);
      final errorCode = e.error.code.toString().toLowerCase();
      final errorMessage = e.error.message?.toLowerCase() ?? '';
      if (errorCode.contains('cancel') ||
          errorMessage.contains('cancel') ||
          errorMessage.contains('dismissed')) {
        isProcessing.value = false;
        return;
      }
      CustomSnackbar.showError(
        title: 'payment_failed_title'.tr,
        message: e.error.message ?? 'payment_processing_failed'.tr,
      );
      isProcessing.value = false;
    } on ApiException catch (error) {
      AppLogger.logError('Payment (saved card) init failed', error: error.message);
      CustomSnackbar.showError(
        title: 'payment_error_title'.tr,
        message: error.message,
      );
      isProcessing.value = false;
    } catch (e) {
      AppLogger.logError('Payment (saved card) failed', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'payment_initiate_error'.tr,
      );
      isProcessing.value = false;
    }
  }

  /// Confirms payment with backend after successful Stripe payment
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

      // v18.5 — use i18n key instead of hardcoded English so the success
      // message matches the owner's language like the rest of the app.
      Get.off(
        () => PaymentResultScreen(
          isSuccess: true,
          message: 'payment_success_message'.tr,
          transactionId: paymentIntentId,
          amount: totalAmount,
          currency: currency,
          booking: booking,
          onContinue: () {
            Get.until((route) => route.isFirst);
          },
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
