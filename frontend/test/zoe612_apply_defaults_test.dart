// 612 §8 (ZOE, 06/10/2026) — postuler depuis la PawMap ou le profil du propriétaire :
// ces deux portes n'envoient ni la durée de la balade ni le lieu de garde ; le dépôt
// refusait alors AVANT d'appeler le serveur (mesuré au simulateur). La durée se
// déduit des dates de l'annonce, le lieu de garde retombe sur « chez le propriétaire ».
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';

import 'lotd_harness.dart';

void main() {
  setUp(() async => lotdSetUp(role: 'walker'));

  test('durée déduite des dates : 60 min, 90 min, sinon 60 par défaut', () {
    expect(SitterRepository.walkDurationFromDates612('2026-10-12T09:00:00.000Z', '2026-10-12T10:00:00.000Z'), 60);
    expect(SitterRepository.walkDurationFromDates612('2026-10-12T09:00:00.000Z', '2026-10-12T10:30:00.000Z'), 90);
    expect(SitterRepository.walkDurationFromDates612('2026-10-12T09:00:00.000Z', '2026-10-12T09:10:00.000Z'), 60); // < 15 min
    expect(SitterRepository.walkDurationFromDates612('2026-10-12T09:00:00.000Z', '2026-10-13T09:00:00.000Z'), 60); // > 300 min
    expect(SitterRepository.walkDurationFromDates612(null, null), 60);
  });

  test('balade sans durée (PawMap / profil) : la candidature part avec la durée de l’annonce', () async {
    final repo = Get.find<SitterRepository>();
    await repo.createApplication(
      ownerId: 'o1', petIds: const ['p1'], serviceType: 'dog_walking', serviceDate: '2026-10-12T00:00:00.000Z',
      startDate: '2026-10-12T09:00:00.000Z', endDate: '2026-10-12T09:30:00.000Z', timeSlot: '9:00 AM', basePrice: 10, postId: 'post1',
    );
    final req = lotdRequests.firstWhere((r) => r.path.endsWith('/applications'));
    expect(req.body?['duration'], 30);
    expect(req.body?['postId'], 'post1');
  });

  test('garde sans lieu (PawMap / profil) : « chez le propriétaire » par défaut', () async {
    final repo = Get.find<SitterRepository>();
    await repo.createApplication(
      ownerId: 'o1', petIds: const ['p1'], serviceType: 'house_sitting', serviceDate: '2026-10-12T00:00:00.000Z',
      startDate: '2026-10-12T09:00:00.000Z', endDate: '2026-10-14T09:00:00.000Z', timeSlot: '9:00 AM', basePrice: 12, postId: 'post2',
    );
    final req = lotdRequests.firstWhere((r) => r.path.endsWith('/applications'));
    expect(req.body?['houseSittingVenue'], 'owners_home');
  });
}
