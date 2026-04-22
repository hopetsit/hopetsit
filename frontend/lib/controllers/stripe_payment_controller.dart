import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
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

      if (_clientSecret == null || _clientSecret!.isEmpty) {
        throw ApiException('payment_error_client_secret_missing'.tr);
      }
      if (_publishableKey == null || _publishableKey!.isEmpty) {
        throw ApiException('payment_error_publishable_key_missing'.tr);
      }
      if (!_publishableKey!.startsWith('pk_')) {
        throw ApiException('payment_error_invalid_publishable_key'.tr);
      }

      Stripe.publishableKey = _publishableKey!;
      await Stripe.instance.applySettings();

      AppLogger.logUserAction(
        'Payment Intent Created',
        data: {'bookingId': booking.id, 'paymentIntentId': _paymentIntentId},
      );

      log('clientSecret: $_clientSecret');
      log('publishableKey: $_publishableKey');
      log('paymentIntentId: $_paymentIntentId');

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

      // Handle specific error cases with user-friendly messages
      String errorMessage = error.message;
      String errorTitle = 'payment_error_title'.tr;

      if (error.message.toLowerCase().contains('stripe connect') ||
          error.message.toLowerCase().contains('sitter must have') ||
          error.message.toLowerCase().contains('active')) {
        errorTitle = 'payment_unavailable_title'.tr;
        errorMessage = 'payment_unavailable_message'.tr;
      } else if (error.message.toLowerCase().contains('amount') ||
          error.message.toLowerCase().contains('price')) {
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
