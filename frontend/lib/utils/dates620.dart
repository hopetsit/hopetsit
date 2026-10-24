// 620 (PAM, 24/10/2026 — contrat CONTRAT_620_dates_visites.md) — « DATES À
// PRÉVOIR » + estimation de prix.
//
//   · `DateMode620` : `exact` (début et fin connus), `approx` (une période,
//     à confirmer), `tbd` (je ne sais pas encore : les candidats montrent leur
//     tarif à l'unité, le total apparaît quand les dates sont posées) ;
//   · `PricingEstimate620` : réponse de `POST /pricing/estimate` — le moteur
//     UNIQUE du serveur (`utils/pricingEngine620.js`). L'app N'A PAS sa propre
//     copie du calcul : sans réponse du serveur, elle n'invente aucun chiffre.
//
// Pur et testable.
import 'dart:async';

import '../data/network/api_client.dart';
import 'services620.dart';

enum DateMode620 { exact, approx, tbd }

DateMode620 dateMode620Parse(dynamic raw, {DateTime? start, DateTime? end}) {
  switch ((raw ?? '').toString().trim().toLowerCase()) {
    case 'exact':
      return DateMode620.exact;
    case 'approx':
    case 'approximate':
      return DateMode620.approx;
    case 'tbd':
    case 'to_be_defined':
      return DateMode620.tbd;
  }
  // Ancienne annonce sans le champ : exact si les deux dates existent, sinon
  // à prévoir (même défaut que le serveur, contrat §A.1).
  return (start != null && end != null) ? DateMode620.exact : DateMode620.tbd;
}

String dateMode620Wire(DateMode620 m) {
  switch (m) {
    case DateMode620.exact:
      return 'exact';
    case DateMode620.approx:
      return 'approx';
    case DateMode620.tbd:
      return 'tbd';
  }
}

/// Clé i18n du libellé court d'un mode (badge sur les cartes).
String dateMode620BadgeKey(DateMode620 m) {
  switch (m) {
    case DateMode620.exact:
      return '';
    case DateMode620.approx:
      return 'dates620_approx_badge';
    case DateMode620.tbd:
      return 'dates620_tbd_badge';
  }
}

/// Visites par jour autorisées (contrat : 1 | 2).
int clampVisitsPerDay620(int? v) => (v ?? 1) >= 2 ? 2 : 1;

/// Réponse du moteur de prix.
class PricingEstimate620 {
  const PricingEstimate620({
    required this.indicative,
    this.quantity,
    this.unitTotal,
    this.commission,
    this.ownerTotal,
    this.rate,
    this.currency = '',
    this.unit = ServiceUnit620.day,
    this.night = false,
    this.fromRate,
    this.ownerTotalFrom,
    this.basedOn = 0,
    this.market = false,
  });

  /// `true` quand `dateMode = tbd` : seule la quantité est inconnue, le
  /// serveur ne renvoie que le tarif unitaire.
  final bool indicative;
  final int? quantity;
  final double? unitTotal;
  final double? commission;
  final double? ownerTotal;
  /// Tarif unitaire utilisé (si le serveur le renvoie).
  final double? rate;
  final String currency;
  final ServiceUnit620 unit;
  /// Garde chez le gardien : quantité en nuits.
  final bool night;
  /// 621 (serveur 620b) — demande OUVERTE (sans prestataire visé) : tarif
  /// « à partir de » = minimum des prestataires du rayon d'alerte.
  final double? fromRate;
  /// 621 — total propriétaire « à partir de » (quantité × fromRate + commission),
  /// null en « dates à prévoir ».
  final double? ownerTotalFrom;
  /// 621 — nombre de prestataires sur lesquels repose le « à partir de »
  /// (0 = aucun : on n'affiche rien).
  final int basedOn;
  /// 621 — réponse de marché (`rateSource: 'market'`, `fromRate` présent).
  final bool market;

  bool get hasTotal => !indicative && ownerTotal != null && ownerTotal! > 0;
  bool get hasQuantity => !indicative && quantity != null && quantity! > 0;
  /// 621 — un « à partir de » exploitable : au moins un prestataire.
  bool get hasFromRate => market && basedOn > 0 && (fromRate ?? 0) > 0;
  bool get hasFromTotal => hasFromRate && (ownerTotalFrom ?? 0) > 0;

  static PricingEstimate620? tryParse(dynamic response) {
    dynamic m = response;
    if (m is Map && m['estimate'] is Map) m = m['estimate'];
    if (m is Map && m['data'] is Map) m = m['data'];
    if (m is! Map) return null;
    double? d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    int? i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    final unitRaw = (m['unit'] ?? m['priceUnit'] ?? '').toString().toLowerCase();
    final indicative = m['indicative'] == true ||
        (m['quantity'] == null && m['ownerTotal'] == null && m['dateMode'] == 'tbd');
    // 621 — réponse « market » (serveur 620b) : `fromRate`, `ownerTotalFrom`,
    // `basedOn`. Un ancien serveur n'envoie aucun de ces champs.
    final market = m['rateSource'] == 'market' ||
        m.containsKey('fromRate') ||
        m.containsKey('basedOn');
    final basedOn = i(m['basedOn']) ?? ((d(m['fromRate']) ?? 0) > 0 ? 1 : 0);
    return PricingEstimate620(
      indicative: indicative,
      market: market,
      fromRate: d(m['fromRate']),
      ownerTotalFrom: d(m['ownerTotalFrom']),
      basedOn: market ? basedOn : 0,
      quantity: i(m['quantity']),
      unitTotal: d(m['unitTotal'] ?? m['basePrice']),
      commission: d(m['commission']),
      ownerTotal: d(m['ownerTotal'] ?? m['totalPrice'] ?? m['total']),
      rate: d(m['rate'] ?? m['unitRate'] ?? m['appliedRate']),
      currency: (m['currency'] ?? '').toString(),
      unit: unitRaw == 'night' ? ServiceUnit620.day : serviceUnit620Parse(unitRaw),
      night: unitRaw == 'night',
    );
  }
}

/// Corps envoyé à `POST /pricing/estimate` (même forme que le moteur :
/// `{ serviceType, unit, rate, post }`, plus les champs à plat pour un
/// serveur qui les lirait ainsi). `rate` est facultatif : sans tarif connu
/// (demande ouverte à tous), le serveur ne renvoie que la quantité.
Map<String, dynamic> estimateBody620({
  required String serviceType,
  required DateMode620 dateMode,
  DateTime? startDate,
  DateTime? endDate,
  int? visitsPerDay,
  int? visitDurationMinutes,
  int? walkDurationMinutes,
  String? houseSittingVenue,
  double? rate,
  String? currency,
  String? providerId,
  String? providerRole,
  double? lat,
  double? lng,
  String? city,
}) {
  final key = ServiceCatalog620.catalogKeyFor(serviceType);
  final unit = ServiceCatalog620.unitFor(serviceType);
  final bool withDates = dateMode != DateMode620.tbd;
  // 621 — position de la demande (serveur 620b : le « à partir de » d'une
  // demande ouverte se calcule autour d'elle, sinon autour du profil).
  final bool hasPos = lat != null && lng != null && (lat != 0 || lng != 0);
  final post = <String, dynamic>{
    'serviceTypes': <String>[key],
    if (hasPos || (city ?? '').trim().isNotEmpty)
      'location': <String, dynamic>{
        if (hasPos) 'lat': lat,
        if (hasPos) 'lng': lng,
        if ((city ?? '').trim().isNotEmpty) 'city': city!.trim(),
      },
    'dateMode': dateMode620Wire(dateMode),
    'startDate': withDates && startDate != null ? startDate.toUtc().toIso8601String() : null,
    'endDate': withDates && endDate != null ? endDate.toUtc().toIso8601String() : null,
    if (unit == ServiceUnit620.visit) 'visitsPerDay': clampVisitsPerDay620(visitsPerDay),
    if (unit == ServiceUnit620.visit && visitDurationMinutes != null)
      'visitDurationMinutes': visitDurationMinutes,
    if (walkDurationMinutes != null) 'walkDurationMinutes': walkDurationMinutes,
    if (houseSittingVenue != null && houseSittingVenue.isNotEmpty)
      'houseSittingVenue': houseSittingVenue,
  };
  // `unit` n'est PAS envoyé : le moteur choisit lui-même (nuit pour une garde
  // chez le gardien, visite, balade…) ; l'app ne fait que lire sa réponse.
  return <String, dynamic>{
    'serviceType': key,
    if (rate != null && rate > 0) 'rate': rate,
    if (currency != null && currency.isNotEmpty) 'currency': currency,
    if (providerId != null && providerId.isNotEmpty) 'providerId': providerId,
    if (providerRole != null && providerRole.isNotEmpty) 'providerRole': providerRole,
    'post': post,
    ...post,
  };
}

/// Appelle le moteur ; null si le serveur ne répond pas (ancien serveur,
/// hors ligne) — l'écran n'affiche alors AUCUN chiffre.
Future<PricingEstimate620?> fetchEstimate620(
  ApiClient client,
  Map<String, dynamic> body,
) async {
  try {
    final res = await client
        .post('/pricing/estimate', body: body, requiresAuth: true)
        .timeout(const Duration(seconds: 8));
    return PricingEstimate620.tryParse(res);
  } catch (_) {
    return null;
  }
}

/// 620 — prestataire visé par une demande lancée depuis la PawMap (fiche d'un
/// membre → « Demander à … ») : identité + tarifs connus par unité,
/// dans SA devise. Un service sans tarif n'est pas proposé pour lui.
class TargetProvider620 {
  const TargetProvider620({
    required this.id,
    required this.role,
    this.name = '',
    this.currency = 'EUR',
    this.rateDay,
    this.rateVisit,
    this.rateWalk,
    this.visitDurationMinutes,
  });

  final String id;
  /// `sitter` | `walker`.
  final String role;
  final String name;
  final String currency;
  final double? rateDay;
  final double? rateVisit;
  final double? rateWalk;
  final int? visitDurationMinutes;

  /// Prénom (le nom complet est trop long pour un bandeau).
  String get firstName {
    final t = name.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).first;
  }

  /// Tarif unitaire pour un service de l'app (`pet_sitting`, `day_care`,
  /// `home_visit`, `dog_walking`) ; null = non proposé.
  double? rateFor(String? service) {
    double? pos(double? v) => (v ?? 0) > 0 ? v : null;
    switch (ServiceCatalog620.unitFor(service)) {
      case ServiceUnit620.walk:
        return role == 'walker' ? pos(rateWalk) : null;
      case ServiceUnit620.visit:
        return role == 'sitter' ? pos(rateVisit) : null;
      case ServiceUnit620.day:
        return role == 'sitter' ? pos(rateDay) : null;
    }
  }

  bool offers(String? service) => rateFor(service) != null;

  Map<String, String> get wire => <String, String>{'role': role, 'id': id};
}
