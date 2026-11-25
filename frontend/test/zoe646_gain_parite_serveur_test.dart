// 646 (ZOE, contrôle du 25/11/2026 — ordre de Daniel : « le gain affiché doit
// être EXACTEMENT celui du serveur »). Les chiffres attendus ci-dessous ont été
// CALCULÉS PAR LE MOTEUR DU SERVEUR lui-même (`applicationRepricing620.
// priceApplication` → `pricingEngine620`, lancé avec node le 25/11) : `net` =
// ce que reçoit le prestataire (basePrice), `owner` = ce que paie le
// propriétaire (totalPrice, commission 20 %).
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/post_price_estimator.dart';

PostModel _post(String service, int days, {String? venue, int? visitsPerDay, int? walkMinutes, bool noEnd = false, Duration? span}) {
  final start = DateTime.utc(2026, 12, 1, 9);
  final end = span != null ? start.add(span) : DateTime.utc(2026, 12, days, 9);
  return PostModel.fromJson(<String, dynamic>{
    'id': 'p646z', 'postType': 'request', 'body': 'ZOE 646', 'serviceTypes': <String>[service],
    'startDate': start.toIso8601String(),
    if (!noEnd) 'endDate': end.toIso8601String(),
    if (venue != null) 'houseSittingVenue': venue,
    if (visitsPerDay != null) 'visitsPerDay': visitsPerDay,
    if (walkMinutes != null) 'walkDurationMinutes': walkMinutes,
    'notes': '', 'images': const [], 'videos': const [], 'likes': const [], 'comments': const [],
    'createdAt': '2026-11-25T10:00:00Z', 'updatedAt': '2026-11-25T10:00:00Z',
    'owner': <String, dynamic>{'id': 'o1', 'name': 'Camille Durand'},
  });
}

PostPriceEstimate? _sitter(PostModel p, {double hourly = 0, double daily = 0, double weekly = 0, double monthly = 0, double visit = 0}) =>
    estimatePostPrice(post: p, userRole: 'sitter', hourlyRate: hourly, dailyRate: daily, weeklyRate: weekly,
        monthlyRate: monthly, visitRate: visit, currency: 'EUR', commissionRate: 0.20);

PostPriceEstimate? _walker(PostModel p, {double? r30, double? r60}) => estimatePostPrice(
    post: p, userRole: 'walker', hourlyRate: (r60 ?? 0) > 0 ? r60! : (r30 ?? 0) * 2, dailyRate: 0, weeklyRate: 0,
    monthlyRate: 0, currency: 'EUR', commissionRate: 0.20, walkRate30: r30, walkRate60: r60);

void main() {
  group('gardes à la journée — mêmes chiffres que le serveur', () {
    // [libellé, service, lieu, jours, jour, semaine, mois, net serveur, payé serveur]
    const cases = <List<Object?>>[
      ['3 j à 20 €/j', 'house_sitting', 'owners_home', 3, 20.0, 0.0, 0.0, 60.0, 72.0],
      ['30 j à 20 €/j, 120 €/sem, 400 €/mois (avant : 400 €)', 'house_sitting', 'owners_home', 30, 20.0, 120.0, 400.0, 520.0, 624.0],
      ['7 j à 50 €/j, 100 €/sem — semaine ignorée car < 3 jours (avant : 100 €)', 'house_sitting', 'owners_home', 7, 50.0, 100.0, 0.0, 350.0, 420.0],
      ['10 j à 20 €/j, 120 €/sem (avant : 171,43 €)', 'house_sitting', 'owners_home', 10, 20.0, 120.0, 0.0, 180.0, 216.0],
      ['10 j chez le gardien = 9 nuits, 20 €/j, 120 €/sem', 'house_sitting', 'sitters_home', 10, 20.0, 120.0, 0.0, 160.0, 192.0],
      ['8 j chez le gardien = 7 nuits, 30 €/j, 150 €/sem', 'pet_sitting', 'sitters_home', 8, 30.0, 150.0, 0.0, 150.0, 180.0],
      ['14 j à 25 €/j seul', 'house_sitting', 'owners_home', 14, 25.0, 0.0, 0.0, 350.0, 420.0],
      ['9 j, tarif semaine seul 140 €', 'house_sitting', 'owners_home', 9, 0.0, 140.0, 0.0, 180.0, 216.0],
      ['5 j, tarif mois seul 400 €', 'house_sitting', 'owners_home', 5, 0.0, 0.0, 400.0, 66.65, 79.98],
      ['45 j, tarif mois seul 400 € (avant : palier mois)', 'house_sitting', 'owners_home', 45, 0.0, 0.0, 400.0, 599.85, 719.82],
      ['garderie 7 j à 18 €/j, 90 €/sem', 'day_care', null, 7, 18.0, 90.0, 0.0, 90.0, 108.0],
      ['21 j à 33,33 €/j, 199,99 €/sem', 'house_sitting', 'owners_home', 21, 33.33, 199.99, 0.0, 599.97, 719.96],
      ['1 j chez le gardien = 1 nuit, 20 €/j', 'house_sitting', 'sitters_home', 1, 20.0, 0.0, 0.0, 20.0, 24.0],
    ];
    for (final c in cases) {
      test(c[0]! as String, () {
        final est = _sitter(_post(c[1]! as String, c[3]! as int, venue: c[2] as String?),
            hourly: 10, daily: c[4]! as double, weekly: c[5]! as double, monthly: c[6]! as double)!;
        expect(est.net, closeTo(c[7]! as double, 0.0001), reason: 'ce que reçoit le gardien');
        expect(est.brut, closeTo(c[8]! as double, 0.0001), reason: 'ce que paie le propriétaire');
      });
    }

    test('tarif à l’heure seul : aucun gain (candidature « tarif à venir » côté serveur)', () {
      expect(_sitter(_post('house_sitting', 3, venue: 'owners_home'), hourly: 10), isNull);
    });

    test('une seule date (pas de date de fin) = 1 jour, comme le serveur : 20 € / 24 €', () {
      final est = _sitter(_post('house_sitting', 1, venue: 'owners_home', noEnd: true), daily: 20)!;
      expect(est.net, 20);
      expect(est.brut, 24);
    });

    test('gardien sur une demande dont le service principal est une balade : aucun gain', () {
      expect(_sitter(_post('dog_walking', 3, walkMinutes: 60), daily: 20, hourly: 10), isNull);
    });
  });

  group('visites à domicile — mêmes chiffres que le serveur', () {
    test('2 jours × 2 visites × 12 € = 48 € reçus, 57,60 € payés', () {
      final est = _sitter(_post('home_visit', 2, visitsPerDay: 2), daily: 20, visit: 12)!;
      expect(est.net, 48);
      expect(est.brut, closeTo(57.6, 0.0001));
    });
    test('5 jours × 1 visite × 12,50 € = 62,50 € reçus, 75 € payés', () {
      final est = _sitter(_post('home_visit', 5), visit: 12.5)!;
      expect(est.net, 62.5);
      expect(est.brut, 75);
    });
    test('3 visites par jour n’existe pas côté serveur (1 ou 2) : compté 1 par jour', () {
      final est = _sitter(_post('home_visit', 2, visitsPerDay: 3), visit: 12)!;
      expect(est.net, 24);
    });
  });

  group('balades — mêmes chiffres que le serveur, ou rien', () {
    test('3 jours, 60 min à 12 € : 36 € reçus, 43,20 € payés', () {
      final est = _walker(_post('dog_walking', 3, walkMinutes: 60), r60: 12)!;
      expect(est.net, 36);
      expect(est.brut, closeTo(43.2, 0.0001));
    });
    test('1 jour, 60 min à 12 € : 12 € reçus, 14,40 € payés', () {
      final est = _walker(_post('dog_walking', 1, walkMinutes: 60, span: const Duration(hours: 1)), r60: 12)!;
      expect(est.net, 12);
      expect(est.brut, closeTo(14.4, 0.0001));
    });
    test('1 jour, créneau de 9 h mais balade de 60 min : 12 € (pas 9 h × 12 €)', () {
      final est = _walker(_post('dog_walking', 1, walkMinutes: 60, span: const Duration(hours: 9)), r60: 12)!;
      expect(est.net, 12);
    });
    test('15 jours, 30 min à 8 € (et 60 min à 14 €) : 120 € reçus, 144 € payés', () {
      final est = _walker(_post('dog_walking', 15, walkMinutes: 30), r30: 8, r60: 14)!;
      expect(est.net, 120);
      expect(est.brut, 144);
    });
    test('balade de 60 min demandée, promeneur avec le seul tarif 30 min : aucun gain affiché (le serveur prend un autre palier)', () {
      expect(_walker(_post('dog_walking', 3, walkMinutes: 60), r30: 8), isNull);
    });
    test('balade de 45 min demandée : aucun gain affiché', () {
      expect(_walker(_post('dog_walking', 3, walkMinutes: 45), r30: 8, r60: 14), isNull);
    });
    test('promeneur sur une garde : aucun gain', () {
      expect(_walker(_post('house_sitting', 3, venue: 'owners_home'), r60: 12), isNull);
    });
  });
}
