import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class SitterBookingsController extends GetxController {
  SitterBookingsController({SitterRepository? sitterRepository})
    : _sitterRepository = sitterRepository ?? Get.find<SitterRepository>();

  final SitterRepository _sitterRepository;

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
    // When status is null, reset to "all" (no filter)
    selectedStatus.value = status ?? '';

    try {
      final bookingsList = await _sitterRepository.getMyBookings(
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

  /// Self-cancel a paid booking with automatic refund (72h window).
  Future<void> selfCancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    try {
      await _sitterRepository.selfCancelBooking(
        bookingId: bookingId,
        reason: reason,
      );

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'cancel_72h_success'.tr,
      );

      await loadBookings();
    } on ApiException catch (error) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: error.message);
    } catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'cancel_72h_error'.tr,
      );
    }
  }

  /// Requests cancellation for a booking (rejects/cancels the booking)
  Future<void> requestCancellation({required String bookingId}) async {
    try {
      await _sitterRepository.requestBookingCancellation(bookingId: bookingId);

      CustomSnackbar.showSuccess(
        title: 'common_success',
        message: 'sitter_bookings_cancel_success',
      );

      // Refresh the bookings list
      await loadBookings();
    } on ApiException {
      CustomSnackbar.showError(
        title: 'common_error',
        message: 'sitter_bookings_cancel_error',
      );
    } catch (error) {
      CustomSnackbar.showError(
        title: 'common_error',
        message: 'sitter_bookings_cancel_error',
      );
    }
  }
}
