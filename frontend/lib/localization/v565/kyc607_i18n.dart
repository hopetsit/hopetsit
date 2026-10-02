// 607 (ZOE, 02/10) — vérification d'identité : caméra refusée → réglages ou continuer.
// 9 langues : fr en es de it pt ko ja pl.

const Map<String, Map<String, String>> kyc607I18n = <String, Map<String, String>>{
  'fr': <String, String>{
    'kyc607_cam_title': 'Accès à l\'appareil photo refusé',
    'kyc607_cam_msg': 'La vérification d\'identité a besoin de l\'appareil photo (pièce d\'identité et selfie). Autorise-le dans les réglages, ou continue : la page de vérification te le redemandera.',
    'kyc607_open_settings': 'Ouvrir les réglages',
    'kyc607_continue': 'Continuer quand même',
  },
  'en': <String, String>{
    'kyc607_cam_title': 'Camera access denied',
    'kyc607_cam_msg': 'Identity verification needs the camera (ID document and selfie). Allow it in Settings, or continue: the verification page will ask you again.',
    'kyc607_open_settings': 'Open Settings',
    'kyc607_continue': 'Continue anyway',
  },
  'es': <String, String>{
    'kyc607_cam_title': 'Acceso a la cámara denegado',
    'kyc607_cam_msg': 'La verificación de identidad necesita la cámara (documento y selfie). Permítelo en Ajustes o continúa: la página de verificación te lo volverá a pedir.',
    'kyc607_open_settings': 'Abrir Ajustes',
    'kyc607_continue': 'Continuar de todos modos',
  },
  'de': <String, String>{
    'kyc607_cam_title': 'Kamerazugriff verweigert',
    'kyc607_cam_msg': 'Die Identitätsprüfung braucht die Kamera (Ausweis und Selfie). Erlaube sie in den Einstellungen oder fahre fort: Die Prüfseite fragt dich erneut.',
    'kyc607_open_settings': 'Einstellungen öffnen',
    'kyc607_continue': 'Trotzdem fortfahren',
  },
  'it': <String, String>{
    'kyc607_cam_title': 'Accesso alla fotocamera negato',
    'kyc607_cam_msg': 'La verifica dell\'identità ha bisogno della fotocamera (documento e selfie). Consentila nelle Impostazioni o continua: la pagina di verifica te lo chiederà di nuovo.',
    'kyc607_open_settings': 'Apri Impostazioni',
    'kyc607_continue': 'Continua comunque',
  },
  'pt': <String, String>{
    'kyc607_cam_title': 'Acesso à câmara recusado',
    'kyc607_cam_msg': 'A verificação de identidade precisa da câmara (documento e selfie). Autoriza-a nas Definições ou continua: a página de verificação vai pedir-te de novo.',
    'kyc607_open_settings': 'Abrir Definições',
    'kyc607_continue': 'Continuar mesmo assim',
  },
  'ko': <String, String>{
    'kyc607_cam_title': '카메라 접근이 거부됐어요',
    'kyc607_cam_msg': '본인 확인에는 카메라(신분증과 셀카)가 필요해요. 설정에서 허용하거나 계속 진행하세요. 확인 페이지에서 다시 요청해요.',
    'kyc607_open_settings': '설정 열기',
    'kyc607_continue': '그래도 계속하기',
  },
  'ja': <String, String>{
    'kyc607_cam_title': 'カメラへのアクセスが拒否されています',
    'kyc607_cam_msg': '本人確認にはカメラ（身分証と自撮り）が必要です。設定で許可するか、このまま続けてください。確認ページで再度許可を求められます。',
    'kyc607_open_settings': '設定を開く',
    'kyc607_continue': 'このまま続ける',
  },
  'pl': <String, String>{
    'kyc607_cam_title': 'Odmówiono dostępu do aparatu',
    'kyc607_cam_msg': 'Weryfikacja tożsamości wymaga aparatu (dokument i selfie). Zezwól w Ustawieniach albo kontynuuj: strona weryfikacji poprosi ponownie.',
    'kyc607_open_settings': 'Otwórz Ustawienia',
    'kyc607_continue': 'Kontynuuj mimo to',
  },
};
