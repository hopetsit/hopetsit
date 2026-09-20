// v571 — clés du lot « Réservations » (sous-titre de l'en-tête des 3 pages
// Réservations : propriétaire, gardien, promeneur).
//
// Règle du lot : la MÊME clé dans les 9 langues (en fr es de it pt ko ja pl),
// tutoiement en français. Les placeholders sont écrits `{n}` et remplacés avec
// `.tr.replaceAll('{n}', …)` — PAS `trParams`, qui attend `@n`.
//
// Ce paquet est à fusionner par `v565_i18n.dart` (branché par Daniel).
const Map<String, Map<String, String>> bookings571I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'bookings571_count_none': 'No booking yet',
    'bookings571_count_one': '1 booking',
    'bookings571_count_many': '{n} bookings',
  },
  'fr': <String, String>{
    'bookings571_count_none': 'Aucune réservation pour le moment',
    'bookings571_count_one': '1 réservation',
    'bookings571_count_many': '{n} réservations',
  },
  'es': <String, String>{
    'bookings571_count_none': 'Aún no tienes reservas',
    'bookings571_count_one': '1 reserva',
    'bookings571_count_many': '{n} reservas',
  },
  'de': <String, String>{
    'bookings571_count_none': 'Noch keine Buchung',
    'bookings571_count_one': '1 Buchung',
    'bookings571_count_many': '{n} Buchungen',
  },
  'it': <String, String>{
    'bookings571_count_none': 'Ancora nessuna prenotazione',
    'bookings571_count_one': '1 prenotazione',
    'bookings571_count_many': '{n} prenotazioni',
  },
  'pt': <String, String>{
    'bookings571_count_none': 'Ainda sem reservas',
    'bookings571_count_one': '1 reserva',
    'bookings571_count_many': '{n} reservas',
  },
  'ko': <String, String>{
    'bookings571_count_none': '아직 예약이 없어요',
    'bookings571_count_one': '예약 1건',
    'bookings571_count_many': '예약 {n}건',
  },
  'ja': <String, String>{
    'bookings571_count_none': 'まだ予約はありません',
    'bookings571_count_one': '予約1件',
    'bookings571_count_many': '予約{n}件',
  },
  'pl': <String, String>{
    'bookings571_count_none': 'Brak rezerwacji',
    'bookings571_count_one': '1 rezerwacja',
    'bookings571_count_many': 'Rezerwacje: {n}',
  },
};
