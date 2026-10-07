// 613 §9 (ZOE, 07/10/2026) — vu sur l'émulateur Android (APK release) :
// bandeau d'accueil du propriétaire « Nouvelle candidature — Paul ·
// 2026-10-16 » pour une promenade publiée le 17/10 à 1 h 18 (Paris) :
// texte ISO brut ET jour UTC. Désormais : jour LOCAL du début, localisé.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    for (final l in ['fr', 'en', 'de']) {
      await initializeDateFormatting(l);
    }
  });

  test('début réel → jour local, format localisé (fr / en / de)', () {
    final start = DateTime(2026, 10, 17, 1, 18).toUtc().toIso8601String();
    Get.locale = const Locale('fr', 'FR');
    expect(BookingDateFormat.serviceDay(start, '2026-10-16T00:00:00.000Z'), '17 oct. 2026');
    Get.locale = const Locale('en', 'US');
    expect(BookingDateFormat.serviceDay(start, '2026-10-16T00:00:00.000Z'), 'Oct 17, 2026');
    Get.locale = const Locale('de', 'DE');
    expect(BookingDateFormat.serviceDay(start), '17. Okt. 2026');
  });

  test('jour seul (minuit UTC) : ce jour-là, sans recul d’un jour ; rien → vide', () {
    Get.locale = const Locale('fr', 'FR');
    expect(BookingDateFormat.serviceDay(null, '2026-10-16T00:00:00.000Z'), '16 oct. 2026');
    expect(BookingDateFormat.serviceDay('', '2026-10-16'), '16 oct. 2026');
    expect(BookingDateFormat.serviceDay(null, ''), '');
    expect(BookingDateFormat.serviceDay('n’importe quoi', null), '');
    // Réservation : `date` = instant de début (avec heure) → jour LOCAL.
    final start = DateTime(2026, 10, 17, 1, 18).toUtc().toIso8601String();
    expect(BookingDateFormat.serviceDay(null, start), '17 oct. 2026');
  });

  test('ApplicationModel lit startDate (le début réel)', () {
    final a = ApplicationModel.fromJson(<String, dynamic>{
      'id': 'a1', 'serviceDate': '2026-10-16T00:00:00.000Z', 'startDate': '2026-10-16T23:18:00.000Z',
      'timeSlot': '1:18 AM', 'status': 'pending', 'walker': <String, dynamic>{'id': 'w', 'name': 'Paul P.'},
    });
    expect(a.startDate, '2026-10-16T23:18:00.000Z');
    expect(a.providerRole, 'walker');
  });
}
