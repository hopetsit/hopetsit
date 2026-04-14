import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/auth/login_screen.dart';

/// Handles the forgot password flow including email verification, OTP verification, and password reset.
class ForgotPasswordController extends GetxController {
  ForgotPasswordController(this._authRepository);

  final AuthRepository _authRepository;

  // Form controllers and validators
  // Removed shared formKey to prevent GlobalKey conflicts across screens
  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // State management
  final RxBool isLoading = false.obs;
  final RxBool isResending = false.obs;
  final RxInt countdownSeconds = 60.obs;
  final RxBool isResendEnabled = false.obs;
  final RxnString errorMessage = RxnString();
  final RxString currentEmail = ''.obs;

  bool _countdownStarted = false;

  @override
  void onClose() {
    emailController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  // ======================== Validation Methods ========================

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_email_required'.tr;
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'error_email_invalid'.tr;
    }
    return null;
  }

  String? validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_otp_required'.tr;
    }
    if (value.length != 6) {
      return 'error_otp_length'.tr;
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      return 'error_otp_numbers_only'.tr;
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_password_required'.tr;
    }
    if (value.length < 8) {
      return 'error_password_length'.tr;
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'error_password_uppercase'.tr;
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'error_password_number'.tr;
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_password_confirm_required'.tr;
    }
    if (value != newPasswordController.text) {
      return 'error_password_match'.tr;
    }
    return null;
  }

  // ======================== Step 1: Request OTP for Email ========================

  /// Requests an OTP to be sent to the user's email
  Future<bool> requestPasswordResetOTP({GlobalKey<FormState>? formKey}) async {
    if (!(formKey?.currentState?.validate() ?? false)) {
      return false;
    }

    isLoading.value = true;
    errorMessage.value = null;

    try {
      final email = emailController.text.trim();

      // Call the forgot password API endpoint
      await _authRepository.requestForgotPasswordOTP(email: email);

      currentEmail.value = email;
      isLoading.value = false;

      CustomSnackbar.showSuccess(
        title: 'forgot_password_otp_sent_title'.tr,
        message: 'forgot_password_otp_sent_message'.tr,
      );

      return true;
    } on ApiException catch (error) {
      errorMessage.value = error.message;
      isLoading.value = false;
      CustomSnackbar.showError(
        title: 'forgot_password_request_failed'.tr,
        message: error.message,
      );
      return false;
    } catch (error) {
      errorMessage.value = 'common_error_generic'.tr;
      isLoading.value = false;
      CustomSnackbar.showError(
        title: 'forgot_password_request_failed'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    }
  }

  // ======================== Step 2: Verify OTP ========================

  /// Verifies the OTP entered by the user
  Future<bool> verifyPasswordResetOTP() async {
    if (otpController.text.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'error_otp_required'.tr,
      );
      return false;
    }

    if (otpController.text.length != 6) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'error_otp_length'.tr,
      );
      return false;
    }

    isLoading.value = true;
    errorMessage.value = null;

    try {
      await _authRepository.verifyForgotPasswordOTP(
        email: currentEmail.value,
        otp: otpController.text,
      );

      isLoading.value = false;

      CustomSnackbar.showSuccess(
        title: 'forgot_password_verified_title'.tr,
        message: 'forgot_password_verified_message'.tr,
      );

      return true;
    } on ApiException catch (error) {
      errorMessage.value = error.message;
      isLoading.value = false;
      CustomSnackbar.showError(
        title: 'forgot_password_verification_failed'.tr,
        message: error.message,
      );
      return false;
    } catch (error) {
      errorMessage.value = 'common_error_generic'.tr;
      isLoading.value = false;
      CustomSnackbar.showError(
        title: 'forgot_password_verification_failed'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    }
  }

  // ======================== Step 3: Reset Password ========================

  /// Resets the user's password
  Future<bool> resetPassword({GlobalKey<FormState>? formKey}) async {
    if (!(formKey?.currentState?.validate() ?? false)) {
      return false;
    }

    isLoading.value = true;
    errorMessage.value = null;

    try {
      await _authRepository.resetPassword(
        email: currentEmail.value,
        otp: otpController.text,
        newPassword: newPasswordController.text,
        confirmPassword: confirmPasswordController.text,
      );

      isLoading.value = false;

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'forgot_password_reset_success'.tr,
      );

      return true;
    } on ApiException catch (error) {
      errorMessage.value = error.message;
      isLoading.value = false;
      CustomSnackbar.showError(
        title: 'forgot_password_reset_failed'.tr,
        message: error.message,
      );
      return false;
    } catch (error) {
      errorMessage.value = 'common_error_generic'.tr;
      isLoading.value = false;
      CustomSnackbar.showError(
        title: 'forgot_password_reset_failed'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    }
  }

  // ======================== OTP Countdown Timer ========================

  void startCountdown() {
    if (_countdownStarted && countdownSeconds.value != 60) return;
    _countdownStarted = true;
    countdownSeconds.value = 60;
    isResendEnabled.value = false;
    _runCountdown();
  }

  void _runCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (countdownSeconds.value > 0) {
        countdownSeconds.value--;
        _runCountdown();
      } else {
        isResendEnabled.value = true;
      }
    });
  }

  /// Resends the OTP to the user's email
  Future<void> resendOTP() async {
    if (isResending.value) return;

    isResending.value = true;

    try {
      await _authRepository.requestForgotPasswordOTP(email: currentEmail.value);

      // Reset countdown after successful API call
      _countdownStarted = false;
      startCountdown();

      CustomSnackbar.showSuccess(
        title: 'forgot_password_code_resent_title'.tr,
        message: 'forgot_password_code_resent_message'.tr,
      );
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'forgot_password_resend_failed'.tr,
        message: error.message,
      );
    } catch (error) {
      CustomSnackbar.showError(
        title: 'forgot_password_resend_failed'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      isResending.value = false;
    }
  }

  // ======================== Navigation Helpers ========================

  /// Navigates back to login screen
  void backToLogin() {
    Get.offAll(() => const LoginScreen());
  }

  /// Resets the controller state
  void resetFlow() {
    emailController.clear();
    otpController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    currentEmail.value = '';
    errorMessage.value = null;
    isLoading.value = false;
    _countdownStarted = false;
  }
}
