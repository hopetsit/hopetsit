class SitterModel {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String language;
  final String address;
  final String? city; // City from location object
  final String? rate;
  final dynamic skills; // Can be String or List<String>
  final String? bio;
  final bool acceptedTerms;
  final List<String> service;
  final bool verified;
  final double rating;
  final int reviewsCount;
  final List<dynamic> feedback;
  final List<dynamic> reviews; // Reviews array from detail endpoint
  final double hourlyRate;
  final double dailyRate;
  final double weeklyRate;
  final double monthlyRate;

  /// Preferred unit to display in the UI: 'hour' | 'day' | 'week' | 'month'.
  final String defaultRateType;

  /// Sprint 5 step 6 — availability calendar.
  final List<DateTime> availableDates;
  final List<DateTime> unavailableDates;

  /// Sprint 5 step 7 — identity verification flag exposed publicly.
  final bool identityVerified;

  /// Currency code for hourly rate (e.g. USD, EUR). Defaults to EUR.
  final String currency;
  final String createdAt;
  final String updatedAt;
  final SitterAvatar avatar;

  /// From nearby API: location coordinates (GeoJSON [lng, lat]) and distance.
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  /// Returns city if available, otherwise returns empty string (for display purposes)
  String get displayCity => (city != null && city!.isNotEmpty) ? city! : '';

  /// True if the sitter has at least one positive rate (hourly, weekly, or monthly).
  bool get hasConfiguredRates =>
      hourlyRate > 0 || dailyRate > 0 || weeklyRate > 0 || monthlyRate > 0;

  /// Get skills as List<String>
  List<String> get skillsList {
    if (skills is List) {
      return (skills as List).map((e) => e.toString()).toList();
    } else if (skills is String) {
      return [skills as String];
    }
    return [];
  }

  SitterModel({
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
    required this.reviews,
    required this.hourlyRate,
    this.dailyRate = 0.0,
    this.weeklyRate = 0.0,
    this.monthlyRate = 0.0,
    this.defaultRateType = 'hour',
    this.availableDates = const <DateTime>[],
    this.unavailableDates = const <DateTime>[],
    this.identityVerified = false,
    this.currency = 'EUR',
    required this.createdAt,
    required this.updatedAt,
    required this.avatar,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  static String _parseCurrency(dynamic value) {
    if (value == null) return 'EUR';
    final s = value.toString().trim().toUpperCase();
    if (s == 'EUR') return 'EUR';
    return s.isNotEmpty ? s : 'EUR';
  }

  factory SitterModel.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;
    double? distKm;
    String? cityName;
    final loc = json['location'];
    if (loc is Map) {
      final coords = loc['coordinates'] as List<dynamic>?;
      if (coords != null && coords.length >= 2) {
        lng = (coords[0] as num?)?.toDouble();
        lat = (coords[1] as num?)?.toDouble();
      }
      // Extract city from location object
      cityName = loc['city'] as String?;
      if (cityName != null && cityName.isEmpty) {
        cityName = null; // Treat empty string as null
      }
    }
    final distStr = json['distance'];
    if (distStr != null) {
      distKm = double.tryParse(distStr.toString());
    }
    if (distKm == null) {
      final meters = json['distanceInMeters'] as num?;
      if (meters != null) distKm = meters.toDouble() / 1000;
    }
    return SitterModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      language: json['language'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: cityName,
      rate: json['rate'] as String?,
      skills: json['skills'], // Can be String or List<String>
      bio: json['bio'] as String?,
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: json['service'] is List
          ? (json['service'] as List).map((e) => e.toString()).toList()
          : (json['service'] is String && (json['service'] as String).isNotEmpty
                ? [(json['service'] as String)]
                : []),
      verified: json['verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: json['reviewsCount'] as int? ?? 0,
      feedback: json['feedback'] as List<dynamic>? ?? [],
      reviews: json['reviews'] as List<dynamic>? ?? [],
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      dailyRate: (json['dailyRate'] as num?)?.toDouble() ?? 0.0,
      weeklyRate: (json['weeklyRate'] as num?)?.toDouble() ?? 0.0,
      monthlyRate: (json['monthlyRate'] as num?)?.toDouble() ?? 0.0,
      defaultRateType: (json['defaultRateType'] as String?) ?? 'hour',
      availableDates: ((json['availableDates'] as List?) ?? const [])
          .map((e) => DateTime.tryParse(e.toString()))
          .whereType<DateTime>()
          .toList(),
      unavailableDates: ((json['unavailableDates'] as List?) ?? const [])
          .map((e) => DateTime.tryParse(e.toString()))
          .whereType<DateTime>()
          .toList(),
      identityVerified: json['identityVerified'] == true,
      currency: _parseCurrency(json['currency'] ?? json['hourlyRateCurrency']),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: SitterAvatar.fromJson(
        json['avatar'] as Map<String, dynamic>? ?? {},
      ),
      latitude: lat,
      longitude: lng,
      distanceKm: distKm,
    );
  }
}

class SitterAvatar {
  final String url;
  final String publicId;

  SitterAvatar({required this.url, required this.publicId});

  factory SitterAvatar.fromJson(Map<String, dynamic> json) {
    return SitterAvatar(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
    );
  }
}
