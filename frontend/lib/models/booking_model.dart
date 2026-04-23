/// Pet info within a booking (from API "pets" array).
class BookingPet {
  final String id;
  final String petName;
  final String breed;
  final String category;
  final String weight;
  final String height;
  final String colour;
  final String vaccination;
  final String medicationAllergies;
  final BookingAvatar avatar;

  BookingPet({
    required this.id,
    required this.petName,
    required this.breed,
    required this.category,
    required this.weight,
    required this.height,
    required this.colour,
    required this.vaccination,
    required this.medicationAllergies,
    required this.avatar,
  });

  factory BookingPet.fromJson(Map<String, dynamic> json) {
    final avatarData = json['avatar'];
    BookingAvatar avatar;
    if (avatarData is String) {
      avatar = BookingAvatar(url: avatarData, publicId: '');
    } else if (avatarData is Map<String, dynamic>) {
      avatar = BookingAvatar.fromJson(avatarData);
    } else {
      avatar = BookingAvatar(url: '', publicId: '');
    }
    return BookingPet(
      id: json['id'] as String? ?? '',
      petName: json['petName'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      category: json['category'] as String? ?? '',
      weight: json['weight']?.toString() ?? '',
      height: json['height']?.toString() ?? '',
      colour: json['colour']?.toString() ?? json['color']?.toString() ?? '',
      vaccination: json['vaccination'] as String? ?? '',
      medicationAllergies: json['medicationAllergies'] as String? ?? '',
      avatar: avatar,
    );
  }
}

class BookingModel {
  final String id;
  final String petName;
  final String petWeight;
  final String petHeight;
  final String petColor;
  final String description;
  final String date;
  final String timeSlot;
  String status;
  final String createdAt;
  final String updatedAt;
  final BookingUser owner;
  final BookingSitter sitter;
  final List<BookingPet> pets; // From API "pets" array
  final String? paymentStatus; // 'pending', 'paid', 'failed', etc.
  final double? totalAmount; // Total amount including platform fee
  final double? basePrice; // Base price before platform fee
  final BookingPricing? pricing; // Pricing details
  final String? cancelledAt; // When booking was cancelled
  final String? cancelledBy; // Who cancelled the booking
  final String? cancellationReason; // Reason for cancellation
  final String? serviceType; // Type of service
  final String? houseSittingVenue; // owners_home or sitters_home
  final int? duration; // Walk duration in minutes (e.g. 30/60) when applicable
  final String? specialInstructions; // Special instructions for the booking

  BookingModel({
    required this.id,
    required this.petName,
    required this.petWeight,
    required this.petHeight,
    required this.petColor,
    required this.description,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.owner,
    required this.sitter,
    List<BookingPet>? pets,
    this.paymentStatus,
    this.totalAmount,
    this.basePrice,
    this.pricing,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.serviceType,
    this.houseSittingVenue,
    this.duration,
    this.specialInstructions,
  }) : pets = pets ?? [];

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Handle 'sitter', 'walker' and 'otherParty' fields from API.
    // For owner flow: 'sitter' OR 'walker' (since v17) OR 'otherParty' carries
    // the provider info — depending on whether the booking targets a sitter
    // or a walker. For sitter/walker flow: only 'otherParty' exists (owner).
    final sitterData = json['sitter'] as Map<String, dynamic>?;
    // Session v17 — walker bookings populate `walker` in sanitizeBooking.
    // BookingSitter is structurally compatible (name/email/avatar/etc.) so
    // we reuse the same model under the `sitter` field for backward compat.
    final walkerData = json['walker'] as Map<String, dynamic>?;
    final ownerData = json['owner'] as Map<String, dynamic>?;
    final otherParty = json['otherParty'] as Map<String, dynamic>?;

    // Determine which field to use based on what's available.
    // Priority: sitter > walker > otherParty > {} (empty fallback).
    final finalSitterData = sitterData ?? walkerData ?? otherParty ?? {};

    // If 'owner' exists, use it; otherwise use 'otherParty' (for sitter flow)
    final finalOwnerData = ownerData ?? otherParty ?? {};

    final petsList = json['pets'] as List<dynamic>?;
    final parsedPets = petsList != null
        ? petsList
              .map((e) => BookingPet.fromJson(e as Map<String, dynamic>))
              .toList()
        : <BookingPet>[];
    final firstPetName = parsedPets.isNotEmpty
        ? parsedPets.first.petName
        : (json['petName'] as String? ?? '');
    final firstPetWeight = parsedPets.isNotEmpty
        ? parsedPets.first.weight
        : (json['petWeight']?.toString() ?? '');
    final firstPetHeight = parsedPets.isNotEmpty
        ? parsedPets.first.height
        : (json['petHeight']?.toString() ?? '');
    final firstPetColor = parsedPets.isNotEmpty
        ? parsedPets.first.colour
        : (json['petColor']?.toString() ?? '');

    return BookingModel(
      id: json['id'] as String? ?? '',
      petName: firstPetName,
      petWeight: firstPetWeight,
      petHeight: firstPetHeight,
      petColor: firstPetColor,
      description: json['description'] as String? ?? '',
      date: json['date'] as String? ?? '',
      timeSlot: json['timeSlot'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      owner: BookingUser.fromJson(finalOwnerData),
      sitter: BookingSitter.fromJson(finalSitterData),
      pets: parsedPets,
      paymentStatus: json['paymentStatus'] as String?,
      totalAmount:
          (json['totalAmount'] as num?)?.toDouble() ??
          (json['total_amount'] as num?)?.toDouble(),
      basePrice:
          (json['basePrice'] as num?)?.toDouble() ??
          (json['base_price'] as num?)?.toDouble(),
      pricing: json['pricing'] != null
          ? BookingPricing.fromJson(json['pricing'] as Map<String, dynamic>)
          : null,
      cancelledAt:
          json['cancelledAt'] as String? ?? json['cancelled_at'] as String?,
      cancelledBy:
          json['cancelledBy'] as String? ?? json['cancelled_by'] as String?,
      cancellationReason:
          json['cancellationReason'] as String? ??
          json['cancellation_reason'] as String?,
      serviceType:
          json['serviceType'] as String? ?? json['service_type'] as String?,
      houseSittingVenue:
          json['houseSittingVenue'] as String? ??
          json['house_sitting_venue'] as String?,
      duration: json['duration'] as int?,
      specialInstructions:
          json['specialInstructions'] as String? ??
          json['special_instructions'] as String?,
    );
  }
}

/// Parses service from API: can be List`<String>` or String (legacy).
List<String> _parseBookingService(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
  if (value is String && value.isNotEmpty) {
    return [value];
  }
  return [];
}

class BookingUser {
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
  final BookingAvatar avatar;

  BookingUser({
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

  factory BookingUser.fromJson(Map<String, dynamic> json) {
    // Handle avatar - can be a string URL or an object
    BookingAvatar avatar;
    final avatarData = json['avatar'];
    if (avatarData is String) {
      // If avatar is a string URL, create an avatar object with it
      avatar = BookingAvatar(url: avatarData, publicId: '');
    } else if (avatarData is Map<String, dynamic>) {
      avatar = BookingAvatar.fromJson(avatarData);
    } else {
      avatar = BookingAvatar(url: '', publicId: '');
    }

    // Handle both 'phone' and 'mobile' fields from API
    final mobile = json['phone'] as String? ?? json['mobile'] as String? ?? '';

    // Handle both 'location' and 'address' fields from API
    final address =
        json['location'] as String? ?? json['address'] as String? ?? '';

    return BookingUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: mobile,
      language: json['language'] as String? ?? '',
      address: address,
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: _parseBookingService(json['service']),
      verified: json['verified'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: avatar,
    );
  }
}

class BookingSitter {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String language;
  final String address;
  final String? city;
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
  final BookingAvatar avatar;

  BookingSitter({
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

  factory BookingSitter.fromJson(Map<String, dynamic> json) {
    // Handle avatar - can be a string URL or an object
    BookingAvatar avatar;
    final avatarData = json['avatar'];
    if (avatarData is String) {
      // If avatar is a string URL, create an avatar object with it
      avatar = BookingAvatar(url: avatarData, publicId: '');
    } else if (avatarData is Map<String, dynamic>) {
      avatar = BookingAvatar.fromJson(avatarData);
    } else {
      avatar = BookingAvatar(url: '', publicId: '');
    }

    // Handle both 'phone' and 'mobile' fields from API
    final mobile = json['phone'] as String? ?? json['mobile'] as String? ?? '';

    // Handle both 'location' and 'address' fields from API
    final address =
        json['location'] as String? ?? json['address'] as String? ?? '';

    final location = json['location'];
    final city = location is Map ? (location['city'] as String?) : null;
    return BookingSitter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: mobile,
      language: json['language'] as String? ?? '',
      address: address,
      city: city,
      rate: json['rate'] as String?,
      skills: json['skills'] as String? ?? '',
      bio: json['bio'] as String?,
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: _parseBookingService(json['service']),
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
      avatar: avatar,
    );
  }

  static String _parseSitterCurrency(dynamic value) {
    if (value == null) return 'EUR';
    final s = value.toString().trim().toUpperCase();
    if (s == 'EUR') return 'EUR';
    return s.isNotEmpty ? s : 'EUR';
  }
}

class BookingPricing {
  final double? platformFeePercentage;
  final double? basePrice;
  final double? platformFee;
  final double? totalPrice;
  final double? netAmount; // Amount after fees
  final String? currency;

  /// Backend tier: `hourly`, `weekly`, or `monthly` (length-based).
  final String? pricingTier;
  final double? appliedRate;
  final double? totalHours;
  final double? totalDays;

  BookingPricing({
    this.platformFeePercentage,
    this.basePrice,
    this.platformFee,
    this.totalPrice,
    this.netAmount,
    this.currency,
    this.pricingTier,
    this.appliedRate,
    this.totalHours,
    this.totalDays,
  });

  factory BookingPricing.fromJson(Map<String, dynamic> json) {
    final baseFromApi =
        (json['basePrice'] as num?)?.toDouble() ??
        (json['base_price'] as num?)?.toDouble();
    final baseFromLegacy =
        (json['netPayout'] as num?)?.toDouble() ??
        (json['net_payout'] as num?)?.toDouble();

    return BookingPricing(
      platformFeePercentage:
          (json['platformFeePercentage'] as num?)?.toDouble() ??
          (json['platform_fee_percentage'] as num?)?.toDouble(),
      basePrice: baseFromApi ?? baseFromLegacy,
      // v18.9.8 — le backend stocke le champ sous le nom `commission`
      // (pricing.js / bookingController). On garde aussi `platformFee` et
      // `platform_fee` pour rétro-compat avec d'anciennes réponses.
      platformFee:
          (json['platformFee'] as num?)?.toDouble() ??
          (json['platform_fee'] as num?)?.toDouble() ??
          (json['commission'] as num?)?.toDouble(),
      totalPrice:
          (json['totalPrice'] as num?)?.toDouble() ??
          (json['total_price'] as num?)?.toDouble(),
      netAmount:
          (json['netAmount'] as num?)?.toDouble() ??
          (json['net_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      pricingTier: json['pricingTier'] as String? ?? json['pricing_tier'] as String?,
      appliedRate:
          (json['appliedRate'] as num?)?.toDouble() ??
          (json['applied_rate'] as num?)?.toDouble(),
      totalHours:
          (json['totalHours'] as num?)?.toDouble() ??
          (json['total_hours'] as num?)?.toDouble(),
      totalDays:
          (json['totalDays'] as num?)?.toDouble() ??
          (json['total_days'] as num?)?.toDouble(),
    );
  }

  /// Best-effort base service amount for display when only tier fields exist.
  double? get resolvedBaseAmount {
    if (basePrice != null && basePrice! > 0) return basePrice;
    if (appliedRate != null && appliedRate! > 0) return appliedRate;
    return null;
  }
}

class BookingAvatar {
  final String url;
  final String publicId;

  BookingAvatar({required this.url, required this.publicId});

  factory BookingAvatar.fromJson(Map<String, dynamic> json) {
    return BookingAvatar(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
    );
  }
}
