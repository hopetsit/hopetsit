// 607 (ZOE, 01/10/2026) — « morning » restait en anglais dans Mes réservations,
// dans les 9 langues : `BookingDateFormat.localizedTime(booking.timeSlot)` ne
// savait traduire que des heures. Valeurs réellement relevées le 01/10 sur les
// réservations des comptes de test (API de production) : « morning » ×8 et
// « 10:00 » ×8 ; l'app et le site écrivent aussi « allday » et « All Day ».
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:intl/date_symbol_data_local.dart';

const _langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

void main() {
  setUpAll(() async => initializeDateFormatting());
  tearDown(() => Get.locale = null);

  test('créneaux nommés traduits dans les 9 langues (jamais l\'anglais hors en)', () {
    for (final raw in ['morning', 'afternoon', 'evening', 'night', 'allday', 'All Day', 'anytime', 'flexible']) {
      final en = BookingDateFormat.namedSlot(raw, 'en');
      expect(en, isNotNull, reason: raw);
      final seen = <String>{};
      for (final l in _langs) {
        Get.locale = Locale(l);
        final out = BookingDateFormat.localizedTime(raw);
        expect(out.trim(), isNotEmpty, reason: '$raw/$l');
        expect(out, isNot(equals(raw)), reason: '$raw/$l rendu brut');
        if (l != 'en' && raw != 'flexible') {
          expect(out, isNot(equals(en)), reason: '$raw/$l resté en anglais');
        }
        seen.add(out);
      }
      expect(seen.length, greaterThanOrEqualTo(7), reason: '$raw : traductions distinctes');
    }
  });

  test('valeurs attendues en français (accents) et cas d\'écriture', () {
    Get.locale = const Locale('fr');
    expect(BookingDateFormat.localizedTime('morning'), 'Matin');
    expect(BookingDateFormat.localizedTime('Morning'), 'Matin');
    expect(BookingDateFormat.localizedTime(' AFTERNOON '), 'Après-midi');
    expect(BookingDateFormat.localizedTime('evening'), 'Soir');
    expect(BookingDateFormat.localizedTime('allday'), 'Toute la journée');
    expect(BookingDateFormat.localizedTime('All Day'), 'Toute la journée');
    expect(BookingDateFormat.localizedTime('all_day'), 'Toute la journée');
    expect(BookingDateFormat.localizedTime('all-day'), 'Toute la journée');
    expect(BookingDateFormat.localizedTime('anytime'), 'À tout moment');
  });

  test('les heures restent des heures (pas de régression)', () {
    Get.locale = const Locale('fr');
    expect(BookingDateFormat.localizedTime('10:00'), '10:00');
    expect(BookingDateFormat.localizedTime('11:19 PM'), '23:19');
    Get.locale = const Locale('en');
    expect(BookingDateFormat.localizedTime('11:19 PM'), '11:19 PM');
    expect(BookingDateFormat.namedSlot('10:00'), isNull);
    expect(BookingDateFormat.namedSlot('matin'), isNull); // texte inconnu : rendu tel quel
    expect(BookingDateFormat.localizedTime('matin'), 'matin');
  });

  test('chaque écran qui affiche le créneau passe par la traduction (lecture du code)', () {
    const files = <String, String>{
      'lib/views/booking/bookings_history_screen.dart': 'localizedTime(booking.timeSlot)',
      'lib/views/booking/booking_agreement_screen.dart': 'localizedTime(_booking.timeSlot)',
      'lib/views/pet_owner/booking/owner_bookings_screen.dart': 'localizedTime(booking.timeSlot)',
      'lib/views/pet_sitter/booking/sitter_bookings_screen.dart': 'localizedTime(booking.timeSlot)',
      'lib/views/pet_walker/booking/walker_bookings_screen.dart': 'localizedTime(booking.timeSlot)',
      'lib/views/pet_owner/booking-application/owner_booking_detail_screen.dart': 'localizedTime(rawTimeSlot',
      'lib/views/pet_sitter/booking-application/sitter_booking_detail_screen.dart': 'localizedTime(rawTimeSlot',
      'lib/views/service_provider/widgets/service_provider_card.dart': 'localizedTime(booking.timeSlot)',
      'lib/views/pet_owner/chat/tracking_request_sheet.dart': 'localizedTime(b.timeSlot)',
      'lib/widgets/home_quick_action_bar.dart': 'localizedTime(app.timeSlot)',
      'lib/views/payment/airwallex_payment_screen.dart': 'BookingDateFormat.namedSlot(raw, lang)',
    };
    files.forEach((f, needle) {
      expect(File(f).readAsStringSync().contains(needle), isTrue, reason: f);
    });
    final bar = File('lib/widgets/home_quick_action_bar.dart').readAsStringSync();
    expect(bar.contains('localizedTime(b.timeSlot)'), isTrue);
  });
}
