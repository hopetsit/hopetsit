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
    };
  }
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
