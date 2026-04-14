class PetMapItem {
  final String id;
  final String name;
  final String petType;
  final String avatarUrl;
  final double latitude;
  final double longitude;
  final String ownerId;
  final double? distanceKm;

  PetMapItem({
    required this.id,
    required this.name,
    required this.petType,
    required this.avatarUrl,
    required this.latitude,
    required this.longitude,
    required this.ownerId,
    this.distanceKm,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'petType': petType,
    'avatarUrl': avatarUrl,
    'latitude': latitude,
    'longitude': longitude,
    'ownerId': ownerId,
    'distanceKm': distanceKm,
  };

  factory PetMapItem.fromJson(Map<String, dynamic> json) => PetMapItem(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    petType: json['petType']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString() ?? '',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    ownerId: json['ownerId']?.toString() ?? '',
    distanceKm: json['distanceKm'] != null
        ? (json['distanceKm'] as num).toDouble()
        : null,
  );
}
