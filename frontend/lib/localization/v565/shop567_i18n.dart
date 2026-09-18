// v567 — clés de traduction du lot « app-boutique » (9 langues) : les 4
// onglets de la Boutique (PawBoost, PawFollow, PawSpot, Paw Premium) après la
// passe de modernisation + le correctif « barre d'achat derrière la barre
// système Samsung ».
//
// Chaque lot n'édite QUE son fichier ; les cartes sont fusionnées par
// v565_i18n.dart (branchement fait par le chef de lot). Règle : la MÊME clé
// dans les 9 langues, aucune chaîne en dur dans l'écran.
//
// `shop567_days_left` prend un placeholder `{n}` remplacé par
// `.tr.replaceAll('{n}', …)` (jamais trParams — règle du projet).
const Map<String, Map<String, String>> shop567I18n = <String, Map<String, String>>{
  'en': <String, String>{
    'shop567_unlimited': 'Unlimited ∞',
    'shop567_days_left': '{n} days left',
    'shop567_state_active': 'Active',
    'shop567_state_inactive': 'Inactive',
    'shop567_choose_plan': 'Choose your plan',
    'shop567_currency': 'Currency',
  },
  'fr': <String, String>{
    'shop567_unlimited': 'Illimité ∞',
    'shop567_days_left': '{n} j restants',
    'shop567_state_active': 'Actif',
    'shop567_state_inactive': 'Inactif',
    'shop567_choose_plan': 'Choisis ton forfait',
    'shop567_currency': 'Devise',
  },
  'es': <String, String>{
    'shop567_unlimited': 'Ilimitado ∞',
    'shop567_days_left': '{n} días restantes',
    'shop567_state_active': 'Activo',
    'shop567_state_inactive': 'Inactivo',
    'shop567_choose_plan': 'Elige tu plan',
    'shop567_currency': 'Moneda',
  },
  'de': <String, String>{
    'shop567_unlimited': 'Unbegrenzt ∞',
    'shop567_days_left': 'noch {n} Tage',
    'shop567_state_active': 'Aktiv',
    'shop567_state_inactive': 'Inaktiv',
    'shop567_choose_plan': 'Tarif wählen',
    'shop567_currency': 'Währung',
  },
  'it': <String, String>{
    'shop567_unlimited': 'Illimitato ∞',
    'shop567_days_left': '{n} giorni rimasti',
    'shop567_state_active': 'Attivo',
    'shop567_state_inactive': 'Non attivo',
    'shop567_choose_plan': 'Scegli il piano',
    'shop567_currency': 'Valuta',
  },
  'pt': <String, String>{
    'shop567_unlimited': 'Ilimitado ∞',
    'shop567_days_left': 'faltam {n} dias',
    'shop567_state_active': 'Ativo',
    'shop567_state_inactive': 'Inativo',
    'shop567_choose_plan': 'Escolhe o teu plano',
    'shop567_currency': 'Moeda',
  },
  'ko': <String, String>{
    'shop567_unlimited': '무제한 ∞',
    'shop567_days_left': '{n}일 남음',
    'shop567_state_active': '사용 중',
    'shop567_state_inactive': '미사용',
    'shop567_choose_plan': '요금제 선택',
    'shop567_currency': '통화',
  },
  'ja': <String, String>{
    'shop567_unlimited': '無制限 ∞',
    'shop567_days_left': '残り{n}日',
    'shop567_state_active': '有効',
    'shop567_state_inactive': '未加入',
    'shop567_choose_plan': 'プランを選ぶ',
    'shop567_currency': '通貨',
  },
  'pl': <String, String>{
    'shop567_unlimited': 'Bez limitu ∞',
    'shop567_days_left': 'pozostało {n} dni',
    'shop567_state_active': 'Aktywny',
    'shop567_state_inactive': 'Nieaktywny',
    'shop567_choose_plan': 'Wybierz plan',
    'shop567_currency': 'Waluta',
  },
};
