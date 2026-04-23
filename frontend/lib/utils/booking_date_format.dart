import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// v18.9 — helper partagé pour formater les dates et heures d'une
/// réservation selon la locale courante. Parse les ISO timestamps et les
/// heures "h:mm a" (AM/PM) et les reformate :
///   - FR / ES / DE / IT / PT → "mer. 24 avr. 2026" + "23:19" (24h)
///   - EN → "Wed, Apr 24, 2026" + "11:19 PM" (12h)
///
/// Avant v18.9, les écrans Mes Réservations affichaient `booking.date`
/// ("2026-04-24T00:00:00.000Z") et `booking.timeSlot` ("11:19 PM") bruts.
class BookingDateFormat {
  BookingDateFormat._();

  static String _lang() => Get.locale?.languageCode ?? 'fr';

  /// Formate une date qui peut arriver en ISO ("2026-04-24T00:00:00.000Z")
  /// ou en format déjà lisible. Retourne la chaîne brute si non parseable.
  static String localizedDate(String raw) {
    if (raw.isEmpty) return '';
    if (raw.contains('T') || raw.contains('-')) {
      try {
        final dt = DateTime.parse(raw).toLocal();
        return DateFormat('EEE, d MMM y', _lang()).format(dt);
      } catch (_) {
        // fall through
      }
    }
    return raw;
  }

  /// Formate une heure qui peut arriver en ISO, en "h:mm a" (AM/PM) ou
  /// déjà en "HH:mm".
  static String localizedTime(String raw) {
    if (raw.isEmpty) return '';
    if (raw.contains('T')) {
      try {
        final dt = DateTime.parse(raw).toLocal();
        final pattern = _lang() == 'en' ? 'h:mm a' : 'HH:mm';
        return DateFormat(pattern, _lang()).format(dt);
      } catch (_) {}
    }
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
            caseSensitive: false)
        .firstMatch(raw.trim());
    if (m != null) {
      int h = int.parse(m.group(1)!);
      final mm = int.parse(m.group(2)!);
      final ampm = m.group(3)?.toUpperCase();
      if (ampm == 'PM' && h < 12) h += 12;
      if (ampm == 'AM' && h == 12) h = 0;
      final dt = DateTime(0, 1, 1, h, mm);
      final pattern = _lang() == 'en' ? 'h:mm a' : 'HH:mm';
      return DateFormat(pattern, _lang()).format(dt);
    }
    return raw;
  }
}
