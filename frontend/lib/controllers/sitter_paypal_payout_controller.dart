import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class SitterPayPalPayoutController extends GetxController {
  SitterPayPalPayoutController({SitterRepository? sitterRepository})
    : _sitterRepository = sitterRepository ?? Get.find<SitterRepository>();

  final SitterRepository _sitterRepository;
  final GetStorage _storage = Get.find<GetStorage>();

  final RxBool isSaving = false.obs;
  final RxString paypalEmail = ''.obs;

  final TextEditingController emailController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _loadFromProfile();
  }

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }

  Future<void> savePayPalEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error',
        message: 'snackbar_sitter_paypal_payout_controller_001',
      );
      return;
    }

    if (isSaving.value) return;
    isSaving.value = true;

    try {
      await _sitterRepository.updatePayPalPayoutEmail(paypalEmail: email);
      await _refreshPayPalEmailFromApi(fallbackEmail: email);

      CustomSnackbar.showSuccess(
        title: 'common_success',
        message: 'snackbar_sitter_paypal_payout_controller_002',
      );
    } on ApiException catch (e) {
      AppLogger.logError('Update PayPal email failed', error: e.message);
      CustomSnackbar.showError(
        title: 'common_error',
        message: 'snackbar_sitter_paypal_payout_controller_003',
      );
    } catch (e) {
      AppLogger.logError('Update PayPal email failed', error: e);
      CustomSnackbar.showError(
        title: 'common_error',
        message: 'snackbar_sitter_paypal_payout_controller_003',
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _loadFromProfile() async {
    try {
      // 1) Source of truth: dedicated payout endpoint.
      final loadedFromApi = await _refreshPayPalEmailFromApi();
      if (loadedFromApi) return;

      // 1) Use cached user profile from latest login (AuthController saves this)
      String? email;
      final cached = _storage.read(StorageKeys.userProfile);
      if (cached is Map && cached['paypalEmail'] is String) {
        email = (cached['paypalEmail'] as String).trim();
      }

      // 2) If still empty, fetch from backend sitter profile
      if (email == null || email.isEmpty) {
        final profile = await _sitterRepository.getMySitterProfile();
        // Depending on backend shape, paypalEmail may be at root or nested
        email =
            (profile['paypalEmail'] as String?)?.trim() ??
            (profile['sitter'] is Map
                ? (profile['sitter']['paypalEmail'] as String?)?.trim()
                : null);
      }

      if (email != null && email.isNotEmpty) {
        paypalEmail.value = email;
      }
    } catch (e) {
      AppLogger.logError('Failed to load sitter PayPal email', error: e);
    }
  }

  Future<bool> _refreshPayPalEmailFromApi({String? fallbackEmail}) async {
    try {
      final response = await _sitterRepository.getPayPalPayoutEmail();

      final resolved =
          (response['paypalEmail'] as String?)?.trim() ??
          (response['email'] as String?)?.trim() ??
          (response['data'] is Map
              ? (response['data']['paypalEmail'] as String?)?.trim()
              : null) ??
          (response['sitter'] is Map
              ? (response['sitter']['paypalEmail'] as String?)?.trim()
              : null) ??
          fallbackEmail;

      if (resolved != null && resolved.isNotEmpty) {
        paypalEmail.value = resolved;
        return true;
      }
    } catch (e) {
      AppLogger.logError('Failed to refresh PayPal email from API', error: e);
      if (fallbackEmail != null && fallbackEmail.isNotEmpty) {
        paypalEmail.value = fallbackEmail;
        return true;
      }
    }
    return false;
  }
}
