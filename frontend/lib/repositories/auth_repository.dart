import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';

/// Handles authentication-related API interactions.
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Performs login with email and password and returns the server response.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authLogin,
      body: {'email': email, 'password': password},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException('Unexpected login response.', details: response);
  }

  /// Creates a new account for either owners or sitters.
  Future<Map<String, dynamic>> signup({
    required String role,
    required Map<String, dynamic> user,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authSignup,
      body: {'role': role, 'user': user},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException('Unexpected signup response.', details: response);
  }

  /// Verifies the OTP code for email verification.
  Future<Map<String, dynamic>> verifyCode({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authVerify,
      queryParameters: {'email': email},
      body: {'code': code},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException('Unexpected verify code response.', details: response);
  }

  /// Resends the verification code to the specified email.
  Future<Map<String, dynamic>> resendVerificationCode({
    required String email,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authResendVerification,
      queryParameters: {'email': email},
      body: null, // Empty body as per API spec
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected resend verification response.',
      details: response,
    );
  }

  /// Chooses services for the user (pet owner or pet sitter).
  /// Accepts an array of service strings.
  Future<Map<String, dynamic>> chooseService({
    required String email,
    required List<String> services,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authChooseService,
      queryParameters: {'email': email},
      body: {'service': services},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected choose service response.',
      details: response,
    );
  }

  /// Changes the user's password.
  Future<Map<String, dynamic>> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.authChangePassword,
      body: {'newPassword': newPassword, 'confirmPassword': confirmPassword},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected change password response.',
      details: response,
    );
  }

  /// Requests an OTP for password reset.
  Future<Map<String, dynamic>> requestForgotPasswordOTP({
    required String email,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authForgotPassword,
      queryParameters: null,
      body: {'email': email},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected forgot password response.',
      details: response,
    );
  }

  /// Verifies the OTP for password reset.
  Future<Map<String, dynamic>> verifyForgotPasswordOTP({
    required String email,
    required String otp,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authVerifyOtp,
      body: {'email': email, 'code': otp},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected verify forgot password response.',
      details: response,
    );
  }

  /// Resets the user's password using email, OTP, and new password.
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.authResetPassword,
      queryParameters: null,
      body: {'email': email, 'code': otp, 'newPassword': newPassword},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected reset password response.',
      details: response,
    );
  }

  /// Sends an existing Firebase ID token to backend for Google auth.
  /// Optionally include a `role` (e.g. 'owner' or 'sitter') when creating a new user.
  Future<Map<String, dynamic>> googleSignInWithIdToken({
    required String idToken,
    String? role,
  }) async {
    final body = <String, dynamic>{'idToken': idToken};
    if (role != null && role.isNotEmpty) {
      body['role'] = role;
      print(
        '[HOPETSIT] Google sign-in API: Including role=$role in request body',
      );
    } else {
      print('[HOPETSIT] Google sign-in API: No role provided');
    }

    final response = await _apiClient.post(
      ApiEndpoints.authGoogleSignIn,
      body: body,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected Google sign in response.',
      details: response,
    );
  }

  /// Sends an existing Firebase ID token to backend for Apple auth.
  /// Optionally include a `role` (e.g. 'owner' or 'sitter') when creating a new user.
  /// Same params as Google sign in.
  Future<Map<String, dynamic>> appleSignInWithIdToken({
    required String idToken,
    String? role,
  }) async {
    final body = <String, dynamic>{'idToken': idToken};
    if (role != null && role.isNotEmpty) {
      body['role'] = role;
    }

    final response = await _apiClient.post(
      ApiEndpoints.authAppleSignIn,
      body: body,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected Apple sign in response.',
      details: response,
    );
  }
}
