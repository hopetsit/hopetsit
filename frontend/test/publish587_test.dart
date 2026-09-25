// v587 (point 8 de Daniel) — « Publier une annonce » : le choix du LIEU
// apparaît pour CHAQUE type de service, avec les bonnes options, et il part
// au serveur.
//   garde multi-jours / garderie de jour : Chez moi / Chez le gardien
//   promenade : Récupérer chez moi / Point de rendez-vous (+ adresse)
//   visites : chez moi, fixé
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/publish587_i18n.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/service_location587.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';

import 'lotd_harness.dart';

Finder _k(String k) => find.byKey(Key(k), skipOffstage: false);

Future<PublishReservationRequestController> _open(
    WidgetTester tester, String service, {Locale locale = const Locale('fr', 'FR')}) async {
  lotdPhone(tester);
  await tester.pumpWidget(lotdApp(
    PublishReservationRequestScreen(initialServiceType: service),
    locale: locale,
  ));
  await lotdSettle(tester);
  return Get.find<PublishReservationRequestController>();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_k(key));
  await lotdSettle(tester, frames: 2);
  await tester.tap(_k(key));
  await lotdSettle(tester, frames: 2);
}

void main() {
  setUp(() async {
    await lotdSetUp(role: 'owner');
    lotdRequests.clear();
  });
  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  for (final svc in <String>['pet_sitting', 'day_care']) {
    testWidgets('$svc : « Chez moi » / « Chez le gardien », obligatoire', (tester) async {
      final c = await _open(tester, svc);
      expect(_k('svc587_title'), findsOneWidget);
      expect(find.text('Où se passe la garde ?', skipOffstage: false), findsOneWidget);
      expect(_k('svc587_opt_at_owner'), findsOneWidget);
      expect(_k('svc587_opt_at_sitter'), findsOneWidget);
      expect(_k('svc587_opt_pickup'), findsNothing);
      expect(_k('svc587_opt_both'), findsNothing);
      // Tant que le lieu n'est pas choisi, l'étape « Service » n'est pas faite.
      expect(c.serviceLocationDone, isFalse);
      expect(c.stepServiceDone, isFalse);
      await _tap(tester, 'svc587_opt_at_sitter');
      expect(c.serviceLocation.value, 'at_sitter');
      expect(c.serviceLocationToSend, 'at_sitter');
      expect(c.stepServiceDone, isTrue);
    });
  }

  testWidgets('promenade : « Récupérer chez moi » / « Point de rendez-vous » + adresse', (tester) async {
    final c = await _open(tester, 'dog_walking');
    expect(find.text('Où commence la promenade ?', skipOffstage: false), findsOneWidget);
    expect(_k('svc587_opt_pickup'), findsOneWidget);
    expect(_k('svc587_opt_meeting_point'), findsOneWidget);
    expect(_k('svc587_opt_at_sitter'), findsNothing);
    expect(_k('svc587_meeting_field'), findsNothing);

    await _tap(tester, 'svc587_opt_meeting_point');
    expect(_k('svc587_meeting_field'), findsOneWidget);
    expect(c.serviceLocationDone, isFalse, reason: 'adresse du rendez-vous requise');
    await tester.enterText(_k('svc587_meeting_field'), 'Parc Monceau');
    await lotdSettle(tester, frames: 2);
    expect(c.meetingPointText.value, 'Parc Monceau');
    expect(c.serviceLocationDone, isTrue);

    await _tap(tester, 'svc587_opt_pickup');
    expect(c.serviceLocationToSend, 'pickup');
    expect(_k('svc587_meeting_field'), findsNothing);
  });

  testWidgets('changer de service vide un lieu qui ne va plus', (tester) async {
    final c = await _open(tester, 'day_care');
    await _tap(tester, 'svc587_opt_at_owner');
    c.selectServiceType('pet_sitting');
    expect(c.serviceLocation.value, 'at_owner', reason: 'garderie → garde : le choix tient');
    c.selectServiceType('dog_walking');
    expect(c.serviceLocation.value, isNull);
  });

  for (final lang in <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
    testWidgets('$lang : question et options traduites, sans débordement (375 dp)', (tester) async {
      lotdPhone(tester, width: 375);
      await tester.pumpWidget(lotdApp(
        const PublishReservationRequestScreen(initialServiceType: 'dog_walking'),
        locale: Locale(lang),
      ));
      await lotdSettle(tester);
      expect(find.text(publish587I18n[lang]!['svc587_title_walk']!, skipOffstage: false), findsOneWidget);
      expect(find.text(publish587I18n[lang]!['svc587_opt_meeting']!, skipOffstage: false), findsOneWidget);
      expect(find.text(publish587I18n[lang]!['svc587_opt_pickup']!, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('le lieu et le point de rendez-vous partent au serveur', () async {
    await Get.find<OwnerRepository>().createReservationRequest(
      body: 'Promenade de Rex',
      startDate: DateTime(2026, 10, 1, 9),
      endDate: DateTime(2026, 10, 1, 10),
      serviceTypes: const <String>['dog_walking'],
      petIds: const <String>['pet1'],
      city: 'Zone test',
      lat: -35,
      lng: -30,
      serviceLocation: 'meeting_point',
      meetingPoint: '  Parc Monceau ',
    );
    final sent = lotdRequests.lastWhere((r) => r.method == 'POST');
    expect(sent.body!['serviceLocation'], 'meeting_point');
    expect(sent.body!['meetingPoint'], 'Parc Monceau');
  });

  group('règle commune (formulaire + affichage)', () {
    test('familles et options par service', () {
      expect(serviceLocationOptions('pet_sitting').map((o) => o.value), <String>['at_owner', 'at_sitter']);
      expect(serviceLocationOptions('house_sitting').map((o) => o.value), <String>['at_owner', 'at_sitter']);
      expect(serviceLocationOptions('day_care').map((o) => o.value), <String>['at_owner', 'at_sitter']);
      expect(serviceLocationOptions('dog_walking').map((o) => o.value), <String>['pickup', 'meeting_point']);
      expect(serviceLocationOptions('home_visit').map((o) => o.value), <String>['at_owner']);
      expect(serviceLocationOptions('pet_sitting', current: 'both').map((o) => o.value),
          contains('both'), reason: 'ancienne annonce « Les deux » modifiable');
    });

    test('libellés neutres, lus par les deux parties', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr', 'FR');
      expect(serviceLocationDisplay('at_owner'), 'Chez le propriétaire');
      expect(serviceLocationDisplay('at_sitter'), 'Chez le gardien');
      expect(serviceLocationDisplay('pickup'), 'Prise en charge au domicile');
      expect(serviceLocationDisplay('meeting_point', meetingPoint: 'Parc Monceau'),
          'Point de rendez-vous · Parc Monceau');
      expect(serviceLocationDisplay(''), '');
      expect(serviceLocationDisplay('inconnu'), '');
    });

    test('9 langues, mêmes clés partout', () {
      final ref = publish587I18n['en']!.keys.toSet();
      for (final lang in <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
        expect(publish587I18n[lang]!.keys.toSet(), ref, reason: lang);
        expect(publish587I18n[lang]!.values.where((v) => v.trim().isEmpty), isEmpty, reason: lang);
      }
    });
  });
}
