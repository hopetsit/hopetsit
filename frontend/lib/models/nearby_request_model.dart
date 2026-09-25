/// Lightweight model for the `/posts/requests/nearby` endpoint — used by the
/// PawMap "Demandes" layer (sitter / walker view) to drop markers for owner
/// reservation requests within a given radius.
///
/// Intentionally minimal: the backend returns a stripped-down payload (no
/// pets details, no photos) so the map stays fast. When the user taps a
/// marker we navigate to the full request detail screen which will load the
/// richer PostModel separately.
import 'package:hopetsit/utils/currency_helper.dart';

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
  /// v584 — budget annoncé par le propriétaire (0 = non renseigné : la bulle
  /// n'affiche alors que l'icône du service) et sa devise.
  final double budget;
  final String currency;
  /// v584 — animaux de l'annonce (nécessaires pour « Proposer mes services »
  /// en un appui : une candidature porte toujours au moins un animal).
  final List<String> petIds;
  /// v584 — position approximative (~1 km) renvoyée par le serveur.
  final bool approx;

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
    this.budget = 0,
    this.currency = 'EUR',
    this.petIds = const <String>[],
    this.approx = false,
  });

  /// « 25 € » (ou « $25 » en anglais) ou vide sans budget — lot D : même
  /// helper que partout ailleurs (`CurrencyHelper.formatCompact`).
  String get budgetLabel {
    if (budget <= 0) return '';
    return CurrencyHelper.formatCompact(currency, budget);
  }

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
      budget: (j['budget'] as num?)?.toDouble() ?? 0.0,
      currency: (j['currency'] ?? 'EUR').toString(),
      petIds: ((j['petIds'] as List?) ?? const [])
          .map((e) => e is Map ? (e['_id'] ?? e['id'] ?? '').toString() : e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      approx: j['approx'] == true || loc['approx'] == true,
    );
  }
}
