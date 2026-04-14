import 'package:get/get.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/payment/payment_result_screen.dart';
import 'package:hopetsit/views/payment/paypal_webview_payment_screen.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class PayPalPaymentController extends GetxController {
  PayPalPaymentController({
    required this.booking,
    required this.totalAmount,
    required this.currency,
    OwnerRepository? ownerRepository,
  }) : _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final BookingModel booking;
  final double totalAmount;
  final String currency;
  final OwnerRepository _ownerRepository;

  final RxBool isProcessing = false.obs;

  String? _orderId;
  String? _approvalUrl;

  Future<void> initiatePayPalPayment() async {
    if (isProcessing.value) return;
    isProcessing.value = true;

    try {
      final order = await _ownerRepository.createPayPalOrder(
        bookingId: booking.id,
      );

      _orderId = (order['orderId'] as String?) ?? (order['orderID'] as String?);
      _approvalUrl = (order['approvalUrl'] as String?) ??
          (order['approvalURL'] as String?);

      if (_orderId == null || _orderId!.isEmpty) {
        throw ApiException('PayPal orderId missing.', details: order);
      }
      if (_approvalUrl == null || _approvalUrl!.isEmpty) {
        throw ApiException('PayPal approvalUrl missing.', details: order);
      }

      Get.to(
        () => PayPalWebviewPaymentScreen(
          booking: booking,
          totalAmount: totalAmount,
          currency: currency,
          orderId: _orderId!,
          approvalUrl: _approvalUrl!,
        ),
      );
    } on ApiException catch (error) {
      AppLogger.logError('PayPal payment init failed', error: error.message);
      CustomSnackbar.showError(
        title: 'payment_failed_title'.tr,
        message: error.message,
      );
    } catch (e) {
      AppLogger.logError('PayPal payment init failed', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'payment_initiate_error'.tr,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> captureOrder({required String orderId}) async {
    if (isProcessing.value) return;
    isProcessing.value = true;

    try {
      final resp = await _ownerRepository.capturePayPalOrder(
        bookingId: booking.id,
        orderId: orderId,
      );

      final status = (resp['status'] as String?)?.toLowerCase() ?? '';
      final message = resp['message'] as String?;

      final isSuccess = status == 'completed' || status == 'paid' || status == 'success';

      // Refresh bookings (owner + sitter)
      if (Get.isRegistered<BookingsController>()) {
        await Get.find<BookingsController>().loadBookings();
      }
      if (Get.isRegistered<SitterBookingsController>()) {
        await Get.find<SitterBookingsController>().loadBookings();
      }

      Get.off(
        () => PaymentResultScreen(
          isSuccess: isSuccess,
          message: message?.isNotEmpty == true
              ? message!
              : (isSuccess
                  ? 'payment_success_message'.tr
                  : 'payment_processing_failed'.tr),
          transactionId: orderId,
          amount: totalAmount,
          currency: currency,
          booking: booking,
          onContinue: () {
            Get.until((route) => route.isFirst);
          },
        ),
      );
    } on ApiException catch (error) {
      AppLogger.logError('PayPal capture failed', error: error.message);
      Get.off(
        () => PaymentResultScreen(
          isSuccess: false,
          message: error.message,
          transactionId: orderId,
          amount: totalAmount,
          currency: currency,
          booking: booking,
          onContinue: () {
            Get.back();
          },
        ),
      );
    } catch (e) {
      AppLogger.logError('PayPal capture failed', error: e);
      Get.off(
        () => PaymentResultScreen(
          isSuccess: false,
          message: 'payment_processing_failed'.tr,
          transactionId: orderId,
          amount: totalAmount,
          currency: currency,
          booking: booking,
          onContinue: () {
            Get.back();
          },
        ),
      );
    } finally {
      isProcessing.value = false;
    }
  }
}

