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

  /// 607 (ZOE, 01/10/2026) — `timeSlot` est un texte libre côté serveur. En
  /// plus des heures (« 10:00 », « 9:30 AM », ISO), il contient des créneaux
  /// nommés : « allday » (valeur par défaut de la demande), « All Day »
  /// (propositions, PawMap, site) et « morning » (relevé le 01/10 sur les
  /// réservations des comptes de test). On traduit ces mots dans les 9 langues.
  static const Map<String, Map<String, String>> _namedSlots = {
    'morning': {
      'en': 'Morning', 'fr': 'Matin', 'es': 'Mañana', 'de': 'Vormittags',
      'it': 'Mattina', 'pt': 'Manhã', 'ko': '오전', 'ja': '午前', 'pl': 'Rano',
    },
    'afternoon': {
      'en': 'Afternoon', 'fr': 'Après-midi', 'es': 'Tarde', 'de': 'Nachmittags',
      'it': 'Pomeriggio', 'pt': 'Tarde', 'ko': '오후', 'ja': '午後', 'pl': 'Po południu',
    },
    'evening': {
      'en': 'Evening', 'fr': 'Soir', 'es': 'Tarde-noche', 'de': 'Abends',
      'it': 'Sera', 'pt': 'Fim de tarde', 'ko': '저녁', 'ja': '夕方', 'pl': 'Wieczorem',
    },
    'night': {
      'en': 'Night', 'fr': 'Nuit', 'es': 'Noche', 'de': 'Nachts',
      'it': 'Notte', 'pt': 'Noite', 'ko': '밤', 'ja': '夜間', 'pl': 'W nocy',
    },
    'allday': {
      'en': 'All day', 'fr': 'Toute la journée', 'es': 'Todo el día', 'de': 'Ganztägig',
      'it': 'Tutto il giorno', 'pt': 'Dia inteiro', 'ko': '하루 종일', 'ja': '終日', 'pl': 'Cały dzień',
    },
    'anytime': {
      'en': 'Any time', 'fr': 'À tout moment', 'es': 'A cualquier hora', 'de': 'Jederzeit',
      'it': 'A qualsiasi ora', 'pt': 'A qualquer hora', 'ko': '언제든지', 'ja': 'いつでも', 'pl': 'O dowolnej porze',
    },
    'flexible': {
      'en': 'Flexible', 'fr': 'Horaire flexible', 'es': 'Horario flexible', 'de': 'Flexibel',
      'it': 'Orario flessibile', 'pt': 'Horário flexível', 'ko': '시간 협의 가능', 'ja': '時間応相談', 'pl': 'Elastyczna pora',
    },
  };

  /// Variantes d'écriture ramenées à une clé de [_namedSlots].
  static const Map<String, String> _slotAliases = {
    'fullday': 'allday', 'wholeday': 'allday', 'anytimeofday': 'anytime',
  };

  /// Traduction d'un créneau nommé, ou `null` si [raw] n'en est pas un
  /// (une heure, par exemple). Insensible à la casse, aux espaces, `_` et `-`.
  static String? namedSlot(String raw, [String? lang]) {
    var key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
    key = _slotAliases[key] ?? key;
    final t = _namedSlots[key];
    if (t == null) return null;
    return t[lang ?? _lang()] ?? t['en'];
  }

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
    // 607 (ZOE) — créneaux NOMMÉS (« morning », « All Day »…) : avant, rendus
    // bruts, donc « morning » en anglais dans Mes réservations, 9 langues.
    final named = namedSlot(raw);
    if (named != null) return named;
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
