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
  // v406 refonte — sexe + fiche enrichie (onglets À propos / Santé / Habitudes).
  final String gender; // '' (non spécifié) | 'male' | 'female'
  // À propos
  final List<String> characterTraits;
  final PetCompatibilities compatibilities;
  final String history;
  final List<String> particularities;
  final String notes;
  // Santé
  final String vaccinationStatus; // '' | 'up_to_date' | 'partial' | 'late' | 'unknown'
  // v440 — santé additive : stérilisé / pucé / restrictions alimentaires.
  final bool sterilized;
  final bool microchipped;
  final String foodRestrictions;
  final PetDeworming deworming;
  final String currentTreatments;
  final String bloodGroup;
  final PetHealthInsurance healthInsurance;
  // Habitudes
  final PetHabits habits;

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
    this.gender = '',
    this.characterTraits = const [],
    this.compatibilities = const PetCompatibilities(),
    this.history = '',
    this.particularities = const [],
    this.notes = '',
    this.vaccinationStatus = '',
    this.sterilized = false,
    this.microchipped = false,
    this.foodRestrictions = '',
    this.deworming = const PetDeworming(),
    this.currentTreatments = '',
    this.bloodGroup = '',
    this.healthInsurance = const PetHealthInsurance(),
    this.habits = const PetHabits(),
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
      gender: json['gender'] as String? ?? '',
      characterTraits: (json['characterTraits'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      compatibilities: PetCompatibilities.fromJson(
          json['compatibilities'] as Map<String, dynamic>? ?? const {}),
      history: json['history'] as String? ?? '',
      particularities: (json['particularities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      notes: json['notes'] as String? ?? '',
      vaccinationStatus: json['vaccinationStatus'] as String? ?? '',
      sterilized: json['sterilized'] == true,
      microchipped: json['microchipped'] == true,
      foodRestrictions: json['foodRestrictions'] as String? ?? '',
      deworming: PetDeworming.fromJson(
          json['deworming'] as Map<String, dynamic>? ?? const {}),
      currentTreatments: json['currentTreatments'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String? ?? '',
      healthInsurance: PetHealthInsurance.fromJson(
          json['healthInsurance'] as Map<String, dynamic>? ?? const {}),
      habits: PetHabits.fromJson(
          json['habits'] as Map<String, dynamic>? ?? const {}),
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
      'gender': gender,
      'characterTraits': characterTraits,
      'compatibilities': compatibilities.toJson(),
      'history': history,
      'particularities': particularities,
      'notes': notes,
      'vaccinationStatus': vaccinationStatus,
      'sterilized': sterilized,
      'microchipped': microchipped,
      'foodRestrictions': foodRestrictions,
      'deworming': deworming.toJson(),
      'currentTreatments': currentTreatments,
      'bloodGroup': bloodGroup,
      'healthInsurance': healthInsurance.toJson(),
      'habits': habits.toJson(),
    };
  }
}

/// v406 — compatibilités de l'animal (chiens / chats / enfants).
/// Valeurs : 'compatible' | 'supervised' | 'no' | '' (non renseigné).
class PetCompatibilities {
  final String withDogs;
  final String withCats;
  final String withChildren;
  // v440 — compatibilité avec les NAC (additif).
  final String withNac;

  const PetCompatibilities({
    this.withDogs = '',
    this.withCats = '',
    this.withChildren = '',
    this.withNac = '',
  });

  factory PetCompatibilities.fromJson(Map<String, dynamic> json) {
    return PetCompatibilities(
      withDogs: json['withDogs'] as String? ?? '',
      withCats: json['withCats'] as String? ?? '',
      withChildren: json['withChildren'] as String? ?? '',
      withNac: json['withNac'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'withDogs': withDogs,
        'withCats': withCats,
        'withChildren': withChildren,
        'withNac': withNac,
      };

  bool get isEmpty =>
      withDogs.isEmpty &&
      withCats.isEmpty &&
      withChildren.isEmpty &&
      withNac.isEmpty;
}

/// v406 — vermifuge (dernière date + fréquence).
class PetDeworming {
  final String lastDate;
  final String frequency;

  const PetDeworming({this.lastDate = '', this.frequency = ''});

  factory PetDeworming.fromJson(Map<String, dynamic> json) {
    return PetDeworming(
      lastDate: json['lastDate']?.toString() ?? '',
      frequency: json['frequency'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        if (lastDate.isNotEmpty) 'lastDate': lastDate,
        'frequency': frequency,
      };

  bool get isEmpty => lastDate.isEmpty && frequency.isEmpty;
}

/// v406 — assurance santé animale (nom + numéro).
class PetHealthInsurance {
  final String name;
  final String number;

  const PetHealthInsurance({this.name = '', this.number = ''});

  factory PetHealthInsurance.fromJson(Map<String, dynamic> json) {
    return PetHealthInsurance(
      name: json['name'] as String? ?? '',
      number: json['number'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'number': number};

  bool get isEmpty => name.isEmpty && number.isEmpty;
}

/// v406 — habitudes de vie de l'animal (onglet Habitudes).
class PetHabits {
  final String energyLevel;
  final String preferredActivity;
  final String education;
  final String aloneTolerance;
  final String barking;
  final String likes;
  final String dislikes;
  final String transport;
  final String brushing;
  final String food;
  final String allowedTreats;
  final String favoriteObjects;
  final String favoritePlaces;
  final String remarks;
  // v440 — habitudes additives (onglet Habitudes maquette).
  final String sleep; // '' | 'indoor' | 'outdoor' | 'crate'
  final String housetrained; // '' | 'yes' | 'learning'
  final String leashBehaviour; // '' | 'off_leash' | 'on_leash' | 'reliable_recall'
  final String fears;

  const PetHabits({
    this.energyLevel = '',
    this.preferredActivity = '',
    this.education = '',
    this.aloneTolerance = '',
    this.barking = '',
    this.likes = '',
    this.dislikes = '',
    this.transport = '',
    this.brushing = '',
    this.food = '',
    this.allowedTreats = '',
    this.favoriteObjects = '',
    this.favoritePlaces = '',
    this.remarks = '',
    this.sleep = '',
    this.housetrained = '',
    this.leashBehaviour = '',
    this.fears = '',
  });

  factory PetHabits.fromJson(Map<String, dynamic> json) {
    return PetHabits(
      energyLevel: json['energyLevel'] as String? ?? '',
      preferredActivity: json['preferredActivity'] as String? ?? '',
      education: json['education'] as String? ?? '',
      aloneTolerance: json['aloneTolerance'] as String? ?? '',
      barking: json['barking'] as String? ?? '',
      likes: json['likes'] as String? ?? '',
      dislikes: json['dislikes'] as String? ?? '',
      transport: json['transport'] as String? ?? '',
      brushing: json['brushing'] as String? ?? '',
      food: json['food'] as String? ?? '',
      allowedTreats: json['allowedTreats'] as String? ?? '',
      favoriteObjects: json['favoriteObjects'] as String? ?? '',
      favoritePlaces: json['favoritePlaces'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      sleep: json['sleep'] as String? ?? '',
      housetrained: json['housetrained'] as String? ?? '',
      leashBehaviour: json['leashBehaviour'] as String? ?? '',
      fears: json['fears'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'energyLevel': energyLevel,
        'preferredActivity': preferredActivity,
        'education': education,
        'aloneTolerance': aloneTolerance,
        'barking': barking,
        'likes': likes,
        'dislikes': dislikes,
        'transport': transport,
        'brushing': brushing,
        'food': food,
        'allowedTreats': allowedTreats,
        'favoriteObjects': favoriteObjects,
        'favoritePlaces': favoritePlaces,
        'remarks': remarks,
        'sleep': sleep,
        'housetrained': housetrained,
        'leashBehaviour': leashBehaviour,
        'fears': fears,
      };

  bool get isEmpty =>
      energyLevel.isEmpty &&
      preferredActivity.isEmpty &&
      education.isEmpty &&
      aloneTolerance.isEmpty &&
      barking.isEmpty &&
      likes.isEmpty &&
      dislikes.isEmpty &&
      transport.isEmpty &&
      brushing.isEmpty &&
      food.isEmpty &&
      allowedTreats.isEmpty &&
      favoriteObjects.isEmpty &&
      favoritePlaces.isEmpty &&
      remarks.isEmpty &&
      sleep.isEmpty &&
      housetrained.isEmpty &&
      leashBehaviour.isEmpty &&
      fears.isEmpty;
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
