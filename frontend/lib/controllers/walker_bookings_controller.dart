import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Bookings controller for the walker role.
///
/// Session v17 — mirror of `SitterBookingsController`. The walker flow used to
/// be crippled because the backend `GET /bookings/my` route returned `[]`
/// for walker callers, and no frontend controller was wired for the walker
/// bookings history tab.
class WalkerBookingsController extends GetxController {
  WalkerBookingsController({WalkerRepository? walkerRepository})
    : _walkerRepository = walkerRepository ?? Get.find<WalkerRepository>();

  final WalkerRepository _walkerRepository;

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
    // When status is null, reset to "all" (no filter) — parity with sitter.
    selectedStatus.value = status ?? '';

    try {
      final bookingsList = await _walkerRepository.getMyBookings(
        status: selectedStatus.value.isEmpty ? null : selectedStatus.value,
      );
      bookings.assignAll(bookingsList);
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load walker bookings', error: error.message);
      bookings.clear();
    } catch (error) {
      AppLogger.logError('Failed to load walker bookings', error: error);
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
      await _walkerRepository.selfCancelBooking(
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

  /// Requests cancellation for a booking (rejects/cancels the booking).
  Future<void> requestCancellation({required String bookingId}) async {
    try {
      await _walkerRepository.requestBookingCancellation(bookingId: bookingId);

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
