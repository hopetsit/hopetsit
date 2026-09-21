// v576 — clés du lot « Facture » (PDF enregistré sur le téléphone + écran
// Mes factures). Complètent les clés `invoice_pdf_*` existantes :
//   · l'en-tête du PDF affichait « Operated by CARDELLI HERMANOS LIMITED »
//     et « Company No. » EN ANGLAIS, même sur une facture française ;
//   · la pastille de statut affichait « PAID » / « REFUNDED » en dur ;
//   · le rôle du prestataire sortait brut (« SITTER », « WALKER ») ;
//   · un échec d'ouverture ou de préparation du PDF ne disait RIEN.
//
// Règle du lot : la MÊME clé dans les 9 langues (en fr es de it pt ko ja pl),
// tutoiement en français.
//
// Ce paquet est à fusionner par `v565_i18n.dart` (branché par Daniel).
const Map<String, Map<String, String>> invoice576I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'invoice576_operated_by': 'Operated by',
    'invoice576_company_no': 'Company No.',
    'invoice576_status_paid': 'Paid',
    'invoice576_status_refunded': 'Refunded',
    'invoice576_role_sitter': 'Sitter',
    'invoice576_role_walker': 'Walker',
    'invoice576_open_failed':
        'This invoice is not available yet. Please try again in a moment.',
    'invoice576_save_failed':
        'Could not prepare the PDF. Check your connection and try again.',
  },
  'fr': <String, String>{
    'invoice576_operated_by': 'Service exploité par',
    'invoice576_company_no': "N° d'entreprise",
    'invoice576_status_paid': 'Payée',
    'invoice576_status_refunded': 'Remboursée',
    'invoice576_role_sitter': 'Gardien',
    'invoice576_role_walker': 'Promeneur',
    'invoice576_open_failed':
        "Cette facture n'est pas encore disponible. Réessaie dans un instant.",
    'invoice576_save_failed':
        'Impossible de préparer le PDF. Vérifie ta connexion puis réessaie.',
  },
  'es': <String, String>{
    'invoice576_operated_by': 'Servicio operado por',
    'invoice576_company_no': 'N.º de empresa',
    'invoice576_status_paid': 'Pagada',
    'invoice576_status_refunded': 'Reembolsada',
    'invoice576_role_sitter': 'Cuidador',
    'invoice576_role_walker': 'Paseador',
    'invoice576_open_failed':
        'Esta factura aún no está disponible. Inténtalo de nuevo en un momento.',
    'invoice576_save_failed':
        'No se ha podido preparar el PDF. Comprueba tu conexión e inténtalo de nuevo.',
  },
  'de': <String, String>{
    'invoice576_operated_by': 'Betrieben von',
    'invoice576_company_no': 'Handelsregisternr.',
    'invoice576_status_paid': 'Bezahlt',
    'invoice576_status_refunded': 'Erstattet',
    'invoice576_role_sitter': 'Tierbetreuer',
    'invoice576_role_walker': 'Gassigeher',
    'invoice576_open_failed':
        'Diese Rechnung ist noch nicht verfügbar. Bitte versuche es gleich noch einmal.',
    'invoice576_save_failed':
        'Das PDF konnte nicht erstellt werden. Prüfe deine Verbindung und versuche es erneut.',
  },
  'it': <String, String>{
    'invoice576_operated_by': 'Servizio gestito da',
    'invoice576_company_no': 'N. impresa',
    'invoice576_status_paid': 'Pagata',
    'invoice576_status_refunded': 'Rimborsata',
    'invoice576_role_sitter': 'Pet sitter',
    'invoice576_role_walker': 'Dog walker',
    'invoice576_open_failed':
        'Questa fattura non è ancora disponibile. Riprova tra poco.',
    'invoice576_save_failed':
        'Impossibile preparare il PDF. Controlla la connessione e riprova.',
  },
  'pt': <String, String>{
    'invoice576_operated_by': 'Serviço operado por',
    'invoice576_company_no': 'N.º de empresa',
    'invoice576_status_paid': 'Paga',
    'invoice576_status_refunded': 'Reembolsada',
    'invoice576_role_sitter': 'Pet sitter',
    'invoice576_role_walker': 'Passeador',
    'invoice576_open_failed':
        'Esta fatura ainda não está disponível. Tenta novamente daqui a pouco.',
    'invoice576_save_failed':
        'Não foi possível preparar o PDF. Verifica a tua ligação e tenta de novo.',
  },
  'ko': <String, String>{
    'invoice576_operated_by': '서비스 운영',
    'invoice576_company_no': '사업자 번호',
    'invoice576_status_paid': '결제 완료',
    'invoice576_status_refunded': '환불 완료',
    'invoice576_role_sitter': '펫시터',
    'invoice576_role_walker': '산책 도우미',
    'invoice576_open_failed': '아직 이 청구서를 열 수 없습니다. 잠시 후 다시 시도해 주세요.',
    'invoice576_save_failed': 'PDF를 준비하지 못했습니다. 연결 상태를 확인한 뒤 다시 시도해 주세요.',
  },
  'ja': <String, String>{
    'invoice576_operated_by': '運営会社',
    'invoice576_company_no': '法人番号',
    'invoice576_status_paid': '支払済み',
    'invoice576_status_refunded': '返金済み',
    'invoice576_role_sitter': 'ペットシッター',
    'invoice576_role_walker': 'ドッグウォーカー',
    'invoice576_open_failed': 'この請求書はまだ利用できません。しばらくしてからお試しください。',
    'invoice576_save_failed': 'PDFを準備できませんでした。通信状況を確認して、もう一度お試しください。',
  },
  'pl': <String, String>{
    'invoice576_operated_by': 'Usługa obsługiwana przez',
    'invoice576_company_no': 'Nr firmy',
    'invoice576_status_paid': 'Opłacona',
    'invoice576_status_refunded': 'Zwrócona',
    'invoice576_role_sitter': 'Opiekun',
    'invoice576_role_walker': 'Wyprowadzacz psów',
    'invoice576_open_failed':
        'Ta faktura nie jest jeszcze dostępna. Spróbuj ponownie za chwilę.',
    'invoice576_save_failed':
        'Nie udało się przygotować pliku PDF. Sprawdź połączenie i spróbuj ponownie.',
  },
};
