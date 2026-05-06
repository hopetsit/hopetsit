import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/services/socket_service.dart';
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
    // v23.1 part 53 — fix Daniel "walker pas de banner Paiement reçu".
    // The backend now emits `booking:paid` to walker too (in addition to
    // owner). We listen here so the WalkerBookingsController bookings
    // list refreshes in real-time on payment, which makes the home banner
    // flip to "Paiement reçu !" within ~1 second instead of waiting for
    // the 30s polling cycle.
    _attachSocketListeners();
    try {
      final svc = Get.find<SocketService>();
      svc.addOnConnectedHook(_attachSocketListeners);
    } catch (_) { /* SocketService not registered yet — re-attach on next init */ }
  }

  void _attachSocketListeners() {
    try {
      final s = Get.find<SocketService>();
      // v23.1 part 63 — Bug A : double-fetch on booking:paid to defeat
      // the rare race where Mongo hasn't committed paymentStatus='paid'
      // by the time we hit /bookings/my. Same pattern as sitter ctrl.
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
      AppLogger.logError('WalkerBookingsController socket bind failed', error: e);
    }
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
      // v23.1 part 48 — same defensive fix as BookingsController : keep
      // the previous list on transient API errors.
      AppLogger.logError(
        'Failed to load walker bookings (keeping previous list)',
        error: error.message,
      );
    } catch (error) {
      AppLogger.logError(
        'Failed to load walker bookings (keeping previous list)',
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
