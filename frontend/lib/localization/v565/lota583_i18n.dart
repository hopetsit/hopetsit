// v583 — lot A du chantier du 24/09 (pages de messages, captures de Daniel du
// 23/09). Libellés COURTS des deux pilules de l'en-tête de discussion :
// « Suivre en direct mon animal » était coupé (« Suivre en direct m… ») à
// 375 px. Le libellé long reste utilisé dans le menu « + » (ligne avec
// sous-titre) ; la pilule prend ces versions courtes, sur 2 lignes au plus,
// jamais tronquées (test test/lota583_messages_test.dart, 9 langues, 320 et
// 375 px). Même clé dans les 9 langues.
const Map<String, Map<String, String>> lotA583I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'cs_pf_pill_follow': 'Track live',
    'cs_pf_pill_share': 'Share my position',
  },
  'fr': <String, String>{
    'cs_pf_pill_follow': 'Suivre en direct',
    'cs_pf_pill_share': 'Partager ma position',
  },
  'es': <String, String>{
    'cs_pf_pill_follow': 'Seguir en vivo',
    'cs_pf_pill_share': 'Compartir posición',
  },
  'de': <String, String>{
    'cs_pf_pill_follow': 'Live verfolgen',
    'cs_pf_pill_share': 'Standort teilen',
  },
  'it': <String, String>{
    'cs_pf_pill_follow': 'Segui in diretta',
    'cs_pf_pill_share': 'Condividi posizione',
  },
  'pt': <String, String>{
    'cs_pf_pill_follow': 'Seguir ao vivo',
    'cs_pf_pill_share': 'Partilhar posição',
  },
  'ko': <String, String>{
    'cs_pf_pill_follow': '실시간 추적',
    'cs_pf_pill_share': '내 위치 공유',
  },
  'ja': <String, String>{
    'cs_pf_pill_follow': 'リアルタイム追跡',
    'cs_pf_pill_share': '位置を共有',
  },
  'pl': <String, String>{
    'cs_pf_pill_follow': 'Śledź na żywo',
    'cs_pf_pill_share': 'Udostępnij pozycję',
  },
};
