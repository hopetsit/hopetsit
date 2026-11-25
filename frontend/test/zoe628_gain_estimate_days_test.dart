// 628 (ZOE, 29/10/2026) — mesuré au simulateur (gardien test, zone fictive) :
// une garde chez le propriétaire du 12/11 9 h au 14/11 9 h, gardien à 20 €/j et
// 10 €/h, affichait « Votre gain estimé : Client paie 576 € / Vous recevez 480 € »
// (48 h × 10 €/h) alors que le serveur (pricingEngine620) facture 3 jours × 20 €
// = 60 € au gardien, 72 € au propriétaire. L'estimateur suit désormais la même
// règle : jours calendaires (fin − début + 1, UTC) × tarif jour, nuits = jours − 1
// chez le gardien.
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/post_price_estimator.dart';

PostModel _post({required List<String> services, required DateTime start, DateTime? end, String? venue}) {
  return PostModel.fromJson(<String, dynamic>{
    'id': 'p628', 'postType': 'request', 'body': 'Garde', 'serviceTypes': services,
    'startDate': start.toUtc().toIso8601String(),
    if (end != null) 'endDate': end.toUtc().toIso8601String(),
    if (venue != null) 'houseSittingVenue': venue,
    'notes': '', 'images': const [], 'videos': const [], 'likes': const [], 'comments': const [],
    'createdAt': '2026-10-29T10:00:00Z', 'updatedAt': '2026-10-29T10:00:00Z',
    'owner': <String, dynamic>{'id': 'o1', 'name': 'Camille Durand'},
  });
}

PostPriceEstimate? _est(PostModel p, {double hourly = 10, double daily = 20, double weekly = 0, double monthly = 0}) =>
    estimatePostPrice(post: p, userRole: 'sitter', hourlyRate: hourly, dailyRate: daily, weeklyRate: weekly,
        monthlyRate: monthly, currency: 'EUR', commissionRate: 0.20);

void main() {
  test('jours calendaires = règle dayCount du serveur', () {
    expect(calendarDays628(DateTime.utc(2026, 11, 12, 9), DateTime.utc(2026, 11, 14, 9)), 3);
    expect(calendarDays628(DateTime.utc(2026, 11, 10), DateTime.utc(2026, 11, 12)), 3);
    expect(calendarDays628(DateTime.utc(2026, 11, 10, 10), DateTime.utc(2026, 11, 10, 18)), 1);
    expect(calendarDays628(DateTime.utc(2026, 11, 10), null), 1);
    expect(calendarDays628(DateTime.utc(2026, 11, 12), DateTime.utc(2026, 11, 10)), 1, reason: 'fin avant début → 1');
  });

  test('garde 12/11 9 h → 14/11 9 h chez le propriétaire : 3 j × 20 € = 60 € net, 72 € client (pas 480 €)', () {
    final est = _est(_post(services: ['house_sitting'], start: DateTime.utc(2026, 11, 12, 9), end: DateTime.utc(2026, 11, 14, 9), venue: 'owners_home'))!;
    expect(est.net, 60);
    expect(est.brut, closeTo(72, 0.001));
    expect(est.unit, 'day');
  });

  test('même garde chez le gardien : 2 nuits × 20 € = 40 € net, 48 € client', () {
    final est = _est(_post(services: ['house_sitting'], start: DateTime.utc(2026, 11, 12, 9), end: DateTime.utc(2026, 11, 14, 9), venue: 'sitters_home'))!;
    expect(est.net, 40);
    expect(est.brut, closeTo(48, 0.001));
    expect(est.unit, 'night');
  });

  test('garde d un seul jour 10 h → 18 h : 1 × tarif jour (jamais 8 h × horaire)', () {
    final est = _est(_post(services: ['pet_sitting'], start: DateTime.utc(2026, 11, 10, 10), end: DateTime.utc(2026, 11, 10, 18)))!;
    expect(est.net, 20);
    expect(est.unit, 'day');
  });

  // 646 (PAM, 25/11/2026) — le serveur ne calcule plus jamais « heure × 8 »
  // (candidature en « tarif à venir ») : l'estimateur ne doit plus afficher
  // 240 €. Ce test affirmait l'ancienne règle ; il affirme la nouvelle.
  test('sans tarif jour : plus de « horaire × 8 » → aucun gain (avant : 240 €)', () {
    final est = _est(_post(services: ['house_sitting'], start: DateTime.utc(2026, 11, 12), end: DateTime.utc(2026, 11, 14)), hourly: 10, daily: 0);
    expect(est, isNull);
  });

  // 646 (ZOE, 25/11/2026) — paliers alignés sur le serveur (pricingEngine620.dailyTotalWithWeekly).
  test('7 jours, tarif semaine seul 120 € : tarif jour = 120 ÷ 7 = 17,14 € ; semaine (120) < 7 × 17,14 (119,98) non → 119,98 €', () {
    final est = _est(_post(services: ['house_sitting'], start: DateTime.utc(2026, 11, 1), end: DateTime.utc(2026, 11, 7)), daily: 0, weekly: 120)!;
    expect(est.unit, 'day');
    expect(est.net, 119.98);
    expect(est.brut, 143.98);
  });
}
