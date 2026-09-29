// v602 (PAM, 29/09/2026) — direct démarré depuis le chat (accepter une
// demande de suivi = ma position part, comme le bouton Balade). 9 langues.
const Map<String, Map<String, String>> pawmap602I18n =
    <String, Map<String, String>>{
  'fr': <String, String>{
    'pawmap602_live_on_title': 'Tu es en direct',
    'pawmap602_live_on_msg':
        'Ta position précise est partagée. Tu l\'arrêtes quand tu veux avec le bouton Balade de la PawMap.',
    'pawmap602_perm_title': 'Position non disponible',
    'pawmap602_perm_msg':
        'Autorise la position pour HoPetSit dans les réglages du téléphone, puis appuie sur « Partager ma position ».',
    'pawmap602_gps_off_msg':
        'Active la localisation du téléphone, puis appuie sur « Partager ma position ».',
    'pawmap602_start_failed': 'Le direct n\'a pas pu démarrer. Réessaie.',
    'pawmap602_card_live': 'Ta position part en direct',
    'pawmap602_card_start': 'Partager ma position en direct',
  },
  'en': <String, String>{
    'pawmap602_live_on_title': 'You\'re live',
    'pawmap602_live_on_msg':
        'Your exact location is being shared. Stop it anytime with the Walk button on the PawMap.',
    'pawmap602_perm_title': 'Location unavailable',
    'pawmap602_perm_msg':
        'Allow location for HoPetSit in your phone settings, then tap “Share my location”.',
    'pawmap602_gps_off_msg':
        'Turn on your phone\'s location, then tap “Share my location”.',
    'pawmap602_start_failed': 'Live sharing couldn\'t start. Please try again.',
    'pawmap602_card_live': 'Your location is live',
    'pawmap602_card_start': 'Share my location live',
  },
  'es': <String, String>{
    'pawmap602_live_on_title': 'Estás en directo',
    'pawmap602_live_on_msg':
        'Tu ubicación exacta se está compartiendo. Deténla cuando quieras con el botón Paseo de la PawMap.',
    'pawmap602_perm_title': 'Ubicación no disponible',
    'pawmap602_perm_msg':
        'Permite la ubicación para HoPetSit en los ajustes del teléfono y luego pulsa «Compartir mi ubicación».',
    'pawmap602_gps_off_msg':
        'Activa la ubicación del teléfono y luego pulsa «Compartir mi ubicación».',
    'pawmap602_start_failed': 'No se pudo iniciar el directo. Inténtalo de nuevo.',
    'pawmap602_card_live': 'Tu ubicación está en directo',
    'pawmap602_card_start': 'Compartir mi ubicación en directo',
  },
  'de': <String, String>{
    'pawmap602_live_on_title': 'Du bist live',
    'pawmap602_live_on_msg':
        'Dein genauer Standort wird geteilt. Beende es jederzeit mit dem Gassi-Button der PawMap.',
    'pawmap602_perm_title': 'Standort nicht verfügbar',
    'pawmap602_perm_msg':
        'Erlaube HoPetSit den Standort in den Handy-Einstellungen und tippe dann auf „Meinen Standort teilen“.',
    'pawmap602_gps_off_msg':
        'Schalte die Ortung deines Handys ein und tippe dann auf „Meinen Standort teilen“.',
    'pawmap602_start_failed': 'Live-Teilen konnte nicht starten. Versuch es erneut.',
    'pawmap602_card_live': 'Dein Standort ist live',
    'pawmap602_card_start': 'Meinen Standort live teilen',
  },
  'it': <String, String>{
    'pawmap602_live_on_title': 'Sei in diretta',
    'pawmap602_live_on_msg':
        'La tua posizione esatta è condivisa. Fermala quando vuoi con il pulsante Passeggiata della PawMap.',
    'pawmap602_perm_title': 'Posizione non disponibile',
    'pawmap602_perm_msg':
        'Consenti la posizione a HoPetSit nelle impostazioni del telefono, poi tocca «Condividi la mia posizione».',
    'pawmap602_gps_off_msg':
        'Attiva la localizzazione del telefono, poi tocca «Condividi la mia posizione».',
    'pawmap602_start_failed': 'Impossibile avviare la diretta. Riprova.',
    'pawmap602_card_live': 'La tua posizione è in diretta',
    'pawmap602_card_start': 'Condividi la mia posizione in diretta',
  },
  'pt': <String, String>{
    'pawmap602_live_on_title': 'Estás em direto',
    'pawmap602_live_on_msg':
        'A tua localização exata está a ser partilhada. Para quando quiseres com o botão Passeio da PawMap.',
    'pawmap602_perm_title': 'Localização indisponível',
    'pawmap602_perm_msg':
        'Permite a localização para a HoPetSit nas definições do telemóvel e toca em «Partilhar a minha localização».',
    'pawmap602_gps_off_msg':
        'Ativa a localização do telemóvel e toca em «Partilhar a minha localização».',
    'pawmap602_start_failed': 'Não foi possível iniciar o direto. Tenta de novo.',
    'pawmap602_card_live': 'A tua localização está em direto',
    'pawmap602_card_start': 'Partilhar a minha localização em direto',
  },
  'pl': <String, String>{
    'pawmap602_live_on_title': 'Jesteś na żywo',
    'pawmap602_live_on_msg':
        'Twoja dokładna lokalizacja jest udostępniana. Zatrzymaj ją w każdej chwili przyciskiem Spacer na PawMap.',
    'pawmap602_perm_title': 'Lokalizacja niedostępna',
    'pawmap602_perm_msg':
        'Zezwól HoPetSit na lokalizację w ustawieniach telefonu, a potem dotknij „Udostępnij moją lokalizację”.',
    'pawmap602_gps_off_msg':
        'Włącz lokalizację w telefonie, a potem dotknij „Udostępnij moją lokalizację”.',
    'pawmap602_start_failed': 'Nie udało się włączyć transmisji. Spróbuj ponownie.',
    'pawmap602_card_live': 'Twoja lokalizacja jest na żywo',
    'pawmap602_card_start': 'Udostępnij moją lokalizację na żywo',
  },
  'ja': <String, String>{
    'pawmap602_live_on_title': 'ライブ共有中',
    'pawmap602_live_on_msg': '正確な位置を共有しています。PawMapの「お散歩」ボタンでいつでも停止できます。',
    'pawmap602_perm_title': '位置情報を使えません',
    'pawmap602_perm_msg': '端末の設定でHoPetSitの位置情報を許可してから、「位置情報を共有」をタップしてください。',
    'pawmap602_gps_off_msg': '端末の位置情報をオンにしてから、「位置情報を共有」をタップしてください。',
    'pawmap602_start_failed': 'ライブ共有を開始できませんでした。もう一度お試しください。',
    'pawmap602_card_live': '位置情報をライブ共有中',
    'pawmap602_card_start': '位置情報をライブで共有',
  },
  'ko': <String, String>{
    'pawmap602_live_on_title': '실시간 공유 중',
    'pawmap602_live_on_msg': '정확한 위치를 공유하고 있어요. PawMap의 산책 버튼으로 언제든 멈출 수 있어요.',
    'pawmap602_perm_title': '위치를 사용할 수 없어요',
    'pawmap602_perm_msg': '휴대폰 설정에서 HoPetSit의 위치 권한을 허용한 뒤 “내 위치 공유”를 누르세요.',
    'pawmap602_gps_off_msg': '휴대폰 위치 서비스를 켠 뒤 “내 위치 공유”를 누르세요.',
    'pawmap602_start_failed': '실시간 공유를 시작하지 못했어요. 다시 시도해 주세요.',
    'pawmap602_card_live': '내 위치가 실시간 공유 중',
    'pawmap602_card_start': '내 위치 실시간 공유',
  },
};
