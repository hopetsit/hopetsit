import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/utils/app_constants.dart';
import 'package:flutter/scheduler.dart';
import 'package:hopetsit/controllers/home_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/controllers/user_controller.dart';
import 'package:hopetsit/controllers/choose_service_controller.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/otp_verification_screen.dart';
import 'package:hopetsit/views/auth/choose_service_screen.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/controllers/otp_verification_controller.dart';
import 'package:hopetsit/widgets/paypal_email_dialog.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart';

/// Controller handling user authentication flows.
class AuthController extends GetxController {
  AuthController(
    this._authRepository,
    this._storage, [
    UserRepository? userRepository,
  ]) : _userRepository = userRepository;

  final AuthRepository _authRepository;
  final GetStorage _storage;
  final UserRepository? _userRepository;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RxBool isSocialLoginLoading = false.obs;

  GoogleSignInAccount? _user;
  late GoogleSignIn _googleSignIn;

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isSwitchingRole = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool requiresEmailVerification = false.obs;
  final RxnString userRole = RxnString();
  bool _isShowingPayPalPrompt = false;

  @override
  void onInit() {
    super.onInit();
    // Load role from storage on initialization
    final storedRole = _storage.read<String>(StorageKeys.userRole);
    _initializeGoogleSignIn();
    if (storedRole != null && storedRole.isNotEmpty) {
      userRole.value = storedRole;
      debugPrint(
        '[HOPETSIT] ✅ AuthController initialized with role: $storedRole',
      );
    } else {
      debugPrint(
        '[HOPETSIT] ⚠️ No role found in storage during AuthController initialization',
      );
    }
  }

  @override
  void onClose() {
    // Don't dispose controllers here - they should persist during auth flow
    // Since AuthController is permanent, controllers will persist across navigation
    // They will only be cleared (not disposed) in logout() method
    super.onClose();
  }

  Future<bool> login() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return false;
    }

    isLoading.value = true;
    errorMessage.value = null;

    try {
      final response = await _authRepository.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final token = _extractToken(response);
      if (token == null) {
        throw ApiException(
          'Token missing in login response.',
          details: response,
        );
      }

      // Save token
      await _storage.write(StorageKeys.authToken, token);
      final tokenPreview = token.length > 20
          ? '${token.substring(0, 20)}...'
          : token;
      debugPrint('[HOPETSIT] ✅ Token saved: $tokenPreview');

      // Extract role from response
      final role = _extractRole(response);
      userRole.value = role;

      // Save role separately for easy access
      if (role != null) {
        await _storage.write(StorageKeys.userRole, role);
        debugPrint('[HOPETSIT] ✅ Role saved: $role');
      } else {
        debugPrint('[HOPETSIT] ⚠️ Role not found in response');
      }

      // Extract and save user data
      final userData = _extractUser(response);
      if (userData != null) {
        // Add role to user data if not already present
        final userDataWithRole = Map<String, dynamic>.from(userData);
        if (role != null && !userDataWithRole.containsKey('role')) {
          userDataWithRole['role'] = role;
        }
        await _storage.write(StorageKeys.userProfile, userDataWithRole);
        debugPrint('[HOPETSIT] ✅ User profile saved:');
        debugPrint('[HOPETSIT]   - Name: ${userDataWithRole['name'] ?? 'N/A'}');
        debugPrint(
          '[HOPETSIT]   - Email: ${userDataWithRole['email'] ?? 'N/A'}',
        );
        debugPrint(
          '[HOPETSIT]   - Mobile: ${userDataWithRole['mobile'] ?? 'N/A'}',
        );
        debugPrint(
          '[HOPETSIT]   - Address: ${userDataWithRole['address'] ?? 'N/A'}',
        );
        debugPrint(
          '[HOPETSIT]   - Verified: ${userDataWithRole['verified'] ?? 'N/A'}',
        );
        debugPrint('[HOPETSIT]   - Role: ${userDataWithRole['role'] ?? 'N/A'}');
        debugPrint('[HOPETSIT]   - ID: ${userDataWithRole['id'] ?? 'N/A'}');
      } else {
        debugPrint('[HOPETSIT] ⚠️ User data not found in response');
      }

      return true;
    } on ApiException catch (error) {
      // Extract message from error details if available
      // API may return both "error" and "message" fields, prefer "message" when available
      String extractedMessage = error.message;
      if (error.details is Map<String, dynamic>) {
        final details = error.details as Map<String, dynamic>;
        if (details.containsKey('message') && details['message'] is String) {
          extractedMessage = details['message'] as String;
        }
      }

      errorMessage.value = extractedMessage;

      // Check if the error is about email verification
      // Check both the error message and status code (403 = Forbidden, often used for unverified accounts)
      final isEmailVerificationError =
          error.message.toLowerCase().contains('email not verified') ||
          error.message.toLowerCase().contains('please verify your account') ||
          error.statusCode == 403;

      requiresEmailVerification.value = isEmailVerificationError;

      if (isEmailVerificationError) {
        debugPrint(
          '[HOPETSIT] Email verification required. Status: ${error.statusCode}, Message: $extractedMessage',
        );
      }

      return false;
    } catch (error) {
      errorMessage.value = error.toString();
      requiresEmailVerification.value = false;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    _googleSignIn = GoogleSignIn.instance;

    // Use the correct client IDs from Firebase configuration
    await _googleSignIn.initialize(
      clientId: Platform.isIOS
          ? "470089536255-sedqnlp3c54m3jv0g21mcoq7a23i6487.apps.googleusercontent.com"
          : "470089536255-q9nrquiekrp6vmjdua2gio42r19fsrd4.apps.googleusercontent.com",
      serverClientId: Platform.isIOS
          ? "470089536255-sedqnlp3c54m3jv0g21mcoq7a23i6487.apps.googleusercontent.com"
          : "470089536255-q9nrquiekrp6vmjdua2gio42r19fsrd4.apps.googleusercontent.com",
    );

    // Listen to authentication events
    _googleSignIn.authenticationEvents.listen((event) {
      _user = switch (event) {
        GoogleSignInAuthenticationEventSignIn() => event.user,
        GoogleSignInAuthenticationEventSignOut() => null,
      };
      update();
    });
  }

  /// [role] When provided (e.g. from sign up screen), sends this role to the backend
  /// for new user creation. Use 'owner' or 'sitter'. If null, uses stored userRole.
  Future<void> loginWithGoogle({String? role}) async {
    try {
      isSocialLoginLoading.value = true;
      // For new users (e.g. signing up), use the provided role; otherwise use stored role
      final roleToSend = role ?? userRole.value;
      debugPrint(
        '[HOPETSIT] Google sign-in: role parameter=$role, roleToSend=$roleToSend',
      );
      if (role != null) {
        userRole.value = role;
      }
      if (_googleSignIn.supportsAuthenticate()) {
        await _googleSignIn.authenticate(scopeHint: ['email']);
      } else {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_web_required',
        );
        return;
      }

      // Wait briefly to ensure authenticationEvents listener populates _user
      await Future.delayed(Duration(milliseconds: 200));
      if (_user == null) {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_failed',
        );
        return;
      }
      final googleAuth = _user!.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_token_missing',
        );
        return;
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      log(' [HOPETSIT] 🔐 Signing in with Google credential');
      await _auth.signInWithCredential(credential);

      // Backend requires Firebase ID token (JWT). Force refresh to get a fresh token.
      final firebaseUser = _auth.currentUser;
      final String? firebaseIdToken = await firebaseUser?.getIdToken(true);

      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_firebase_token_failed',
        );
        return;
      }

      // Send Firebase ID token (and optional role for new users) to backend
      final response = await _authRepository.googleSignInWithIdToken(
        idToken: firebaseIdToken,
        role: roleToSend ?? 'sitter',
      );

      // Backend may return success with token/role/user without a "success" key
      final backendToken = _extractToken(response);
      final isSuccess =
          (response["success"] == true) ||
          (backendToken != null && backendToken.isNotEmpty);

      if (isSuccess && backendToken != null) {
        await _storage.write(StorageKeys.authToken, backendToken);
        debugPrint('[HOPETSIT] ✅ Token saved from Google sign-in');

        final role = _extractRole(response);
        userRole.value = role;
        if (role != null) {
          await _storage.write(StorageKeys.userRole, role);
        }

        final userData = _extractUser(response);
        if (userData != null) {
          final userDataWithRole = Map<String, dynamic>.from(userData);
          if (role != null && !userDataWithRole.containsKey('role')) {
            userDataWithRole['role'] = role;
          }
          await _storage.write(StorageKeys.userProfile, userDataWithRole);
        }

        // Check if this is a new user (existingUser: false)
        final existingUser = response['existingUser'] as bool? ?? true;
        debugPrint(
          '[HOPETSIT] Google sign-in: existingUser=$existingUser, role=$role',
        );

        if (!existingUser) {
          // New user - navigate to choose service screen
          final email =
              userData?['email']?.toString() ??
              response['email']?.toString() ??
              firebaseUser?.email ??
              '';

          if (email.isNotEmpty && role != null) {
            // Map role to userType format
            final userType = role == 'owner' ? 'pet_owner' : 'pet_sitter';

            debugPrint(
              '[HOPETSIT] Navigating new Google user to ChooseServiceScreen: email=$email, userType=$userType',
            );

            CustomSnackbar.showSuccess(
              title: 'auth_google_signin_title',
              message: 'auth_google_signin_choose_services',
            );

            Get.offAll(
              () => ChooseServiceScreen(
                userType: userType,
                email: email,
                isFromProfile: false,
              ),
            );
          } else {
            debugPrint(
              '[HOPETSIT] ⚠️ Missing email or role for new user navigation',
            );
            _navigateToHome();
          }
        } else {
          // Existing user - navigate to home
          CustomSnackbar.showSuccess(
            title: 'auth_google_signin_title',
            message: 'auth_google_signin_success',
          );
          _navigateToHome();
        }
      } else {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_failed',
        );
      }
    } catch (e) {
      print("Google Login Error: $e");
      CustomSnackbar.showError(
        title: 'auth_google_signin_title',
        message: 'common_error_generic',
      );
    } finally {
      isSocialLoginLoading.value = false;
    }
  }

  /// [role] When provided (e.g. from sign up screen), sends this role to the backend
  /// for new user creation. Use 'owner' or 'sitter'. If null, uses stored userRole.
  /// Implemented exactly like loginWithGoogle.
  Future<void> loginWithApple({String? role}) async {
    try {
      isSocialLoginLoading.value = true;
      final roleToSend = role ?? userRole.value;
      if (role != null) {
        userRole.value = role;
      }

      final AuthorizationResult result = await TheAppleSignIn.performRequests([
        const AppleIdRequest(requestedScopes: [Scope.email, Scope.fullName]),
      ]);

      if (result.status != AuthorizationStatus.authorized) {
        if (result.status == AuthorizationStatus.cancelled) {
          return;
        }
        throw ApiException(
          result.status == AuthorizationStatus.error
              ? 'Apple sign in failed: ${result.error?.localizedDescription}'
              : 'Apple sign in was cancelled.',
        );
      }

      final AppleIdCredential credential = result.credential!;
      final AuthCredential authCredential = OAuthProvider('apple.com')
          .credential(
            idToken: String.fromCharCodes(credential.identityToken!),
            accessToken: String.fromCharCodes(credential.authorizationCode!),
          );

      await _auth.signInWithCredential(authCredential);

      final firebaseUser = _auth.currentUser;
      final String? firebaseIdToken = await firebaseUser?.getIdToken(true);

      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        CustomSnackbar.showError(
          title: 'auth_apple_signin_failed',
          message: 'auth_google_signin_firebase_token_failed',
        );
        return;
      }

      final response = await _authRepository.appleSignInWithIdToken(
        idToken: firebaseIdToken,
        role: roleToSend ?? 'sitter',
      );

      final backendToken = _extractToken(response);
      final isSuccess =
          (response['success'] == true) ||
          (backendToken != null && backendToken.isNotEmpty);

      if (isSuccess && backendToken != null) {
        await _storage.write(StorageKeys.authToken, backendToken);

        final role = _extractRole(response);
        userRole.value = role;
        if (role != null) {
          await _storage.write(StorageKeys.userRole, role);
        }

        final userData = _extractUser(response);
        if (userData != null) {
          final userDataWithRole = Map<String, dynamic>.from(userData);
          if (role != null && !userDataWithRole.containsKey('role')) {
            userDataWithRole['role'] = role;
          }
          await _storage.write(StorageKeys.userProfile, userDataWithRole);
        }

        final existingUser = response['existingUser'] as bool? ?? true;

        if (!existingUser) {
          final email =
              userData?['email']?.toString() ??
              response['email']?.toString() ??
              firebaseUser?.email ??
              '';

          if (email.isNotEmpty && role != null) {
            final userType = role == 'owner' ? 'pet_owner' : 'pet_sitter';

            CustomSnackbar.showSuccess(
              title: 'common_success',
              message: 'auth_google_signin_choose_services',
            );

            Get.offAll(
              () => ChooseServiceScreen(
                userType: userType,
                email: email,
                isFromProfile: false,
              ),
            );
          } else {
            _navigateToHome();
          }
        } else {
          CustomSnackbar.showSuccess(
            title: 'common_success',
            message: 'auth_apple_signin_success',
          );
          _navigateToHome();
        }
      } else {
        CustomSnackbar.showError(
          title: 'auth_apple_signin_failed',
          message: 'auth_apple_signin_failed_generic',
        );
      }
    } on ApiException {
      CustomSnackbar.showError(
        title: 'auth_apple_signin_failed',
        message: 'auth_apple_signin_failed_generic',
      );
    } catch (e) {
      CustomSnackbar.showError(
        title: 'auth_apple_signin_failed',
        message: 'common_error_generic',
      );
    } finally {
      isSocialLoginLoading.value = false;
    }
  }

  /// Navigates to the appropriate home screen based on user role
  void _navigateToHome() {
    final role = userRole.value;
    if (role == 'owner') {
      Get.offAll(() => const BottomNavWrapper());
    } else if (role == 'sitter') {
      Get.offAll(() => const SitterNavWrapper());
    } else {
      // Fallback: go back if role is not recognized
      Get.back();
    }
  }

  String? _extractToken(Map<String, dynamic> response) {
    final token =
        response['token'] ??
        response['accessToken'] ??
        response['access_token'] ??
        response['data']?['token'] ??
        response['data']?['accessToken'] ??
        response['data']?['access_token'];

    if (token is String && token.isNotEmpty) {
      return token;
    }
    return null;
  }

  Map<String, dynamic>? _extractUser(Map<String, dynamic> response) {
    final user =
        response['user'] ??
        response['profile'] ??
        response['data']?['user'] ??
        response['data']?['profile'];
    if (user is Map<String, dynamic>) {
      return user;
    }
    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }
    return null;
  }

  String? _extractRole(Map<String, dynamic> response) {
    // Check for role in various possible locations
    final role =
        response['role'] ??
        response['data']?['role'] ??
        response['user']?['role'] ??
        response['data']?['user']?['role'];

    if (role is String && role.isNotEmpty) {
      return role.toLowerCase(); // Normalize to lowercase
    }
    return null;
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'error_email_required'.tr;
    }
    if (!GetUtils.isEmail(email)) {
      return 'error_email_invalid'.tr;
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
    return null;
  }

  /// Handles login with navigation logic
  Future<void> handleLoginWithNavigation() async {
    final success = await login();

    if (success) {
      // Navigate based on user role
      _navigateToHome();

      CustomSnackbar.showSuccess(
        title: 'common_success',
        message: 'auth_welcome_back',
      );
    } else {
      // Check if email verification is required
      if (requiresEmailVerification.value) {
        final displayMessage =
            errorMessage.value ??
            'Email not verified. Please verify your account.';

        // Check if the message indicates a new code was sent
        final isNewCodeSent =
            displayMessage.toLowerCase().contains('new verification code') ||
            displayMessage.toLowerCase().contains(
              'verification code has been sent',
            ) ||
            displayMessage.toLowerCase().contains(
              'has been sent to your email',
            );

        if (isNewCodeSent) {
          // Show success/info message when new code is sent
          CustomSnackbar.showSuccess(
            title: 'snackbar_text_verification_code_sent',
            message: displayMessage,
          );
        } else {
          // Show error for other verification issues
          CustomSnackbar.showError(
            title: 'snackbar_text_email_not_verified',
            message: displayMessage,
          );
        }

        // Add a small delay to ensure snackbar is visible before navigating
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to OTP verification screen
        debugPrint(
          '[HOPETSIT] Navigating to OTP verification screen for email: ${emailController.text.trim()}',
        );
        Get.to(
          () => OtpVerificationScreen(
            email: emailController.text.trim(),
            verificationType: VerificationType.login,
          ),
        );
      } else {
        CustomSnackbar.showError(
          title: 'signup_failed_title',
          message: 'signup_failed_generic_message',
        );
      }
    }
  }

  /// Switches between pet owner and pet sitter roles via API.
  Future<void> switchRole() async {
    isSwitchingRole.value = true;
    final repo =
        _userRepository ??
        (Get.isRegistered<UserRepository>()
            ? Get.find<UserRepository>()
            : null);
    if (repo == null) {
      _switchRoleLocalOnly();
      isSwitchingRole.value = false;
      return;
    }

    try {
      final response = await repo.switchRole();
      final newRole = _extractRole(response);

      // Backend may return a new token with updated role claim – save it so
      // subsequent requests (e.g. GET /users/me/profile, GET /blocks) succeed.
      final newToken = _extractToken(response);
      if (newToken != null && newToken.isNotEmpty) {
        await _storage.write(StorageKeys.authToken, newToken);
        debugPrint('[HOPETSIT] ✅ New token saved after role switch');
      }

      final userData = _extractUser(response);
      if (userData != null) {
        final userDataWithRole = Map<String, dynamic>.from(userData);
        final role = newRole ?? userDataWithRole['role']?.toString();
        if (role != null && !userDataWithRole.containsKey('role')) {
          userDataWithRole['role'] = role;
        }
        await _storage.write(StorageKeys.userProfile, userDataWithRole);
        debugPrint('[HOPETSIT] ✅ User profile updated after role switch');
      }

      if (newRole == null || newRole.isEmpty) {
        // API did not return role; fallback to local toggle
        final currentRole = userRole.value;
        final toggled = currentRole == 'owner' ? 'sitter' : 'owner';
        await _storage.write(StorageKeys.userRole, toggled);
        userRole.value = toggled;
        debugPrint('[HOPETSIT] ✅ Role switched to: $toggled (local fallback)');
      } else {
        await _storage.write(StorageKeys.userRole, newRole);
        userRole.value = newRole;
        debugPrint('[HOPETSIT] ✅ Role switched to: $newRole');
      }

      CustomSnackbar.showSuccess(
        title: 'snackbar_text_role_switched',
        message: 'auth_role_switched_message'.tr.replaceAll(
          '@role',
          userRole.value == 'owner'
              ? 'auth_role_pet_owner'.tr
              : 'auth_role_pet_sitter'.tr,
        ),
      );

      _navigateToHome();
      _scheduleRefreshAfterRoleSwitch();
    } on ApiException catch (e) {
      debugPrint('[HOPETSIT] ❌ Switch role API error: ${e.message}');
      CustomSnackbar.showError(
        title: 'auth_role_switch_failed',
        message: 'auth_role_switch_failed',
      );
    } catch (e) {
      debugPrint('[HOPETSIT] ❌ Error switching role: $e');
      CustomSnackbar.showError(
        title: 'snackbar_text_switch_role_failed',
        message: 'snackbar_text_failed_to_switch_role_please_try_again',
      );
    } finally {
      isSwitchingRole.value = false;
    }
  }

  void _switchRoleLocalOnly() {
    try {
      final currentRole = userRole.value;
      final newRole = currentRole == 'owner' ? 'sitter' : 'owner';
      _storage.write(StorageKeys.userRole, newRole);
      userRole.value = newRole;
      CustomSnackbar.showSuccess(
        title: 'auth_role_switched',
        message: 'auth_role_switched_message'.tr.replaceAll(
          '@role',
          newRole == 'owner'
              ? 'auth_role_pet_owner'.tr
              : 'auth_role_pet_sitter'.tr,
        ),
      );
      _navigateToHome();
      _scheduleRefreshAfterRoleSwitch();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'snackbar_text_switch_role_failed',
        message: 'snackbar_text_failed_to_switch_role_please_try_again',
      );
    } finally {
      isSwitchingRole.value = false;
    }
  }

  /// Schedules a post-frame refresh so the new role's data is loaded (same as app startup).
  void _scheduleRefreshAfterRoleSwitch() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _refreshDataAfterRoleSwitch();
    });
  }

  /// Re-triggers startup APIs for the current role and clears the other role's cached data.
  Future<void> _refreshDataAfterRoleSwitch() async {
    final role = userRole.value;
    if (role == null) return;

    try {
      if (role == 'owner') {
        _clearSitterCachedData();
        _clearServiceSelections();
        await _refreshOwnerData();
      } else {
        _clearOwnerCachedData();
        _clearServiceSelections();
        // Keep sitter refresh and PayPal prompt checks isolated so one failure
        // does not block the other.
        try {
          await _refreshSitterData();
        } catch (e) {
          debugPrint(
            '[HOPETSIT] ⚠️ Sitter refresh failed after role switch: $e',
          );
        }

        // PayPal prompt is gated by feature flag; hidden for new sitters.
        if (AppConstants.showPayPalOption) {
          await _promptForSitterPayPalEmailIfMissing();
        }
      }
      debugPrint('[HOPETSIT] ✅ Data refreshed after role switch to $role');
    } catch (e) {
      debugPrint('[HOPETSIT] ⚠️ Refresh after role switch failed: $e');
    }
  }

  Future<void> _promptForSitterPayPalEmailIfMissing() async {
    try {
      // Always check latest payout email from backend first.
      final sitterRepo = Get.find<SitterRepository>();
      String? existingEmail;
      try {
        final payoutEmailResponse = await sitterRepo.getPayPalPayoutEmail();
        existingEmail =
            (payoutEmailResponse['paypalEmail'] as String?)?.trim() ??
            (payoutEmailResponse['email'] as String?)?.trim() ??
            (payoutEmailResponse['data'] is Map
                ? (payoutEmailResponse['data']['paypalEmail'] as String?)
                      ?.trim()
                : null) ??
            (payoutEmailResponse['sitter'] is Map
                ? (payoutEmailResponse['sitter']['paypalEmail'] as String?)
                      ?.trim()
                : null);
      } catch (_) {
        // Fallback to profile endpoint for backward compatibility.
        final profile = await sitterRepo.getMySitterProfile();
        existingEmail =
            (profile['paypalEmail'] as String?)?.trim() ??
            (profile['sitter'] is Map
                ? (profile['sitter']['paypalEmail'] as String?)?.trim()
                : null);
      }
      if (existingEmail != null && existingEmail.isNotEmpty) return;

      if (_isShowingPayPalPrompt || Get.isDialogOpen == true) return;
      _isShowingPayPalPrompt = true;

      final textController = TextEditingController();
      final isSaving = false.obs;

      await Get.dialog(
        Obx(
          () => PayPalEmailDialog(
            controller: textController,
            title: 'payout_add_paypal_email_title'.tr,
            subtitle: 'payout_add_paypal_email_subtitle'.tr,
            primaryText: 'common_save'.tr,
            secondaryText: 'common_later'.tr,
            isLoading: isSaving.value,
            onSecondary: () => Get.back(),
            onPrimary: () async {
              final email = textController.text.trim();
              if (email.isEmpty) {
                CustomSnackbar.showError(
                  title: 'common_error',
                  message: 'snackbar_text_please_enter_your_paypal_email',
                );
                return;
              }

              if (isSaving.value) return;
              isSaving.value = true;
              try {
                await sitterRepo.updatePayPalPayoutEmail(paypalEmail: email);
                Get.back();
              } catch (e) {
                debugPrint('[HOPETSIT] ⚠️ Failed to set PayPal email: $e');
              } finally {
                isSaving.value = false;
              }
            },
          ),
        ),
        barrierDismissible: false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        textController.dispose();
      });
    } catch (e) {
      debugPrint('[HOPETSIT] ⚠️ PayPal prompt failed: $e');
    } finally {
      _isShowingPayPalPrompt = false;
    }
  }

  void _clearOwnerCachedData() {
    if (Get.isRegistered<ProfileController>()) {
      final c = Get.find<ProfileController>();
      c.profile.value = null;
      c.userName.value = '';
      c.phoneNumber.value = '';
      c.email.value = '';
      c.profileImageUrl.value = '';
    }
    if (Get.isRegistered<UserController>()) {
      final uc = Get.find<UserController>();
      uc.profile.value = null;
      uc.userProfile.clear();
    }
  }

  void _clearSitterCachedData() {
    if (Get.isRegistered<SitterProfileController>()) {
      final c = Get.find<SitterProfileController>();
      c.profile.value = null;
      c.userName.value = '';
      c.phoneNumber.value = '';
      c.email.value = '';
      c.profileImageUrl.value = '';
    }
    if (Get.isRegistered<UserController>()) {
      final uc = Get.find<UserController>();
      uc.profile.value = null;
      uc.userProfile.clear();
    }
  }

  /// Clears any locally cached service selections so invalid services
  /// (e.g., Dog Walking for owners) do not persist across role switches.
  void _clearServiceSelections() {
    // Untagged controller (e.g. profile flow)
    if (Get.isRegistered<ChooseServiceController>()) {
      final c = Get.find<ChooseServiceController>();
      c.clearAllServices();
    }

    // Tagged controllers used in signup flows
    if (Get.isRegistered<ChooseServiceController>(tag: 'pet_owner')) {
      final ownerController = Get.find<ChooseServiceController>(
        tag: 'pet_owner',
      );
      ownerController.clearAllServices();
    }

    if (Get.isRegistered<ChooseServiceController>(tag: 'pet_sitter')) {
      final sitterController = Get.find<ChooseServiceController>(
        tag: 'pet_sitter',
      );
      sitterController.clearAllServices();
    }
  }

  Future<void> _refreshOwnerData() async {
    if (Get.isRegistered<UserController>()) {
      await Get.find<UserController>().loadMyProfile();
    }
    if (Get.isRegistered<ProfileController>()) {
      final pc = Get.find<ProfileController>();
      await pc.loadMyProfile();
      await pc.loadBlockedUsers();
    }
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().loadSitters();
    }
  }

  Future<void> _refreshSitterData() async {
    if (Get.isRegistered<SitterProfileController>()) {
      await Get.find<SitterProfileController>().loadMyProfile();
    }
    if (Get.isRegistered<PostsController>()) {
      final pc = Get.find<PostsController>();
      await pc.loadPostsWithoutMedia();
      await pc.loadMediaPosts();
    }
    if (Get.isRegistered<UserController>()) {
      await Get.find<UserController>().loadMyProfile();
    }
  }

  /// Logs out the user by clearing all stored data and navigating to login screen
  Future<void> logout() async {
    // Clear all stored authentication data
    await _storage.remove(StorageKeys.authToken);
    await _storage.remove(StorageKeys.userProfile);
    await _storage.remove(StorageKeys.userRole);

    // Clear controller state
    userRole.value = null;
    errorMessage.value = null;
    requiresEmailVerification.value = false;

    // Clear form fields (but don't dispose - they'll be reused)
    emailController.clear();
    passwordController.clear();

    // Navigate to login screen
    Get.offAll(() => const LoginScreen());
  }

  /// Handles "please login again" errors by logging out and routing to signin screen
  /// This should be called whenever an error indicates the user needs to re-authenticate
  static Future<void> handleLoginRequiredError() async {
    try {
      // Get AuthController instance if available
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        await authController.logout();
      } else {
        // If AuthController is not registered, manually clear storage and navigate
        final storage = GetStorage();
        await storage.remove(StorageKeys.authToken);
        await storage.remove(StorageKeys.userProfile);
        await storage.remove(StorageKeys.userRole);
        Get.offAll(() => const LoginScreen());
      }
    } catch (e) {
      // Fallback: clear storage and navigate even if logout fails
      final storage = GetStorage();
      await storage.remove(StorageKeys.authToken);
      await storage.remove(StorageKeys.userProfile);
      await storage.remove(StorageKeys.userRole);
      Get.offAll(() => const LoginScreen());
    }
  }

  /// Checks if an error message indicates login is required
  /// Also checks ApiException status code for 401 (Unauthorized)
  static bool isLoginRequiredError(String errorMessage, {int? statusCode}) {
    // Check status code first (401 = Unauthorized)
    if (statusCode == 401) {
      return true;
    }

    final lowerMessage = errorMessage.toLowerCase();
    return lowerMessage.contains('please login again') ||
        lowerMessage.contains('please login') ||
        lowerMessage.contains('login again') ||
        lowerMessage.contains('user id not found') ||
        lowerMessage.contains('sitter id not found') ||
        lowerMessage.contains('auth token not found') ||
        lowerMessage.contains('authentication required') ||
        lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('token expired') ||
        lowerMessage.contains('session expired') ||
        lowerMessage.contains('missing auth token');
  }
}
