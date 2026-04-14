import 'dart:io';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/utils/logger.dart';

/// Handles pet-related API interactions.
class PetRepository {
  PetRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Creates a pet profile.
  Future<Map<String, dynamic>> createPetProfile({
    required Map<String, dynamic> petData,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.petsCreateProfile,
      body: {'pet': petData},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected create pet profile response.',
      details: response,
    );
  }

  /// Fetches the current user's pets.
  Future<List<PetModel>> getMyPets() async {
    final response = await _apiClient.get(
      ApiEndpoints.myPets,
      requiresAuth: true,
    );

    // Handle response with pets array and count
    if (response is Map<String, dynamic>) {
      if (response.containsKey('pets') && response['pets'] is List) {
        return (response['pets'] as List)
            .map((e) => PetModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    // Fallback: handle direct list response
    if (response is List) {
      return response
          .map((e) => PetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException('Unexpected get my pets response.', details: response);
  }

  /// Fetches a single pet by ID.
  Future<PetModel> getPetById(String petId) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.pets}/$petId',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      // Handle response with nested pet object
      if (response.containsKey('pet')) {
        final petData = response['pet'] as Map<String, dynamic>;
        // Include owner info from root if available
        if (response.containsKey('owner') || response.containsKey('name')) {
          petData['owner'] = response['owner'] ?? response;
        }
        return PetModel.fromJson(petData);
      }
      // Handle direct pet object - owner info might be at root level
      return PetModel.fromJson(response);
    }

    throw ApiException('Unexpected get pet response.', details: response);
  }

  /// Updates an existing pet profile.
  Future<Map<String, dynamic>> updatePet({
    required String petId,
    required Map<String, dynamic> petData,
  }) async {
    final response = await _apiClient.put(
      '${ApiEndpoints.pets}/$petId',
      body: petData,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected update pet profile response.',
      details: response,
    );
  }

  /// Uploads media (image) for a pet.
  Future<Map<String, dynamic>> uploadPetMedia({
    required String petId,
    required File imageFile,
  }) async {
    final response = await _apiClient.putMultipart(
      '${ApiEndpoints.petMedia}/$petId/media',
      file: imageFile,
      fileFieldName: 'avatar',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected upload pet media response.',
      details: response,
    );
  }

  /// Uploads media (image) for a pet.
  /// Endpoint: /pets/{id}/media with query parameter id=petId
  Future<Map<String, dynamic>> uploadPetMediaWithQuery({
    required String petId,
    required File imageFile,
  }) async {
    // Log file information before upload
    final filePath = imageFile.path;
    final fileExists = await imageFile.exists();
    final fileSize = fileExists ? await imageFile.length() : 0;

    AppLogger.logInfo(
      'Starting pet media upload',
      data: {
        'petId': petId,
        'filePath': filePath,
        'fileName': filePath.split('/').last,
        'fileExists': fileExists,
        'fileSize': fileSize,
        'fileSizeKB': (fileSize / 1024).toStringAsFixed(2),
        'endpoint': '${ApiEndpoints.pets}/$petId/media',
        'queryParameters': {'id': petId},
        'fileFieldName': 'avatar',
      },
    );

    try {
      final response = await _apiClient.putMultipart(
        '${ApiEndpoints.pets}/$petId/media',
        file: imageFile,
        fileFieldName: 'avatar',
        queryParameters: {'id': petId},
        requiresAuth: true,
      );

      // Log successful response
      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Pet media uploaded successfully',
          data: {
            'petId': petId,
            'response': response,
            'avatarUrl': response['avatar']?['url'] ?? 'N/A',
            'publicId': response['avatar']?['publicId'] ?? 'N/A',
          },
        );
        return response;
      }

      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        AppLogger.logSuccess(
          'Pet media uploaded successfully',
          data: {
            'petId': petId,
            'response': responseMap,
            'avatarUrl': responseMap['avatar']?['url'] ?? 'N/A',
            'publicId': responseMap['avatar']?['publicId'] ?? 'N/A',
          },
        );
        return responseMap;
      }

      AppLogger.logError(
        'Unexpected upload pet media response format',
        error: 'Response is not a Map: ${response.runtimeType}',
      );
      throw ApiException(
        'Unexpected upload pet media response.',
        details: response,
      );
    } catch (error) {
      AppLogger.logError('Failed to upload pet media', error: error);
      rethrow;
    }
  }

  /// Uploads pet media/images during pet profile creation.
  /// Supports avatar, passportImage, and multiple photos.
  /// Deletes a specific pet media item (avatar, photo, passportImage or video)
  /// via PUT /pets/:id/media with a JSON body containing
  /// action: 'delete', mediaType, and optional publicId.
  Future<Map<String, dynamic>> deletePetMedia({
    required String petId,
    required String mediaType,
    String? publicId,
  }) async {
    final body = <String, dynamic>{
      'action': 'delete',
      'mediaType': mediaType,
    };
    if (publicId != null && publicId.isNotEmpty) {
      body['publicId'] = publicId;
    }
    final response = await _apiClient.put(
      '${ApiEndpoints.pets}/$petId/media',
      body: body,
      requiresAuth: true,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw ApiException(
      'Unexpected delete pet media response.',
      details: response,
    );
  }

  Future<Map<String, dynamic>> uploadPetCreationMedia({
    required String petId,
    File? avatar,
    File? passportImage,
    List<File>? photos,
    List<File>? videos,
    String? folder,
  }) async {
    final fileFields = <String, dynamic>{};

    // Add avatar if provided
    if (avatar != null) {
      fileFields['avatar'] = avatar;
    }

    // Add passport image if provided
    if (passportImage != null) {
      fileFields['passportImage'] = passportImage;
    }

    // Add photos if provided (limit to 10 as per API spec)
    if (photos != null && photos.isNotEmpty) {
      fileFields['photo'] = photos.take(10).toList();
    }

    // Add videos if provided (limit to 10 as per API spec)
    if (videos != null && videos.isNotEmpty) {
      fileFields['video'] = videos.take(10).toList();
    }

    // Build query parameters (petId is required)
    final queryParameters = <String, dynamic>{'petId': petId};

    // Build text fields (folder is optional)
    final textFields = <String, String>{};
    if (folder != null && folder.isNotEmpty) {
      textFields['folder'] = folder;
    }

    final response = await _apiClient.postMultipartWithFields(
      endpoint: ApiEndpoints.petsCreateProfileImages,
      fileFields: fileFields,
      textFields: textFields.isNotEmpty ? textFields : null,
      queryParameters: queryParameters,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected upload pet creation media response.',
      details: response,
    );
  }
}
