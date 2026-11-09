// 635 (03/11/2026) — accueil propriétaire : singulier du compteur de
// résultats (« 1 pet-sitters autour de moi », « 1 résultats trouvés » vus au
// simulateur). Utilisées quand le compteur vaut exactement 1 ; les clés
// existantes `home_results_*` restent le pluriel. Placeholder `@count`
// (trParams), comme les clés d'origine.
const Map<String, Map<String, String>> home635I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'home635_results_sitter_one': '1 pet sitter near me',
    'home635_results_walker_one': '1 dog walker near me',
    'home635_results_found_one': '1 result found',
  },
  'fr': <String, String>{
    'home635_results_sitter_one': '1 pet-sitter autour de moi',
    'home635_results_walker_one': '1 promeneur autour de moi',
    'home635_results_found_one': '1 résultat trouvé',
  },
  'es': <String, String>{
    'home635_results_sitter_one': '1 cuidador cerca de mí',
    'home635_results_walker_one': '1 paseador cerca de mí',
    'home635_results_found_one': '1 resultado encontrado',
  },
  'de': <String, String>{
    'home635_results_sitter_one': '1 Tiersitter in meiner Nähe',
    'home635_results_walker_one': '1 Gassigeher in meiner Nähe',
    'home635_results_found_one': '1 Ergebnis gefunden',
  },
  'it': <String, String>{
    'home635_results_sitter_one': '1 pet sitter vicino a me',
    'home635_results_walker_one': '1 dog sitter vicino a me',
    'home635_results_found_one': '1 risultato trovato',
  },
  'pt': <String, String>{
    'home635_results_sitter_one': '1 pet sitter perto de mim',
    'home635_results_walker_one': '1 passeador perto de mim',
    'home635_results_found_one': '1 resultado encontrado',
  },
  'ko': <String, String>{
    'home635_results_sitter_one': '내 주변 펫시터 1명',
    'home635_results_walker_one': '내 주변 산책 도우미 1명',
    'home635_results_found_one': '결과 1건',
  },
  'ja': <String, String>{
    'home635_results_sitter_one': '近くのペットシッター 1人',
    'home635_results_walker_one': '近くの散歩代行 1人',
    'home635_results_found_one': '1件の結果',
  },
  'pl': <String, String>{
    'home635_results_sitter_one': '1 opiekun w pobliżu',
    'home635_results_walker_one': '1 wyprowadzacz psów w pobliżu',
    'home635_results_found_one': 'Znaleziono 1 wynik',
  },
};
