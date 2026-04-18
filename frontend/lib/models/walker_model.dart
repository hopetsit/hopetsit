/// Walker model — frontend mirror of backend src/models/Walker.js.
///
/// A Walker is a dog walker (third role alongside Owner and Sitter) with a
/// per-walk pricing model (walkRates) instead of per-stay pricing.
class WalkerModel {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String language;
  final String address;
  final String? city;
  final String? bio;
  final String? skills;
  final bool acceptedTerms;
  final List<String> service;
  final bool verified;
  final double rating;
  final int reviewsCount;
  final List<dynamic> feedback;
  final List<dynamic> reviews;

  /// Pricing — list of per-duration walk rates. Each entry is a WalkRate.
  final List<WalkRate> walkRates;

  /// Preferred default duration in minutes (15 to 300, multiple of 15).
  final int defaultWalkDurationMinutes;

  /// Walker-specific attributes.
  final List<String> acceptedPetTypes;
  final int maxPetsPerWalk;
  final bool hasInsurance;
  final DateTime? insuranceExpiresAt;
  final String coverageCity;
  final int coverageRadiusKm;

  /// Availability calendar.
  final List<DateTime> availableDates;
  final List<DateTime> unavailableDates;

  /// Identity verification flag (publicly exposed).
  final bool identityVerified;

  /// Top-Walker program (analog to Sitter's Top-Sitter).
  final bool isTopWalker;
  final int completedWalksCount;
  final double averageRating;

  /// Coin Boost — profile boost.
  final bool isBoosted;
  final String? boostTier;

  /// Map boost — highlighted pin on PawMap (Phase 1 shop product).
  final DateTime? mapBoostExpiry;

  /// Currency for pricing (EUR default).
  final String currency;

  final String createdAt;
  final String updatedAt;
  final WalkerAvatar avatar;

  /// Geospatial info (from nearby queries).
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  String get displayCity => (city != null && city!.isNotEmpty) ? city! : '';

  /// True if the walker has at least one enabled, non-zero walk rate.
  bool get hasConfiguredRates =>
      walkRates.any((r) => r.enabled && r.basePrice > 0);

  WalkerModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.language,
    required this.address,
    this.city,
    this.bio,
    this.skills,
    required this.acceptedTerms,
    required this.service,
    required this.verified,
    required this.rating,
    required this.reviewsCount,
    required this.feedback,
    required this.reviews,
    required this.walkRates,
    this.defaultWalkDurationMinutes = 30,
    this.acceptedPetTypes = const [],
    this.maxPetsPerWalk = 1,
    this.hasInsurance = false,
    this.insuranceExpiresAt,
    this.coverageCity = '',
    this.coverageRadiusKm = 3,
    this.availableDates = const <DateTime>[],
    this.unavailableDates = const <DateTime>[],
    this.identityVerified = false,
    this.isTopWalker = false,
    this.completedWalksCount = 0,
    this.averageRating = 0.0,
    this.isBoosted = false,
    this.boostTier,
    this.mapBoostExpiry,
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
    return s.isNotEmpty ? s : 'EUR';
  }

  factory WalkerModel.fromJson(Map<String, dynamic> json) {
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
      cityName = loc['city'] as String?;
      if (cityName != null && cityName.isEmpty) {
        cityName = null;
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

    final walkRatesRaw = json['walkRates'];
    final walkRates = walkRatesRaw is List
        ? walkRatesRaw
              .whereType<Map>()
              .map((e) => WalkRate.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <WalkRate>[];

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return WalkerModel(
      id: json['id'] as String? ?? json['_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      language: json['language'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: cityName,
      bio: json['bio'] as String?,
      skills: json['skills'] as String?,
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: json['service'] is List
          ? (json['service'] as List).map((e) => e.toString()).toList()
          : (json['service'] is String && (json['service'] as String).isNotEmpty
                ? [(json['service'] as String)]
                : <String>[]),
      verified: json['verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 0,
      feedback: json['feedback'] as List<dynamic>? ?? [],
      reviews: json['reviews'] as List<dynamic>? ?? [],
      walkRates: walkRates,
      defaultWalkDurationMinutes:
          (json['defaultWalkDurationMinutes'] as num?)?.toInt() ?? 30,
      acceptedPetTypes: json['acceptedPetTypes'] is List
          ? (json['acceptedPetTypes'] as List).map((e) => e.toString()).toList()
          : <String>[],
      maxPetsPerWalk: (json['maxPetsPerWalk'] as num?)?.toInt() ?? 1,
      hasInsurance: json['hasInsurance'] as bool? ?? false,
      insuranceExpiresAt: parseDate(json['insuranceExpiresAt']),
      coverageCity: (json['coverageCity'] as String?) ?? '',
      coverageRadiusKm: (json['coverageRadiusKm'] as num?)?.toInt() ?? 3,
      availableDates: ((json['availableDates'] as List?) ?? const [])
          .map((e) => DateTime.tryParse(e.toString()))
          .whereType<DateTime>()
          .toList(),
      unavailableDates: ((json['unavailableDates'] as List?) ?? const [])
          .map((e) => DateTime.tryParse(e.toString()))
          .whereType<DateTime>()
          .toList(),
      identityVerified: json['identityVerified'] == true,
      isTopWalker: json['isTopWalker'] == true,
      isBoosted: json['isBoosted'] == true,
      boostTier: json['boostTier'] as String?,
      mapBoostExpiry: parseDate(json['mapBoostExpiry']),
      completedWalksCount: (json['completedWalksCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      currency: _parseCurrency(json['currency']),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: WalkerAvatar.fromJson(
        json['avatar'] as Map<String, dynamic>? ?? {},
      ),
      latitude: lat,
      longitude: lng,
      distanceKm: distKm,
    );
  }
}

/// A single per-duration walk rate (e.g. 30 min = 15 EUR).
class WalkRate {
  final int durationMinutes;
  final double basePrice;
  final String currency;
  final bool enabled;

  WalkRate({
    required this.durationMinutes,
    required this.basePrice,
    this.currency = 'EUR',
    this.enabled = true,
  });

  factory WalkRate.fromJson(Map<String, dynamic> json) => WalkRate(
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
        currency: (json['currency'] as String?) ?? 'EUR',
        enabled: json['enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'durationMinutes': durationMinutes,
        'basePrice': basePrice,
        'currency': currency,
        'enabled': enabled,
      };
}

class WalkerAvatar {
  final String url;
  final String publicId;

  WalkerAvatar({required this.url, required this.publicId});

  factory WalkerAvatar.fromJson(Map<String, dynamic> json) {
    return WalkerAvatar(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
    );
  }
}
