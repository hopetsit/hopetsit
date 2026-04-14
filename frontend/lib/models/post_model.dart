import 'dart:convert';

class PostModel {
  final String id;
  final String postType;
  final String body;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> serviceTypes;
  final String? houseSittingVenue;
  final String? petId;
  final PostLocation? location;
  final String notes;
  final List<PostImage> images;
  final List<PostVideo> videos;
  final List<PostLike> likes;
  final List<PostComment> comments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PostOwner owner;
  final int likesCount;
  final int commentsCount;
  final List<PostPet> pets;
  /// Sprint 4 step 6 — body translated to each supported locale. Empty map if none.
  final Map<String, String> translations;
  final String sourceLanguage;

  PostModel({
    required this.id,
    required this.postType,
    required this.body,
    this.startDate,
    this.endDate,
    required this.serviceTypes,
    this.houseSittingVenue,
    this.petId,
    this.location,
    required this.notes,
    required this.images,
    required this.videos,
    required this.likes,
    required this.comments,
    required this.createdAt,
    required this.updatedAt,
    required this.owner,
    required this.likesCount,
    required this.commentsCount,
    required this.pets,
    this.translations = const <String, String>{},
    this.sourceLanguage = '',
  });

  /// Returns the body translated to [locale] if available, else falls back to the original body.
  String bodyForLocale(String locale) {
    final key = locale.toLowerCase();
    final t = translations[key];
    if (t != null && t.trim().isNotEmpty) return t;
    return body;
  }

  /// True if this post has reservation request data (dates, location, service, pet).
  bool get isReservationRequest =>
      startDate != null ||
      endDate != null ||
      serviceTypes.isNotEmpty ||
      location != null ||
      (petId != null && petId!.isNotEmpty);

  factory PostModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    List<String> parseServiceTypes(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString()).toList();
      }
      if (v is String && v.isNotEmpty) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
        return [v];
      }
      return <String>[];
    }

    PostLocation? parseLocation(dynamic v) {
      if (v is Map<String, dynamic>) {
        return PostLocation.fromJson(v);
      }
      return null;
    }

    return PostModel(
      id: json['id'] as String? ?? '',
      postType: json['postType'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      serviceTypes: parseServiceTypes(json['serviceTypes']),
      houseSittingVenue: json['houseSittingVenue'] as String?,
      petId: json['petId'] as String?,
      location: parseLocation(json['location']),
      notes: json['notes'] as String? ?? '',
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => PostImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      videos:
          (json['videos'] as List<dynamic>?)
              ?.map((e) => PostVideo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      likes:
          (json['likes'] as List<dynamic>?)
              ?.map((e) => PostLike.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((e) => PostComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      owner: json['owner'] != null
          ? PostOwner.fromJson(json['owner'] as Map<String, dynamic>)
          : PostOwner(
              id: json['ownerId'] as String? ?? '',
              name: '',
              email: '',
              avatar: '',
            ),
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      pets:
          (json['pets'] as List<dynamic>?)
              ?.map((e) => PostPet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      translations: (json['translations'] is Map)
          ? (json['translations'] as Map).map(
              (k, v) => MapEntry(k.toString().toLowerCase(), (v ?? '').toString()),
            )
          : const <String, String>{},
      sourceLanguage: (json['sourceLanguage'] as String?) ?? '',
    );
  }

  /// Checks if the current user has liked this post.
  bool isLikedByUser(String userId) {
    return likes.any((like) => like.userId == userId);
  }

  /// Creates a copy of this post with updated like status.
  PostModel copyWith({List<PostLike>? likes, int? likesCount}) {
    return PostModel(
      id: id,
      postType: postType,
      body: body,
      startDate: startDate,
      endDate: endDate,
      serviceTypes: serviceTypes,
      houseSittingVenue: houseSittingVenue,
      petId: petId,
      location: location,
      notes: notes,
      images: images,
      videos: videos,
      likes: likes ?? this.likes,
      comments: comments,
      createdAt: createdAt,
      updatedAt: updatedAt,
      owner: owner,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount,
      pets: pets,
    );
  }
}

class PostLocation {
  final String city;
  final double? lat;
  final double? lng;

  PostLocation({required this.city, this.lat, this.lng});

  factory PostLocation.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String && v.isNotEmpty) return double.tryParse(v);
      return null;
    }

    return PostLocation(
      city: json['city'] as String? ?? '',
      lat: toDouble(json['lat']),
      lng: toDouble(json['lng']),
    );
  }
}

class PostImage {
  final String url;
  final String publicId;
  final DateTime uploadedAt;

  PostImage({
    required this.url,
    required this.publicId,
    required this.uploadedAt,
  });

  factory PostImage.fromJson(Map<String, dynamic> json) {
    return PostImage(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'] as String)
          : DateTime.now(),
    );
  }
}

class PostVideo {
  final String url;
  final String publicId;
  final DateTime uploadedAt;

  PostVideo({
    required this.url,
    required this.publicId,
    required this.uploadedAt,
  });

  factory PostVideo.fromJson(Map<String, dynamic> json) {
    return PostVideo(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'] as String)
          : DateTime.now(),
    );
  }
}

class PostLike {
  final String id;
  final String userId;
  final DateTime createdAt;

  PostLike({required this.id, required this.userId, required this.createdAt});

  factory PostLike.fromJson(Map<String, dynamic> json) {
    return PostLike(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class PostComment {
  final String id;
  final String userId;
  final String userRole;
  final String authorName;
  final String authorAvatar;
  final String body;
  final DateTime createdAt;

  PostComment({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.authorName,
    required this.authorAvatar,
    required this.body,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userRole: json['userRole'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorAvatar: json['authorAvatar'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class PostOwner {
  final String id;
  final String name;
  final String email;
  final String avatar;

  PostOwner({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
  });

  factory PostOwner.fromJson(Map<String, dynamic> json) {
    return PostOwner(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
    );
  }
}

class PostPet {
  final String id;
  final String petName;
  final String avatar;
  final List<PostImage> photos;

  PostPet({
    required this.id,
    required this.petName,
    required this.avatar,
    required this.photos,
  });

  factory PostPet.fromJson(Map<String, dynamic> json) {
    return PostPet(
      id: json['id'] as String? ?? '',
      petName: json['petName'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      photos:
          (json['photos'] as List<dynamic>?)
              ?.map((e) => PostImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
