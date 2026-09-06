class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String language;
  final String address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final bool acceptedTerms;
  final List<String> service;
  final bool verified;
  final String createdAt;
  final String updatedAt;
  final ProfileAvatar avatar;
  final List<dynamic> pets;
  final List<dynamic> bookings;
  final List<dynamic> posts;
  final List<dynamic> tasks;
  final List<dynamic> reviewsGiven;
  final List<dynamic> reviewsReceived;
  final ProfileStats stats;
  // v23.1.292 — note/avis/top status renvoyés par le profil public (sitter &
  // walker) mais ignorés jusqu'ici. Maintenant lus pour afficher la vraie note,
  // le vrai nombre d'avis (cliquable), et l'état Top Sitter/Walker.
  final double rating;
  final int reviewsCount;
  final List<dynamic> reviews;
  final double averageRating;
  final int completedServicesCount;
  final bool isTopSitter;
  // v406 refonte — onglets Profil/Préférences/Sécurité + champs prestataire.
  final String bio;
  final String dateOfBirth;
  final bool twoFactorEnabled;
  final ProfilePreferences preferences;
  final ProfileSearchPrefs searchPreferences;
  final List<String> experienceTags;
  final List<String> acceptedPetTypes;
  final List<String> availableDays;
  final int coverageRadiusKm;
  final int? responseTimeMinutes;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.language,
    required this.address,
    this.city,
    this.latitude,
    this.longitude,
    required this.acceptedTerms,
    required this.service,
    required this.verified,
    required this.createdAt,
    required this.updatedAt,
    required this.avatar,
    required this.pets,
    required this.bookings,
    required this.posts,
    required this.tasks,
    required this.reviewsGiven,
    required this.reviewsReceived,
    required this.stats,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.reviews = const [],
    this.averageRating = 0.0,
    this.completedServicesCount = 0,
    this.isTopSitter = false,
    this.bio = '',
    this.dateOfBirth = '',
    this.twoFactorEnabled = false,
    this.preferences = const ProfilePreferences(),
    this.searchPreferences = const ProfileSearchPrefs(),
    this.experienceTags = const [],
    this.acceptedPetTypes = const [],
    this.availableDays = const [],
    this.coverageRadiusKm = 20,
    this.responseTimeMinutes,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      language: json['language'] as String? ?? '',
      address: json['address'] as String? ?? '',
      // Support nested `location` object while keeping backwards compatibility
      city: (json['location'] is Map<String, dynamic>)
          ? (json['location']['city'] as String?)
          : json['city'] as String?,
      latitude: (json['location'] is Map<String, dynamic>)
          ? (json['location']['lat'] as num?)?.toDouble()
          : (json['latitude'] as num?)?.toDouble(),
      longitude: (json['location'] is Map<String, dynamic>)
          ? (json['location']['lng'] as num?)?.toDouble()
          : (json['longitude'] as num?)?.toDouble(),
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: json['service'] is List
          ? (json['service'] as List).map((e) => e.toString()).toList()
          : (json['service'] is String && (json['service'] as String).isNotEmpty
                ? [(json['service'] as String)]
                : []),
      verified: json['verified'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: ProfileAvatar.fromJson(
        json['avatar'] as Map<String, dynamic>? ?? {},
      ),
      pets: json['pets'] as List<dynamic>? ?? [],
      bookings: json['bookings'] as List<dynamic>? ?? [],
      posts: json['posts'] as List<dynamic>? ?? [],
      tasks: json['tasks'] as List<dynamic>? ?? [],
      reviewsGiven: json['reviewsGiven'] as List<dynamic>? ?? [],
      reviewsReceived: json['reviewsReceived'] as List<dynamic>? ?? [],
      stats: ProfileStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? {},
      ),
      rating: (json['rating'] as num?)?.toDouble() ??
          (json['averageRating'] as num?)?.toDouble() ??
          0.0,
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 0,
      // Le profil public sitter/walker renvoie `reviews` ; fallback sur
      // `reviewsReceived` selon l'endpoint.
      reviews: json['reviews'] as List<dynamic>? ??
          (json['reviewsReceived'] as List<dynamic>? ?? []),
      averageRating: (json['averageRating'] as num?)?.toDouble() ??
          (json['rating'] as num?)?.toDouble() ??
          0.0,
      completedServicesCount:
          (json['completedServicesCount'] as num?)?.toInt() ?? 0,
      isTopSitter: (json['isTopSitter'] as bool?) ??
          (json['isTopWalker'] as bool?) ??
          false,
      bio: json['bio'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
      preferences: ProfilePreferences.fromJson(
          json['preferences'] as Map<String, dynamic>? ?? const {}),
      searchPreferences: ProfileSearchPrefs.fromJson(
          json['searchPreferences'] as Map<String, dynamic>? ?? const {}),
      experienceTags: (json['experienceTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      acceptedPetTypes: (json['acceptedPetTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      availableDays: (json['availableDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      coverageRadiusKm: (json['coverageRadiusKm'] as num?)?.toInt() ?? 20,
      responseTimeMinutes: (json['responseTimeMinutes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'language': language,
      'address': address,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      // Add nested `location` object for APIs expecting { location: { lat, lng, city } }
      'location': {'lat': latitude, 'lng': longitude, 'city': city},
      'acceptedTerms': acceptedTerms,
      'service': service,
      'verified': verified,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'avatar': avatar.toJson(),
      'pets': pets,
      'bookings': bookings,
      'posts': posts,
      'tasks': tasks,
      'reviewsGiven': reviewsGiven,
      'reviewsReceived': reviewsReceived,
      'stats': stats.toJson(),
      'bio': bio,
      'dateOfBirth': dateOfBirth,
      'twoFactorEnabled': twoFactorEnabled,
      'preferences': preferences.toJson(),
      'searchPreferences': searchPreferences.toJson(),
      'experienceTags': experienceTags,
      'acceptedPetTypes': acceptedPetTypes,
      'availableDays': availableDays,
      'coverageRadiusKm': coverageRadiusKm,
      if (responseTimeMinutes != null) 'responseTimeMinutes': responseTimeMinutes,
    };
  }
}

/// v406 — préférences utilisateur (toggles maquette « Mes préférences »).
class ProfilePreferences {
  final bool sendPhotosVideos;
  final bool quickReplies;
  final bool flexibleCancellation;
  final bool pawMapInsurance;
  final bool notifications;
  /// v551 — Daniel : « masquer mon profil sur la carte (on/off) ». Quand c'est
  /// activé, le membre n'apparaît plus sur la PawMap publique ; ses amis
  /// continuent de le voir.
  final bool hideFromMap;

  const ProfilePreferences({
    this.sendPhotosVideos = true,
    this.quickReplies = true,
    this.flexibleCancellation = true,
    this.pawMapInsurance = true,
    this.notifications = true,
    this.hideFromMap = false,
  });

  factory ProfilePreferences.fromJson(Map<String, dynamic> json) {
    return ProfilePreferences(
      sendPhotosVideos: json['sendPhotosVideos'] as bool? ?? true,
      quickReplies: json['quickReplies'] as bool? ?? true,
      flexibleCancellation: json['flexibleCancellation'] as bool? ?? true,
      pawMapInsurance: json['pawMapInsurance'] as bool? ?? true,
      notifications: json['notifications'] as bool? ?? true,
      hideFromMap: json['hideFromMap'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'sendPhotosVideos': sendPhotosVideos,
        'quickReplies': quickReplies,
        'flexibleCancellation': flexibleCancellation,
        'pawMapInsurance': pawMapInsurance,
        'notifications': notifications,
        'hideFromMap': hideFromMap,
      };

  ProfilePreferences copyWith({
    bool? sendPhotosVideos,
    bool? quickReplies,
    bool? flexibleCancellation,
    bool? pawMapInsurance,
    bool? notifications,
    bool? hideFromMap,
  }) =>
      ProfilePreferences(
        sendPhotosVideos: sendPhotosVideos ?? this.sendPhotosVideos,
        quickReplies: quickReplies ?? this.quickReplies,
        flexibleCancellation: flexibleCancellation ?? this.flexibleCancellation,
        pawMapInsurance: pawMapInsurance ?? this.pawMapInsurance,
        notifications: notifications ?? this.notifications,
        hideFromMap: hideFromMap ?? this.hideFromMap,
      );
}

/// v406 — préférences de recherche (owner) : services, rayon, langue.
class ProfileSearchPrefs {
  final List<String> services;
  final int radiusKm;
  final String preferredLanguage;

  const ProfileSearchPrefs({
    this.services = const [],
    this.radiusKm = 20,
    this.preferredLanguage = '',
  });

  factory ProfileSearchPrefs.fromJson(Map<String, dynamic> json) {
    return ProfileSearchPrefs(
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      radiusKm: (json['radiusKm'] as num?)?.toInt() ?? 20,
      preferredLanguage: json['preferredLanguage'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'services': services,
        'radiusKm': radiusKm,
        'preferredLanguage': preferredLanguage,
      };
}

class ProfileAvatar {
  final String url;
  final String publicId;

  ProfileAvatar({required this.url, required this.publicId});

  factory ProfileAvatar.fromJson(Map<String, dynamic> json) {
    return ProfileAvatar(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'publicId': publicId};
  }
}

class ProfileStats {
  final int petsCount;
  final int bookingsCount;
  final int postsCount;
  final int tasksCount;
  final int reviewsGivenCount;
  final int reviewsReceivedCount;

  ProfileStats({
    required this.petsCount,
    required this.bookingsCount,
    required this.postsCount,
    required this.tasksCount,
    required this.reviewsGivenCount,
    required this.reviewsReceivedCount,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    // Backend may return counts as num (double or int) — coerce safely.
    int asInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ProfileStats(
      petsCount: asInt('petsCount'),
      bookingsCount: asInt('bookingsCount'),
      postsCount: asInt('postsCount'),
      tasksCount: asInt('tasksCount'),
      reviewsGivenCount: asInt('reviewsGivenCount'),
      reviewsReceivedCount: asInt('reviewsReceivedCount'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'petsCount': petsCount,
      'bookingsCount': bookingsCount,
      'postsCount': postsCount,
      'tasksCount': tasksCount,
      'reviewsGivenCount': reviewsGivenCount,
      'reviewsReceivedCount': reviewsReceivedCount,
    };
  }
}
