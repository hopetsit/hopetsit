import 'dart:io';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/logger.dart';

/// Handles sitter-related API interactions.
class SitterRepository {
  SitterRepository(this._apiClient);

  final ApiClient _apiClient;

  static String? _normalizeApplicationServiceType(String raw) {
    final value = raw
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    switch (value) {
      case 'home_visit':
      case 'dog_walking':
      case 'overnight_stay':
      case 'long_stay':
      case 'boarding':
      case 'pet_sitting':
      case 'house_sitting':
      case 'day_care':
        return value;
      // Common aliases from posts/legacy values
      case 'house_sit':
      case 'overnight':
        return 'overnight_stay';
      case 'long_term_care':
        return 'long_stay';
      case 'daycare':
        return 'day_care';
      default:
        return null;
    }
  }

  /// Updates sitter PayPal payout email (Sitter only).
  /// PUT /sitters/paypal-email
  /// Body: { "paypalEmail": "sitter-payments@example.com" }
  Future<Map<String, dynamic>> updatePayPalPayoutEmail({
    required String paypalEmail,
  }) async {
    AppLogger.logInfo(
      'Updating sitter PayPal payout email',
      data: {'paypalEmail': paypalEmail},
    );

    try {
      final response = await _apiClient.put(
        ApiEndpoints.sittersPayPalEmail,
        body: {'paypalEmail': paypalEmail},
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      throw ApiException(
        'Unexpected update PayPal payout email response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to update PayPal payout email', error: e);
      rethrow;
    }
  }

  /// Fetches sitter PayPal payout email (Sitter only).
  /// GET /sitters/paypal-email
  Future<Map<String, dynamic>> getPayPalPayoutEmail() async {
    AppLogger.logInfo('Fetching sitter PayPal payout email');

    try {
      final response = await _apiClient.get(
        ApiEndpoints.sittersPayPalEmail,
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      throw ApiException(
        'Unexpected get PayPal payout email response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to fetch PayPal payout email', error: e);
      rethrow;
    }
  }

  /// Fetches list of bookings for a specific sitter.
  /// [sitterId] - Optional, if not provided, will fetch for current user
  /// [status] - Optional status filter (e.g., 'agreed', 'pending', 'paid', etc.)
  Future<List<BookingModel>> getMyBookings({
    String? sitterId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (sitterId != null && sitterId.isNotEmpty) {
      queryParams['sitterId'] = sitterId;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      ApiEndpoints.myBookings,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      final bookingsList = response['bookings'] as List<dynamic>?;
      if (bookingsList != null) {
        return bookingsList
            .map(
              (booking) =>
                  BookingModel.fromJson(booking as Map<String, dynamic>),
            )
            .toList();
      }
    }

    if (response is Map) {
      final bookingsList = response['bookings'] as List<dynamic>?;
      if (bookingsList != null) {
        return bookingsList
            .map(
              (booking) =>
                  BookingModel.fromJson(booking as Map<String, dynamic>),
            )
            .toList();
      }
    }

    throw ApiException('Unexpected get bookings response.', details: response);
  }

  /// Changes the sitter's password.
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

  /// Deletes the current sitter's account.
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

  /// Agrees to a booking (accepts the booking request).
  Future<Map<String, dynamic>> agreeToBooking({
    required String bookingId,
  }) async {
    final response = await _apiClient.put(
      '${ApiEndpoints.bookings}/$bookingId/agree',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected agree to booking response.',
      details: response,
    );
  }

  /// Responds to a booking request with accept/reject.
  /// POST /bookings/{bookingId}/respond
  Future<Map<String, dynamic>> respondToBooking({
    required String bookingId,
    required String action, // 'accept' or 'reject'
  }) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.bookings}/$bookingId/respond',
      body: {'action': action},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected respond to booking response.',
      details: response,
    );
  }

  /// Requests cancellation for a booking (rejects the booking request).
  Future<Map<String, dynamic>> requestBookingCancellation({
    required String bookingId,
  }) async {
    AppLogger.logInfo(
      'Sitter requesting booking cancellation',
      data: {'bookingId': bookingId},
    );

    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.requestCancellation}',
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Sitter booking cancellation requested successfully',
          data: {
            'bookingId': bookingId,
            'status': response['status'],
            'message': response['message'],
          },
        );
        return response;
      }

      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        AppLogger.logSuccess(
          'Sitter booking cancellation requested successfully',
          data: {
            'bookingId': bookingId,
            'status': responseMap['status'],
            'message': responseMap['message'],
          },
        );
        return responseMap;
      }

      throw ApiException(
        'Unexpected request booking cancellation response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError(
        'Failed to request booking cancellation (sitter)',
        error: e,
      );
      rethrow;
    }
  }

  /// Self-cancel a paid booking (72h free cancellation window).
  Future<Map<String, dynamic>> selfCancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.bookings}/$bookingId/self-cancel',
      body: reason != null ? {'reason': reason} : {},
      requiresAuth: true,
    );
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    throw ApiException('Unexpected self-cancel response.', details: response);
  }

  /// Creates an application (sends request to owner).
  /// POST /applications?ownerId={ownerId}
  Future<Map<String, dynamic>> createApplication({
    required String ownerId,
    required List<String> petIds,
    required String serviceType,
    required String serviceDate,
    required String timeSlot,
    double basePrice = 1.0,
    int? duration,
    String? startDate,
    String? endDate,
    String? houseSittingVenue,
    // Session v17.1 — stable back-reference to the owner's Post the sitter
    // is applying to. Lets the sitter home screen resolve "is this post
    // already applied to?" by Post id instead of a fragile fingerprint.
    String? postId,
  }) async {
    if (petIds.isEmpty) {
      throw ApiException(
        'petIds must not be empty for createApplication.',
        details: {'ownerId': ownerId},
      );
    }

    final normalizedServiceType = _normalizeApplicationServiceType(serviceType);
    if (normalizedServiceType == null) {
      throw ApiException(
        'serviceType is required. Valid types: home_visit, dog_walking, overnight_stay, long_stay',
        details: {'ownerId': ownerId, 'serviceType': serviceType},
      );
    }
    if (timeSlot.trim().isEmpty) {
      throw ApiException(
        'timeSlot is required.',
        details: {'ownerId': ownerId},
      );
    }
    if (serviceDate.trim().isEmpty) {
      throw ApiException(
        'serviceDate is required.',
        details: {'ownerId': ownerId},
      );
    }
    if (basePrice <= 0) {
      throw ApiException(
        'basePrice must be a positive number.',
        details: {'ownerId': ownerId, 'basePrice': basePrice},
      );
    }
    if (normalizedServiceType == 'dog_walking' &&
        (duration == null || (duration != 30 && duration != 60))) {
      throw ApiException(
        'duration is required for dog_walking. Valid values: 30 or 60.',
        details: {
          'ownerId': ownerId,
          'serviceType': normalizedServiceType,
          'duration': duration,
        },
      );
    }
    if (normalizedServiceType == 'house_sitting') {
      final venue = houseSittingVenue?.trim();
      if (venue != 'owners_home' && venue != 'sitters_home') {
        throw ApiException(
          'houseSittingVenue is required for house_sitting and must be owners_home or sitters_home.',
          details: {
            'ownerId': ownerId,
            'serviceType': normalizedServiceType,
            'houseSittingVenue': houseSittingVenue,
          },
        );
      }
    }
    final response = await _apiClient.post(
      ApiEndpoints.applications,
      queryParameters: {'ownerId': ownerId},
      body: {
        'petIds': petIds,
        'serviceType': normalizedServiceType,
        if (normalizedServiceType == 'house_sitting')
          'houseSittingVenue': houseSittingVenue,
        'serviceDate': serviceDate,
        if (startDate != null && startDate.trim().isNotEmpty)
          'startDate': startDate,
        if (endDate != null && endDate.trim().isNotEmpty) 'endDate': endDate,
        'timeSlot': timeSlot,
        'basePrice': basePrice,
        if (duration != null) 'duration': duration,
        if (postId != null && postId.trim().isNotEmpty) 'postId': postId,
      },
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected create application response.',
      details: response,
    );
  }

  /// Cancels sitter's own pending application request.
  /// POST /applications/{id}/cancel-request
  Future<Map<String, dynamic>> cancelApplicationRequest({
    required String applicationId,
  }) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.applications}/$applicationId${ApiEndpoints.requestCancellation}',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected cancel application request response.',
      details: response,
    );
  }

  /// Fetches sitter's own sent applications.
  /// GET /applications/my
  Future<List<Map<String, dynamic>>> getMyApplicationsRaw() async {
    final response = await _apiClient.get(
      ApiEndpoints.myApplications,
      requiresAuth: true,
    );

    List<dynamic>? applications;
    if (response is Map<String, dynamic>) {
      applications = response['applications'] as List<dynamic>?;
    } else if (response is Map) {
      applications = response['applications'] as List<dynamic>?;
    }

    if (applications == null) {
      throw ApiException(
        'Unexpected get my applications response.',
        details: response,
      );
    }

    return applications
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Responds to an application (accept or reject).
  Future<Map<String, dynamic>> respondToApplication({
    required String applicationId,
    required String action, // 'accept' or 'reject'
  }) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.applications}/$applicationId/respond',
      body: {'action': action},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected respond to application response.',
      details: response,
    );
  }

  /// Fetches a sitter profile by sitter ID.
  Future<Map<String, dynamic>> getSitterProfile(String sitterId) async {
    final response =
        await _apiClient.get(
              '${ApiEndpoints.sitters}/$sitterId',
              requiresAuth: true,
            )
            as dynamic;

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected response type when fetching sitter profile.',
      details: response,
    );
  }

  /// Fetches the current sitter's profile using GET /sitters/me/profile.
  Future<Map<String, dynamic>> getMySitterProfile() async {
    final response =
        await _apiClient.get(
              '${ApiEndpoints.sitters}/me/profile',
              requiresAuth: true,
            )
            as dynamic;

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected response type when fetching my sitter profile.',
      details: response,
    );
  }

  /// Creates a Stripe Connect account for the sitter.
  Future<Map<String, dynamic>> createStripeConnectAccount() async {
    AppLogger.logInfo('Creating Stripe Connect account for sitter');

    try {
      final response = await _apiClient.post(
        ApiEndpoints.stripeConnectCreateAccount,
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Stripe Connect account created successfully',
          data: {
            'accountId': response['accountId'] ?? response['account_id'],
            'hasOnboardingUrl':
                response.containsKey('onboardingUrl') ||
                response.containsKey('onboarding_url') ||
                response.containsKey('url'),
            'expiresAt': response['expiresAt'] ?? response['expires_at'],
          },
        );
        return response;
      }

      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        AppLogger.logSuccess(
          'Stripe Connect account created successfully',
          data: {
            'accountId': responseMap['accountId'] ?? responseMap['account_id'],
            'hasOnboardingUrl':
                responseMap.containsKey('onboardingUrl') ||
                responseMap.containsKey('onboarding_url') ||
                responseMap.containsKey('url'),
            'expiresAt': responseMap['expiresAt'] ?? responseMap['expires_at'],
          },
        );
        return responseMap;
      }

      throw ApiException(
        'Unexpected create Stripe Connect account response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to create Stripe Connect account', error: e);
      rethrow;
    }
  }

  /// Gets the Stripe Connect account status for the sitter.
  Future<Map<String, dynamic>> getStripeConnectAccountStatus() async {
    AppLogger.logInfo('Fetching Stripe Connect account status for sitter');

    try {
      final response = await _apiClient.get(
        ApiEndpoints.stripeConnectAccountStatus,
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Stripe Connect account status fetched successfully',
          data: {
            'accountId': response['accountId'] ?? response['account_id'],
            'status': response['status'],
            'chargesEnabled':
                response['chargesEnabled'] ?? response['charges_enabled'],
            'payoutsEnabled':
                response['payoutsEnabled'] ?? response['payouts_enabled'],
            'detailsSubmitted':
                response['detailsSubmitted'] ?? response['details_submitted'],
          },
        );
        return response;
      }

      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        AppLogger.logSuccess(
          'Stripe Connect account status fetched successfully',
          data: {
            'accountId': responseMap['accountId'] ?? responseMap['account_id'],
            'status': responseMap['status'],
            'chargesEnabled':
                responseMap['chargesEnabled'] ?? responseMap['charges_enabled'],
            'payoutsEnabled':
                responseMap['payoutsEnabled'] ?? responseMap['payouts_enabled'],
            'detailsSubmitted':
                responseMap['detailsSubmitted'] ??
                responseMap['details_submitted'],
          },
        );
        return responseMap;
      }

      throw ApiException(
        'Unexpected get Stripe Connect account status response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError(
        'Failed to fetch Stripe Connect account status',
        error: e,
      );
      rethrow;
    }
  }

  /// Updates a sitter's profile.
  Future<Map<String, dynamic>> updateSitterProfile(
    String sitterId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.put(
      '${ApiEndpoints.sitters}/$sitterId',
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected update sitter profile response.',
      details: response,
    );
  }

  /// Uploads a profile image for the sitter.
  Future<Map<String, dynamic>> uploadSitterProfileImage(
    String sitterId,
    File imageFile,
  ) async {
    final response = await _apiClient.putMultipart(
      '${ApiEndpoints.sitters}/$sitterId/profile-picture',
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
      'Unexpected upload sitter profile image response.',
      details: response,
    );
  }

  /// Updates the current sitter's profile using PUT /sitters/me/profile.
  /// Fields: name, email, mobile, address, location, bio, skills, language
  Future<Map<String, dynamic>> updateSitterProfileMe({
    required String name,
    required String email,
    required String mobile,
    String? countryCode,
    String? address,
    Map<String, dynamic>? location,
    String? bio,
    String? skills,
    String? language,
    double? hourlyRate,
    String? currency,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'mobile': mobile,
      'countryCode': countryCode,
    };

    if (address != null && address.isNotEmpty) {
      payload['address'] = address;
    }
    if (location != null) {
      payload['location'] = location;
    }
    if (bio != null && bio.isNotEmpty) {
      payload['bio'] = bio;
    }
    if (skills != null && skills.isNotEmpty) {
      payload['skills'] = skills;
    }
    if (language != null && language.isNotEmpty) {
      payload['language'] = language;
    }
    if (hourlyRate != null) {
      payload['hourlyRate'] = hourlyRate;
    }
    if (currency != null && currency.isNotEmpty) {
      payload['currency'] = currency;
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      payload['countryCode'] = countryCode;
    }

    final response = await _apiClient.put(
      '${ApiEndpoints.sitters}/me/profile',
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected update sitter profile response.',
      details: response,
    );
  }

  /// Lightweight profile update used by the sitter onboarding flow.
  /// Only sends the fields the onboarding actually collects so we never wipe
  /// name/email/mobile just because the user hasn't filled them yet.
  Future<Map<String, dynamic>> updateMyBioAndSkills({
    String? bio,
    String? skills,
    double? hourlyRate,
    String? currency,
  }) async {
    final payload = <String, dynamic>{};
    if (bio != null && bio.isNotEmpty) payload['bio'] = bio;
    if (skills != null && skills.isNotEmpty) payload['skills'] = skills;
    if (hourlyRate != null) payload['hourlyRate'] = hourlyRate;
    if (currency != null && currency.isNotEmpty) payload['currency'] = currency;

    if (payload.isEmpty) return <String, dynamic>{};

    final response = await _apiClient.put(
      '${ApiEndpoints.sitters}/me/profile',
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);

    throw ApiException(
      'Unexpected update sitter profile response.',
      details: response,
    );
  }

  /// Gets current sitter rates using GET /sitters/me/rates.
  Future<Map<String, dynamic>> getMyRates() async {
    final response = await _apiClient.get(
      '${ApiEndpoints.sitters}/me/rates',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected get sitter rates response.',
      details: response,
    );
  }

  /// Sets current sitter rates using PUT /sitters/me/rates.
  Future<Map<String, dynamic>> setMyRates({
    required double hourlyRate,
    required double dailyRate,
    required double weeklyRate,
    required double monthlyRate,
  }) async {
    final response = await _apiClient.put(
      '${ApiEndpoints.sitters}/me/rates',
      body: {
        'hourlyRate': hourlyRate,
        'dailyRate': dailyRate,
        'weeklyRate': weeklyRate,
        'monthlyRate': monthlyRate,
      },
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected set sitter rates response.',
      details: response,
    );
  }

  /// Updates the current sitter's profile picture using PUT /sitters/me/profile-picture.
  Future<Map<String, dynamic>> updateSitterProfilePicture(
    File imageFile,
  ) async {
    final response = await _apiClient.putMultipart(
      '${ApiEndpoints.sitters}/me/avatar',
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
      'Unexpected update sitter profile picture response.',
      details: response,
    );
  }

  /// Starts a new conversation with an owner (Sitter only).
  /// POST /conversations/start-by-sitter?ownerId={ownerId}
  Future<Map<String, dynamic>> startConversationBySitter({
    required String ownerId,
    String? message,
  }) async {
    // v18.9 — plus de message auto anglais.
    final response = await _apiClient.post(
      ApiEndpoints.conversationsStartBySitter,
      queryParameters: {'ownerId': ownerId},
      body: {
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      },
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected start conversation by sitter response.',
      details: response,
    );
  }
}
