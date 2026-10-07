// 613 §9 (ZOE, 07/10/2026) — trouvé sur l'émulateur Android (APK release) :
// « Publier une demande » de PROMENADE, date choisie mais pas encore l'heure ni
// la durée → la barre collante disait « Choisis la date de fin de la garde. »,
// un champ qui n'existe pas pour une promenade (la fin = début + durée).
// Elle doit nommer le vrai champ manquant : l'heure, puis la durée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';

import 'lotd_harness.dart';

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));
  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  testWidgets('promenade : jamais « date de fin de la garde », le vrai champ manquant', (tester) async {
    lotdPhone(tester);
    await tester.pumpWidget(lotdApp(
      const PublishReservationRequestScreen(initialServiceType: 'dog_walking'),
      locale: const Locale('fr', 'FR'),
    ));
    await lotdSettle(tester);
    final c = Get.find<PublishReservationRequestController>();
    c.selectServiceType('dog_walking');
    c.selectedPetIds.add('pet1');
    // Rien de daté : « Choisis le jour de la promenade » (pas « …de la garde »).
    c.startDate.value = null;
    expect(c.firstMissingField, 'walkDate');
    expect(c.missingFieldLabel('walkDate'), 'Choisis le jour de la promenade.');
    final day = DateTime.now().add(const Duration(days: 10));
    c.startDate.value = DateTime(day.year, day.month, day.day);
    c.startTime.value = null;
    c.selectDuration(null);
    c.onDatesChanged();
    // Date seule : il manque l'HEURE (pas une date de fin).
    expect(c.firstMissingField, 'startTime');
    expect(c.missingFieldLabel(c.firstMissingField!), "Choisis l'heure de début.");
    // Heure choisie, durée absente : il manque la DURÉE.
    c.startTime.value = const TimeOfDay(hour: 10, minute: 0);
    c.onDatesChanged();
    expect(c.firstMissingField, 'duration');
    expect(c.missingFieldLabel('duration'), 'Choisis la durée de la promenade.');
    // Durée choisie : la fin se calcule toute seule (10 h + 60 min = 11 h).
    c.selectDuration('60');
    expect(c.endTime.value, const TimeOfDay(hour: 11, minute: 0));
    expect(c.firstMissingField, isNot(anyOf('startDate', 'endDate', 'startTime', 'endTime', 'duration')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('garde multi-jours : la date de fin reste demandée (inchangé)', (tester) async {
    lotdPhone(tester);
    await tester.pumpWidget(lotdApp(
      const PublishReservationRequestScreen(initialServiceType: 'pet_sitting'),
      locale: const Locale('fr', 'FR'),
    ));
    await lotdSettle(tester);
    final c = Get.find<PublishReservationRequestController>();
    c.selectServiceType('pet_sitting');
    c.selectedPetIds.add('pet1');
    final day = DateTime.now().add(const Duration(days: 10));
    c.startDate.value = DateTime(day.year, day.month, day.day);
    c.endDate.value = null;
    expect(c.firstMissingField, 'endDate');
  });
}
