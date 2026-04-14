import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/auth/choose_service_screen.dart';

class EmailVerificationController extends GetxController {
  final String email;
  final String userType;

  EmailVerificationController({required this.email, required this.userType});

  final pinController = TextEditingController();
  final RxInt countdownSeconds = 60.obs;
  final RxBool isResendEnabled = false.obs;
  bool _countdownStarted = false;

  @override
  void onInit() {
    super.onInit();
    startCountdown();
  }

  @override
  void onClose() {
    pinController.dispose();
    super.onClose();
  }

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

  void resendCode() {
    _countdownStarted = false;
    startCountdown();

    // Add your resend logic here
    CustomSnackbar.showSuccess(
      title: 'common_success'.tr,
      message: 'snackbar_text_verification_code_resent',
    );
  }

  bool verifyCode() {
    if (pinController.text.length == 4) {
      // Add your verification logic here
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'email_verification_success'.tr,
      );
      return true;
    } else {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'email_verification_code_required'.tr,
      );
      return false;
    }
  }

  String getMaskedEmail() {
    if (email.length <= 10) return email;
    final start = email.substring(0, 2);
    final end = email.substring(email.length - 10);
    return '$start****$end';
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Reset verification state (call when going back or leaving screen)
  void resetVerificationState() {
    pinController.clear();
    _countdownStarted = false;
    countdownSeconds.value = 60;
    isResendEnabled.value = false;
  }

  /// Restart countdown (call when returning to screen)
  void restartCountdown() {
    _countdownStarted = false;
    startCountdown();
  }

  /// Handles verification with navigation logic
  void handleVerificationWithNavigation() {
    if (verifyCode()) {
      // Clear OTP state before navigating
      resetVerificationState();

      // Navigate to Choose Service screen (controllers will be cleaned up later)
      Get.off(() => ChooseServiceScreen(userType: userType, email: email));
    }
  }
}
