// 613 §9 (ZOE, 07/10/2026) — trouvé sur l'émulateur Android (APK release,
// banc local) : fiche d'un promeneur qui échoue une première fois, puis
// « Réessayer » charge bien la fiche (le titre passe au nom du promeneur)…
// mais l'écran d'erreur RESTAIT affiché : l'ancienne erreur n'était jamais
// effacée et passait avant la fiche. Le test rejoue exactement ce cas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/service_provider/walker_detail_screen.dart';

import 'lotd_harness.dart';

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  testWidgets('fiche promeneur : échec puis « Réessayer » → la fiche s’affiche', (tester) async {
    var calls = 0;
    lotdResponder = (req) {
      if (req.url.path.endsWith('/walkers/aaaaaaaaaaaaaaaaaaaaaa03')) {
        calls++;
        if (calls == 1) throw Exception('réseau coupé (simulé)');
        return <String, dynamic>{
          'walker': <String, dynamic>{
            'id': 'aaaaaaaaaaaaaaaaaaaaaa03',
            '_id': 'aaaaaaaaaaaaaaaaaaaaaa03',
            'name': 'Paul P.',
            'city': 'Paris',
            'bio': 'Promeneur de test.',
            'walkRates': [
              {'durationMinutes': 30, 'basePrice': 10, 'currency': 'EUR', 'enabled': true},
            ],
          },
        };
      }
      return <String, dynamic>{};
    };
    lotdPhone(tester, height: 2400);
    await tester.pumpWidget(lotdApp(const WalkerDetailScreen(walkerId: 'aaaaaaaaaaaaaaaaaaaaaa03')));
    await lotdSettle(tester);
    expect(find.text('walker_load_error'.tr), findsOneWidget, reason: '1er chargement en échec');

    await tester.tap(find.text('common_retry'.tr));
    await lotdSettle(tester);
    expect(calls, 2);
    expect(find.text('walker_load_error'.tr), findsNothing,
        reason: 'après un 2e chargement réussi, l’erreur ne doit plus être affichée');
    expect(find.text('Paul P.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
