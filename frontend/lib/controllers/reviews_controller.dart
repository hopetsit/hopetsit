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

  // v23.1.290 — mode édition : si l'owner a déjà un avis pour ce booking, on
  // pré-remplit l'écran et on bascule sur PUT (au lieu de POST), avec la
  // possibilité de supprimer.
  final RxBool isEditing = false.obs;
  String? _reviewId;

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
    String? bookingId,
    String? revieweeRole,
  }) async {
    if (!canSubmit) return;

    isLoading.value = true;

    try {
      if (isEditing.value && _reviewId != null) {
        // v23.1.290 — édition d'un avis existant → PUT.
        await _ownerRepository.updateReview(
          reviewId: _reviewId!,
          rating: rating.value.toDouble(),
          comment: description.value.trim(),
        );
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'reviews_updated_success'.tr,
        );
      } else {
        await _ownerRepository.submitReview(
          revieweeId: serviceProviderId,
          rating: rating.value.toDouble(),
          comment: description.value.trim(),
          bookingId: bookingId,
          revieweeRole: revieweeRole,
        );
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'snackbar_text_review_submitted_successfully',
        );
      }

      // Reset form
      rating.value = 0;
      description.value = '';

      // Navigate to home screen
      _navigateToHome();
    } on ApiException catch (e) {
      // v18.6 — surface le vrai message backend au lieu du générique
      // "Impossible d'envoyer l'avis". Le backend renvoie par ex. :
      // "A completed booking between you and this user is required..."
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
        _navigateToHome();
      } else {
        final detailsMessage = (e.details is Map
            ? (e.details['error'] as String?)
            : null);
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: detailsMessage?.trim().isNotEmpty == true
              ? detailsMessage!.trim()
              : (e.message.isNotEmpty ? e.message : 'review_submit_failed'.tr),
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

  /// v23.1.290 — au montage de l'écran : charge l'avis existant de l'owner pour
  /// ce booking. S'il existe → mode édition + pré-remplissage note/commentaire.
  Future<void> loadExistingReview(String? bookingId) async {
    isEditing.value = false;
    _reviewId = null;
    try {
      final existing = await _ownerRepository.getMyReview(bookingId: bookingId);
      if (existing != null) {
        _reviewId = (existing['id'] ?? existing['_id'])?.toString();
        if (_reviewId != null && _reviewId!.isNotEmpty) {
          isEditing.value = true;
          final r = existing['rating'];
          rating.value = r is num ? r.round() : (int.tryParse('$r') ?? 0);
          description.value = (existing['comment'] ?? '').toString();
        }
      }
    } catch (_) {
      // Silencieux : en cas d'échec on reste en mode création.
    }
  }

  /// v23.1.290 — supprime l'avis existant (mode édition uniquement).
  Future<void> deleteReview() async {
    if (_reviewId == null || _reviewId!.isEmpty) return;
    isLoading.value = true;
    try {
      await _ownerRepository.deleteReview(reviewId: _reviewId!);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'reviews_deleted_success'.tr,
      );
      rating.value = 0;
      description.value = '';
      isEditing.value = false;
      _reviewId = null;
      _navigateToHome();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'review_delete_failed'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
