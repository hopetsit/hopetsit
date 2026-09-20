// v573 — lot 3 : clés nouvelles du chantier « chat & dialogues transverses du
// Profil » + modernisation de la page « Mes animaux ».
//
// Règle du lot : la MÊME clé dans les 9 langues (en fr es de it pt ko ja pl),
// tutoiement en français. Les placeholders sont écrits `{n}` et remplacés avec
// `.tr.replaceAll('{n}', …)` — PAS `trParams`, qui attend `@n`.
//
// Ce paquet est fusionné par `v565_i18n.dart` (branché par Daniel).
const Map<String, Map<String, String>> lot3573I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'lot3_573_pets_count_one': '1 pet',
    'lot3_573_pets_count': '{n} pets',
    'lot3_573_pets_none': 'No pet yet',
    'lot3_573_pets_add_first': 'Add my first pet',
  },
  'fr': <String, String>{
    'lot3_573_pets_count_one': '1 animal',
    'lot3_573_pets_count': '{n} animaux',
    'lot3_573_pets_none': 'Aucun animal pour l’instant',
    'lot3_573_pets_add_first': 'Ajouter mon premier animal',
  },
  'es': <String, String>{
    'lot3_573_pets_count_one': '1 mascota',
    'lot3_573_pets_count': '{n} mascotas',
    'lot3_573_pets_none': 'Aún no hay mascotas',
    'lot3_573_pets_add_first': 'Añadir mi primera mascota',
  },
  'de': <String, String>{
    'lot3_573_pets_count_one': '1 Tier',
    'lot3_573_pets_count': '{n} Tiere',
    'lot3_573_pets_none': 'Noch kein Tier',
    'lot3_573_pets_add_first': 'Mein erstes Tier hinzufügen',
  },
  'it': <String, String>{
    'lot3_573_pets_count_one': '1 animale',
    'lot3_573_pets_count': '{n} animali',
    'lot3_573_pets_none': 'Ancora nessun animale',
    'lot3_573_pets_add_first': 'Aggiungi il mio primo animale',
  },
  'pt': <String, String>{
    'lot3_573_pets_count_one': '1 animal',
    'lot3_573_pets_count': '{n} animais',
    'lot3_573_pets_none': 'Ainda sem animais',
    'lot3_573_pets_add_first': 'Adicionar o meu primeiro animal',
  },
  'ko': <String, String>{
    'lot3_573_pets_count_one': '반려동물 1마리',
    'lot3_573_pets_count': '반려동물 {n}마리',
    'lot3_573_pets_none': '아직 반려동물이 없습니다',
    'lot3_573_pets_add_first': '첫 반려동물 추가하기',
  },
  'ja': <String, String>{
    'lot3_573_pets_count_one': 'ペット1匹',
    'lot3_573_pets_count': 'ペット{n}匹',
    'lot3_573_pets_none': 'まだペットがいません',
    'lot3_573_pets_add_first': '最初のペットを追加',
  },
  'pl': <String, String>{
    'lot3_573_pets_count_one': '1 zwierzak',
    'lot3_573_pets_count': 'Zwierzaki: {n}',
    'lot3_573_pets_none': 'Brak zwierzaków',
    'lot3_573_pets_add_first': 'Dodaj pierwszego zwierzaka',
  },
};
