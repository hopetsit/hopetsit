// 619 (PAM, 23/10/2026 — ordre de Daniel « code postal = position ») : champ
// « Code postal » à l'inscription (3 rôles), dans « Modifier le profil »
// (3 rôles) et sur « Publier ma demande » sans GPS précis. Le serveur place
// le compte / la demande au code postal (geocodePostal2310), plus jamais au
// centre-ville. Même clé dans les 9 langues. Fusionné par `v565_i18n.dart`.
const Map<String, Map<String, String>> postal2310I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'postal2310_label': 'Postal code',
    'postal2310_hint': 'e.g. 75011',
    'postal2310_help_signup':
        'It places your account in your neighbourhood, not in the city centre.',
    'postal2310_help_profile':
        'Your spot on the PawMap follows your postal code, not the city centre.',
    'postal2310_help_request':
        'Without a precise GPS position, your postal code places your request in your neighbourhood.',
    'postal2310_required': 'Enter your postal code (3 to 10 characters).',
    'postal2310_moved': 'Your spot on the PawMap has been moved.',
  },
  'fr': <String, String>{
    'postal2310_label': 'Code postal',
    'postal2310_hint': 'ex. 75011',
    'postal2310_help_signup':
        'Il place ton compte dans ton quartier, pas au centre-ville.',
    'postal2310_help_profile':
        'Ton point sur la PawMap suit ton code postal, pas le centre-ville.',
    'postal2310_help_request':
        'Sans position GPS précise, ton code postal place ta demande dans ton quartier.',
    'postal2310_required': 'Indique ton code postal (3 à 10 caractères).',
    'postal2310_moved': 'Ton point sur la PawMap a été déplacé.',
  },
  'es': <String, String>{
    'postal2310_label': 'Código postal',
    'postal2310_hint': 'p. ej. 28012',
    'postal2310_help_signup':
        'Sitúa tu cuenta en tu barrio, no en el centro de la ciudad.',
    'postal2310_help_profile':
        'Tu punto en la PawMap sigue tu código postal, no el centro de la ciudad.',
    'postal2310_help_request':
        'Sin una posición GPS precisa, tu código postal sitúa tu solicitud en tu barrio.',
    'postal2310_required': 'Indica tu código postal (de 3 a 10 caracteres).',
    'postal2310_moved': 'Tu punto en la PawMap se ha movido.',
  },
  'de': <String, String>{
    'postal2310_label': 'Postleitzahl',
    'postal2310_hint': 'z. B. 40213',
    'postal2310_help_signup':
        'Sie platziert dein Konto in deinem Viertel, nicht im Stadtzentrum.',
    'postal2310_help_profile':
        'Dein Punkt auf der PawMap folgt deiner Postleitzahl, nicht dem Stadtzentrum.',
    'postal2310_help_request':
        'Ohne genaue GPS-Position platziert deine Postleitzahl deine Anfrage in deinem Viertel.',
    'postal2310_required': 'Gib deine Postleitzahl an (3 bis 10 Zeichen).',
    'postal2310_moved': 'Dein Punkt auf der PawMap wurde verschoben.',
  },
  'it': <String, String>{
    'postal2310_label': 'CAP',
    'postal2310_hint': 'es. 20121',
    'postal2310_help_signup':
        'Colloca il tuo account nel tuo quartiere, non nel centro città.',
    'postal2310_help_profile':
        'Il tuo punto sulla PawMap segue il tuo CAP, non il centro città.',
    'postal2310_help_request':
        'Senza una posizione GPS precisa, il tuo CAP colloca la tua richiesta nel tuo quartiere.',
    'postal2310_required': 'Indica il tuo CAP (da 3 a 10 caratteri).',
    'postal2310_moved': 'Il tuo punto sulla PawMap è stato spostato.',
  },
  'pt': <String, String>{
    'postal2310_label': 'Código postal',
    'postal2310_hint': 'ex. 1200-109',
    'postal2310_help_signup':
        'Coloca a tua conta no teu bairro, não no centro da cidade.',
    'postal2310_help_profile':
        'O teu ponto na PawMap segue o teu código postal, não o centro da cidade.',
    'postal2310_help_request':
        'Sem uma posição GPS precisa, o teu código postal coloca o teu pedido no teu bairro.',
    'postal2310_required': 'Indica o teu código postal (3 a 10 caracteres).',
    'postal2310_moved': 'O teu ponto na PawMap foi movido.',
  },
  'ko': <String, String>{
    'postal2310_label': '우편번호',
    'postal2310_hint': '예: 06236',
    'postal2310_help_signup': '도심이 아닌 내 동네에 계정을 표시합니다.',
    'postal2310_help_profile':
        'PawMap의 내 위치는 도심이 아닌 우편번호를 따릅니다.',
    'postal2310_help_request':
        '정확한 GPS 위치가 없으면 우편번호가 요청을 내 동네에 표시합니다.',
    'postal2310_required': '우편번호를 입력하세요 (3~10자).',
    'postal2310_moved': 'PawMap의 내 위치가 이동되었습니다.',
  },
  'ja': <String, String>{
    'postal2310_label': '郵便番号',
    'postal2310_hint': '例: 150-0001',
    'postal2310_help_signup':
        'アカウントを市の中心ではなく、あなたの地区に表示します。',
    'postal2310_help_profile':
        'PawMap上のあなたの位置は、市の中心ではなく郵便番号に従います。',
    'postal2310_help_request':
        '正確なGPS位置がない場合、郵便番号によってリクエストがあなたの地区に表示されます。',
    'postal2310_required': '郵便番号を入力してください（3〜10文字）。',
    'postal2310_moved': 'PawMap上のあなたの位置を移動しました。',
  },
  'pl': <String, String>{
    'postal2310_label': 'Kod pocztowy',
    'postal2310_hint': 'np. 00-001',
    'postal2310_help_signup':
        'Umieszcza Twoje konto w Twojej dzielnicy, a nie w centrum miasta.',
    'postal2310_help_profile':
        'Twój punkt na PawMap podąża za kodem pocztowym, a nie za centrum miasta.',
    'postal2310_help_request':
        'Bez dokładnej pozycji GPS kod pocztowy umieszcza Twoją prośbę w Twojej dzielnicy.',
    'postal2310_required': 'Podaj swój kod pocztowy (od 3 do 10 znaków).',
    'postal2310_moved': 'Twój punkt na PawMap został przeniesiony.',
  },
};
