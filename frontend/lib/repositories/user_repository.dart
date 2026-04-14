import 'dart:io';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';

/// Repository coordinating data access for user resources.
class UserRepository {
  UserRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches a user profile by id.
  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    final response =
        await _apiClient.get(
              '${ApiEndpoints.users}/$userId',
              requiresAuth: true,
            )
            as Map?;

    if (response is! Map<String, dynamic>) {
      throw ApiException(
        'Unexpected response type when fetching user profile.',
        details: response,
      );
    }

    return response;
  }

  /// Updates a user profile.
  Future<Map<String, dynamic>> updateUserProfile(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final response =
        await _apiClient.put(
              '${ApiEndpoints.users}/$userId/profile',
              body: payload,
              requiresAuth: true,
            )
            as Map?;

    if (response is! Map<String, dynamic>) {
      throw ApiException(
        'Unexpected response type when updating user profile.',
        details: response,
      );
    }

    return response;
  }

  /// Saves or updates user card information.
  Future<Map<String, dynamic>> saveCard({
    required String holderName,
    required String cardNumber,
    required String expDate,
    required String cvc,
  }) async {
    final response =
        await _apiClient.put(
              ApiEndpoints.userCard,
              body: {
                'holderName': holderName,
                'cardNumber': cardNumber,
                'expDate': expDate,
                'cvc': cvc,
              },
              requiresAuth: true,
            )
            as Map?;

    if (response is! Map<String, dynamic>) {
      throw ApiException(
        'Unexpected response type when saving card.',
        details: response,
      );
    }

    return response;
  }

  /// Switches user role (Owner to Sitter or Sitter to Owner).
  /// Calls POST /users/switch-role.
  Future<Map<String, dynamic>> switchRole() async {
    final response =
        await _apiClient.post(
              ApiEndpoints.switchRole,
              body: <String, dynamic>{},
              requiresAuth: true,
            )
            as Map?;

    if (response is! Map<String, dynamic>) {
      throw ApiException(
        'Unexpected response type when switching role.',
        details: response,
      );
    }

    return response;
  }

  /// Deletes the current user's account.
  Future<Map<String, dynamic>> deleteAccount() async {
    final response =
        await _apiClient.delete(ApiEndpoints.deleteAccount, requiresAuth: true)
            as Map?;

    if (response is! Map<String, dynamic>) {
      throw ApiException(
        'Unexpected response type when deleting account.',
        details: response,
      );
    }

    return response;
  }

  /// Fetches the current user's profile.
  Future<Map<String, dynamic>> getMyProfile() async {
    final response =
        await _apiClient.get(ApiEndpoints.myProfile, requiresAuth: true)
            as Map?;

    if (response is! Map<String, dynamic>) {
      throw ApiException(
        'Unexpected response type when fetching my profile.',
        details: response,
      );
    }

    return response;
  }

  /// Updates the current user's profile picture.
  Future<Map<String, dynamic>> updateProfilePicture(File imageFile) async {
    final response =
        await _apiClient.putMultipart(
              ApiEndpoints.profilePicture,
              file: imageFile,
              fileFieldName: 'avatar',
              requiresAuth: true,
            )
            as Map?;

    if (response is! Map<String, dynamic>) {
      throw ApiException(
        'Unexpected response type when updating profile picture.',
        details: response,
      );
    }

    return response;
  }
}
