import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class ChangePasswordController extends GetxController {
  final String userType;

  ChangePasswordController({required this.userType});

  final formKey = GlobalKey<FormState>();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final RxBool isLoading = false.obs;

  late final AuthRepository _authRepository;
  late final SitterRepository? _sitterRepository;

  @override
  void onInit() {
    super.onInit();
    _authRepository = Get.find<AuthRepository>();
    if (userType == 'pet_sitter') {
      _sitterRepository = Get.find<SitterRepository>();
    } else {
      _sitterRepository = null;
    }
  }

  @override
  void onClose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  String? validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> savePassword() async {
    // Validate form fields
    if (!(formKey.currentState?.validate() ?? false)) {
      CustomSnackbar.showError(
        title: 'change_password_validation_error'.tr,
        message: 'change_password_fields_required'.tr,
      );
      return;
    }

    // Check if passwords match
    if (newPasswordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      CustomSnackbar.showError(
        title: 'change_password_validation_error'.tr,
        message: 'snackbar_text_passwords_do_not_match',
      );
      return;
    }

    // Check if both fields are empty
    if (newPasswordController.text.trim().isEmpty &&
        confirmPasswordController.text.trim().isEmpty) {
      CustomSnackbar.showError(
        title: 'change_password_validation_error'.tr,
        message: 'change_password_new_required'.tr,
      );
      return;
    }

    isLoading.value = true;

    try {
      // Use SitterRepository for pet_sitter, otherwise use AuthRepository
      if (userType == 'pet_sitter' && _sitterRepository != null) {
        await _sitterRepository.changePassword(
          newPassword: newPasswordController.text.trim(),
          confirmPassword: confirmPasswordController.text.trim(),
        );
      } else {
        await _authRepository.changePassword(
          newPassword: newPasswordController.text.trim(),
          confirmPassword: confirmPasswordController.text.trim(),
        );
      }

      // Clear fields after successful save
      newPasswordController.clear();
      confirmPasswordController.clear();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'change_password_success'.tr,
      );

      // Navigate back after a short delay to ensure snackbar is visible
      await Future.delayed(const Duration(milliseconds: 500));
      Get.back();
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'change_password_failed'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
