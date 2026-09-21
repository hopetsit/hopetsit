// v575 — clés du lot « audit des parcours » : annulation d'une réservation
// déjà payée, notification reçue sous le mauvais profil, offre de service sur
// sa propre annonce.
//
// Règle du lot : la MÊME clé dans les 9 langues (en fr es de it pt ko ja pl),
// tutoiement en français. Les placeholders sont écrits `{x}` et remplacés avec
// `.tr.replaceAll('{x}', …)` — PAS `trParams`, qui attend `@x`.
//
// Ce paquet est fusionné par `v565_i18n.dart` (branché par Daniel).
const Map<String, Map<String, String>> fixes575I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'fixes575_cancel_paid_use_refund':
        'This booking is already paid: cancel it with a refund.',
    'fixes575_notification_other_role':
        'This notification is for your {role} profile.',
    'fixes575_role_owner': 'owner',
    'fixes575_role_sitter': 'pet sitter',
    'fixes575_role_walker': 'dog walker',
    'fixes575_own_post': 'This is your own listing, you cannot apply to it.',
  },
  'fr': <String, String>{
    'fixes575_cancel_paid_use_refund':
        'Cette réservation est déjà payée : annule-la avec remboursement.',
    'fixes575_notification_other_role':
        'Cette notification concerne ton profil {role}.',
    'fixes575_role_owner': 'propriétaire',
    'fixes575_role_sitter': 'gardien',
    'fixes575_role_walker': 'promeneur',
    'fixes575_own_post':
        "C'est ta propre annonce, tu ne peux pas t'y proposer.",
  },
  'es': <String, String>{
    'fixes575_cancel_paid_use_refund':
        'Esta reserva ya está pagada: cancélala con reembolso.',
    'fixes575_notification_other_role':
        'Esta notificación es para tu perfil de {role}.',
    'fixes575_role_owner': 'propietario',
    'fixes575_role_sitter': 'cuidador',
    'fixes575_role_walker': 'paseador',
    'fixes575_own_post': 'Es tu propio anuncio, no puedes ofrecerte en él.',
  },
  'de': <String, String>{
    'fixes575_cancel_paid_use_refund':
        'Diese Buchung ist bereits bezahlt: storniere sie mit Rückerstattung.',
    'fixes575_notification_other_role':
        'Diese Benachrichtigung betrifft dein Profil als {role}.',
    'fixes575_role_owner': 'Tierhalter',
    'fixes575_role_sitter': 'Tiersitter',
    'fixes575_role_walker': 'Gassigeher',
    'fixes575_own_post':
        'Das ist deine eigene Anzeige, du kannst dich nicht darauf bewerben.',
  },
  'it': <String, String>{
    'fixes575_cancel_paid_use_refund':
        'Questa prenotazione è già pagata: annullala con rimborso.',
    'fixes575_notification_other_role':
        'Questa notifica riguarda il tuo profilo {role}.',
    'fixes575_role_owner': 'proprietario',
    'fixes575_role_sitter': 'pet sitter',
    'fixes575_role_walker': 'dog walker',
    'fixes575_own_post': 'È il tuo annuncio, non puoi proporti.',
  },
  'pt': <String, String>{
    'fixes575_cancel_paid_use_refund':
        'Esta reserva já está paga: cancela-a com reembolso.',
    'fixes575_notification_other_role':
        'Esta notificação diz respeito ao teu perfil de {role}.',
    'fixes575_role_owner': 'proprietário',
    'fixes575_role_sitter': 'cuidador',
    'fixes575_role_walker': 'passeador',
    'fixes575_own_post': 'É o teu próprio anúncio, não te podes propor.',
  },
  'ko': <String, String>{
    'fixes575_cancel_paid_use_refund':
        '이미 결제된 예약입니다. 환불이 포함된 취소를 이용하세요.',
    'fixes575_notification_other_role': '이 알림은 {role} 프로필에 대한 알림입니다.',
    'fixes575_role_owner': '반려인',
    'fixes575_role_sitter': '펫시터',
    'fixes575_role_walker': '산책 도우미',
    'fixes575_own_post': '직접 올린 공고에는 지원할 수 없습니다.',
  },
  'ja': <String, String>{
    'fixes575_cancel_paid_use_refund':
        'この予約はすでに支払い済みです。返金付きのキャンセルをご利用ください。',
    'fixes575_notification_other_role': 'この通知は{role}プロフィール宛てです。',
    'fixes575_role_owner': '飼い主',
    'fixes575_role_sitter': 'ペットシッター',
    'fixes575_role_walker': 'ドッグウォーカー',
    'fixes575_own_post': '自分の募集に応募することはできません。',
  },
  'pl': <String, String>{
    'fixes575_cancel_paid_use_refund':
        'Ta rezerwacja jest już opłacona: anuluj ją ze zwrotem pieniędzy.',
    'fixes575_notification_other_role':
        'To powiadomienie dotyczy Twojego profilu: {role}.',
    'fixes575_role_owner': 'właściciel',
    'fixes575_role_sitter': 'opiekun',
    'fixes575_role_walker': 'wyprowadzacz psów',
    'fixes575_own_post':
        'To Twoje własne ogłoszenie, nie możesz się na nie zgłosić.',
  },
};

/// v575 — libellé traduit d'un rôle (`owner` / `sitter` / `walker`), pour le
/// bandeau « Cette notification concerne ton profil … ». Fonction pure.
String fixes575RoleLabelKey(String role) {
  switch (role.trim().toLowerCase()) {
    case 'sitter':
      return 'fixes575_role_sitter';
    case 'walker':
      return 'fixes575_role_walker';
    default:
      return 'fixes575_role_owner';
  }
}
