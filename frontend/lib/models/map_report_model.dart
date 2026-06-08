// v23.1.147 — i18n : labelFr/hintFr retournent désormais des strings
// traduites via .tr (étaient hardcodés FR avant). Les clés i18n sont
// `map_report_label_<type>` et `map_report_hint_<type>`.
import 'package:get/get.dart';

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
      // v23.1 part 252 — crash audit : as num? (nullable) au lieu de
      // as num pour ne pas crasher si une coord arrive en String.
      lng = (coords[0] as num?)?.toDouble() ?? 0;
      lat = (coords[1] as num?)?.toDouble() ?? 0;
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
  // Session v3.2 — 5 types Premium existants.
  static const String deadAnimal = 'dead_animal';
  static const String trap = 'trap';
  static const String poison = 'poison';
  static const String strayPet = 'stray_pet';
  static const String construction = 'construction';
  // Session v3.4 — 7 nouveaux types Premium (safety étendu).
  static const String busyTraffic = 'busy_traffic';
  static const String fireSmoke = 'fire_smoke';
  static const String flood = 'flood';
  static const String fallenTree = 'fallen_tree';
  static const String chemical = 'chemical';
  static const String wildlife = 'wildlife';
  static const String noDogsZone = 'no_dogs_zone';
  // v23.1.293 — 2 nouveaux types GRATUITS (Daniel).
  static const String food = 'food'; // nourriture laissée dans la rue
  static const String trash = 'trash'; // détritus / poubelle abandonnés

  static const List<String> all = [
    // Gratuits
    aggressiveDog,
    hazard,
    waterActive,
    // Premium (existants)
    poop,
    pee,
    waterBroken,
    lostPet,
    foundPet,
    other,
    deadAnimal,
    trap,
    poison,
    strayPet,
    construction,
    // Premium (session v3.4)
    busyTraffic,
    fireSmoke,
    flood,
    fallenTree,
    chemical,
    wildlife,
    noDogsZone,
    // v23.1.293 — gratuits
    food,
    trash,
  ];

  /// Freemium whitelist — 3 signalements gratuits pour tous les profils
  /// (owner / sitter / walker). Les autres requièrent Premium.
  ///   • 😾 Chien agressif — safety communauté.
  ///   • ⚠️ Danger — zone accidentogène.
  ///   • 🚰 Point d'eau OK — partage utile aux promeneurs.
  ///   • 💀 Animal mort — alerte sanitaire / risque pour les autres animaux.
  static const List<String> freeTypes = [
    aggressiveDog,
    hazard,
    waterActive,
    deadAnimal,
    // v23.1.293 — nouveaux gratuits.
    food,
    trash,
  ];

  /// Returns true if [type] is usable by a free user (no Premium required).
  static bool isFree(String type) => freeTypes.contains(type);

  /// Accent color for each type — used for markers, chips, and tile icons.
  /// Mirrors the backend palette so badges look identical end-to-end.
  static int colorArgb(String t) {
    switch (t) {
      // FREE
      case aggressiveDog: return 0xFFD32F2F; // red
      case hazard:        return 0xFFFF9800; // amber
      case waterActive:   return 0xFF0288D1; // blue
      // PREMIUM - existants
      case poop:          return 0xFF795548; // brown
      case pee:           return 0xFFFFB300; // yellow
      case waterBroken:   return 0xFF455A64; // blue grey
      case lostPet:       return 0xFFEC407A; // pink
      case foundPet:      return 0xFF43A047; // green
      case deadAnimal:    return 0xFF424242; // dark grey
      case trap:          return 0xFF6D4C41; // dark brown
      case poison:        return 0xFF7B1FA2; // purple
      case strayPet:      return 0xFF8D6E63; // light brown
      case construction:  return 0xFFFF7043; // orange
      // PREMIUM - session v3.4
      case busyTraffic:   return 0xFFE65100; // deep orange
      case fireSmoke:     return 0xFFB71C1C; // dark red
      case flood:         return 0xFF01579B; // dark blue
      case fallenTree:    return 0xFF2E7D32; // dark green
      case chemical:      return 0xFFF57F17; // amber dark
      case wildlife:      return 0xFF5D4037; // brown
      case noDogsZone:    return 0xFF37474F; // dark blue grey
      // FREE - v23.1.293
      case food:          return 0xFF8BC34A; // light green
      case trash:         return 0xFF607D8B; // blue grey
      case other:
      default:            return 0xFF9E9E9E; // neutral grey
    }
  }

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
        // v23.1.300 — Daniel : un CHAT (😾) s'affichait pour "chien agressif".
        return '🐕';
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
      // Session v3.4 — 7 nouveaux Premium.
      case busyTraffic:
        return '🚗';
      case fireSmoke:
        return '🔥';
      case flood:
        return '🌊';
      case fallenTree:
        return '🌳';
      case chemical:
        return '🧴';
      case wildlife:
        return '🦊';
      case noDogsZone:
        return '🚫';
      // FREE - v23.1.293
      case food:
        return '🍖';
      case trash:
        return '🗑️';
      default:
        return '📍';
    }
  }

  // v23.1.147 — labels traduits dynamiquement via .tr. Le nom `labelFr`
  // est conservé pour ne pas casser les appelants (paw_map_screen,
  // create_report_sheet). Les clés sont définies dans les 6 fichiers
  // localization/translations/<lang>.dart.
  static String labelFr(String t) {
    return 'map_report_label_$t'.tr;
  }

  /// Hint / placeholder text shown under each report type option in the
  /// CreateReportSheet. Now translated dynamically via .tr.
  static String hintFr(String t) {
    return 'map_report_hint_$t'.tr;
  }
}
