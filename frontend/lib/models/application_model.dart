import 'package:hopetsit/models/booking_model.dart';

class ApplicationModel {
  final String id;
  final String postBody;
  final String petName;
  final String description;
  final String? serviceDate;
  final String timeSlot;
  final String status;
  final String createdAt;
  final String updatedAt;
  final ApplicationUser owner;
  final ApplicationSitter sitter;
  final BookingPricing? pricing;
  /// Session v17.2 — id of the Booking created when the owner accepts this
  /// application. Populated from `application.bookingId` on the backend
  /// (sanitizeApplication). Used to open StripePaymentScreen when the
  /// owner reopens a "Demande du sitter / walker" notification that has
  /// already been accepted.
  final String? bookingId;

  ApplicationModel({
    required this.id,
    required this.postBody,
    required this.petName,
    required this.description,
    this.serviceDate,
    required this.timeSlot,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.owner,
    required this.sitter,
    this.pricing,
    this.bookingId,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    final pricingJson = json['pricing'];
    final rawBookingId = json['bookingId'];
    String? parsedBookingId;
    if (rawBookingId is String && rawBookingId.isNotEmpty) {
      parsedBookingId = rawBookingId;
    } else if (rawBookingId is Map) {
      // Populated booking — grab its id.
      final inner = rawBookingId['id']?.toString() ?? rawBookingId['_id']?.toString();
      if (inner != null && inner.isNotEmpty) parsedBookingId = inner;
    }
    return ApplicationModel(
      id: json['id'] as String? ?? '',
      postBody: json['postBody'] as String? ?? '',
      petName: json['petName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      serviceDate: json['serviceDate'] as String?,
      timeSlot: json['timeSlot'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      owner: ApplicationUser.fromJson(
        json['owner'] as Map<String, dynamic>? ?? {},
      ),
      sitter: ApplicationSitter.fromJson(
        json['sitter'] as Map<String, dynamic>? ?? {},
      ),
      pricing: pricingJson is Map<String, dynamic>
          ? BookingPricing.fromJson(pricingJson)
          : null,
      bookingId: parsedBookingId,
    );
  }
}

class ApplicationUser {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String language;
  final String address;
  final bool acceptedTerms;
  final List<String> service;
  final bool verified;
  final String createdAt;
  final String updatedAt;
  final ApplicationAvatar avatar;

  ApplicationUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.language,
    required this.address,
    required this.acceptedTerms,
    required this.service,
    required this.verified,
    required this.createdAt,
    required this.updatedAt,
    required this.avatar,
  });

  factory ApplicationUser.fromJson(Map<String, dynamic> json) {
    return ApplicationUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      language: json['language'] as String? ?? '',
      address: json['address'] as String? ?? '',
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: _parseService(json['service']),
      verified: json['verified'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: ApplicationAvatar.fromJson(
        json['avatar'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  static List<String> _parseService(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) {
      return [value];
    }
    return [];
  }
}

class ApplicationSitter {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String language;
  final String address;
  final String? city; // City extracted from location object
  final String? rate;
  final String skills;
  final String? bio;
  final bool acceptedTerms;
  final List<String> service;
  final bool verified;
  final double rating;
  final int reviewsCount;
  final List<dynamic> feedback;
  final double hourlyRate;
  final double weeklyRate;
  final double monthlyRate;
  final String currency;
  final String createdAt;
  final String updatedAt;
  final ApplicationAvatar avatar;

  ApplicationSitter({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.language,
    required this.address,
    this.city,
    this.rate,
    required this.skills,
    this.bio,
    required this.acceptedTerms,
    required this.service,
    required this.verified,
    required this.rating,
    required this.reviewsCount,
    required this.feedback,
    required this.hourlyRate,
    this.weeklyRate = 0.0,
    this.monthlyRate = 0.0,
    this.currency = 'EUR',
    required this.createdAt,
    required this.updatedAt,
    required this.avatar,
  });

  factory ApplicationSitter.fromJson(Map<String, dynamic> json) {
    return ApplicationSitter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      language: json['language'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['location'] is Map<String, dynamic>
          ? (json['location']['city'] as String?)
          : null,
      rate: json['rate'] as String?,
      skills: json['skills'] as String? ?? '',
      bio: json['bio'] as String?,
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: ApplicationUser._parseService(json['service']),
      verified: json['verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: json['reviewsCount'] as int? ?? 0,
      feedback: json['feedback'] as List<dynamic>? ?? [],
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      weeklyRate: (json['weeklyRate'] as num?)?.toDouble() ?? 0.0,
      monthlyRate: (json['monthlyRate'] as num?)?.toDouble() ?? 0.0,
      currency: _parseSitterCurrency(
        json['currency'] ?? json['hourlyRateCurrency'],
      ),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: ApplicationAvatar.fromJson(
        json['avatar'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  static String _parseSitterCurrency(dynamic value) {
    if (value == null) return 'EUR';
    final s = value.toString().trim().toUpperCase();
    if (s == 'EUR') return 'EUR';
    return s.isNotEmpty ? s : 'EUR';
  }
}

class ApplicationAvatar {
  final String url;
  final String publicId;

  ApplicationAvatar({required this.url, required this.publicId});

  factory ApplicationAvatar.fromJson(Map<String, dynamic> json) {
    return ApplicationAvatar(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
    );
  }
}
