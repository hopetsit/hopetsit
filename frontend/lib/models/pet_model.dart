class PetModel {
  final String id;
  final String ownerId;
  final String petName;
  final String breed;
  final String dob;
  final String weight;
  final String height;
  final String passportNumber;
  final String chipNumber;
  final String medicationAllergies;
  final String category;
  final String vaccination;
  final String bio;
  final String colour;
  final String profileView;
  final String age;
  final List<String> vaccinations;
  /// Sprint 5 step 5 — enriched pet profile.
  final String behavior;
  final PetVet regularVet;
  final PetVet emergencyVet;
  final bool emergencyInterventionAuthorization;
  final String emergencyAuthorizationText;
  final List<dynamic> photos;
  final List<dynamic> videos;
  final String createdAt;
  final String updatedAt;
  final PetAvatar avatar;
  final PetPassportImage passportImage;
  final PetOwnerInfo? owner; // Owner information from API response

  PetModel({
    required this.id,
    required this.ownerId,
    required this.petName,
    required this.breed,
    required this.dob,
    required this.weight,
    required this.height,
    required this.passportNumber,
    required this.chipNumber,
    required this.medicationAllergies,
    required this.category,
    required this.vaccination,
    required this.bio,
    required this.colour,
    required this.profileView,
    required this.age,
    required this.vaccinations,
    this.behavior = '',
    this.regularVet = const PetVet(),
    this.emergencyVet = const PetVet(),
    this.emergencyInterventionAuthorization = false,
    this.emergencyAuthorizationText = '',
    required this.photos,
    required this.videos,
    required this.createdAt,
    required this.updatedAt,
    required this.avatar,
    required this.passportImage,
    this.owner,
  });

  factory PetModel.fromJson(Map<String, dynamic> json) {
    // Handle weight - can be number or string
    String weightStr = '';
    if (json['weight'] != null) {
      if (json['weight'] is num) {
        weightStr = json['weight'].toString();
      } else {
        weightStr = json['weight'].toString();
      }
    }

    // Handle height - can be number or string
    String heightStr = '';
    if (json['height'] != null) {
      if (json['height'] is num) {
        heightStr = json['height'].toString();
      } else {
        heightStr = json['height'].toString();
      }
    }

    // Handle age - can be number or string
    String ageStr = '';
    if (json['age'] != null) {
      if (json['age'] is num) {
        ageStr = json['age'].toString();
      } else {
        ageStr = json['age'].toString();
      }
    }

    // Handle category - can be 'category' or 'petType'
    String categoryStr =
        json['category'] as String? ?? json['petType'] as String? ?? '';

    // Handle description - can be 'description' or 'bio'
    String bioStr =
        json['bio'] as String? ?? json['description'] as String? ?? '';

    return PetModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      petName: json['petName'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      dob: json['dob'] as String? ?? '',
      weight: weightStr,
      height: heightStr,
      passportNumber: json['passportNumber'] as String? ?? '',
      chipNumber: json['chipNumber'] as String? ?? '',
      medicationAllergies: json['medicationAllergies'] as String? ?? '',
      category: categoryStr,
      vaccination: json['vaccination'] as String? ?? '',
      bio: bioStr,
      colour: json['colour'] as String? ?? json['color'] as String? ?? '',
      profileView: json['profileView'] as String? ?? '',
      age: ageStr,
      vaccinations:
          (json['vaccinations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      behavior: json['behavior'] as String? ?? '',
      regularVet: PetVet.fromJson(json['regularVet'] as Map<String, dynamic>? ?? const {}),
      emergencyVet: PetVet.fromJson(json['emergencyVet'] as Map<String, dynamic>? ?? const {}),
      emergencyInterventionAuthorization:
          json['emergencyInterventionAuthorization'] == true,
      emergencyAuthorizationText: json['emergencyAuthorizationText'] as String? ?? '',
      photos: json['photos'] as List<dynamic>? ?? [],
      videos: json['videos'] as List<dynamic>? ?? [],
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: PetAvatar.fromJson(json['avatar'] as Map<String, dynamic>? ?? {}),
      passportImage: PetPassportImage.fromJson(
        json['passportImage'] as Map<String, dynamic>? ?? {},
      ),
      owner: json['owner'] != null
          ? PetOwnerInfo.fromJson(json['owner'] as Map<String, dynamic>)
          : (json['name'] != null || json['email'] != null
                ? PetOwnerInfo.fromJson(json)
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'petName': petName,
      'breed': breed,
      'dob': dob,
      'weight': weight,
      'height': height,
      'passportNumber': passportNumber,
      'chipNumber': chipNumber,
      'medicationAllergies': medicationAllergies,
      'category': category,
      'vaccination': vaccination,
      'bio': bio,
      'colour': colour,
      'profileView': profileView,
      'age': age,
      'vaccinations': vaccinations,
      'behavior': behavior,
      'regularVet': regularVet.toJson(),
      'emergencyVet': emergencyVet.toJson(),
      'emergencyInterventionAuthorization': emergencyInterventionAuthorization,
      'emergencyAuthorizationText': emergencyAuthorizationText,
      'photos': photos,
      'videos': videos,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'avatar': avatar.toJson(),
      'passportImage': passportImage.toJson(),
      if (owner != null) 'owner': owner!.toJson(),
    };
  }
}

class PetVet {
  final String name;
  final String phone;
  final String address;

  const PetVet({this.name = '', this.phone = '', this.address = ''});

  factory PetVet.fromJson(Map<String, dynamic> json) {
    return PetVet(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
      };
}

class PetOwnerInfo {
  final String name;
  final String email;
  final String avatar;
  // v22.1 — Bug 11c : ville du propriétaire pour la page détails animal
  // côté sitter. Le backend doit la fournir dans `pet.owner.city` ou
  // `pet.owner.location.city` (on essaie les deux dans fromJson).
  final String city;
  final String createdAt;
  final String updatedAt;

  PetOwnerInfo({
    required this.name,
    required this.email,
    required this.avatar,
    this.city = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory PetOwnerInfo.fromJson(Map<String, dynamic> json) {
    String resolvedCity = '';
    if (json['city'] is String) {
      resolvedCity = json['city'] as String;
    } else if (json['location'] is Map<String, dynamic>) {
      final loc = json['location'] as Map<String, dynamic>;
      resolvedCity = (loc['city'] as String?) ?? '';
    }
    return PetOwnerInfo(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      city: resolvedCity,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'avatar': avatar,
      'city': city,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class PetAvatar {
  final String url;
  final String publicId;

  PetAvatar({required this.url, required this.publicId});

  factory PetAvatar.fromJson(Map<String, dynamic> json) {
    return PetAvatar(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'publicId': publicId};
  }
}

class PetPassportImage {
  final String url;
  final String publicId;
  final String uploadedAt;

  PetPassportImage({
    required this.url,
    required this.publicId,
    required this.uploadedAt,
  });

  factory PetPassportImage.fromJson(Map<String, dynamic> json) {
    return PetPassportImage(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
      uploadedAt: json['uploadedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'publicId': publicId, 'uploadedAt': uploadedAt};
  }
}
