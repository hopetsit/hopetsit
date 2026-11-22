/**
 * 2211 (« Proposer mon prix », mesure du 22/11/2026 : 55 propriétaires voient leurs candidats, 0 paie ;
 * deux étaient d'accord avec le gardien sur un prix plus bas, que rien ne permettait d'enregistrer) —
 * TEXTES de la proposition de prix (services/priceOffer2211.js) :
 *   · message du propriétaire dans la conversation (« Je vous propose 30 $ au total pour cette demande. ») ;
 *   · e-mail / push au gardien ou promeneur, avec le lien signé de la page de réponse ;
 *   · page de réponse servie par le serveur (Accepter / Refuser), sur le modèle de « toujours libre ? » ;
 *   · e-mail / push au propriétaire après la réponse.
 * Aucun montant n'est calculé ici : ils viennent du service. Toute valeur venue d'un utilisateur est
 * échappée avant d'entrer dans du HTML. Vouvoiement, comme les textes « toujours libre ? ».
 */
const base = require('./applicationEmailText2610');
const free = require('./sitterFreeText1011');

const { esc, lang2, serviceFamily } = base;

const T = {
  fr: {
    chat: (m) => `Je vous propose ${m} au total pour cette demande.`,
    subject: (m) => `Proposition de prix : ${m} pour votre candidature`,
    intro: 'Le propriétaire vous propose un prix pour cette demande. Vous êtes libre d’accepter ou de refuser : rien ne change tant que vous n’avez pas répondu.',
    offered: 'Prix proposé (payé par le propriétaire)',
    youGet: 'Vous toucherez',
    current: 'Votre prix actuel',
    currentNet: (t, n) => `${t} (vous touchez ${n})`,
    cta: 'Voir et répondre',
    expires: 'Cette proposition est valable 48 h.',
    pushTitle: 'Proposition de prix',
    pushBody: (m) => `Le propriétaire vous propose ${m}. Répondez dans l’e-mail que nous venons de vous envoyer.`,
    pageTitle: 'Proposition de prix',
    accept: (n) => `Accepter · je toucherai ${n}`,
    decline: 'Refuser · garder mon prix',
    thanksYes: (m, n) => `C’est noté : vous avez accepté ${m}. Vous toucherez ${n}.`,
    ownerTold: 'Nous prévenons le propriétaire, qui peut maintenant payer.',
    thanksNo: 'C’est noté : vous gardez votre prix. Le propriétaire est prévenu.',
    already: 'Vous avez déjà répondu à cette proposition.',
    expired: 'Cette proposition a expiré.',
    acceptedSubject: (n, m) => `${n} a accepté votre prix : ${m}`,
    acceptedLine: (n, m) => `${n} a accepté votre prix : ${m}. Vous pouvez payer et réserver maintenant.`,
    pay: (m) => `Payer ${m}`,
    acceptedPush: 'Ouvrez pour payer et réserver.',
    declinedSubject: (n) => `${n} préfère garder son prix`,
    declinedLine: (n, m) => `${n} préfère garder son prix${m ? ` : ${m}` : ''}. Vous pouvez toujours le choisir à ce prix, ou choisir un autre candidat.`,
    see: 'Voir mes candidats',
    declinedPush: 'Ouvrez pour voir vos candidats.',
  },
  en: {
    chat: (m) => `I would like to offer ${m} in total for this request.`,
    subject: (m) => `Price offer: ${m} for your application`,
    intro: 'The owner is offering a price for this request. You are free to accept or decline: nothing changes until you answer.',
    offered: 'Offered price (paid by the owner)',
    youGet: 'You will receive',
    current: 'Your current price',
    currentNet: (t, n) => `${t} (you receive ${n})`,
    cta: 'View and answer',
    expires: 'This offer is valid for 48 hours.',
    pushTitle: 'Price offer',
    pushBody: (m) => `The owner is offering ${m}. Answer in the email we have just sent you.`,
    pageTitle: 'Price offer',
    accept: (n) => `Accept · I will receive ${n}`,
    decline: 'Decline · keep my price',
    thanksYes: (m, n) => `Noted: you accepted ${m}. You will receive ${n}.`,
    ownerTold: 'We are letting the owner know. They can now pay.',
    thanksNo: 'Noted: you are keeping your price. The owner has been told.',
    already: 'You have already answered this offer.',
    expired: 'This offer has expired.',
    acceptedSubject: (n, m) => `${n} accepted your price: ${m}`,
    acceptedLine: (n, m) => `${n} accepted your price: ${m}. You can pay and book now.`,
    pay: (m) => `Pay ${m}`,
    acceptedPush: 'Open to pay and book.',
    declinedSubject: (n) => `${n} prefers to keep their price`,
    declinedLine: (n, m) => `${n} prefers to keep their price${m ? `: ${m}` : ''}. You can still choose them at that price, or choose another candidate.`,
    see: 'See my candidates',
    declinedPush: 'Open to see your candidates.',
  },
  es: {
    chat: (m) => `Le propongo ${m} en total para esta solicitud.`,
    subject: (m) => `Propuesta de precio: ${m} para su candidatura`,
    intro: 'El propietario le propone un precio para esta solicitud. Puede aceptar o rechazar libremente: nada cambia hasta que responda.',
    offered: 'Precio propuesto (pagado por el propietario)',
    youGet: 'Usted recibirá',
    current: 'Su precio actual',
    currentNet: (t, n) => `${t} (usted recibe ${n})`,
    cta: 'Ver y responder',
    expires: 'Esta propuesta es válida 48 horas.',
    pushTitle: 'Propuesta de precio',
    pushBody: (m) => `El propietario le propone ${m}. Responda en el correo que acabamos de enviarle.`,
    pageTitle: 'Propuesta de precio',
    accept: (n) => `Aceptar · recibiré ${n}`,
    decline: 'Rechazar · mantener mi precio',
    thanksYes: (m, n) => `Anotado: ha aceptado ${m}. Recibirá ${n}.`,
    ownerTold: 'Avisamos al propietario, que ya puede pagar.',
    thanksNo: 'Anotado: mantiene su precio. El propietario ha sido avisado.',
    already: 'Ya ha respondido a esta propuesta.',
    expired: 'Esta propuesta ha caducado.',
    acceptedSubject: (n, m) => `${n} ha aceptado su precio: ${m}`,
    acceptedLine: (n, m) => `${n} ha aceptado su precio: ${m}. Ya puede pagar y reservar.`,
    pay: (m) => `Pagar ${m}`,
    acceptedPush: 'Abra para pagar y reservar.',
    declinedSubject: (n) => `${n} prefiere mantener su precio`,
    declinedLine: (n, m) => `${n} prefiere mantener su precio${m ? `: ${m}` : ''}. Puede elegirle a ese precio o elegir otro candidato.`,
    see: 'Ver mis candidatos',
    declinedPush: 'Abra para ver sus candidatos.',
  },
  de: {
    chat: (m) => `Ich biete Ihnen insgesamt ${m} für diese Anfrage an.`,
    subject: (m) => `Preisvorschlag: ${m} für Ihre Bewerbung`,
    intro: 'Der Besitzer schlägt Ihnen einen Preis für diese Anfrage vor. Sie können frei annehmen oder ablehnen: Bis zu Ihrer Antwort ändert sich nichts.',
    offered: 'Vorgeschlagener Preis (vom Besitzer bezahlt)',
    youGet: 'Sie erhalten',
    current: 'Ihr aktueller Preis',
    currentNet: (t, n) => `${t} (Sie erhalten ${n})`,
    cta: 'Ansehen und antworten',
    expires: 'Dieser Vorschlag gilt 48 Stunden.',
    pushTitle: 'Preisvorschlag',
    pushBody: (m) => `Der Besitzer bietet ${m} an. Antworten Sie in der E-Mail, die wir Ihnen gerade gesendet haben.`,
    pageTitle: 'Preisvorschlag',
    accept: (n) => `Annehmen · ich erhalte ${n}`,
    decline: 'Ablehnen · meinen Preis behalten',
    thanksYes: (m, n) => `Notiert: Sie haben ${m} angenommen. Sie erhalten ${n}.`,
    ownerTold: 'Wir informieren den Besitzer, der jetzt bezahlen kann.',
    thanksNo: 'Notiert: Sie behalten Ihren Preis. Der Besitzer wurde informiert.',
    already: 'Sie haben auf diesen Vorschlag bereits geantwortet.',
    expired: 'Dieser Vorschlag ist abgelaufen.',
    acceptedSubject: (n, m) => `${n} hat Ihren Preis angenommen: ${m}`,
    acceptedLine: (n, m) => `${n} hat Ihren Preis angenommen: ${m}. Sie können jetzt bezahlen und buchen.`,
    pay: (m) => `${m} bezahlen`,
    acceptedPush: 'Öffnen, um zu bezahlen und zu buchen.',
    declinedSubject: (n) => `${n} möchte den eigenen Preis behalten`,
    declinedLine: (n, m) => `${n} möchte den eigenen Preis behalten${m ? `: ${m}` : ''}. Sie können weiterhin zu diesem Preis wählen oder einen anderen Kandidaten nehmen.`,
    see: 'Meine Kandidaten ansehen',
    declinedPush: 'Öffnen, um Ihre Kandidaten zu sehen.',
  },
  it: {
    chat: (m) => `Le propongo ${m} in totale per questa richiesta.`,
    subject: (m) => `Proposta di prezzo: ${m} per la sua candidatura`,
    intro: 'Il proprietario le propone un prezzo per questa richiesta. È libero di accettare o rifiutare: nulla cambia finché non risponde.',
    offered: 'Prezzo proposto (pagato dal proprietario)',
    youGet: 'Lei riceverà',
    current: 'Il suo prezzo attuale',
    currentNet: (t, n) => `${t} (lei riceve ${n})`,
    cta: 'Vedi e rispondi',
    expires: 'Questa proposta è valida 48 ore.',
    pushTitle: 'Proposta di prezzo',
    pushBody: (m) => `Il proprietario le propone ${m}. Risponda nell’e-mail che le abbiamo appena inviato.`,
    pageTitle: 'Proposta di prezzo',
    accept: (n) => `Accetta · riceverò ${n}`,
    decline: 'Rifiuta · mantengo il mio prezzo',
    thanksYes: (m, n) => `Annotato: ha accettato ${m}. Riceverà ${n}.`,
    ownerTold: 'Avvisiamo il proprietario, che ora può pagare.',
    thanksNo: 'Annotato: mantiene il suo prezzo. Il proprietario è stato avvisato.',
    already: 'Ha già risposto a questa proposta.',
    expired: 'Questa proposta è scaduta.',
    acceptedSubject: (n, m) => `${n} ha accettato il suo prezzo: ${m}`,
    acceptedLine: (n, m) => `${n} ha accettato il suo prezzo: ${m}. Ora può pagare e prenotare.`,
    pay: (m) => `Paga ${m}`,
    acceptedPush: 'Apra per pagare e prenotare.',
    declinedSubject: (n) => `${n} preferisce mantenere il suo prezzo`,
    declinedLine: (n, m) => `${n} preferisce mantenere il suo prezzo${m ? `: ${m}` : ''}. Può ancora sceglierlo a quel prezzo o scegliere un altro candidato.`,
    see: 'Vedi i miei candidati',
    declinedPush: 'Apra per vedere i suoi candidati.',
  },
  pt: {
    chat: (m) => `Proponho-lhe ${m} no total para este pedido.`,
    subject: (m) => `Proposta de preço: ${m} para a sua candidatura`,
    intro: 'O dono propõe-lhe um preço para este pedido. É livre de aceitar ou recusar: nada muda enquanto não responder.',
    offered: 'Preço proposto (pago pelo dono)',
    youGet: 'Vai receber',
    current: 'O seu preço atual',
    currentNet: (t, n) => `${t} (recebe ${n})`,
    cta: 'Ver e responder',
    expires: 'Esta proposta é válida 48 horas.',
    pushTitle: 'Proposta de preço',
    pushBody: (m) => `O dono propõe-lhe ${m}. Responda no e-mail que acabámos de lhe enviar.`,
    pageTitle: 'Proposta de preço',
    accept: (n) => `Aceitar · vou receber ${n}`,
    decline: 'Recusar · manter o meu preço',
    thanksYes: (m, n) => `Anotado: aceitou ${m}. Vai receber ${n}.`,
    ownerTold: 'Estamos a avisar o dono, que já pode pagar.',
    thanksNo: 'Anotado: mantém o seu preço. O dono foi avisado.',
    already: 'Já respondeu a esta proposta.',
    expired: 'Esta proposta expirou.',
    acceptedSubject: (n, m) => `${n} aceitou o seu preço: ${m}`,
    acceptedLine: (n, m) => `${n} aceitou o seu preço: ${m}. Já pode pagar e reservar.`,
    pay: (m) => `Pagar ${m}`,
    acceptedPush: 'Abra para pagar e reservar.',
    declinedSubject: (n) => `${n} prefere manter o seu preço`,
    declinedLine: (n, m) => `${n} prefere manter o seu preço${m ? `: ${m}` : ''}. Pode escolhê-lo a esse preço ou escolher outro candidato.`,
    see: 'Ver os meus candidatos',
    declinedPush: 'Abra para ver os seus candidatos.',
  },
  ko: {
    chat: (m) => `이 요청에 대해 총 ${m}을(를) 제안드립니다.`,
    subject: (m) => `가격 제안: ${m}`,
    intro: '보호자가 이 요청에 대한 가격을 제안했습니다. 수락하거나 거절하실 수 있으며, 답변하기 전에는 아무것도 바뀌지 않습니다.',
    offered: '제안 가격 (보호자 결제 금액)',
    youGet: '받으실 금액',
    current: '현재 가격',
    currentNet: (t, n) => `${t} (받으실 금액 ${n})`,
    cta: '보고 답변하기',
    expires: '이 제안은 48시간 동안 유효합니다.',
    pushTitle: '가격 제안',
    pushBody: (m) => `보호자가 ${m}을(를) 제안했습니다. 방금 보내 드린 이메일에서 답변해 주세요.`,
    pageTitle: '가격 제안',
    accept: (n) => `수락 · ${n} 받기`,
    decline: '거절 · 내 가격 유지',
    thanksYes: (m, n) => `기록했습니다. ${m}을(를) 수락하셨습니다. 받으실 금액은 ${n}입니다.`,
    ownerTold: '보호자에게 알려 드립니다. 이제 결제할 수 있습니다.',
    thanksNo: '기록했습니다. 가격을 유지합니다. 보호자에게 알렸습니다.',
    already: '이미 이 제안에 답변하셨습니다.',
    expired: '이 제안은 만료되었습니다.',
    acceptedSubject: (n, m) => `${n} 님이 제안 가격을 수락했습니다: ${m}`,
    acceptedLine: (n, m) => `${n} 님이 제안 가격 ${m}을(를) 수락했습니다. 지금 결제하고 예약할 수 있습니다.`,
    pay: (m) => `${m} 결제하기`,
    acceptedPush: '열어서 결제하고 예약하세요.',
    declinedSubject: (n) => `${n} 님이 기존 가격을 유지합니다`,
    declinedLine: (n, m) => `${n} 님이 기존 가격을 유지합니다${m ? `: ${m}` : ''}. 그 가격으로 선택하거나 다른 후보를 선택할 수 있습니다.`,
    see: '후보 보기',
    declinedPush: '열어서 후보를 확인하세요.',
  },
  ja: {
    chat: (m) => `このご依頼について、合計${m}でお願いできますでしょうか。`,
    subject: (m) => `料金のご提案：${m}`,
    intro: '飼い主からこの依頼の料金について提案がありました。承諾もお断りも自由です。ご回答いただくまで何も変わりません。',
    offered: '提案された料金（飼い主のお支払い額）',
    youGet: '受け取り額',
    current: '現在の料金',
    currentNet: (t, n) => `${t}（受け取り額 ${n}）`,
    cta: '確認して回答する',
    expires: 'この提案は48時間有効です。',
    pushTitle: '料金のご提案',
    pushBody: (m) => `飼い主から${m}の提案がありました。先ほどお送りしたメールでご回答ください。`,
    pageTitle: '料金のご提案',
    accept: (n) => `承諾する · 受け取り額 ${n}`,
    decline: '断る · 現在の料金のまま',
    thanksYes: (m, n) => `記録しました。${m}を承諾されました。受け取り額は${n}です。`,
    ownerTold: '飼い主にお知らせします。これでお支払いいただけます。',
    thanksNo: '記録しました。現在の料金のままです。飼い主にお知らせしました。',
    already: 'この提案にはすでに回答済みです。',
    expired: 'この提案は期限切れです。',
    acceptedSubject: (n, m) => `${n}さんがご提案の料金を承諾しました：${m}`,
    acceptedLine: (n, m) => `${n}さんがご提案の料金${m}を承諾しました。今すぐ支払って予約できます。`,
    pay: (m) => `${m}を支払う`,
    acceptedPush: '開いて支払い、予約してください。',
    declinedSubject: (n) => `${n}さんは現在の料金を希望しています`,
    declinedLine: (n, m) => `${n}さんは現在の料金を希望しています${m ? `：${m}` : ''}。その料金で選ぶか、別の候補者を選べます。`,
    see: '候補者を見る',
    declinedPush: '開いて候補者をご確認ください。',
  },
  pl: {
    chat: (m) => `Proponuję łącznie ${m} za to zgłoszenie.`,
    subject: (m) => `Propozycja ceny: ${m}`,
    intro: 'Właściciel proponuje cenę za to zgłoszenie. Możesz ją przyjąć lub odrzucić: nic się nie zmienia, dopóki nie odpowiesz.',
    offered: 'Proponowana cena (płaci właściciel)',
    youGet: 'Otrzymasz',
    current: 'Twoja obecna cena',
    currentNet: (t, n) => `${t} (otrzymujesz ${n})`,
    cta: 'Zobacz i odpowiedz',
    expires: 'Ta propozycja jest ważna 48 godzin.',
    pushTitle: 'Propozycja ceny',
    pushBody: (m) => `Właściciel proponuje ${m}. Odpowiedz w e-mailu, który właśnie wysłaliśmy.`,
    pageTitle: 'Propozycja ceny',
    accept: (n) => `Przyjmij · otrzymam ${n}`,
    decline: 'Odrzuć · zostaję przy swojej cenie',
    thanksYes: (m, n) => `Zapisane: przyjęto ${m}. Otrzymasz ${n}.`,
    ownerTold: 'Powiadamiamy właściciela, który może teraz zapłacić.',
    thanksNo: 'Zapisane: zostajesz przy swojej cenie. Właściciel został powiadomiony.',
    already: 'Odpowiedź na tę propozycję została już udzielona.',
    expired: 'Ta propozycja wygasła.',
    acceptedSubject: (n, m) => `${n} przyjmuje Twoją cenę: ${m}`,
    acceptedLine: (n, m) => `${n} przyjmuje Twoją cenę: ${m}. Możesz teraz zapłacić i zarezerwować.`,
    pay: (m) => `Zapłać ${m}`,
    acceptedPush: 'Otwórz, aby zapłacić i zarezerwować.',
    declinedSubject: (n) => `${n} zostaje przy swojej cenie`,
    declinedLine: (n, m) => `${n} zostaje przy swojej cenie${m ? `: ${m}` : ''}. Możesz nadal wybrać tę osobę w tej cenie albo wybrać innego kandydata.`,
    see: 'Zobacz kandydatów',
    declinedPush: 'Otwórz, aby zobaczyć kandydatów.',
  },
};

const L = (lang) => T[lang2(lang)] || T.en;

/** Montant dans la langue du lecteur (« 30,00 $US », « $30.00 ») ; jamais d'exception. */
const money = (amount, currency, lang) => {
  const n = Number(amount) || 0;
  const cur = String(currency || 'EUR').toUpperCase();
  try {
    return new Intl.NumberFormat(lang2(lang) === 'en' ? 'en-US' : lang2(lang), { style: 'currency', currency: cur, maximumFractionDigits: Number.isInteger(n) ? 0 : 2 }).format(n);
  } catch (_) {
    return `${n} ${cur}`;
  }
};

/** Message du propriétaire dans la conversation, dans SA langue. */
const chatMessage = ({ lang, amount, currency }) => L(lang).chat(money(amount, currency, lang));

/** Lignes « service · dates · ville » + montants, pour l'e-mail et la page (valeurs brutes, à échapper). */
function rowsFor({ lang, post, serviceType, view }) {
  const l = lang2(lang);
  const t = L(l);
  const f = free.L(l);
  const fam = serviceFamily(serviceType || (post && Array.isArray(post.serviceTypes) ? post.serviceTypes[0] : ''));
  const m = (v) => money(v, view.currency, l);
  return [
    [f.labels.service, f.svc[fam]],
    [f.labels.dates, post ? free.datesOf(post, l) : ''],
    [f.labels.city, post ? base.cityOfPost(post) : ''],
    [t.offered, m(view.amount)],
    [t.youGet, m(view.newNet)],
    [t.current, t.currentNet(m(view.currentTotal), m(view.currentNet))],
  ].filter((r) => r[1]);
}

const tableHtml = (rows, strongFrom = 3) => `<table role="presentation" cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin:0 0 14px">${rows.map(([label, value], i) => `<tr><td style="padding:4px 12px 4px 0;font-size:14px;color:#6E4F48;vertical-align:top">${esc(label)}</td><td style="padding:4px 0;font-size:${i >= strongFrom ? 16 : 15}px;font-weight:${i === strongFrom + 1 ? 800 : 700};color:${i === strongFrom + 1 ? '#15803D' : '#231715'}">${esc(value)}</td></tr>`).join('')}</table>`;

/** E-mail au gardien / promeneur (gabarit application_new_2610 : bouton = lien signé de la page de réponse). */
function providerEmailData({ lang, post, serviceType, view, link }) {
  const l = lang2(lang);
  const t = L(l);
  const html = `<p style="margin:0 0 12px;font-size:15px;line-height:1.5;color:#231715">${esc(t.intro)}</p>`
    + tableHtml(rowsFor({ lang: l, post, serviceType, view }))
    + `<p style="margin:0 0 16px;font-size:13px;line-height:1.5;color:#6E4F48">${esc(t.expires)}</p>`;
  return { subjectLine: t.subject(money(view.amount, view.currency, l)), candidatesHtml2610: html, ctaLabel: t.cta, emailLink: String(link || '') };
}

/** Push / cloche du gardien (gabarit application_reminder_615). */
function providerPushData({ lang, view }) {
  const t = L(lang);
  return { reminderTitle: t.pushTitle, reminderBody: t.pushBody(money(view.amount, view.currency, lang)) };
}

/** E-mail au propriétaire après la réponse : le bouton du gabarit ouvre sa page candidats (lien signé). */
function ownerEmailData({ lang, accepted, providerName, amount, currentTotal, currency }) {
  const l = lang2(lang);
  const t = L(l);
  const name = String(providerName || 'HoPetSit');
  const m = money(accepted ? amount : currentTotal, currency, l);
  const line = accepted ? t.acceptedLine(name, m) : t.declinedLine(name, Number(currentTotal) > 0 ? m : '');
  return {
    subjectLine: accepted ? t.acceptedSubject(name, m) : t.declinedSubject(name),
    candidatesHtml2610: `<p style="margin:0 0 14px;font-size:15px;line-height:1.5;color:#231715">${esc(line)}</p>`,
    ctaLabel: accepted ? t.pay(m) : t.see,
  };
}

function ownerPushData({ lang, accepted, providerName, amount, currency }) {
  const t = L(lang);
  const name = String(providerName || 'HoPetSit');
  return accepted
    ? { reminderTitle: t.acceptedSubject(name, money(amount, currency, lang)), reminderBody: t.acceptedPush }
    : { reminderTitle: t.declinedSubject(name), reminderBody: t.declinedPush };
}

const BTN = 'display:block;width:100%;padding:16px 12px;border-radius:14px;font-size:17px;font-weight:800;font-family:inherit;cursor:pointer';

/**
 * Page HTML servie par le serveur. Aucun script, aucune ressource externe, styles en ligne.
 * `rows` : [libellé, valeur][] ; `acceptAction` / `declineAction` : adresses des deux formulaires POST.
 */
function pageHtml({ lang, title, lines = [], rows = [], acceptAction = '', declineAction = '', acceptLabel = '', declineLabel = '', tone = 'ok' }) {
  const l = lang2(lang);
  const body = lines.filter(Boolean).map((x) => `<p style="margin:0 0 12px;font-size:16px;line-height:1.5;color:#231715">${esc(x)}</p>`).join('');
  const table = rows.length ? tableHtml(rows) : '';
  const forms = (acceptAction && acceptLabel
    ? `<form method="POST" action="${esc(acceptAction)}" style="margin:18px 0 0"><button type="submit" style="${BTN};border:0;background:#C92A12;color:#FFFFFF">${esc(acceptLabel)}</button></form>`
    : '')
    + (declineAction && declineLabel
      ? `<form method="POST" action="${esc(declineAction)}" style="margin:10px 0 0"><button type="submit" style="${BTN};border:2px solid #231715;background:#FFFFFF;color:#231715">${esc(declineLabel)}</button></form>`
      : '');
  return `<!doctype html><html lang="${esc(l)}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex, nofollow"><title>HoPetSit</title></head>`
    + '<body style="margin:0;padding:24px 16px;background:#FFF6F2;font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,Arial,sans-serif">'
    + '<div style="max-width:440px;margin:0 auto;padding:22px 18px;background:#FFFFFF;border-radius:18px">'
    + '<div style="margin:0 0 14px;font-size:15px;font-weight:800;color:#C92A12">HoPetSit</div>'
    + `<h1 style="margin:0 0 14px;font-size:22px;line-height:1.3;color:${tone === 'warn' ? '#9E1F0B' : '#231715'}">${esc(title)}</h1>${body}${table}${forms}`
    + '</div></body></html>';
}

module.exports = { T, L, money, chatMessage, rowsFor, providerEmailData, providerPushData, ownerEmailData, ownerPushData, pageHtml };
