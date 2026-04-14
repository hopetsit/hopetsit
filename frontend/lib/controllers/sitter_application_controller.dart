import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/logger.dart';

class SitterApplicationController extends GetxController {
  SitterApplicationController({SitterRepository? sitterRepository})
    : _sitterRepository = sitterRepository ?? Get.find<SitterRepository>();

  final SitterRepository _sitterRepository;

  final RxList<BookingModel> bookings = <BookingModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadBookings();
  }

  Future<void> loadBookings() async {
    isLoading.value = true;

    try {
      // Load bookings without status filter (for applications tab)
      final bookingsList = await _sitterRepository.getMyBookings();
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

  /// Accepts an application by agreeing to the booking.
  Future<Map<String, dynamic>> acceptApplication(String bookingId) async {
    try {
      await _sitterRepository.respondToBooking(
        bookingId: bookingId,
        action: 'accept',
      );

      // Reload bookings to reflect the updated status
      await loadBookings();
      return {'success': true};
    } on ApiException catch (error) {
      AppLogger.logError('Failed to accept application', error: error.message);
      return {'success': false, 'message': error.message};
    } catch (error) {
      AppLogger.logError('Failed to accept application', error: error);
      return {
        'success': false,
        'message': 'sitter_application_accept_failed'.tr,
      };
    }
  }

  /// Rejects an application by requesting cancellation.
  Future<Map<String, dynamic>> rejectApplication(String bookingId) async {
    try {
      await _sitterRepository.respondToBooking(
        bookingId: bookingId,
        action: 'reject',
      );

      // Reload bookings to reflect the updated status
      await loadBookings();
      return {'success': true};
    } on ApiException catch (error) {
      AppLogger.logError('Failed to reject application', error: error.message);
      return {'success': false, 'message': error.message};
    } catch (error) {
      AppLogger.logError('Failed to reject application', error: error);
      return {
        'success': false,
        'message': 'sitter_application_reject_failed'.tr,
      };
    }
  }
}
