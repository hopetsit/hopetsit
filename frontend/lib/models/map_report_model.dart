/// Ephemeral 48h map report (Couche 2) — Premium feature.
///
/// Mirrors the backend MapReport schema. Reports auto-expire after 48h
/// (TTL on the server) and can be extended by Premium users via "confirm".
class MapReport {
  final String id;
  final String type;
  final String note;
  final String photoUrl;
  final double latitude;
  final double longitude;
  final String city;
  final String reporterId;
  final String reporterModel;
  final DateTime expiresAt;
  final DateTime createdAt;
  final double hoursRemaining;
  final int confirmationsCount;

  const MapReport({
    required this.id,
    required this.type,
    required this.note,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.reporterId,
    required this.reporterModel,
    required this.expiresAt,
    required this.createdAt,
    this.city = '',
    this.hoursRemaining = 0,
    this.confirmationsCount = 0,
  });

  factory MapReport.fromJson(Map<String, dynamic> j) {
    final loc = (j['location'] as Map?) ?? const {};
    final coords = (loc['coordinates'] as List?) ?? const [];
    double lng = 0;
    double lat = 0;
    if (coords.length >= 2) {
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }
    return MapReport(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      type: (j['type'] as String?) ?? 'other',
      note: (j['note'] as String?) ?? '',
      photoUrl: (j['photoUrl'] as String?) ?? '',
      latitude: lat,
      longitude: lng,
      city: (loc['city'] as String?) ?? '',
      reporterId: j['reporterId']?.toString() ?? '',
      reporterModel: (j['reporterModel'] as String?) ?? '',
      expiresAt: DateTime.tryParse(j['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 48)),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      hoursRemaining: ((j['hoursRemaining'] as num?) ?? 0).toDouble(),
      confirmationsCount: ((j['confirmationsCount'] as num?) ?? 0).toInt(),
    );
  }

  /// Live-computed hours remaining based on expiresAt (more accurate than the
  /// server-stamped `hoursRemaining` which drifts as time passes on the client).
  double get liveHoursRemaining {
    final diff = expiresAt.difference(DateTime.now()).inMinutes;
    return diff < 0 ? 0 : diff / 60.0;
  }

  bool get isExpired => liveHoursRemaining <= 0;
}

/// Known report types — mirrors backend `REPORT_TYPES`.
class ReportTypes {
  ReportTypes._();

  static const String poop = 'poop';
  static const String pee = 'pee';
  static const String waterActive = 'water_active';
  static const String waterBroken = 'water_broken';
  static const String hazard = 'hazard';
  static const String aggressiveDog = 'aggressive_dog';
  static const String lostPet = 'lost_pet';
  static const String foundPet = 'found_pet';
  static const String other = 'other';
  // Session v3.2 — 5 nouveaux types Premium.
  static const String deadAnimal = 'dead_animal';
  static const String trap = 'trap';
  static const String poison = 'poison';
  static const String strayPet = 'stray_pet';
  static const String construction = 'construction';

  static const List<String> all = [
    poop,
    pee,
    waterActive,
    waterBroken,
    hazard,
    aggressiveDog,
    lostPet,
    foundPet,
    other,
    deadAnimal,
    trap,
    poison,
    strayPet,
    construction,
  ];

  /// Freemium whitelist — mirrors backend `FREE_REPORT_TYPES` (session v3.2).
  /// Les 3 types community-safety : animal perdu, chien méchant, point d'eau
  /// actif. found_pet est passé en Premium pour renforcer l'upsell.
  static const List<String> freeTypes = [
    lostPet,
    aggressiveDog,
    waterActive,
  ];

  /// Returns true if [type] is usable by a free user (no Premium required).
  static bool isFree(String type) => freeTypes.contains(type);

  /// Emoji badge per report type — used as map marker + list icon.
  static String emoji(String t) {
    switch (t) {
      case poop:
        return '💩';
      case pee:
        return '💧';
      case waterActive:
        return '🚰';
      case waterBroken:
        return '🚱';
      case hazard:
        return '⚠️';
      case aggressiveDog:
        return '😾';
      case lostPet:
        return '🔎';
      case foundPet:
        return '🤝';
      case deadAnimal:
        return '🪦';
      case trap:
        return '🪤';
      case poison:
        return '☠️';
      case strayPet:
        return '🐕';
      case construction:
        return '🚧';
      default:
        return '📍';
    }
  }

  static String labelFr(String t) {
    switch (t) {
      case poop:
        return 'Caca';
      case pee:
        return 'Pipi';
      case waterActive:
        return 'Point d\'eau OK';
      case waterBroken:
        return 'Point d\'eau cassé';
      case hazard:
        return 'Danger';
      case aggressiveDog:
        return 'Chien méchant';
      case lostPet:
        return 'Animal perdu';
      case foundPet:
        return 'Animal trouvé';
      case deadAnimal:
        return 'Animal décédé';
      case trap:
        return 'Piège repéré';
      case poison:
        return 'Appât empoisonné';
      case strayPet:
        return 'Animal errant';
      case construction:
        return 'Travaux dangereux';
      default:
        return 'Autre';
    }
  }

  /// Short 1-line description used in the picker.
  static String hintFr(String t) {
    switch (t) {
      case poop:
        return 'Déjection à signaler pour qu\'on l\'évite';
      case pee:
        return 'Zone de marquage intense';
      case waterActive:
        return 'Fontaine / point d\'eau en service';
      case waterBroken:
        return 'Point d\'eau cassé ou fermé';
      case hazard:
        return 'Verre, piège, produit dangereux';
      case aggressiveDog:
        return 'Chien non-tenu ou agressif — à éviter';
      case lostPet:
        return 'Animal perdu aperçu ici';
      case foundPet:
        return 'Animal trouvé — contactez-moi';
      case deadAnimal:
        return 'Carcasse / animal décédé';
      case trap:
        return 'Piège à animaux installé ici';
      case poison:
        return 'Appât suspect — pas laisser approcher';
      case strayPet:
        return 'Animal sans collier qui erre';
      case construction:
        return 'Zone de travaux à éviter avec ton animal';
      default:
        return 'Autre signalement';
    }
  }
}
