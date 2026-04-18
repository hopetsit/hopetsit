import 'dart:developer';

import 'package:flutter/material.dart';
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
import 'package:hopetsit/views/payment/modern_card_payment_screen.dart';
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

  /// Initiates payment by creating payment intent and showing Stripe PaymentSheet
  Future<void> initiatePayment() async {
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
      // Reset the flag after use.
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
        throw ApiException(
          'payment_error_client_secret_missing'.tr,
        );
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

      // Session v3.3 — remplace la PaymentSheet native par ModernCardPaymentScreen
      // (même raison que Premium/Boost/MapBoost/Chat : la sheet native avait un
      // bug connu sur certains Android où le champ numéro de carte ne recevait
      // pas les taps). L'écran custom accepte toujours le clientSecret et gère
      // confirmPayment côté Stripe avec la même API.
      final ok = await Get.to<bool>(
        () => ModernCardPaymentScreen(
          clientSecret: _clientSecret!,
          amount: totalAmount,
          currency: currency,
          productLabel: 'Réservation',
          productSubtitle: booking.sitter.name.isNotEmpty
              ? 'Prestation avec ${booking.sitter.name}'
              : null,
        ),
      );
      if (ok != true) {
        // User cancelled or payment failed — bail without confirm.
        isProcessing.value = false;
        return;
      }

      // Step 4: Confirm payment with backend
      if (_paymentIntentId != null && _paymentIntentId!.isNotEmpty) {
        await confirmPayment(paymentIntentId: _paymentIntentId!);
      } else {
        // Payment succeeded on Stripe side, show success
        AppLogger.logUserAction(
          'Payment Completed',
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

      // Navigate to success screen
      Get.off(
        () => PaymentResultScreen(
          isSuccess: true,
          message: 'Your payment has been processed successfully.',
          transactionId: paymentIntentId,
          amount: totalAmount,
          currency: currency,
          booking: booking,
          onContinue: () {
            // Navigate back to home or bookings screen
            Get.until((route) => route.isFirst);
          },
        ),
      );
    } on ApiException catch (error) {
      AppLogger.logError('Payment confirmation failed', error: error.message);
      Get.off(
        () => PaymentResultScreen(
          isSuccess: false,
          message: error.message,
          onContinue: () {
            Get.back();
          },
        ),
      );
    } catch (e) {
      AppLogger.logError('Payment confirmation failed', error: e);
      Get.off(
        () => PaymentResultScreen(
          isSuccess: false,
          message: 'payment_confirmation_failed'.tr,
          onContinue: () {
            Get.back();
          },
        ),
      );
    }
  }

  /// Legacy method - kept for backward compatibility
  Future<void> processPayment() async {
    await initiatePayment();
  }
}
