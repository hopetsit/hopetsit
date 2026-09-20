// v573 — clés du lot « fiches de profil public » (gardien / promeneur /
// propriétaire vus depuis une annonce, la PawMap, le chat ou les amis).
//
// Règle du lot : la MÊME clé dans les 9 langues (en fr es de it pt ko ja pl),
// tutoiement en français. Les placeholders seraient écrits `{x}` et remplacés
// avec `.tr.replaceAll('{x}', …)` — PAS `trParams`, qui attend `@x` (aucune de
// ces clés n'en a pour l'instant).
//
// Volontairement court : tout ce qui existait déjà (titres de sections, « Aucun
// avis », « Aucune compétence indiquée », statuts, tarifs…) est RÉUTILISÉ. Ne
// sont créés ici que les libellés des 3 tuiles de statistiques et la ligne
// discrète d'une carte « tarifs » vide.
//
// Ce paquet est fusionné par `v565_i18n.dart` (branché par Daniel).
const Map<String, Map<String, String>> profiles573I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'profiles573_stat_rating': 'Rating',
    'profiles573_stat_reviews': 'Reviews',
    'profiles573_stat_services': 'Services',
    'profiles573_stat_walks': 'Walks',
    'profiles573_stat_pets': 'Pets',
    'profiles573_no_rates': 'No rates set yet.',
  },
  'fr': <String, String>{
    'profiles573_stat_rating': 'Note',
    'profiles573_stat_reviews': 'Avis',
    'profiles573_stat_services': 'Prestations',
    'profiles573_stat_walks': 'Promenades',
    'profiles573_stat_pets': 'Animaux',
    'profiles573_no_rates': 'Tarifs non renseignés.',
  },
  'es': <String, String>{
    'profiles573_stat_rating': 'Valoración',
    'profiles573_stat_reviews': 'Reseñas',
    'profiles573_stat_services': 'Servicios',
    'profiles573_stat_walks': 'Paseos',
    'profiles573_stat_pets': 'Mascotas',
    'profiles573_no_rates': 'Tarifas sin indicar.',
  },
  'de': <String, String>{
    'profiles573_stat_rating': 'Bewertung',
    'profiles573_stat_reviews': 'Rezensionen',
    'profiles573_stat_services': 'Leistungen',
    'profiles573_stat_walks': 'Gassi-Gänge',
    'profiles573_stat_pets': 'Tiere',
    'profiles573_no_rates': 'Noch keine Preise angegeben.',
  },
  'it': <String, String>{
    'profiles573_stat_rating': 'Valutazione',
    'profiles573_stat_reviews': 'Recensioni',
    'profiles573_stat_services': 'Servizi',
    'profiles573_stat_walks': 'Passeggiate',
    'profiles573_stat_pets': 'Animali',
    'profiles573_no_rates': 'Tariffe non indicate.',
  },
  'pt': <String, String>{
    'profiles573_stat_rating': 'Avaliação',
    'profiles573_stat_reviews': 'Opiniões',
    'profiles573_stat_services': 'Serviços',
    'profiles573_stat_walks': 'Passeios',
    'profiles573_stat_pets': 'Animais',
    'profiles573_no_rates': 'Tarifas não indicadas.',
  },
  'ko': <String, String>{
    'profiles573_stat_rating': '평점',
    'profiles573_stat_reviews': '후기',
    'profiles573_stat_services': '서비스',
    'profiles573_stat_walks': '산책',
    'profiles573_stat_pets': '반려동물',
    'profiles573_no_rates': '등록된 요금이 없습니다.',
  },
  'ja': <String, String>{
    'profiles573_stat_rating': '評価',
    'profiles573_stat_reviews': 'レビュー',
    'profiles573_stat_services': '実績',
    'profiles573_stat_walks': '散歩',
    'profiles573_stat_pets': 'ペット',
    'profiles573_no_rates': '料金は未設定です。',
  },
  'pl': <String, String>{
    'profiles573_stat_rating': 'Ocena',
    'profiles573_stat_reviews': 'Opinie',
    'profiles573_stat_services': 'Usługi',
    'profiles573_stat_walks': 'Spacery',
    'profiles573_stat_pets': 'Zwierzęta',
    'profiles573_no_rates': 'Brak podanych stawek.',
  },
};
