// v586 (point 9 de Daniel) — fiche d'un PROPRIÉTAIRE vue par un gardien /
// promeneur : carte « Demandes en cours » (service, dates, animal, budget,
// ville · distance, jamais l'adresse) et candidature en UN appui ; sans
// demande : « Message » seul ; candidature déjà envoyée / refusée : bouton
// inactif avec le bon libellé. 9 langues à 320 et 375 dp sans débordement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/models/owner_active_request.dart';
import 'package:hopetsit/services/propose_services_service.dart';
import 'package:hopetsit/views/service_provider/owner_profile_view_screen.dart';

import 'lotd_harness.dart';

OwnerActiveRequest _req({String id = 'p1', String? app}) => OwnerActiveRequest(
      id: id,
      ownerId: 'o-dan',
      serviceTypes: const <String>['pet_sitting'],
      startDate: DateTime(2026, 10, 3, 9),
      endDate: DateTime(2026, 10, 6, 18),
      city: 'Paris',
      distanceKm: 3,
      budget: 120,
      currency: 'EUR',
      petIds: const <String>['pet1'],
      pets: const <OwnerActiveRequestPet>[OwnerActiveRequestPet(id: 'pet1', name: 'Rex', category: 'dog')],
      myApplication: app,
    );

final _card = find.byKey(const ValueKey<String>('owner_requests_card'));
final _propose = find.byKey(const ValueKey<String>('owner_request_propose_p1'));
final _message = find.byKey(const ValueKey<String>('owner_profile_message'));

Future<void> _as(String role) async {
  await lotdSetUp(role: role);
  Get.find<AuthController>().userRole.value = role;
}

Widget _screen({
  required List<OwnerActiveRequest> requests,
  Future<OwnerRequestApplyState> Function(OwnerActiveRequest, String)? proposer,
}) =>
    OwnerProfileViewScreen(
      ownerId: 'o-dan',
      ownerName: 'Daniel',
      ownerCity: 'Paris',
      requestsLoader: (_) async => requests,
      proposer: proposer ?? (_, __) async => OwnerRequestApplyState.sent,
    );

void main() {
  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  group('spectateur gardien', () {
    setUp(() => _as('sitter'));

    testWidgets('avec demande : carte complète + candidature en un appui', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      final calls = <String>[];
      await tester.pumpWidget(lotdApp(_screen(
        requests: [_req()],
        proposer: (r, role) async {
          calls.add('${r.id}/$role');
          return OwnerRequestApplyState.sent;
        },
      )));
      await lotdSettle(tester);
      expect(tester.takeException(), isNull);
      expect(_card, findsOneWidget);
      expect(find.text('Demandes en cours'), findsOneWidget);
      expect(find.textContaining('Rex'), findsOneWidget);
      expect(find.textContaining('Budget'), findsOneWidget);
      expect(find.textContaining('Paris · à 3 km'), findsOneWidget);
      expect(find.text('Proposer mes services'), findsOneWidget);
      expect(_message, findsOneWidget);
      await tester.tap(_propose);
      await lotdSettle(tester);
      expect(calls, <String>['p1/sitter']);
      expect(find.text('Candidature envoyée'), findsOneWidget);
      // Un 2e appui ne renvoie rien.
      await tester.tap(_propose);
      await lotdSettle(tester);
      expect(calls.length, 1);
    });

    testWidgets('déjà candidaté / refusée : bouton inactif, aucun envoi', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      var sent = 0;
      await tester.pumpWidget(lotdApp(_screen(
        requests: [_req(app: 'pending'), _req(id: 'p2', app: 'rejected')],
        proposer: (_, __) async {
          sent++;
          return OwnerRequestApplyState.sent;
        },
      )));
      await lotdSettle(tester);
      expect(find.text('Candidature déjà envoyée'), findsOneWidget);
      expect(find.text('Candidature refusée'), findsOneWidget);
      await tester.tap(_propose);
      await lotdSettle(tester);
      expect(sent, 0);
    });
  });

  group('spectateur promeneur', () {
    setUp(() => _as('walker'));

    testWidgets('sans demande : pas de carte, Message seul', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      await tester.pumpWidget(lotdApp(_screen(requests: const <OwnerActiveRequest>[])));
      await lotdSettle(tester);
      expect(_card, findsNothing);
      expect(_message, findsOneWidget);
    });

    for (final width in const [320.0, 375.0]) {
      testWidgets('9 langues à $width dp : rien ne déborde', (tester) async {
        for (final lang in const ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
          lotdPhone(tester, width: width, height: 812);
          await tester.pumpWidget(lotdApp(
            _screen(requests: [_req(), _req(id: 'p2', app: 'rejected')]),
            locale: Locale(lang),
          ));
          await lotdSettle(tester);
          expect(tester.takeException(), isNull, reason: '$lang @ $width');
          expect(_card, findsOneWidget, reason: lang);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  });

  group('spectateur propriétaire', () {
    setUp(() => _as('owner'));

    testWidgets('ni carte ni barre (inchangé)', (tester) async {
      lotdPhone(tester, width: 375, height: 812);
      await tester.pumpWidget(lotdApp(_screen(requests: [_req()])));
      await lotdSettle(tester);
      expect(_card, findsNothing);
      expect(_message, findsNothing);
    });
  });
}
