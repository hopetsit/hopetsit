// v571 — clés du lot « accueil propriétaire » : cartes d'action garde /
// promenade, bandeau de confiance, carte « première annonce », états vides
// des onglets Gardiens / Promeneurs, invitation d'un gardien connu, carte
// « Ajoute ton animal ».
//
// Règle du lot : la MÊME clé dans les 9 langues (en fr es de it pt ko ja pl),
// tutoiement en français. Les placeholders sont écrits `{x}` et remplacés avec
// `.tr.replaceAll('{x}', …)` — PAS `trParams`, qui attend `@x`.
//
// Ce paquet est fusionné par `v565_i18n.dart` (branché par Daniel).
const Map<String, Map<String, String>> ownerhome571I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'ownerhome571_action_sitting': 'Find a sitter for my pet',
    'ownerhome571_action_walking': 'Find a dog walker',
    'ownerhome571_trust_payment': 'Secure payment',
    'ownerhome571_trust_identity': 'Verified identity',
    'ownerhome571_trust_cancel': 'Free cancellation, 72 h',
    'ownerhome571_first_title': 'Post your first request in 1 minute',
    'ownerhome571_first_step1': 'You post your request',
    'ownerhome571_first_step2': 'Sitters near you send you an offer',
    'ownerhome571_first_step3': 'You pay securely',
    'ownerhome571_first_cta': 'Post my request',
    'ownerhome571_empty_sitters_title': 'No sitter within this radius yet',
    'ownerhome571_empty_walkers_title': 'No dog walker within this radius yet',
    'ownerhome571_empty_body':
        'Post your request: they will be notified as soon as they arrive.',
    'ownerhome571_empty_cta': 'Post my request',
    'ownerhome571_widen_to_km': 'Widen the radius to {km} km',
    'ownerhome571_invite_title': 'Invite a sitter you know',
    'ownerhome571_invite_body':
        'Send them your link: they sign up and find you right away.',
    'ownerhome571_invite_cta': 'Share my link',
    'ownerhome571_addpet_title': 'Add your pet so you can book',
    'ownerhome571_addpet_cta': 'Add',
  },
  'fr': <String, String>{
    'ownerhome571_action_sitting': 'Faire garder mon animal',
    'ownerhome571_action_walking': 'Faire promener mon chien',
    'ownerhome571_trust_payment': 'Paiement sécurisé',
    'ownerhome571_trust_identity': 'Identité vérifiée',
    'ownerhome571_trust_cancel': 'Annulation gratuite 72 h',
    'ownerhome571_first_title': 'Publie ta première annonce en 1 minute',
    'ownerhome571_first_step1': 'Tu publies ton annonce',
    'ownerhome571_first_step2': 'Les gardiens autour de toi te font une offre',
    'ownerhome571_first_step3': 'Tu paies en toute sécurité',
    'ownerhome571_first_cta': 'Publier mon annonce',
    'ownerhome571_empty_sitters_title': 'Pas encore de gardien dans ce rayon',
    'ownerhome571_empty_walkers_title': 'Pas encore de promeneur dans ce rayon',
    'ownerhome571_empty_body':
        'Publie ton annonce : ils seront prévenus dès leur arrivée.',
    'ownerhome571_empty_cta': 'Publier mon annonce',
    'ownerhome571_widen_to_km': 'Élargir le rayon à {km} km',
    'ownerhome571_invite_title': 'Invite un gardien que tu connais',
    'ownerhome571_invite_body':
        'Envoie-lui ton lien : il s’inscrit et te retrouve tout de suite.',
    'ownerhome571_invite_cta': 'Partager mon lien',
    'ownerhome571_addpet_title': 'Ajoute ton animal pour pouvoir réserver',
    'ownerhome571_addpet_cta': 'Ajouter',
  },
  'es': <String, String>{
    'ownerhome571_action_sitting': 'Que cuiden a mi mascota',
    'ownerhome571_action_walking': 'Que paseen a mi perro',
    'ownerhome571_trust_payment': 'Pago seguro',
    'ownerhome571_trust_identity': 'Identidad verificada',
    'ownerhome571_trust_cancel': 'Cancelación gratis 72 h',
    'ownerhome571_first_title': 'Publica tu primer anuncio en 1 minuto',
    'ownerhome571_first_step1': 'Publicas tu anuncio',
    'ownerhome571_first_step2': 'Los cuidadores cercanos te hacen una oferta',
    'ownerhome571_first_step3': 'Pagas con total seguridad',
    'ownerhome571_first_cta': 'Publicar mi anuncio',
    'ownerhome571_empty_sitters_title': 'Aún no hay cuidadores en este radio',
    'ownerhome571_empty_walkers_title': 'Aún no hay paseadores en este radio',
    'ownerhome571_empty_body':
        'Publica tu anuncio: les avisaremos en cuanto lleguen.',
    'ownerhome571_empty_cta': 'Publicar mi anuncio',
    'ownerhome571_widen_to_km': 'Ampliar el radio a {km} km',
    'ownerhome571_invite_title': 'Invita a un cuidador que conozcas',
    'ownerhome571_invite_body':
        'Envíale tu enlace: se registra y te encuentra enseguida.',
    'ownerhome571_invite_cta': 'Compartir mi enlace',
    'ownerhome571_addpet_title': 'Añade tu mascota para poder reservar',
    'ownerhome571_addpet_cta': 'Añadir',
  },
  'de': <String, String>{
    'ownerhome571_action_sitting': 'Mein Tier betreuen lassen',
    'ownerhome571_action_walking': 'Meinen Hund ausführen lassen',
    'ownerhome571_trust_payment': 'Sichere Zahlung',
    'ownerhome571_trust_identity': 'Geprüfte Identität',
    'ownerhome571_trust_cancel': '72 h kostenlos stornierbar',
    'ownerhome571_first_title':
        'Veröffentliche deine erste Anzeige in 1 Minute',
    'ownerhome571_first_step1': 'Du veröffentlichst deine Anzeige',
    'ownerhome571_first_step2':
        'Betreuer in deiner Nähe machen dir ein Angebot',
    'ownerhome571_first_step3': 'Du zahlst sicher',
    'ownerhome571_first_cta': 'Anzeige veröffentlichen',
    'ownerhome571_empty_sitters_title':
        'Noch keine Betreuer in diesem Umkreis',
    'ownerhome571_empty_walkers_title':
        'Noch keine Hundeausführer in diesem Umkreis',
    'ownerhome571_empty_body':
        'Veröffentliche deine Anzeige: Sie werden benachrichtigt, sobald sie da sind.',
    'ownerhome571_empty_cta': 'Anzeige veröffentlichen',
    'ownerhome571_widen_to_km': 'Umkreis auf {km} km erweitern',
    'ownerhome571_invite_title': 'Lade einen Betreuer ein, den du kennst',
    'ownerhome571_invite_body':
        'Schick ihm deinen Link: Er meldet sich an und findet dich sofort.',
    'ownerhome571_invite_cta': 'Meinen Link teilen',
    'ownerhome571_addpet_title': 'Füge dein Tier hinzu, um buchen zu können',
    'ownerhome571_addpet_cta': 'Hinzufügen',
  },
  'it': <String, String>{
    'ownerhome571_action_sitting': 'Far accudire il mio animale',
    'ownerhome571_action_walking': 'Far passeggiare il mio cane',
    'ownerhome571_trust_payment': 'Pagamento sicuro',
    'ownerhome571_trust_identity': 'Identità verificata',
    'ownerhome571_trust_cancel': 'Cancellazione gratis 72 h',
    'ownerhome571_first_title': 'Pubblica il tuo primo annuncio in 1 minuto',
    'ownerhome571_first_step1': 'Pubblichi il tuo annuncio',
    'ownerhome571_first_step2': 'I pet sitter vicino a te ti fanno un’offerta',
    'ownerhome571_first_step3': 'Paghi in tutta sicurezza',
    'ownerhome571_first_cta': 'Pubblica il mio annuncio',
    'ownerhome571_empty_sitters_title':
        'Ancora nessun pet sitter in questo raggio',
    'ownerhome571_empty_walkers_title':
        'Ancora nessun dog walker in questo raggio',
    'ownerhome571_empty_body':
        'Pubblica il tuo annuncio: li avviseremo appena arrivano.',
    'ownerhome571_empty_cta': 'Pubblica il mio annuncio',
    'ownerhome571_widen_to_km': 'Amplia il raggio a {km} km',
    'ownerhome571_invite_title': 'Invita un pet sitter che conosci',
    'ownerhome571_invite_body':
        'Mandagli il tuo link: si iscrive e ti trova subito.',
    'ownerhome571_invite_cta': 'Condividi il mio link',
    'ownerhome571_addpet_title':
        'Aggiungi il tuo animale per poter prenotare',
    'ownerhome571_addpet_cta': 'Aggiungi',
  },
  'pt': <String, String>{
    'ownerhome571_action_sitting': 'Encontrar um cuidador',
    'ownerhome571_action_walking': 'Encontrar um passeador',
    'ownerhome571_trust_payment': 'Pagamento seguro',
    'ownerhome571_trust_identity': 'Identidade verificada',
    'ownerhome571_trust_cancel': 'Cancelamento grátis 72 h',
    'ownerhome571_first_title': 'Publica o teu primeiro anúncio em 1 minuto',
    'ownerhome571_first_step1': 'Publicas o teu anúncio',
    'ownerhome571_first_step2': 'Os cuidadores à tua volta fazem-te uma oferta',
    'ownerhome571_first_step3': 'Pagas em segurança',
    'ownerhome571_first_cta': 'Publicar o meu anúncio',
    'ownerhome571_empty_sitters_title':
        'Ainda não há cuidadores neste raio',
    'ownerhome571_empty_walkers_title':
        'Ainda não há passeadores neste raio',
    'ownerhome571_empty_body':
        'Publica o teu anúncio: serão avisados assim que chegarem.',
    'ownerhome571_empty_cta': 'Publicar o meu anúncio',
    'ownerhome571_widen_to_km': 'Alargar o raio para {km} km',
    'ownerhome571_invite_title': 'Convida um cuidador que conheças',
    'ownerhome571_invite_body':
        'Envia-lhe o teu link: inscreve-se e encontra-te logo.',
    'ownerhome571_invite_cta': 'Partilhar o meu link',
    'ownerhome571_addpet_title':
        'Adiciona o teu animal para poderes reservar',
    'ownerhome571_addpet_cta': 'Adicionar',
  },
  'ko': <String, String>{
    'ownerhome571_action_sitting': '반려동물 돌봄 맡기기',
    'ownerhome571_action_walking': '반려견 산책 맡기기',
    'ownerhome571_trust_payment': '안전한 결제',
    'ownerhome571_trust_identity': '신원 확인 완료',
    'ownerhome571_trust_cancel': '72시간 무료 취소',
    'ownerhome571_first_title': '1분이면 첫 요청을 올릴 수 있어요',
    'ownerhome571_first_step1': '요청을 올려요',
    'ownerhome571_first_step2': '주변 돌보미가 제안을 보내요',
    'ownerhome571_first_step3': '안전하게 결제해요',
    'ownerhome571_first_cta': '요청 올리기',
    'ownerhome571_empty_sitters_title': '이 반경에는 아직 돌보미가 없어요',
    'ownerhome571_empty_walkers_title': '이 반경에는 아직 산책 도우미가 없어요',
    'ownerhome571_empty_body': '요청을 올려 두면 새로 들어오는 즉시 알려 드려요.',
    'ownerhome571_empty_cta': '요청 올리기',
    'ownerhome571_widen_to_km': '반경을 {km}km로 넓히기',
    'ownerhome571_invite_title': '아는 돌보미 초대하기',
    'ownerhome571_invite_body': '링크를 보내 주세요. 가입하면 바로 만날 수 있어요.',
    'ownerhome571_invite_cta': '내 링크 공유하기',
    'ownerhome571_addpet_title': '예약하려면 반려동물을 등록하세요',
    'ownerhome571_addpet_cta': '추가',
  },
  'ja': <String, String>{
    'ownerhome571_action_sitting': 'ペットを預ける',
    'ownerhome571_action_walking': '愛犬の散歩を頼む',
    'ownerhome571_trust_payment': '安全な決済',
    'ownerhome571_trust_identity': '本人確認済み',
    'ownerhome571_trust_cancel': '72時間まで無料キャンセル',
    'ownerhome571_first_title': '1分で最初の依頼を投稿',
    'ownerhome571_first_step1': '依頼を投稿します',
    'ownerhome571_first_step2': '近くのシッターから提案が届きます',
    'ownerhome571_first_step3': '安心して支払います',
    'ownerhome571_first_cta': '依頼を投稿する',
    'ownerhome571_empty_sitters_title': 'この範囲にはまだシッターがいません',
    'ownerhome571_empty_walkers_title': 'この範囲にはまだドッグウォーカーがいません',
    'ownerhome571_empty_body': '依頼を投稿しておけば、登録され次第すぐにお知らせします。',
    'ownerhome571_empty_cta': '依頼を投稿する',
    'ownerhome571_widen_to_km': '範囲を{km}kmに広げる',
    'ownerhome571_invite_title': '知り合いのシッターを招待',
    'ownerhome571_invite_body': 'リンクを送るだけ。登録すればすぐにつながります。',
    'ownerhome571_invite_cta': 'リンクを共有',
    'ownerhome571_addpet_title': '予約するにはペットを登録してください',
    'ownerhome571_addpet_cta': '追加',
  },
  'pl': <String, String>{
    'ownerhome571_action_sitting': 'Zleć opiekę nad zwierzakiem',
    'ownerhome571_action_walking': 'Zleć spacer z psem',
    'ownerhome571_trust_payment': 'Bezpieczna płatność',
    'ownerhome571_trust_identity': 'Zweryfikowana tożsamość',
    'ownerhome571_trust_cancel': 'Bezpłatna anulacja 72 h',
    'ownerhome571_first_title': 'Opublikuj pierwsze ogłoszenie w minutę',
    'ownerhome571_first_step1': 'Publikujesz ogłoszenie',
    'ownerhome571_first_step2': 'Opiekunowie w okolicy składają ofertę',
    'ownerhome571_first_step3': 'Płacisz bezpiecznie',
    'ownerhome571_first_cta': 'Opublikuj ogłoszenie',
    'ownerhome571_empty_sitters_title':
        'W tym promieniu nie ma jeszcze opiekunów',
    'ownerhome571_empty_walkers_title':
        'W tym promieniu nie ma jeszcze osób do spacerów',
    'ownerhome571_empty_body':
        'Opublikuj ogłoszenie: powiadomimy ich, gdy tylko się pojawią.',
    'ownerhome571_empty_cta': 'Opublikuj ogłoszenie',
    'ownerhome571_widen_to_km': 'Zwiększ promień do {km} km',
    'ownerhome571_invite_title': 'Zaproś opiekuna, którego znasz',
    'ownerhome571_invite_body':
        'Wyślij mu swój link: zarejestruje się i od razu Cię znajdzie.',
    'ownerhome571_invite_cta': 'Udostępnij mój link',
    'ownerhome571_addpet_title': 'Dodaj zwierzaka, aby móc rezerwować',
    'ownerhome571_addpet_cta': 'Dodaj',
  },
};
