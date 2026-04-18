/// Lightweight model for the `/posts/requests/nearby` endpoint — used by the
/// PawMap "Demandes" layer (sitter / walker view) to drop markers for owner
/// reservation requests within a given radius.
///
/// Intentionally minimal: the backend returns a stripped-down payload (no
/// pets details, no photos) so the map stays fast. When the user taps a
/// marker we navigate to the full request detail screen which will load the
/// richer PostModel separately.
class NearbyRequestPost {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerAvatar;
  final String body;
  final List<String> serviceTypes;
  final String serviceLocation;
  final DateTime? startDate;
  final DateTime? endDate;
  final String city;
  final double lat;
  final double lng;
  final double distanceKm;
  final DateTime? createdAt;

  const NearbyRequestPost({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerAvatar,
    required this.body,
    required this.serviceTypes,
    required this.serviceLocation,
    required this.startDate,
    required this.endDate,
    required this.city,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.createdAt,
  });

  factory NearbyRequestPost.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    final loc = (j['location'] as Map?) ?? const {};
    final services = (j['serviceTypes'] as List?) ?? const [];

    return NearbyRequestPost(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      ownerId: (j['ownerId'] ?? '').toString(),
      ownerName: (j['ownerName'] ?? '').toString(),
      ownerAvatar: (j['ownerAvatar'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      serviceTypes: services.map((s) => s.toString()).toList(),
      serviceLocation: (j['serviceLocation'] ?? '').toString(),
      startDate: parseDate(j['startDate']),
      endDate: parseDate(j['endDate']),
      city: (loc['city'] ?? '').toString(),
      lat: (loc['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (loc['lng'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate(j['createdAt']),
    );
  }
}
