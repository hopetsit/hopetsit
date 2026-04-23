import 'dart:convert';
import 'dart:io';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/models/block_model.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/models/task_model.dart';
import 'package:hopetsit/utils/logger.dart';

/// Handles owner-related API interactions.
class OwnerRepository {
  OwnerRepository(this._apiClient);

  final ApiClient _apiClient;

  // Legacy direct post creation methods (replaced by structured reservation requests).
  //
  // Future<Map<String, dynamic>> createPost({required String body}) async { ... }
  //
  // Future<Map<String, dynamic>> createPostWithMedia({
  //   required String body,
  //   File? imageFile,
  //   List<File>? imageFiles,
  // }) async { ... }

  /// Creates a structured reservation request post (without media).
  /// Uses the existing /posts endpoint with an extended JSON body.
  Future<Map<String, dynamic>> createReservationRequest({
    required String body,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> serviceTypes,
    required String petId,
    required String city,
    double? lat,
    double? lng,
    String? notes,
    String? houseSittingVenue,
    String? serviceLocation,
  }) async {
    final requestBody = <String, dynamic>{
      'body': body,
      'startDate': startDate.toUtc().toIso8601String(),
      'endDate': endDate.toUtc().toIso8601String(),
      'serviceTypes': serviceTypes,
      'petId': petId,
      'location': {
        'city': city,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (houseSittingVenue != null && houseSittingVenue.isNotEmpty)
        'houseSittingVenue': houseSittingVenue,
      if (serviceLocation != null && serviceLocation.isNotEmpty)
        'serviceLocation': serviceLocation,
    };

    final response = await _apiClient.post(
      ApiEndpoints.posts,
      body: requestBody,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected create reservation request response.',
      details: response,
    );
  }

  /// Creates a structured reservation request post with media (images).
  /// Uses the existing /posts/with-media endpoint and encodes complex fields.
  Future<Map<String, dynamic>> createReservationRequestWithMedia({
    required String body,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> serviceTypes,
    required String petId,
    required String city,
    double? lat,
    double? lng,
    String? notes,
    String? houseSittingVenue,
    String? serviceLocation,
    required List<File> imageFiles,
  }) async {
    final location = <String, dynamic>{
      'city': city,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };

    final fields = <String, String>{
      'body': body,
      'startDate': startDate.toUtc().toIso8601String(),
      'endDate': endDate.toUtc().toIso8601String(),
      // Backend expects a simple value it wraps into an array,
      // so we send the first service type as plain string.
      if (serviceTypes.isNotEmpty) 'serviceTypes': serviceTypes.first,
      'petId': petId,
      // Match Postman format: location as JSON string.
      'location': jsonEncode(location),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (houseSittingVenue != null && houseSittingVenue.isNotEmpty)
        'houseSittingVenue': houseSittingVenue,
      if (serviceLocation != null && serviceLocation.isNotEmpty)
        'serviceLocation': serviceLocation,
    };

    final response = await _apiClient.postMultipart(
      ApiEndpoints.postsWithMedia,
      files: imageFiles,
      fileFieldName: 'image',
      fields: fields,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected create reservation request with media response.',
      details: response,
    );
  }

  /// Finds nearby sitters based on owner's location (GET /sitters/nearby).
  /// [lat] and [lng] are required; [radiusInMeters] is optional.
  Future<List<SitterModel>> getNearbySitters({
    required double lat,
    required double lng,
    int? radiusInMeters,
  }) async {
    final queryParams = <String, dynamic>{'lat': lat, 'lng': lng};
    if (radiusInMeters != null) {
      queryParams['radiusInMeters'] = radiusInMeters;
    }
    final response = await _apiClient.get(
      ApiEndpoints.sittersNearby,
      queryParameters: queryParams,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      final sittersList = response['sitters'] as List<dynamic>?;
      if (sittersList != null) {
        final parsed = sittersList
            .map(
              (sitter) => SitterModel.fromJson(sitter as Map<String, dynamic>),
            )
            .toList();
        return parsed.where((s) => s.hasConfiguredRates).toList();
      }
    }

    if (response is Map) {
      final sittersList = response['sitters'] as List<dynamic>?;
      if (sittersList != null) {
        final parsed = sittersList
            .map(
              (sitter) => SitterModel.fromJson(sitter as Map<String, dynamic>),
            )
            .toList();
        return parsed.where((s) => s.hasConfiguredRates).toList();
      }
    }

    throw ApiException(
      'Unexpected get nearby sitters response.',
      details: response,
    );
  }

  /// Fetches list of available sitters.
  Future<List<SitterModel>> getSitters() async {
    final response = await _apiClient.get(
      ApiEndpoints.sitters,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      final sittersList = response['sitters'] as List<dynamic>?;
      if (sittersList != null) {
        final parsed = sittersList
            .map(
              (sitter) => SitterModel.fromJson(sitter as Map<String, dynamic>),
            )
            .toList();
        return parsed.where((s) => s.hasConfiguredRates).toList();
      }
    }

    if (response is Map) {
      final sittersList = response['sitters'] as List<dynamic>?;
      if (sittersList != null) {
        final parsed = sittersList
            .map(
              (sitter) => SitterModel.fromJson(sitter as Map<String, dynamic>),
            )
            .toList();
        return parsed.where((s) => s.hasConfiguredRates).toList();
      }
    }

    throw ApiException('Unexpected get sitters response.', details: response);
  }

  /// Fetches a single sitter's details by ID.
  Future<SitterModel> getSitterDetail(String sitterId) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.sitters}/$sitterId',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      final sitterData = response['sitter'] as Map<String, dynamic>?;
      if (sitterData != null) {
        return SitterModel.fromJson(sitterData);
      }
    }

    if (response is Map) {
      final sitterData = response['sitter'] as Map<String, dynamic>?;
      if (sitterData != null) {
        return SitterModel.fromJson(sitterData);
      }
    }

    throw ApiException(
      'Unexpected get sitter detail response.',
      details: response,
    );
  }

  /// Fetches the current owner's profile using GET /users/me/profile.
  Future<Map<String, dynamic>> getMyUserProfile() async {
    final response =
        await _apiClient.get(
              '${ApiEndpoints.users}/me/profile',
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
      'Unexpected response type when fetching my owner profile.',
      details: response,
    );
  }

  /// Creates a booking request for a sitter or a walker.
  /// [petIds] must contain at least one pet ID.
  ///
  /// Session v16-owner-walker — the [providerRole] decides which query
  /// parameter name the backend expects. 'walker' → ?walkerId=..., anything
  /// else → ?sitterId=... (kept as default for retrocompat with the dozens
  /// of existing callers that don't pass the new param).
  Future<Map<String, dynamic>> createBooking({
    required String sitterId,
    required List<String> petIds,
    required String description,
    required String serviceDate,
    required String timeSlot,
    required String serviceType,
    required double basePrice,
    String? duration,
    String? startDate,
    String? endDate,
    String? houseSittingVenue,
    String? serviceLocation,
    String providerRole = 'sitter',
  }) async {
    final body = <String, dynamic>{
      'petIds': petIds,
      'description': description,
      'serviceDate': serviceDate,
      'timeSlot': timeSlot,
      'serviceType': serviceType,
      'basePrice': basePrice,
    };

    if (startDate != null && startDate.trim().isNotEmpty) {
      body['startDate'] = startDate;
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      body['endDate'] = endDate;
    }
    if (houseSittingVenue != null && houseSittingVenue.trim().isNotEmpty) {
      body['houseSittingVenue'] = houseSittingVenue;
    }

    // Add duration only if provided (required for dog_walking)
    if (duration != null && duration.isNotEmpty) {
      body['duration'] = int.parse(duration);
    }

    // Session v16-owner-walker — send the right query key. The backend
    // treats `walkerId` as the trigger to fetch the Walker collection
    // instead of Sitter and persists the booking on `walkerId` field.
    final queryParams = providerRole == 'walker'
        ? {'walkerId': sitterId}
        : {'sitterId': sitterId};

    final response = await _apiClient.post(
      ApiEndpoints.bookings,
      queryParameters: queryParams,
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
      'Unexpected create booking response.',
      details: response,
    );
  }

  /// Fetches list of bookings for the current owner.
  Future<List<BookingModel>> getMyBookings({String? status}) async {
    final response = await _apiClient.get(
      ApiEndpoints.myBookings,
      queryParameters: status != null ? {'status': status} : null,
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

  /// Cancels a booking.
  Future<Map<String, dynamic>> cancelBooking({
    required String bookingId,
    required String sitterId,
  }) async {
    final response = await _apiClient.delete(
      '${ApiEndpoints.bookings}/$bookingId/cancel',
      queryParameters: {'sitterId': sitterId},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected cancel booking response.',
      details: response,
    );
  }

  /// Self-cancel a paid booking (72h free cancellation window).
  /// Calls POST /bookings/:id/self-cancel
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

  /// Creates a Stripe payment intent for a booking.
  Future<Map<String, dynamic>> createPaymentIntent({
    required String bookingId,
    bool useLoyaltyCredit = false,
  }) async {
    AppLogger.logInfo(
      'Creating payment intent for booking',
      data: {'bookingId': bookingId},
    );

    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.createPaymentIntent}',
        body: {'useLoyaltyCredit': useLoyaltyCredit},
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Payment intent created successfully',
          data: {
            'bookingId': bookingId,
            'paymentIntentId':
                response['paymentIntentId'] ?? response['payment_intent_id'],
            'hasClientSecret':
                response.containsKey('clientSecret') ||
                response.containsKey('client_secret'),
          },
        );
        return response;
      }

      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        AppLogger.logSuccess(
          'Payment intent created successfully',
          data: {
            'bookingId': bookingId,
            'paymentIntentId':
                responseMap['paymentIntentId'] ??
                responseMap['payment_intent_id'],
            'hasClientSecret':
                responseMap.containsKey('clientSecret') ||
                responseMap.containsKey('client_secret'),
          },
        );
        return responseMap;
      }

      throw ApiException(
        'Unexpected create payment intent response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to create payment intent', error: e);
      rethrow;
    }
  }

  /// Session v16.3b — transition a booking from status `accepted` to `agreed`.
  ///
  /// Required before payment can be initiated (backend enforces this).
  /// When called by the owner, the backend also auto-creates a Stripe
  /// PaymentIntent and returns its `clientSecret` in the response, which
  /// the payment screen can reuse to skip a round-trip.
  Future<Map<String, dynamic>> agreeToBooking({
    required String bookingId,
  }) async {
    AppLogger.logInfo(
      'Agreeing to booking (status accepted -> agreed)',
      data: {'bookingId': bookingId},
    );
    try {
      final response = await _apiClient.put(
        '${ApiEndpoints.bookings}/$bookingId/agree',
        body: {},
        requiresAuth: true,
      );
      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess('Booking agreed', data: {'bookingId': bookingId});
        return response;
      }
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      throw ApiException(
        'Unexpected agree to booking response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to agree to booking', error: e);
      rethrow;
    }
  }

  /// Gets the booking agreement/price details.
  Future<Map<String, dynamic>> getBookingAgreement({
    required String bookingId,
  }) async {
    AppLogger.logInfo(
      'Fetching booking agreement/price details',
      data: {'bookingId': bookingId},
    );

    try {
      final response = await _apiClient.get(
        '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.bookingAgreement}',
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Booking agreement fetched successfully',
          data: {
            'bookingId': bookingId,
            'hasTotalAmount':
                response.containsKey('totalAmount') ||
                response.containsKey('total_amount'),
            'hasBasePrice':
                response.containsKey('basePrice') ||
                response.containsKey('base_price'),
          },
        );
        return response;
      }

      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        AppLogger.logSuccess(
          'Booking agreement fetched successfully',
          data: {
            'bookingId': bookingId,
            'hasTotalAmount':
                responseMap.containsKey('totalAmount') ||
                responseMap.containsKey('total_amount'),
            'hasBasePrice':
                responseMap.containsKey('basePrice') ||
                responseMap.containsKey('base_price'),
          },
        );
        return responseMap;
      }

      throw ApiException(
        'Unexpected get booking agreement response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to fetch booking agreement', error: e);
      rethrow;
    }
  }

  /// Requests cancellation for a booking.
  Future<Map<String, dynamic>> requestCancellation({
    required String bookingId,
  }) async {
    AppLogger.logInfo(
      'Requesting booking cancellation',
      data: {'bookingId': bookingId},
    );

    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.requestCancellation}',
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Booking cancellation requested successfully',
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
          'Booking cancellation requested successfully',
          data: {
            'bookingId': bookingId,
            'status': responseMap['status'],
            'message': responseMap['message'],
          },
        );
        return responseMap;
      }

      throw ApiException(
        'Unexpected request cancellation response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to request booking cancellation', error: e);
      rethrow;
    }
  }

  /// Gets the payment status for a booking.
  Future<Map<String, dynamic>> getPaymentStatus({
    required String bookingId,
  }) async {
    AppLogger.logInfo(
      'Fetching payment status for booking',
      data: {'bookingId': bookingId},
    );

    try {
      final response = await _apiClient.get(
        '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.paymentStatus}',
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Payment status fetched successfully',
          data: {
            'bookingId': bookingId,
            'paymentStatus':
                response['paymentStatus'] ??
                response['payment_status'] ??
                response['status'],
            'isPaid': response['isPaid'] ?? response['is_paid'] ?? false,
          },
        );
        return response;
      }

      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        AppLogger.logSuccess(
          'Payment status fetched successfully',
          data: {
            'bookingId': bookingId,
            'paymentStatus':
                responseMap['paymentStatus'] ??
                responseMap['payment_status'] ??
                responseMap['status'],
            'isPaid': responseMap['isPaid'] ?? responseMap['is_paid'] ?? false,
          },
        );
        return responseMap;
      }

      throw ApiException(
        'Unexpected get payment status response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to fetch payment status', error: e);
      rethrow;
    }
  }

  /// Confirms payment for a booking.
  Future<Map<String, dynamic>> confirmPayment({
    required String bookingId,
    required String paymentIntentId,
  }) async {
    AppLogger.logInfo(
      'Confirming payment for booking',
      data: {'bookingId': bookingId, 'paymentIntentId': paymentIntentId},
    );

    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.confirmPayment}/$paymentIntentId',
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Payment confirmed successfully',
          data: {
            'bookingId': bookingId,
            'paymentIntentId': paymentIntentId,
            'status': response['status'],
            'message': response['message'],
          },
        );
        return response;
      }

      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        AppLogger.logSuccess(
          'Payment confirmed successfully',
          data: {
            'bookingId': bookingId,
            'paymentIntentId': paymentIntentId,
            'status': responseMap['status'],
            'message': responseMap['message'],
          },
        );
        return responseMap;
      }

      throw ApiException(
        'Unexpected confirm payment response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to confirm payment', error: e);
      rethrow;
    }
  }

  /// Creates (or returns existing) PayPal order for a booking (Owner only).
  /// POST /bookings/{id}/paypal/create-order
  Future<Map<String, dynamic>> createPayPalOrder({
    required String bookingId,
  }) async {
    AppLogger.logInfo(
      'Creating PayPal order for booking',
      data: {'bookingId': bookingId},
    );

    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.paypalCreateOrder}',
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      throw ApiException(
        'Unexpected create PayPal order response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to create PayPal order', error: e);
      rethrow;
    }
  }

  /// Captures an approved PayPal order for a booking (Owner only).
  /// POST /bookings/{id}/paypal/capture/{orderId}
  Future<Map<String, dynamic>> capturePayPalOrder({
    required String bookingId,
    required String orderId,
  }) async {
    AppLogger.logInfo(
      'Capturing PayPal order for booking',
      data: {'bookingId': bookingId, 'orderId': orderId},
    );

    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.bookings}/$bookingId${ApiEndpoints.paypalCapture}/$orderId',
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      throw ApiException(
        'Unexpected capture PayPal order response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to capture PayPal order', error: e);
      rethrow;
    }
  }

  /// Fetches list of applications for the current owner.
  Future<List<ApplicationModel>> getMyApplications() async {
    final response = await _apiClient.get(
      ApiEndpoints.myApplications,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      final applicationsList = response['applications'] as List<dynamic>?;
      if (applicationsList != null) {
        return applicationsList
            .map(
              (application) => ApplicationModel.fromJson(
                application as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    }

    if (response is Map) {
      final applicationsList = response['applications'] as List<dynamic>?;
      if (applicationsList != null) {
        return applicationsList
            .map(
              (application) => ApplicationModel.fromJson(
                application as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    }

    throw ApiException(
      'Unexpected get applications response.',
      details: response,
    );
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

  // ── Session v18.2 — Owner "Mes paiements" ────────────────────────────
  /// GET /owner/payments/methods — list the owner's saved Stripe cards.
  Future<List<Map<String, dynamic>>> getOwnerPaymentMethods() async {
    final response = await _apiClient.get(
      ApiEndpoints.ownerPaymentMethods,
      requiresAuth: true,
    );
    if (response is Map) {
      final list = response['paymentMethods'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  /// POST /owner/payments/setup-intent — start the "add card" flow.
  Future<Map<String, dynamic>> createOwnerSetupIntent() async {
    final response = await _apiClient.post(
      ApiEndpoints.ownerPaymentsSetupIntent,
      body: const {},
      requiresAuth: true,
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    throw ApiException('Unexpected setup-intent response.', details: response);
  }

  /// DELETE /owner/payments/methods/:id — detach a saved PaymentMethod.
  Future<void> deleteOwnerPaymentMethod(String paymentMethodId) async {
    await _apiClient.delete(
      '${ApiEndpoints.ownerPaymentMethods}/$paymentMethodId',
      requiresAuth: true,
    );
  }

  /// GET /owner/payments/history — list past paid bookings.
  Future<List<Map<String, dynamic>>> getOwnerPaymentHistory() async {
    final response = await _apiClient.get(
      ApiEndpoints.ownerPaymentsHistory,
      requiresAuth: true,
    );
    if (response is Map) {
      final list = response['history'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  /// Get tasks
  Future<List<TaskModel>> getTasks() async {
    final response = await _apiClient.get(
      ApiEndpoints.tasks,
      requiresAuth: true,
    );

    // Handle response with tasks array and count
    if (response is Map<String, dynamic>) {
      if (response.containsKey('tasks') && response['tasks'] is List) {
        return (response['tasks'] as List)
            .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    // Fallback: handle direct list response
    if (response is List) {
      return response
          .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException('Unexpected get tasks response.', details: response);
  }

  /// Creates a new task.
  Future<Map<String, dynamic>> createTask({
    required String title,
    required String description,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.tasks,
      body: {'title': title, 'description': description},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException('Unexpected create task response.', details: response);
  }

  /// Blocks a sitter.
  Future<Map<String, dynamic>> blockSitter({required String sitterId}) async {
    final response = await _apiClient.post(
      ApiEndpoints.blocks,
      body: {'sitterId': sitterId},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException('Unexpected block sitter response.', details: response);
  }

  /// Starts a new conversation with a provider (Owner only).
  /// POST /conversations/start?sitterId={sitterId}  (sitter path)
  /// POST /conversations/start?walkerId={walkerId}  (walker path, v18.8)
  ///
  /// Pass either `sitterId` OR `walkerId`. If `walkerId` is set the
  /// backend matches on Conversation.walkerId (XOR schema) instead of
  /// sitterId → plus de 404 "Sitter not found" quand le booking est avec
  /// un walker.
  Future<Map<String, dynamic>> startConversation({
    String? sitterId,
    String? walkerId,
    String? message,
  }) async {
    assert(
      (sitterId != null && sitterId.isNotEmpty) ||
          (walkerId != null && walkerId.isNotEmpty),
      'startConversation requires sitterId OR walkerId',
    );
    final queryParams = <String, String>{};
    if (walkerId != null && walkerId.isNotEmpty) {
      queryParams['walkerId'] = walkerId;
    } else if (sitterId != null && sitterId.isNotEmpty) {
      queryParams['sitterId'] = sitterId;
    }
    final response = await _apiClient.post(
      ApiEndpoints.conversationsStart,
      queryParameters: queryParams,
      body: {'message': message ?? "Hello, I'm interested in your services!"},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected start conversation response.',
      details: response,
    );
  }

  /// Fetches list of blocked users.
  Future<List<BlockModel>> getBlockedUsers() async {
    final response = await _apiClient.get(
      ApiEndpoints.blocks,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      final blocksList = response['blocks'] as List<dynamic>?;
      if (blocksList != null) {
        return blocksList
            .map((block) => BlockModel.fromJson(block as Map<String, dynamic>))
            .toList();
      }
    }

    if (response is Map) {
      final blocksList = response['blocks'] as List<dynamic>?;
      if (blocksList != null) {
        return blocksList
            .map((block) => BlockModel.fromJson(block as Map<String, dynamic>))
            .toList();
      }
    }

    throw ApiException(
      'Unexpected get blocked users response.',
      details: response,
    );
  }

  /// Unblocks a sitter.
  Future<Map<String, dynamic>> unblockSitter({required String sitterId}) async {
    final response = await _apiClient.delete(
      ApiEndpoints.blocks,
      body: {'sitterId': sitterId},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected unblock sitter response.',
      details: response,
    );
  }

  /// Submits a review for a service provider.
  /// v18.6 — bookingId + revieweeRole ajoutés. Sans eux le backend ne trouve
  /// pas la booking trust-chain et retourne 400 "completed booking required".
  Future<Map<String, dynamic>> submitReview({
    required String revieweeId,
    required double rating,
    required String comment,
    String? bookingId,
    String? revieweeRole, // 'sitter' | 'walker'
  }) async {
    AppLogger.logInfo(
      'Submitting review',
      data: {
        'revieweeId': revieweeId,
        'rating': rating,
        'bookingId': bookingId,
        'revieweeRole': revieweeRole,
      },
    );

    try {
      final body = <String, dynamic>{
        'revieweeId': revieweeId,
        'rating': rating,
        'comment': comment,
      };
      if (bookingId != null && bookingId.isNotEmpty) {
        body['bookingId'] = bookingId;
      }
      if (revieweeRole != null && revieweeRole.isNotEmpty) {
        body['revieweeRole'] = revieweeRole;
      }
      final response = await _apiClient.post(
        ApiEndpoints.reviews,
        body: body,
        requiresAuth: true,
      );

      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess(
          'Review submitted successfully',
          data: {
            'revieweeId': revieweeId,
            'rating': rating,
            'reviewId': response['reviewId'] ?? response['id'],
          },
        );
        return response;
      }

      if (response is Map) {
        final responseMap = Map<String, dynamic>.from(response);
        AppLogger.logSuccess(
          'Review submitted successfully',
          data: {
            'revieweeId': revieweeId,
            'rating': rating,
            'reviewId': responseMap['reviewId'] ?? responseMap['id'],
          },
        );
        return responseMap;
      }

      throw ApiException(
        'Unexpected submit review response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to submit review', error: e);
      rethrow;
    }
  }

  /// Blocks any user (owner or sitter) via the generic /blocks endpoint.
  Future<Map<String, dynamic>> blockAnyUser({
    required String targetUserId,
    String? targetRole,
  }) async {
    final body = <String, dynamic>{'targetUserId': targetUserId};
    if (targetRole != null && targetRole.isNotEmpty) {
      body['targetRole'] = targetRole;
    }
    final response = await _apiClient.post(
      ApiEndpoints.blocks,
      body: body,
      requiresAuth: true,
    );
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    throw ApiException('Unexpected block user response.', details: response);
  }

  Future<Map<String, dynamic>> unblockAnyUser({
    required String targetUserId,
    String? targetRole,
  }) async {
    final body = <String, dynamic>{'targetUserId': targetUserId};
    if (targetRole != null && targetRole.isNotEmpty) {
      body['targetRole'] = targetRole;
    }
    final response = await _apiClient.delete(
      ApiEndpoints.blocks,
      body: body,
      requiresAuth: true,
    );
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    throw ApiException('Unexpected unblock user response.', details: response);
  }

}
