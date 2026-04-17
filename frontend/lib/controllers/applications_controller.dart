import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class ApplicationsController extends GetxController {
  ApplicationsController({OwnerRepository? ownerRepository})
    : _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final OwnerRepository _ownerRepository;

  final RxList<ApplicationModel> applications = <ApplicationModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadApplications();
  }

  Future<void> loadApplications() async {
    isLoading.value = true;

    try {
      final applicationsList = await _ownerRepository.getMyApplications();
      applications.assignAll(applicationsList);
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load applications', error: error.message);
      applications.clear();
    } catch (error) {
      AppLogger.logError('Failed to load applications', error: error);
      applications.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> respondToApplication({
    required String applicationId,
    required String action, // 'accept' or 'reject'
  }) async {
    final result = await respondToApplicationFull(
      applicationId: applicationId,
      action: action,
    );
    return result != null;
  }

  /// Richer variant used by the one-tap accept-and-pay flow.
  /// Returns the raw backend response on success (so the caller can inspect the
  /// `booking` + `payment` fields to open Stripe PaymentSheet directly) or
  /// null on failure.
  Future<Map<String, dynamic>?> respondToApplicationFull({
    required String applicationId,
    required String action, // 'accept' or 'reject'
  }) async {
    try {
      final response = await _ownerRepository.respondToApplication(
        applicationId: applicationId,
        action: action,
      );

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: action == 'accept'
            ? 'application_accept_success'.tr
            : 'application_reject_success'.tr,
      );

      // Refresh the applications list
      await loadApplications();
      return response;
    } on ApiException catch (error) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: error.message);
      return null;
    } catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'application_action_failed'.tr,
      );
      return null;
    }
  }
}
