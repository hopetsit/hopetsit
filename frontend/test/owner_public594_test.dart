// v594 — Daniel (26/09) : « ma grande page de profil est vide ». Depuis la
// PawMap la page ne recevait que nom + photo ; elle charge maintenant le
// profil public (bio, ville, animaux).
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/views/service_provider/owner_profile_view_screen.dart';

import 'lotd_harness.dart';

void main() {
  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  setUp(() async {
    await lotdSetUp(role: 'owner');
    Get.find<AuthController>().userRole.value = 'owner';
  });

  testWidgets('depuis la carte : bio, ville et animaux chargés', (tester) async {
    lotdPhone(tester, width: 375, height: 812);
    await tester.pumpWidget(lotdApp(OwnerProfileViewScreen(
      ownerId: 'o-dan',
      ownerName: 'Daniel C',
      profileLoader: (_) async => <String, dynamic>{
        'bio': 'Amoureux des chiens depuis toujours',
        'city': 'Alhama de Murcia',
        'pets': [
          {'id': 'p1', 'petName': 'Rocky', 'breed': 'Berger'},
        ],
      },
    )));
    await lotdSettle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Amoureux des chiens depuis toujours'), findsOneWidget);
    expect(find.textContaining('Alhama de Murcia'), findsWidgets);
    expect(find.text('Rocky'), findsOneWidget);
  });
}
