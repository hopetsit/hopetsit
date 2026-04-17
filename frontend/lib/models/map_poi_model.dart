/// Simple model mirroring backend MapPOI documents.
class MapPOI {
  final String id;
  final String title;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final String address;
  final String phone;
  final String website;
  final String openingHours;
  final String source; // 'seed' | 'user' | 'admin'
  final double rating;
  final int reviewsCount;

  const MapPOI({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.city = '',
    this.country = '',
    this.address = '',
    this.phone = '',
    this.website = '',
    this.openingHours = '',
    this.source = 'user',
    this.rating = 0,
    this.reviewsCount = 0,
  });

  factory MapPOI.fromJson(Map<String, dynamic> j) {
    final loc = (j['location'] as Map?) ?? const {};
    final coords = (loc['coordinates'] as List?) ?? const [];
    double lng = 0;
    double lat = 0;
    if (coords.length >= 2) {
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }
    return MapPOI(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      title: (j['title'] as String?) ?? '',
      description: (j['description'] as String?) ?? '',
      category: (j['category'] as String?) ?? 'other',
      latitude: lat,
      longitude: lng,
      city: (loc['city'] as String?) ?? '',
      country: (loc['country'] as String?) ?? '',
      address: (j['address'] as String?) ?? '',
      phone: (j['phone'] as String?) ?? '',
      website: (j['website'] as String?) ?? '',
      openingHours: (j['openingHours'] as String?) ?? '',
      source: (j['source'] as String?) ?? 'user',
      rating: ((j['rating'] as num?) ?? 0).toDouble(),
      reviewsCount: ((j['reviewsCount'] as num?) ?? 0).toInt(),
    );
  }
}

/// Known POI categories — mirrors backend POI_CATEGORIES.
class PoiCategories {
  PoiCategories._();

  static const String vet = 'vet';
  static const String shop = 'shop';
  static const String groomer = 'groomer';
  static const String park = 'park';
  static const String beach = 'beach';
  static const String water = 'water';
  static const String trainer = 'trainer';
  static const String hotel = 'hotel';
  static const String restaurant = 'restaurant';
  static const String other = 'other';

  static const List<String> all = [
    vet, shop, groomer, park, beach, water, trainer, hotel, restaurant, other,
  ];

  /// Emoji badge per category.
  static String emoji(String c) {
    switch (c) {
      case vet: return '🏥';
      case shop: return '🛍️';
      case groomer: return '✂️';
      case park: return '🌳';
      case beach: return '🏖️';
      case water: return '💧';
      case trainer: return '🎓';
      case hotel: return '🏨';
      case restaurant: return '🍽️';
      default: return '📍';
    }
  }

  /// French display label.
  static String labelFr(String c) {
    switch (c) {
      case vet: return 'Vétérinaire';
      case shop: return 'Animalerie';
      case groomer: return 'Toiletteur';
      case park: return 'Parc à chiens';
      case beach: return 'Plage';
      case water: return 'Point d\'eau';
      case trainer: return 'Éducateur';
      case hotel: return 'Hôtel pet-friendly';
      case restaurant: return 'Restaurant pet-friendly';
      default: return 'Autre';
    }
  }
}
