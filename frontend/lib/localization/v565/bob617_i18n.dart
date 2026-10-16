// 617 (BOB, 16/10/2026) — textes du build 617 : candidatures à 200 km au plus,
// codes serveur TOO_FAR / CURRENCY_MISMATCH / DUPLICATE_REQUEST, badge
// « Nouveau · vérifié » des fiches sans avis, message « N prévenus » après la
// publication. Même clé dans les 9 langues ; placeholders `{x}` remplacés par
// `.replaceAll`. Fusionné par `v565_i18n.dart`.
const Map<String, Map<String, String>> bob617I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'bob617_err_too_far':
        'This request is too far from you: applications are limited to providers within 200 km.',
    'bob617_err_currency':
        'Your rates are not in the currency of this request. Set your rates in the owner’s currency to apply.',
    'bob617_err_duplicate':
        'You have already posted this request: it is online and providers can see it.',
    'bob617_nothing_within_max': 'No request within {max} km of you right now.',
    'bob617_nothing_within_max_sub':
        'Requests further away are not shown: you could not honour them. You will be alerted as soon as one is posted near you.',
    'bob617_new': 'New',
    'bob617_new_verified': 'New · verified',
    'bob617_new_hint': 'No reviews yet: this profile has just joined. Be the first to book.',
    'bob617_sent_sitters':
        '{n} pet sitters within {km} km have been alerted. They usually reply within the day.',
    'bob617_sent_walkers':
        '{n} dog walkers within {km} km have been alerted. They usually reply within the day.',
    'bob617_sent_none_title': 'No provider near you yet',
    'bob617_sent_none':
        'Your request is online. Share it with people around you to find someone faster.',
    'bob617_share': 'Share my request',
    'bob617_share_text': 'I am looking for someone to look after my pet on HoPetSit: {link}',
    'bob617_later': 'Later',
  },
  'fr': <String, String>{
    'bob617_err_too_far':
        'Cette demande est trop loin de chez toi : les candidatures sont réservées aux prestataires à moins de 200 km.',
    'bob617_err_currency':
        'Tes tarifs ne sont pas dans la devise de cette demande. Mets-les dans la devise du propriétaire pour candidater.',
    'bob617_err_duplicate':
        'Tu as déjà publié cette demande : elle est en ligne et les prestataires la voient.',
    'bob617_nothing_within_max': 'Aucune demande à moins de {max} km de toi pour l’instant.',
    'bob617_nothing_within_max_sub':
        'Les demandes plus lointaines ne sont pas proposées : tu ne pourrais pas les honorer. Tu seras prévenu dès qu’une demande arrive près de chez toi.',
    'bob617_new': 'Nouveau',
    'bob617_new_verified': 'Nouveau · vérifié',
    'bob617_new_hint': 'Pas encore d’avis : ce profil vient d’arriver. Sois le premier à réserver.',
    'bob617_sent_sitters':
        '{n} gardiens à moins de {km} km ont été prévenus. En général ils répondent dans la journée.',
    'bob617_sent_walkers':
        '{n} promeneurs à moins de {km} km ont été prévenus. En général ils répondent dans la journée.',
    'bob617_sent_none_title': 'Aucun prestataire près de chez toi pour l’instant',
    'bob617_sent_none':
        'Ta demande est en ligne. Partage-la autour de toi pour trouver quelqu’un plus vite.',
    'bob617_share': 'Partager ma demande',
    'bob617_share_text': 'Je cherche quelqu’un pour garder mon animal sur HoPetSit : {link}',
    'bob617_later': 'Plus tard',
  },
  'es': <String, String>{
    'bob617_err_too_far':
        'Esta solicitud está demasiado lejos de ti: las candidaturas se reservan a cuidadores a menos de 200 km.',
    'bob617_err_currency':
        'Tus tarifas no están en la moneda de esta solicitud. Ponlas en la moneda del propietario para candidatarte.',
    'bob617_err_duplicate':
        'Ya has publicado esta solicitud: está en línea y los cuidadores la ven.',
    'bob617_nothing_within_max': 'Ninguna solicitud a menos de {max} km de ti por ahora.',
    'bob617_nothing_within_max_sub':
        'Las solicitudes más lejanas no se muestran: no podrías atenderlas. Te avisaremos en cuanto llegue una cerca de ti.',
    'bob617_new': 'Nuevo',
    'bob617_new_verified': 'Nuevo · verificado',
    'bob617_new_hint': 'Aún sin opiniones: este perfil acaba de llegar. Sé el primero en reservar.',
    'bob617_sent_sitters':
        '{n} cuidadores a menos de {km} km han sido avisados. Suelen responder en el día.',
    'bob617_sent_walkers':
        '{n} paseadores a menos de {km} km han sido avisados. Suelen responder en el día.',
    'bob617_sent_none_title': 'Ningún cuidador cerca de ti por ahora',
    'bob617_sent_none':
        'Tu solicitud está en línea. Compártela a tu alrededor para encontrar a alguien más rápido.',
    'bob617_share': 'Compartir mi solicitud',
    'bob617_share_text': 'Busco a alguien que cuide de mi mascota en HoPetSit: {link}',
    'bob617_later': 'Más tarde',
  },
  'de': <String, String>{
    'bob617_err_too_far':
        'Diese Anfrage ist zu weit von dir entfernt: Bewerbungen sind Anbietern im Umkreis von 200 km vorbehalten.',
    'bob617_err_currency':
        'Deine Preise sind nicht in der Währung dieser Anfrage. Stelle sie in der Währung des Besitzers ein, um dich zu bewerben.',
    'bob617_err_duplicate':
        'Du hast diese Anfrage bereits veröffentlicht: sie ist online und die Anbieter sehen sie.',
    'bob617_nothing_within_max': 'Derzeit keine Anfrage im Umkreis von {max} km.',
    'bob617_nothing_within_max_sub':
        'Weiter entfernte Anfragen werden nicht angezeigt: du könntest sie nicht erfüllen. Du wirst benachrichtigt, sobald eine Anfrage in deiner Nähe eingeht.',
    'bob617_new': 'Neu',
    'bob617_new_verified': 'Neu · verifiziert',
    'bob617_new_hint': 'Noch keine Bewertungen: dieses Profil ist gerade erst dazugekommen. Sei der Erste, der bucht.',
    'bob617_sent_sitters':
        '{n} Tiersitter im Umkreis von {km} km wurden benachrichtigt. Sie antworten meist noch am selben Tag.',
    'bob617_sent_walkers':
        '{n} Hundeausführer im Umkreis von {km} km wurden benachrichtigt. Sie antworten meist noch am selben Tag.',
    'bob617_sent_none_title': 'Noch kein Anbieter in deiner Nähe',
    'bob617_sent_none':
        'Deine Anfrage ist online. Teile sie in deinem Umfeld, um schneller jemanden zu finden.',
    'bob617_share': 'Meine Anfrage teilen',
    'bob617_share_text': 'Ich suche jemanden, der auf mein Tier aufpasst, auf HoPetSit: {link}',
    'bob617_later': 'Später',
  },
  'it': <String, String>{
    'bob617_err_too_far':
        'Questa richiesta è troppo lontana da te: le candidature sono riservate ai prestatori entro 200 km.',
    'bob617_err_currency':
        'Le tue tariffe non sono nella valuta di questa richiesta. Impostale nella valuta del proprietario per candidarti.',
    'bob617_err_duplicate':
        'Hai già pubblicato questa richiesta: è online e i prestatori la vedono.',
    'bob617_nothing_within_max': 'Nessuna richiesta entro {max} km da te per ora.',
    'bob617_nothing_within_max_sub':
        'Le richieste più lontane non vengono proposte: non potresti onorarle. Sarai avvisato appena ne arriva una vicino a te.',
    'bob617_new': 'Nuovo',
    'bob617_new_verified': 'Nuovo · verificato',
    'bob617_new_hint': 'Ancora nessuna recensione: questo profilo è appena arrivato. Sii il primo a prenotare.',
    'bob617_sent_sitters':
        '{n} pet sitter entro {km} km sono stati avvisati. Di solito rispondono in giornata.',
    'bob617_sent_walkers':
        '{n} dog walker entro {km} km sono stati avvisati. Di solito rispondono in giornata.',
    'bob617_sent_none_title': 'Nessun prestatore vicino a te per ora',
    'bob617_sent_none':
        'La tua richiesta è online. Condividila intorno a te per trovare qualcuno più in fretta.',
    'bob617_share': 'Condividi la mia richiesta',
    'bob617_share_text': 'Cerco qualcuno che si occupi del mio animale su HoPetSit: {link}',
    'bob617_later': 'Più tardi',
  },
  'pt': <String, String>{
    'bob617_err_too_far':
        'Este pedido está demasiado longe de ti: as candidaturas são reservadas a prestadores a menos de 200 km.',
    'bob617_err_currency':
        'As tuas tarifas não estão na moeda deste pedido. Define-as na moeda do dono para te candidatares.',
    'bob617_err_duplicate':
        'Já publicaste este pedido: está online e os prestadores veem-no.',
    'bob617_nothing_within_max': 'Nenhum pedido a menos de {max} km de ti por agora.',
    'bob617_nothing_within_max_sub':
        'Os pedidos mais distantes não são mostrados: não poderias cumpri-los. Serás avisado assim que chegar um pedido perto de ti.',
    'bob617_new': 'Novo',
    'bob617_new_verified': 'Novo · verificado',
    'bob617_new_hint': 'Ainda sem avaliações: este perfil acabou de chegar. Sê o primeiro a reservar.',
    'bob617_sent_sitters':
        '{n} pet sitters a menos de {km} km foram avisados. Normalmente respondem no próprio dia.',
    'bob617_sent_walkers':
        '{n} passeadores a menos de {km} km foram avisados. Normalmente respondem no próprio dia.',
    'bob617_sent_none_title': 'Ainda nenhum prestador perto de ti',
    'bob617_sent_none':
        'O teu pedido está online. Partilha-o à tua volta para encontrar alguém mais depressa.',
    'bob617_share': 'Partilhar o meu pedido',
    'bob617_share_text': 'Procuro alguém para cuidar do meu animal no HoPetSit: {link}',
    'bob617_later': 'Mais tarde',
  },
  'ko': <String, String>{
    'bob617_err_too_far': '이 요청은 회원님과 너무 멀리 있습니다. 지원은 200 km 이내의 제공자만 할 수 있습니다.',
    'bob617_err_currency': '회원님의 요금이 이 요청의 통화와 다릅니다. 지원하려면 보호자의 통화로 요금을 설정하세요.',
    'bob617_err_duplicate': '이미 같은 요청을 게시했습니다. 요청은 온라인 상태이며 제공자들이 볼 수 있습니다.',
    'bob617_nothing_within_max': '현재 {max} km 이내에 요청이 없습니다.',
    'bob617_nothing_within_max_sub': '더 먼 요청은 표시되지 않습니다(수행할 수 없기 때문). 근처에 요청이 올라오면 바로 알려드릴게요.',
    'bob617_new': '신규',
    'bob617_new_verified': '신규 · 인증됨',
    'bob617_new_hint': '아직 후기가 없습니다. 이 프로필은 방금 가입했어요. 첫 예약자가 되어 보세요.',
    'bob617_sent_sitters': '{km} km 이내의 펫시터 {n}명에게 알렸습니다. 보통 당일에 답합니다.',
    'bob617_sent_walkers': '{km} km 이내의 도그워커 {n}명에게 알렸습니다. 보통 당일에 답합니다.',
    'bob617_sent_none_title': '아직 근처에 제공자가 없습니다',
    'bob617_sent_none': '요청이 게시되었습니다. 주변에 공유하면 더 빨리 찾을 수 있어요.',
    'bob617_share': '내 요청 공유',
    'bob617_share_text': 'HoPetSit에서 반려동물을 돌봐 줄 분을 찾고 있어요: {link}',
    'bob617_later': '나중에',
  },
  'ja': <String, String>{
    'bob617_err_too_far': 'この依頼はあなたから遠すぎます。応募は200 km以内のプロバイダーに限られます。',
    'bob617_err_currency': 'あなたの料金はこの依頼の通貨と異なります。応募するには飼い主の通貨で料金を設定してください。',
    'bob617_err_duplicate': 'この依頼はすでに投稿済みです。公開中で、プロバイダーに表示されています。',
    'bob617_nothing_within_max': '現在、{max} km以内に依頼はありません。',
    'bob617_nothing_within_max_sub': 'より遠い依頼は表示されません（対応できないため）。近くに依頼が投稿されたらすぐお知らせします。',
    'bob617_new': '新規',
    'bob617_new_verified': '新規 · 認証済み',
    'bob617_new_hint': 'まだレビューはありません。このプロフィールは登録したばかりです。最初に予約してみましょう。',
    'bob617_sent_sitters': '{km} km以内のペットシッター{n}人に通知しました。通常はその日のうちに返事があります。',
    'bob617_sent_walkers': '{km} km以内のドッグウォーカー{n}人に通知しました。通常はその日のうちに返事があります。',
    'bob617_sent_none_title': 'まだ近くにプロバイダーがいません',
    'bob617_sent_none': '依頼は公開されています。周りの人に共有すると、早く見つかります。',
    'bob617_share': '依頼を共有',
    'bob617_share_text': 'HoPetSitでペットのお世話をしてくれる人を探しています: {link}',
    'bob617_later': '後で',
  },
  'pl': <String, String>{
    'bob617_err_too_far':
        'To zgłoszenie jest za daleko od Ciebie: zgłaszać się mogą tylko opiekunowie w promieniu 200 km.',
    'bob617_err_currency':
        'Twoje stawki nie są w walucie tego zgłoszenia. Ustaw je w walucie właściciela, aby się zgłosić.',
    'bob617_err_duplicate':
        'Już opublikowałeś to zgłoszenie: jest online i opiekunowie je widzą.',
    'bob617_nothing_within_max': 'Na razie brak zgłoszeń w promieniu {max} km od Ciebie.',
    'bob617_nothing_within_max_sub':
        'Dalsze zgłoszenia nie są pokazywane: nie mógłbyś ich zrealizować. Powiadomimy Cię, gdy pojawi się zgłoszenie w Twojej okolicy.',
    'bob617_new': 'Nowy',
    'bob617_new_verified': 'Nowy · zweryfikowany',
    'bob617_new_hint': 'Brak opinii: ten profil dopiero dołączył. Bądź pierwszym, który zarezerwuje.',
    'bob617_sent_sitters':
        '{n} opiekunów w promieniu {km} km zostało powiadomionych. Zwykle odpowiadają tego samego dnia.',
    'bob617_sent_walkers':
        '{n} wyprowadzaczy w promieniu {km} km zostało powiadomionych. Zwykle odpowiadają tego samego dnia.',
    'bob617_sent_none_title': 'Na razie brak opiekunów w Twojej okolicy',
    'bob617_sent_none':
        'Twoje zgłoszenie jest online. Podziel się nim z otoczeniem, aby szybciej kogoś znaleźć.',
    'bob617_share': 'Udostępnij moje zgłoszenie',
    'bob617_share_text': 'Szukam kogoś do opieki nad moim zwierzakiem na HoPetSit: {link}',
    'bob617_later': 'Później',
  },
};
