import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/services/socket_service.dart';
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
    // v23.1 part 53 — same socket listener pattern as walker. Listens to
    // backend's booking:paid event so the home banner flips to
    // "Paiement reçu !" instantly when the owner pays.
    _attachSocketListeners();
    try {
      final svc = Get.find<SocketService>();
      svc.addOnConnectedHook(_attachSocketListeners);
    } catch (_) { /* SocketService not registered — re-attach on next init */ }
  }

  void _attachSocketListeners() {
    try {
      final s = Get.find<SocketService>();
      // v23.1 part 63 — Bug A : double-fetch on booking:paid to defeat
      // the rare race where Mongo hasn't committed paymentStatus='paid'
      // by the time we hit /bookings/my. The 2s delayed retry catches
      // it. If the first call already saw the new status, the retry is
      // a harmless no-op. Same defensive pattern on accepted/new.
      s.socket?.off('booking:paid');
      s.socket?.on('booking:paid', (_) {
        loadBookings();
        Future.delayed(const Duration(seconds: 2), () => loadBookings());
      });
      s.socket?.off('booking:accepted');
      s.socket?.on('booking:accepted', (_) {
        loadBookings();
        Future.delayed(const Duration(seconds: 2), () => loadBookings());
      });
      s.socket?.off('booking:new');
      s.socket?.on('booking:new', (_) => loadBookings());
    } catch (e) {
      AppLogger.logError('SitterBookingsController socket bind failed', error: e);
    }
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
      // v23.1 part 48 — same defensive fix as BookingsController : keep
      // the previous list on transient API errors so the screen doesn't
      // jump to "Aucune réservation" on a network blip.
      AppLogger.logError(
        'Failed to load bookings (keeping previous list)',
        error: error.message,
      );
    } catch (error) {
      AppLogger.logError(
        'Failed to load bookings (keeping previous list)',
        error: error,
      );
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
