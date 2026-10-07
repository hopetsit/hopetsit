// 613 §9 (ZOE, 07/10/2026) — mesuré sur l'émulateur Android (APK release,
// banc local) : Paul, promeneur TOP (commission 15 %), ouvre une demande de
// promenade d'1 h à 100 € : la carte « Votre gain estimé » disait « Client
// paie 120 € » (20 % figé) alors que le propriétaire paie 115 €.
// Le bloc prend désormais le taux RÉEL du prestataire connecté, lu sur la
// même route que l'écran de demande (GET /pricing/commission-rate).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/commission_rate.dart';
import 'package:hopetsit/utils/post_price_estimator.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:http/http.dart' as http;

import 'lotd_harness.dart';

PostModel _walk60() {
  final s = DateTime.now().add(const Duration(days: 10));
  final start = DateTime(s.year, s.month, s.day, 10);
  return PostModel.fromJson(<String, dynamic>{
    'id': 'p613', 'postType': 'request', 'body': 'Promenade', 'serviceTypes': <String>['dog_walking'],
    'startDate': start.toUtc().toIso8601String(),
    'endDate': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
    'notes': '', 'images': const [], 'videos': const [], 'likes': const [], 'comments': const [],
    'createdAt': '2026-10-07T10:00:00Z', 'updatedAt': '2026-10-07T10:00:00Z',
    'owner': <String, dynamic>{'id': 'o1', 'name': 'Camille Durand'},
  });
}

void main() {
  setUp(() async {
    await lotdSetUp(role: 'walker');
    resetMyProviderCommissionRate613();
    await GetStorage().write(StorageKeys.userProfile, <String, dynamic>{'id': 'aaaaaaaaaaaaaaaaaaaaaa03'});
  });

  test('promeneur Top : taux lu sur le serveur → client paie 115 € (pas 120 €)', () async {
    lotdResponder = (http.Request req) => req.url.path.endsWith('/pricing/commission-rate')
        ? <String, dynamic>{'commissionRate': 0.15}
        : <String, dynamic>{};
    final rate = await myProviderCommissionRate613('walker');
    expect(rate, 0.15);
    final call = lotdRequests.where((r) => r.path.endsWith('/pricing/commission-rate')).toList();
    expect(call, hasLength(1));
    expect(call.first.query, {'providerId': 'aaaaaaaaaaaaaaaaaaaaaa03', 'role': 'walker'});
    // 2e lecture : cache, aucun nouvel appel.
    expect(await myProviderCommissionRate613('walker'), 0.15);
    expect(lotdRequests.where((r) => r.path.endsWith('/pricing/commission-rate')), hasLength(1));

    final est = estimatePostPrice(
      post: _walk60(), userRole: 'walker', hourlyRate: 100, dailyRate: 0, weeklyRate: 0, monthlyRate: 0,
      currency: 'EUR', walkRate60: 100, commissionRate: rate ?? 0.20,
    )!;
    expect(est.net, 100);
    expect(est.brut, closeTo(115, 0.001));
  });

  test('promeneur normal : 120 € ; serveur muet / propriétaire : null (estimation habituelle)', () async {
    lotdResponder = (http.Request req) => <String, dynamic>{'commissionRate': 0.2};
    expect(await myProviderCommissionRate613('walker'), 0.2);
    resetMyProviderCommissionRate613();
    lotdResponder = (http.Request req) => <String, dynamic>{};
    expect(await myProviderCommissionRate613('walker'), isNull);
    expect(await myProviderCommissionRate613('owner'), isNull);
    final est = estimatePostPrice(
      post: _walk60(), userRole: 'walker', hourlyRate: 100, dailyRate: 0, weeklyRate: 0, monthlyRate: 0,
      currency: 'EUR', walkRate60: 100, commissionRate: 0.20,
    )!;
    expect(est.brut, closeTo(120, 0.001));
  });
}
