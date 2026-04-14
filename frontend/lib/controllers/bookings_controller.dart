import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class BookingsController extends GetxController {
  BookingsController({OwnerRepository? ownerRepository})
    : _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final OwnerRepository _ownerRepository;

  final RxList<BookingModel> bookings = <BookingModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString selectedStatus = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadBookings();
  }

  Future<void> loadBookings({String? status}) async {
    isLoading.value = true;
    if (status != null) {
      selectedStatus.value = status;
    }

    try {
      final bookingsList = await _ownerRepository.getMyBookings(
        status: selectedStatus.value.isEmpty ? null : selectedStatus.value,
      );
      bookings.assignAll(bookingsList);
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load bookings', error: error.message);
      bookings.clear();
    } catch (error) {
      AppLogger.logError('Failed to load bookings', error: error);
      bookings.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> cancelBooking({
    required String bookingId,
    required String sitterId,
  }) async {
    try {
      await _ownerRepository.cancelBooking(
        bookingId: bookingId,
        sitterId: sitterId,
      );

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'bookings_cancel_success'.tr,
      );

      // Refresh the bookings list
      await loadBookings();
    } on ApiException catch (error) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: error.message);
    } catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'bookings_cancel_error'.tr,
      );
    }
  }

  /// Requests cancellation for a booking (initiates cancellation request)
  Future<void> requestCancellation({
    required String bookingId,
  }) async {
    try {
      await _ownerRepository.requestCancellation(
        bookingId: bookingId,
      );

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'bookings_cancel_request_success'.tr,
      );

      // Refresh the bookings list
      await loadBookings();
    } on ApiException catch (error) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: error.message);
    } catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'bookings_cancel_request_error'.tr,
      );
    }
  }

  /// Gets booking agreement/price details
  Future<Map<String, dynamic>> getBookingAgreement({
    required String bookingId,
  }) async {
    try {
      return await _ownerRepository.getBookingAgreement(
        bookingId: bookingId,
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to get booking agreement', error: error.message);
      rethrow;
    } catch (error) {
      AppLogger.logError('Failed to get booking agreement', error: error);
      rethrow;
    }
  }

  /// Gets payment status for a booking
  Future<Map<String, dynamic>?> getPaymentStatus({
    required String bookingId,
  }) async {
    try {
      final status = await _ownerRepository.getPaymentStatus(
        bookingId: bookingId,
      );

      AppLogger.logUserAction(
        'Payment Status Retrieved',
        data: {
          'bookingId': bookingId,
          'status': status,
        },
      );

      return status;
    } on ApiException catch (error) {
      AppLogger.logError('Failed to get payment status', error: error.message);
      CustomSnackbar.showError(title: 'common_error'.tr, message: error.message);
      return null;
    } catch (error) {
      AppLogger.logError('Failed to get payment status', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'bookings_payment_status_error'.tr,
      );
      return null;
    }
  }
}
