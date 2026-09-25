// v587 — BUDGET d'une demande (option A, décision de Daniel du 25/09).
//   · modèles : le budget + sa devise sont lus (« 35 € », « $35 ») ; sans
//     budget → libellé vide (icône du service, jamais « 0 € ») ;
//   · bulle PawMap (feuille de la demande) et carte d'annonce : « 35 € » ;
//   · « Publier » : champ « Mon budget » facultatif, envoyé au serveur avec la
//     devise ; absent de la requête quand il est vide.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:hopetsit/models/owner_active_request.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';

import 'lotd_harness.dart';

Map<String, dynamic> _nearby(Object? budget, String cur) => <String, dynamic>{
      'id': 'p1',
      'ownerId': 'o1',
      'serviceTypes': <String>['dog_walking'],
      'location': <String, dynamic>{'city': 'Zone test', 'lat': -35, 'lng': -30},
      'budget': budget,
      'budgetCurrency': cur,
      'currency': 'EUR',
    };

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  test('demande proche : budget + devise du budget (prioritaire), sinon vide', () {
    Get.locale = const Locale('fr', 'FR');
    expect(NearbyRequestPost.fromJson(_nearby(35, 'EUR')).budgetLabel, contains('35'));
    expect(NearbyRequestPost.fromJson(_nearby(35, 'EUR')).budgetLabel, contains('€'));
    expect(NearbyRequestPost.fromJson(_nearby(40, 'USD')).budgetLabel, contains(r'$'));
    expect(NearbyRequestPost.fromJson(_nearby(0, '')).budgetLabel, isEmpty);
    expect(NearbyRequestPost.fromJson(_nearby(null, '')).budgetLabel, isEmpty);
    final o = OwnerActiveRequest.fromJson(<String, dynamic>{
      'id': 'p1', 'ownerId': 'o1', 'budget': 18, 'budgetCurrency': 'EUR', 'currency': 'USD',
    });
    expect(o.budgetLabel, contains('€'));
  });

  test('annonce (carte + fiche) : budgetLabel, jamais « 0 € »', () {
    Get.locale = const Locale('fr', 'FR');
    PostModel post(Object? b, String c) => PostModel.fromJson(<String, dynamic>{
          'id': 'p1', 'postType': 'request', 'body': 'x', 'serviceTypes': <String>['house_sitting'],
          'notes': '', 'images': const [], 'videos': const [], 'likes': const [], 'comments': const [],
          'createdAt': '2026-09-25T10:00:00Z', 'updatedAt': '2026-09-25T10:00:00Z',
          'owner': <String, dynamic>{'id': 'o1', 'name': 'Camille'},
          'budget': b, 'budgetCurrency': c,
        });
    expect(post(35, 'EUR').budgetLabel, contains('35'));
    expect(post(35, 'EUR').budget, 35);
    expect(post(0, '').budgetLabel, isEmpty);
    expect(post(null, '').budgetLabel, isEmpty);
  });

  testWidgets('bulle PawMap : « 35 € » affiché ; sans budget, rien', (t) async {
    lotdPhone(t, width: 320, height: 800);
    Widget sheet(String label) => lotdApp(Scaffold(
          body: SingleChildScrollView(
            child: PawMapRequestSheet(
              ownerName: 'Marc', ownerAvatar: '', walking: true, city: 'Zone test',
              distanceLabel: '', dateLabel: '', budgetLabel: label, body: '',
              mine: false, approx: true, viewerRole: 'walker',
              proposeState: PawProposeState.idle,
              onPropose: () {}, onOpenMine: () {}, onOwnerProfile: () {},
            ),
          ),
        ));
    await t.pumpWidget(sheet('35 €'));
    await lotdSettle(t);
    expect(find.text('35 €'), findsOneWidget);
    await t.pumpWidget(sheet(''));
    await lotdSettle(t);
    expect(find.textContaining('0 €'), findsNothing);
  });

  test('Publier : le budget part au serveur avec la devise ; vide = non envoyé', () async {
    final repo = Get.find<OwnerRepository>();
    await repo.createReservationRequest(
      body: 'Balade', startDate: DateTime(2026, 12, 1, 9), endDate: DateTime(2026, 12, 1, 10),
      serviceTypes: const <String>['dog_walking'], city: 'Zone test',
      budget: 35, budgetCurrency: 'EUR',
    );
    final withB = lotdRequests.lastWhere((r) => r.method == 'POST');
    expect(withB.body!['budget'], 35);
    expect(withB.body!['budgetCurrency'], 'EUR');
    await repo.createReservationRequest(
      body: 'Balade', startDate: DateTime(2026, 12, 1, 9), endDate: DateTime(2026, 12, 1, 10),
      serviceTypes: const <String>['dog_walking'], city: 'Zone test',
    );
    final noB = lotdRequests.lastWhere((r) => r.method == 'POST');
    expect(noB.body!.containsKey('budget'), isFalse);
  });

  for (final lang in const <String>['fr', 'ja']) {
    testWidgets('$lang : « Publier » a un champ « Mon budget » facultatif (320 px)', (t) async {
      lotdPhone(t, width: 320, height: 800);
      await t.pumpWidget(lotdApp(
        const PublishReservationRequestScreen(initialServiceType: 'dog_walking'),
        locale: lang == 'fr' ? const Locale('fr', 'FR') : const Locale('ja', 'JP'),
      ));
      await lotdSettle(t);
      expect(t.takeException(), isNull);
      final field = find.byKey(const Key('budget587_field'), skipOffstage: false);
      expect(field, findsOneWidget);
      final c = Get.find<PublishReservationRequestController>();
      expect(c.budgetAmount, isNull, reason: 'facultatif : vide par défaut');
      await t.ensureVisible(field);
      await lotdSettle(t, frames: 2);
      await t.enterText(field, '35,5');
      await lotdSettle(t, frames: 2);
      expect(c.budgetAmount, 35.5);
      expect(c.budgetCurrency, isNotEmpty);
      await Get.deleteAll(force: true);
    });
  }
}
