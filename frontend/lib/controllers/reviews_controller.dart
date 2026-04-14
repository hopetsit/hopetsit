import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class ReviewsController extends GetxController {
  final OwnerRepository _ownerRepository = Get.find<OwnerRepository>();

  final RxInt rating = 0.obs;
  final RxString description = ''.obs;
  final RxBool isLoading = false.obs;

  void setRating(int newRating) {
    rating.value = newRating;
  }

  void setDescription(String newDescription) {
    description.value = newDescription;
  }

  bool get canSubmit => rating.value > 0 && description.value.trim().isNotEmpty;

  /// Navigates to the home screen based on user role
  void _navigateToHome() {
    final role = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().userRole.value
        : null;

    if (role == 'owner') {
      Get.offAll(() => const BottomNavWrapper());
    } else if (role == 'sitter') {
      Get.offAll(() => const SitterNavWrapper());
    } else {
      // Fallback: navigate back if role is not recognized
      Get.back();
    }
  }

  Future<void> submitReview({
    required String serviceProviderId,
    required String serviceProviderName,
  }) async {
    if (!canSubmit) return;

    isLoading.value = true;

    try {
      await _ownerRepository.submitReview(
        revieweeId: serviceProviderId,
        rating: rating.value.toDouble(),
        comment: description.value.trim(),
      );

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_review_submitted_successfully',
      );

      // Reset form
      rating.value = 0;
      description.value = '';

      // Navigate to home screen
      _navigateToHome();
    } on ApiException catch (e) {
      // 409 means the backend already has a review for this sitter by this user.
      // Show a clear message and navigate to home screen.
      if (e.statusCode == 409) {
        final detailsMessage = (e.details is Map
            ? (e.details['error'] as String?)
            : null);
        CustomSnackbar.showWarning(
          title: 'review_already_reviewed_title'.tr,
          message: detailsMessage?.trim().isNotEmpty == true
              ? detailsMessage!.trim()
              : e.message,
        );
        // Navigate to home screen even if already reviewed
        _navigateToHome();
      } else {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'review_submit_failed'.tr,
        );
      }
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'review_submit_failed'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
