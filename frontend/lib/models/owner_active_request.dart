// v586 (point 9) — demande ACTIVE d'un propriétaire, lue par un gardien /
// promeneur connecté (`GET /posts/requests/by-owner/:ownerId`). Ville seule,
// distance arrondie au km : jamais d'adresse ni de coordonnées.
import 'package:hopetsit/utils/currency_helper.dart';

class OwnerActiveRequestPet {
  final String id;
  final String name;
  final String category;
  const OwnerActiveRequestPet({required this.id, required this.name, this.category = ''});
}

class OwnerActiveRequest {
  final String id;
  final String ownerId;
  final List<String> serviceTypes;
  final DateTime? startDate;
  final DateTime? endDate;
  final String city;
  final int? distanceKm;
  final double budget;
  final String currency;
  final List<String> petIds;
  final List<OwnerActiveRequestPet> pets;

  /// Statut de MA candidature : null (aucune) | pending | accepted | rejected.
  final String? myApplication;

  const OwnerActiveRequest({
    required this.id,
    required this.ownerId,
    this.serviceTypes = const <String>[],
    this.startDate,
    this.endDate,
    this.city = '',
    this.distanceKm,
    this.budget = 0,
    this.currency = 'EUR',
    this.petIds = const <String>[],
    this.pets = const <OwnerActiveRequestPet>[],
    this.myApplication,
  });

  String get budgetLabel => budget > 0 ? CurrencyHelper.formatCompact(currency, budget) : '';

  factory OwnerActiveRequest.fromJson(Map<String, dynamic> j) {
    DateTime? d(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    final pets = ((j['pets'] as List?) ?? const [])
        .whereType<Map>()
        .map((p) => OwnerActiveRequestPet(
              id: (p['id'] ?? '').toString(),
              name: (p['name'] ?? '').toString(),
              category: (p['category'] ?? '').toString(),
            ))
        .toList();
    final String? app = j['myApplication']?.toString();
    return OwnerActiveRequest(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      ownerId: (j['ownerId'] ?? '').toString(),
      serviceTypes: ((j['serviceTypes'] as List?) ?? const []).map((e) => e.toString()).toList(),
      startDate: d(j['startDate']),
      endDate: d(j['endDate']),
      city: (j['city'] ?? '').toString(),
      distanceKm: (j['distanceKm'] as num?)?.round(),
      budget: (j['budget'] as num?)?.toDouble() ?? 0,
      // v587 — devise du budget saisi (sinon celle du propriétaire).
      currency: ((j['budgetCurrency'] ?? '').toString().isNotEmpty
              ? j['budgetCurrency']
              : (j['currency'] ?? 'EUR'))
          .toString(),
      petIds: ((j['petIds'] as List?) ?? const []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
      pets: pets,
      myApplication: (app == null || app.isEmpty) ? null : app,
    );
  }
}
