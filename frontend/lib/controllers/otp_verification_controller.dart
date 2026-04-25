import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/auth/choose_service_screen.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart';

enum VerificationType { signup, login }

class OtpVerificationController extends GetxController {
  final String email;
  final VerificationType verificationType;
  final String? userType; // Only needed for signup
  final AuthRepository _authRepository;
  final GetStorage _storage = GetStorage();

  OtpVerificationController({
    required this.email,
    required this.verificationType,
    this.userType,
    AuthRepository? authRepository,
  }) : _authRepository = authRepository ?? Get.find<AuthRepository>();

  final pinController = TextEditingController();

  // Individual digit controllers for custom text fields
  final List<TextEditingController> digitControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  // Focus nodes for each digit field
  final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());

  final RxInt countdownSeconds = 60.obs;
  final RxBool isResendEnabled = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isResending = false.obs;
  bool _countdownStarted = false;

  @override
  void onInit() {
    super.onInit();
    startCountdown();
  }

  @override
  void onClose() {
    // Dispose individual controllers and focus nodes
    for (final controller in digitControllers) {
      controller.dispose();
    }
    for (final node in focusNodes) {
      node.dispose();
    }
    pinController.dispose();
    super.onClose();
  }

  /// Handles input changes for individual digit fields
  void onDigitChanged(String value, int index) {
    // Update the digit controller
    digitControllers[index].text = value;

    // Update the combined PIN
    _updateCombinedPin();

    // Auto-focus next field if a digit was entered
    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    }

    // Auto-verify if all digits are filled
    if (_isCompletePin()) {
      handleVerificationWithNavigation();
    }
  }

  /// Handles backspace for individual digit fields
  void onDigitBackspace(int index) {
    // If current field is empty and not the first field, move to previous
    if (digitControllers[index].text.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
  }

  /// Updates the combined PIN from individual digit controllers
  void _updateCombinedPin() {
    final combined = digitControllers
        .map((controller) => controller.text)
        .join();
    pinController.text = combined;
  }

  /// Checks if all digit fields have values
  bool _isCompletePin() {
    return digitControllers.every((controller) => controller.text.isNotEmpty);
  }

  /// Resets all digit fields
  void resetDigits() {
    for (final controller in digitControllers) {
      controller.clear();
    }
    focusNodes[0].requestFocus();
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

  Future<void> resendCode() async {
    if (isResending.value) return;

    isResending.value = true;

    try {
      await _authRepository.resendVerificationCode(email: email);

      // Only restart countdown after successful API call
      _countdownStarted = false;
      startCountdown();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_verification_code_has_been_resent_to_your_email',
      );
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      isResending.value = false;
    }
  }

  Future<bool> verifyCode() async {
    if (pinController.text.length != 6) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'email_verification_code_required'.tr,
      );
      return false;
    }

    isLoading.value = true;

    try {
      final response = await _authRepository.verifyCode(
        email: email,
        code: pinController.text,
      );

      // Persist token returned by /auth/verify so subsequent
      // authenticated requests can use it.
      final token = response['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await _storage.write(StorageKeys.authToken, token);
      }

      // Persist user profile and role so SitterProfileController, SitterChatController, etc.
      // can resolve userId/sitterId and avoid redirecting to login.
      final userData = response['user'];
      final role = response['role'] as String?;
      if (userData != null && userData is Map<String, dynamic>) {
        final userProfile = Map<String, dynamic>.from(userData);
        if (role != null &&
            role.isNotEmpty &&
            !userProfile.containsKey('role')) {
          userProfile['role'] = role;
        }
        await _storage.write(StorageKeys.userProfile, userProfile);
      }
      if (role != null && role.isNotEmpty) {
        await _storage.write(StorageKeys.userRole, role);
      }

      // Sync AuthController's userRole so navigation and session stay consistent
      if (Get.isRegistered<AuthController>()) {
        Get.find<AuthController>().userRole.value = role;
      }

      // v20.2.1 — bug fix : si une photo de profil a été sélectionnée pendant
      // l'inscription, on l'upload maintenant que /auth/verify a renvoyé un
      // token (donc /users/me/profile-picture peut être appelé authentifié).
      // Fire-and-forget : on ne bloque pas la nav si l'upload rate ; on log
      // simplement et on garde le path pour qu'un nouvel essai puisse se
      // faire la prochaine fois (ou que l'user le re-uploade depuis profil).
      // ignore: discarded_futures
      _uploadPendingSignupPhotoIfAny();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'email_verification_success'.tr,
      );
      return true;
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
      return false;
    } catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// v20.2.1 — Reads the pending profile-photo path persisted by
  /// SignUpController (see signup_controller.dart) and uploads it now that
  /// /auth/verify has returned an auth token. Best-effort : never throws,
  /// only logs failures so the OTP flow continues uninterrupted.
  Future<void> _uploadPendingSignupPhotoIfAny() async {
    try {
      final path = (_storage.read(StorageKeys.pendingSignupPhotoPath) ?? '')
          .toString()
          .trim();
      if (path.isEmpty) return;
      final file = File(path);
      if (!file.existsSync()) {
        await _storage.remove(StorageKeys.pendingSignupPhotoPath);
        return;
      }
      // Resolve UserRepository via GetIt-style lookup. At this stage the
      // dependency injection container should already have it registered
      // (it's set up at app boot in helper/dependency_injection.dart).
      // If not, fall back to constructing one with a fresh ApiClient.
      final UserRepository repo = Get.isRegistered<UserRepository>()
          ? Get.find<UserRepository>()
          : UserRepository(Get.find());
      await repo.updateProfilePicture(file);
      await _storage.remove(StorageKeys.pendingSignupPhotoPath);
      AppLogger.logInfo('[otp] post-signup profile photo uploaded OK');
    } catch (e) {
      AppLogger.logError(
        '[otp] failed to upload post-signup profile photo (will retry next session)',
        error: e,
      );
      // Don't clear the storage key on failure — leave it so a future
      // session can retry, OR the user can re-upload from profile screen
      // and that path overrides this one.
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
    resetDigits();
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
  Future<void> handleVerificationWithNavigation() async {
    final success = await verifyCode();

    if (success) {
      // Clear OTP state before navigating
      resetVerificationState();

      // Navigate based on verification type
      if (verificationType == VerificationType.signup) {
        // For signup, navigate to Choose Service screen
        if (userType != null) {
          Get.off(() => ChooseServiceScreen(userType: userType!, email: email));
        }
      } else {
        // For login, automatically retry login after email verification
        await _retryLoginAfterVerification();
      }
    }
  }

  /// Retries login after successful email verification
  Future<void> _retryLoginAfterVerification() async {
    try {
      // Get the AuthController to retry login
      if (!Get.isRegistered<AuthController>()) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'snackbar_text_please_try_logging_in_again',
        );
        Get.back();
        return;
      }

      final authController = Get.find<AuthController>();

      // Add a small delay to ensure the verification success snackbar is visible
      await Future.delayed(const Duration(milliseconds: 800));

      // Retry login
      final loginSuccess = await authController.login();

      if (loginSuccess) {
        // Get the user role to navigate appropriately
        final role = authController.userRole.value;

        // v19.1.5 — Navigate based on user role. Walker was falling through
        // the else branch (→ "unknown user role" or stale Sitter screen);
        // now routed explicitly to the dedicated Walker wrapper.
        if (role == 'owner') {
          Get.offAll(() => const BottomNavWrapper());
        } else if (role == 'sitter') {
          Get.offAll(() => const SitterNavWrapper());
        } else if (role == 'walker') {
          Get.offAll(() => const WalkerNavWrapper());
        } else {
          // Fallback: go back to login if role is not recognized
          Get.back();
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: 'snackbar_text_unknown_user_role_please_try_again',
          );
          return;
        }

        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'snackbar_text_welcome_back',
        );
      } else {
        // Login failed even after verification
        Get.back();
        final errorMessage =
            authController.errorMessage.value ??
            'Login failed. Please try again.';
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: errorMessage,
        );
      }
    } catch (error) {
      Get.back();
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'snackbar_text_something_went_wrong_please_try_logging_in_again',
      );
    }
  }
}
