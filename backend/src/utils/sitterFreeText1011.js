/**
 * 1011 (FLO, plan « conclure » B.4, validé par Daniel le 09/11) — TEXTES du message automatique
 * « un gardien est libre et vous attend → payer » (services/sitterFree1011.js).
 *
 *   · question au gardien / promeneur : « Êtes-vous toujours libre pour garder Rex du … au … à … ? »
 *     (fr et en en phrases complètes ; les 7 autres langues en forme courte « question · service ·
 *     dates · ville », pour ne pas risquer une faute d'accord) ;
 *   · message au propriétaire : « <Prénom> est libre et vous attend · <prix> » ;
 *   · pages de confirmation servies par le serveur (le lien de l'e-mail n'agit jamais seul).
 * Aucun chiffre n'est écrit ici : le prix vient du moteur unique (priceLabel), les dates de la
 * demande (formatDates). Toute valeur venue d'un utilisateur est échappée avant d'entrer dans du HTML.
 */
const base = require('./applicationEmailText2610');
const { formatDates } = require('./requestAlertText612');

const { esc, lang2, serviceFamily, petKey } = base;

const T = {
  fr: {
    still: 'Êtes-vous toujours libre ?',
    svc: { sit: 'Garde', visit: 'Visite à domicile', walk: 'Promenade' },
    verb: { sit: 'garder', visit: 'rendre visite à', walk: 'promener' },
    pet: { dog: 'un chien', dogs: 'des chiens', cat: 'un chat', cats: 'des chats', pet: 'un animal', pets: 'des animaux' },
    and: 'et',
    when: (a, b) => (a && b && a !== b ? ` du ${a} au ${b}` : a ? ` le ${a}` : ''),
    ask: (v, p, w, c) => `Êtes-vous toujours libre pour ${v} ${p}${w}${c ? ` à ${c}` : ''} ?`,
    intro: 'Vous avez répondu à cette demande. Le propriétaire n’a pas encore choisi : dites-nous en un clic si vous êtes toujours disponible.',
    labels: { service: 'Service', dates: 'Dates', city: 'Ville', breed: 'Race', note: 'Message du propriétaire' },
    yes: 'Oui, je suis libre',
    no: 'Non, plus disponible',
    noLine: 'Vous n’êtes plus disponible ? Votre candidature sera retirée :',
    pushBody: 'Répondez oui ou non dans l’e-mail que nous venons de vous envoyer.',
    ownerSubject: (n) => `${n} est libre et vous attend`,
    ownerLine: (n, w) => `${n} vient de confirmer sa disponibilité pour votre demande${w}.`,
    pay: 'Payer et réserver',
    profile: 'Voir son profil',
    ownerPush: 'Ouvrez pour payer et réserver.',
    page: {
      yesTitle: 'Vous êtes toujours libre ?',
      yesText: 'Confirmez que vous êtes disponible pour cette demande.',
      noTitle: 'Vous n’êtes plus disponible ?',
      noText: 'Votre candidature pour cette demande sera retirée.',
      noBtn: 'Confirmer : plus disponible',
      thanksYes: 'Merci, c’est noté : vous êtes libre pour cette demande.',
      ownerTold: 'Nous prévenons le propriétaire.',
      thanksNo: 'C’est noté : votre candidature a été retirée. Merci de nous avoir prévenus.',
      invalid: 'Ce lien n’est pas valable.',
      expired: 'Ce lien a expiré.',
      gone: 'Cette demande n’est plus ouverte : il n’y a rien à faire.',
      error: 'Un problème est survenu. Réessayez dans quelques minutes.',
    },
  },
  en: {
    still: 'Are you still available?',
    svc: { sit: 'Pet sitting', visit: 'Home visit', walk: 'Dog walk' },
    verb: { sit: 'look after', visit: 'visit', walk: 'walk' },
    pet: { dog: 'a dog', dogs: 'dogs', cat: 'a cat', cats: 'cats', pet: 'a pet', pets: 'pets' },
    and: 'and',
    when: (a, b) => (a && b && a !== b ? ` from ${a} to ${b}` : a ? ` on ${a}` : ''),
    ask: (v, p, w, c) => `Are you still available to ${v} ${p}${w}${c ? ` in ${c}` : ''}?`,
    intro: 'You replied to this request. The owner has not chosen yet: tell us in one click whether you are still available.',
    labels: { service: 'Service', dates: 'Dates', city: 'City', breed: "Breed", note: "Owner's message" },
    yes: 'Yes, I am available',
    no: 'No, not available any more',
    noLine: 'Not available any more? Your application will be withdrawn:',
    pushBody: 'Answer yes or no in the email we have just sent you.',
    ownerSubject: (n) => `${n} is available and waiting for you`,
    ownerLine: (n, w) => `${n} has just confirmed being available for your request${w}.`,
    pay: 'Pay and book',
    profile: 'View profile',
    ownerPush: 'Open to pay and book.',
    page: {
      yesTitle: 'Are you still available?',
      yesText: 'Confirm that you are available for this request.',
      noTitle: 'Not available any more?',
      noText: 'Your application for this request will be withdrawn.',
      noBtn: 'Confirm: not available',
      thanksYes: 'Thank you, noted: you are available for this request.',
      ownerTold: 'We are letting the owner know.',
      thanksNo: 'Noted: your application has been withdrawn. Thank you for telling us.',
      invalid: 'This link is not valid.',
      expired: 'This link has expired.',
      gone: 'This request is no longer open: there is nothing to do.',
      error: 'Something went wrong. Please try again in a few minutes.',
    },
  },
  es: {
    still: '¿Sigue disponible?',
    svc: { sit: 'Cuidado de mascotas', visit: 'Visita a domicilio', walk: 'Paseo' },
    intro: 'Usted respondió a esta solicitud. El propietario aún no ha elegido: díganos en un clic si sigue disponible.',
    labels: { service: 'Servicio', dates: 'Fechas', city: 'Ciudad', breed: 'Raza', note: 'Mensaje del propietario' },
    yes: 'Sí, estoy disponible',
    no: 'No, ya no estoy disponible',
    noLine: '¿Ya no está disponible? Su candidatura se retirará:',
    pushBody: 'Responda sí o no en el correo que acabamos de enviarle.',
    ownerSubject: (n) => `${n} está disponible y le espera`,
    ownerLine: (n) => `${n} acaba de confirmar su disponibilidad para su solicitud.`,
    pay: 'Pagar y reservar',
    profile: 'Ver su perfil',
    ownerPush: 'Abra para pagar y reservar.',
    page: {
      yesTitle: '¿Sigue disponible?',
      yesText: 'Confirme que está disponible para esta solicitud.',
      noTitle: '¿Ya no está disponible?',
      noText: 'Su candidatura para esta solicitud se retirará.',
      noBtn: 'Confirmar: no disponible',
      thanksYes: 'Gracias, anotado: está disponible para esta solicitud.',
      ownerTold: 'Avisamos al propietario.',
      thanksNo: 'Anotado: su candidatura se ha retirado. Gracias por avisarnos.',
      invalid: 'Este enlace no es válido.',
      expired: 'Este enlace ha caducado.',
      gone: 'Esta solicitud ya no está abierta: no hay nada que hacer.',
      error: 'Ha ocurrido un problema. Inténtelo de nuevo en unos minutos.',
    },
  },
  de: {
    still: 'Sind Sie noch verfügbar?',
    svc: { sit: 'Tierbetreuung', visit: 'Hausbesuch', walk: 'Gassi-Service' },
    intro: 'Sie haben auf diese Anfrage geantwortet. Der Besitzer hat noch nicht gewählt: Sagen Sie uns mit einem Klick, ob Sie noch verfügbar sind.',
    labels: { service: 'Service', dates: 'Daten', city: 'Ort', breed: 'Rasse', note: 'Nachricht des Halters' },
    yes: 'Ja, ich bin verfügbar',
    no: 'Nein, nicht mehr verfügbar',
    noLine: 'Nicht mehr verfügbar? Ihre Bewerbung wird zurückgezogen:',
    pushBody: 'Antworten Sie mit Ja oder Nein in der E-Mail, die wir Ihnen gerade gesendet haben.',
    ownerSubject: (n) => `${n} ist verfügbar und wartet auf Sie`,
    ownerLine: (n) => `${n} hat gerade bestätigt, für Ihre Anfrage verfügbar zu sein.`,
    pay: 'Bezahlen und buchen',
    profile: 'Profil ansehen',
    ownerPush: 'Öffnen, um zu bezahlen und zu buchen.',
    page: {
      yesTitle: 'Sind Sie noch verfügbar?',
      yesText: 'Bestätigen Sie, dass Sie für diese Anfrage verfügbar sind.',
      noTitle: 'Nicht mehr verfügbar?',
      noText: 'Ihre Bewerbung für diese Anfrage wird zurückgezogen.',
      noBtn: 'Bestätigen: nicht verfügbar',
      thanksYes: 'Danke, notiert: Sie sind für diese Anfrage verfügbar.',
      ownerTold: 'Wir informieren den Besitzer.',
      thanksNo: 'Notiert: Ihre Bewerbung wurde zurückgezogen. Danke für die Information.',
      invalid: 'Dieser Link ist nicht gültig.',
      expired: 'Dieser Link ist abgelaufen.',
      gone: 'Diese Anfrage ist nicht mehr offen: Es gibt nichts zu tun.',
      error: 'Ein Problem ist aufgetreten. Bitte versuchen Sie es in einigen Minuten erneut.',
    },
  },
  it: {
    still: 'È ancora disponibile?',
    svc: { sit: 'Pet sitting', visit: 'Visita a domicilio', walk: 'Passeggiata' },
    intro: 'Ha risposto a questa richiesta. Il proprietario non ha ancora scelto: ci dica con un clic se è ancora disponibile.',
    labels: { service: 'Servizio', dates: 'Date', city: 'Città', breed: 'Razza', note: 'Messaggio del proprietario' },
    yes: 'Sì, sono disponibile',
    no: 'No, non sono più disponibile',
    noLine: 'Non è più disponibile? La sua candidatura sarà ritirata:',
    pushBody: 'Risponda sì o no nell’e-mail che le abbiamo appena inviato.',
    ownerSubject: (n) => `${n} è disponibile e la aspetta`,
    ownerLine: (n) => `${n} ha appena confermato la sua disponibilità per la sua richiesta.`,
    pay: 'Paga e prenota',
    profile: 'Vedi il profilo',
    ownerPush: 'Apra per pagare e prenotare.',
    page: {
      yesTitle: 'È ancora disponibile?',
      yesText: 'Confermi di essere disponibile per questa richiesta.',
      noTitle: 'Non è più disponibile?',
      noText: 'La sua candidatura per questa richiesta sarà ritirata.',
      noBtn: 'Conferma: non disponibile',
      thanksYes: 'Grazie, annotato: è disponibile per questa richiesta.',
      ownerTold: 'Avvisiamo il proprietario.',
      thanksNo: 'Annotato: la sua candidatura è stata ritirata. Grazie per averci avvisato.',
      invalid: 'Questo link non è valido.',
      expired: 'Questo link è scaduto.',
      gone: 'Questa richiesta non è più aperta: non c’è nulla da fare.',
      error: 'Si è verificato un problema. Riprovi tra qualche minuto.',
    },
  },
  pt: {
    still: 'Ainda está disponível?',
    svc: { sit: 'Pet sitting', visit: 'Visita ao domicílio', walk: 'Passeio' },
    intro: 'Respondeu a este pedido. O dono ainda não escolheu: diga-nos com um clique se ainda está disponível.',
    labels: { service: 'Serviço', dates: 'Datas', city: 'Cidade', breed: 'Raça', note: 'Mensagem do dono' },
    yes: 'Sim, estou disponível',
    no: 'Não, já não estou disponível',
    noLine: 'Já não está disponível? A sua candidatura será retirada:',
    pushBody: 'Responda sim ou não no e-mail que acabámos de lhe enviar.',
    ownerSubject: (n) => `${n} está disponível e espera por si`,
    ownerLine: (n) => `${n} acaba de confirmar a sua disponibilidade para o seu pedido.`,
    pay: 'Pagar e reservar',
    profile: 'Ver o perfil',
    ownerPush: 'Abra para pagar e reservar.',
    page: {
      yesTitle: 'Ainda está disponível?',
      yesText: 'Confirme que está disponível para este pedido.',
      noTitle: 'Já não está disponível?',
      noText: 'A sua candidatura para este pedido será retirada.',
      noBtn: 'Confirmar: não disponível',
      thanksYes: 'Obrigado, anotado: está disponível para este pedido.',
      ownerTold: 'Estamos a avisar o dono.',
      thanksNo: 'Anotado: a sua candidatura foi retirada. Obrigado por nos avisar.',
      invalid: 'Esta ligação não é válida.',
      expired: 'Esta ligação expirou.',
      gone: 'Este pedido já não está aberto: não há nada a fazer.',
      error: 'Ocorreu um problema. Tente novamente dentro de alguns minutos.',
    },
  },
  ko: {
    still: '아직 가능하신가요?',
    svc: { sit: '펫시팅', visit: '방문 돌봄', walk: '산책' },
    intro: '이 요청에 지원하셨습니다. 보호자가 아직 선택하지 않았습니다. 아직 가능하신지 한 번의 클릭으로 알려 주세요.',
    labels: { service: '서비스', dates: '날짜', city: '지역', breed: '품종', note: '보호자 메시지' },
    yes: '네, 가능합니다',
    no: '아니요, 더 이상 불가능합니다',
    noLine: '더 이상 가능하지 않으신가요? 지원이 취소됩니다:',
    pushBody: '방금 보내 드린 이메일에서 예 또는 아니요로 답해 주세요.',
    ownerSubject: (n) => `${n} 님이 가능하며 기다리고 있어요`,
    ownerLine: (n) => `${n} 님이 방금 요청에 대해 가능하다고 확인했습니다.`,
    pay: '결제하고 예약하기',
    profile: '프로필 보기',
    ownerPush: '열어서 결제하고 예약하세요.',
    page: {
      yesTitle: '아직 가능하신가요?',
      yesText: '이 요청에 대해 가능하다고 확인해 주세요.',
      noTitle: '더 이상 가능하지 않으신가요?',
      noText: '이 요청에 대한 지원이 취소됩니다.',
      noBtn: '확인: 불가능합니다',
      thanksYes: '감사합니다. 이 요청에 대해 가능하다고 기록했습니다.',
      ownerTold: '보호자에게 알려 드립니다.',
      thanksNo: '기록했습니다. 지원이 취소되었습니다. 알려 주셔서 감사합니다.',
      invalid: '이 링크는 유효하지 않습니다.',
      expired: '이 링크는 만료되었습니다.',
      gone: '이 요청은 더 이상 열려 있지 않습니다. 하실 일이 없습니다.',
      error: '문제가 발생했습니다. 몇 분 후에 다시 시도해 주세요.',
    },
  },
  ja: {
    still: 'まだご都合はよろしいですか？',
    svc: { sit: 'ペットシッティング', visit: '訪問ケア', walk: 'お散歩' },
    intro: 'この依頼に応募されました。飼い主はまだ選んでいません。まだ対応可能かどうか、ワンクリックでお知らせください。',
    labels: { service: 'サービス', dates: '日程', city: '地域', breed: '犬種・猫種', note: '飼い主からのメッセージ' },
    yes: 'はい、対応できます',
    no: 'いいえ、対応できなくなりました',
    noLine: '対応できなくなりましたか？応募は取り下げられます：',
    pushBody: '先ほどお送りしたメールで「はい」か「いいえ」をお答えください。',
    ownerSubject: (n) => `${n}さんが対応可能で、お待ちしています`,
    ownerLine: (n) => `${n}さんが、ご依頼に対応できることを確認しました。`,
    pay: '支払って予約する',
    profile: 'プロフィールを見る',
    ownerPush: '開いて支払い、予約してください。',
    page: {
      yesTitle: 'まだご都合はよろしいですか？',
      yesText: 'この依頼に対応できることをご確認ください。',
      noTitle: '対応できなくなりましたか？',
      noText: 'この依頼への応募は取り下げられます。',
      noBtn: '確認：対応できません',
      thanksYes: 'ありがとうございます。この依頼に対応可能として記録しました。',
      ownerTold: '飼い主にお知らせします。',
      thanksNo: '記録しました。応募は取り下げられました。お知らせいただきありがとうございます。',
      invalid: 'このリンクは無効です。',
      expired: 'このリンクは期限切れです。',
      gone: 'この依頼はすでに受付を終了しています。対応は不要です。',
      error: '問題が発生しました。数分後にもう一度お試しください。',
    },
  },
  pl: {
    still: 'Czy nadal masz czas?',
    svc: { sit: 'Opieka nad zwierzęciem', visit: 'Wizyta domowa', walk: 'Spacer' },
    intro: 'Masz zgłoszenie do tej prośby. Właściciel jeszcze nie wybrał: daj nam znać jednym kliknięciem, czy nadal masz czas.',
    labels: { service: 'Usługa', dates: 'Daty', city: 'Miasto', breed: 'Rasa', note: 'Wiadomość od właściciela' },
    yes: 'Tak, mam czas',
    no: 'Nie, już nie mam czasu',
    noLine: 'Nie masz już czasu? Twoje zgłoszenie zostanie wycofane:',
    pushBody: 'Odpowiedz tak lub nie w e-mailu, który właśnie wysłaliśmy.',
    ownerSubject: (n) => `${n} ma czas i czeka na Ciebie`,
    ownerLine: (n) => `${n} właśnie potwierdza, że ma czas na Twoją prośbę.`,
    pay: 'Zapłać i zarezerwuj',
    profile: 'Zobacz profil',
    ownerPush: 'Otwórz, aby zapłacić i zarezerwować.',
    page: {
      yesTitle: 'Czy nadal masz czas?',
      yesText: 'Potwierdź, że masz czas na tę prośbę.',
      noTitle: 'Nie masz już czasu?',
      noText: 'Twoje zgłoszenie do tej prośby zostanie wycofane.',
      noBtn: 'Potwierdź: nie mam czasu',
      thanksYes: 'Dziękujemy, zapisane: masz czas na tę prośbę.',
      ownerTold: 'Powiadamiamy właściciela.',
      thanksNo: 'Zapisane: Twoje zgłoszenie zostało wycofane. Dziękujemy za informację.',
      invalid: 'Ten link jest nieprawidłowy.',
      expired: 'Ten link wygasł.',
      gone: 'Ta prośba nie jest już otwarta: nie trzeba nic robić.',
      error: 'Wystąpił problem. Spróbuj ponownie za kilka minut.',
    },
  },
};

const L = (lang) => T[lang2(lang)] || T.en;

const day = (d, lang) => (d ? formatDates(d, d, lang2(lang)) : '');

/** Dates de la demande, déjà formatées dans la langue (« 12 novembre – 15 novembre »). */
const datesOf = (post, lang) => formatDates(post && post.startDate, post && post.endDate, lang2(lang));

/** Nom(s) de l'animal (1 ou 2), sinon « un chien / un chat / un animal » — fr et en seulement. */
const petPhrase = (lang, post, petNames) => {
  const t = L(lang);
  const names = (Array.isArray(petNames) ? petNames : []).map((n) => String(n || '').trim()).filter(Boolean);
  if (names.length === 1) return names[0];
  if (names.length === 2) return `${names[0]} ${t.and || '&'} ${names[1]}`;
  return t.pet ? t.pet[petKey(post)] || t.pet.pet : '';
};

/**
 * La question posée au prestataire, en une phrase (objet de l'e-mail).
 * @param {{lang:string, post:object, serviceType?:string, petNames?:string[]}} p
 */
function questionLine({ lang, post, serviceType, petNames }) {
  const l = lang2(lang);
  const t = L(l);
  const fam = serviceFamily(serviceType || (post && Array.isArray(post.serviceTypes) ? post.serviceTypes[0] : ''));
  const city = base.cityOfPost(post);
  if (t.ask) {
    const w = t.when(day(post && post.startDate, l), day(post && (post.endDate || post.startDate), l));
    return t.ask(t.verb[fam], petPhrase(l, post, petNames), w, city);
  }
  return [t.still, [t.svc[fam], datesOf(post, l), city].filter(Boolean).join(' · ')].filter(Boolean).join(' ');
}

const row = (label, value) => (value
  ? `<tr><td style="padding:4px 12px 4px 0;font-size:14px;color:#6E4F48;white-space:nowrap;vertical-align:top">${esc(label)}</td><td style="padding:4px 0;font-size:15px;font-weight:700;color:#231715">${esc(value)}</td></tr>`
  : '');

/**
 * Données de rendu de la QUESTION (gabarit application_new_2610) : le bouton principal du
 * gabarit est « Oui » (`emailLink`), le lien « Non » est dans le corps.
 */
/**
 * 11/11/2026 (BOB, ordre de Daniel après la demande d'une gardienne : « merci de me dire la race à chaque fois ») —
 * la race de l'animal (fiche animal de la demande) et un court extrait du message du propriétaire sont ajoutés à
 * l'e-mail « êtes-vous toujours libre ? ». Rien d'inventé : pas de race connue = pas de ligne. L'extrait est
 * nettoyé de toute adresse e-mail, lien et numéro de téléphone. Coupe-circuit : SITTER_FREE_BREED_1111=off.
 */
const breedOn1111 = () => String(process.env.SITTER_FREE_BREED_1111 || '').trim().toLowerCase() !== 'off';
function breedLine1111(breeds) {
  if (!breedOn1111() || !Array.isArray(breeds)) return '';
  const seen = new Set();
  const out = [];
  for (const b of breeds) {
    const v = String(b || '').replace(/\s+/g, ' ').trim().slice(0, 40);
    const k = v.toLowerCase();
    if (!v || seen.has(k)) continue;
    seen.add(k);
    out.push(v);
    if (out.length >= 3) break;
  }
  return out.join(', ');
}
function noteLine1111(post) {
  if (!breedOn1111()) return '';
  let v = String((post && post.body) || '').replace(/\s+/g, ' ').trim();
  if (!v) return '';
  v = v
    .replace(/[^\s@]+@[^\s@]+\.[^\s@]+/g, '…')
    .replace(/(?:https?:\/\/|www\.)\S+/gi, '…')
    .replace(/(?:\+|00)?\d[\d .()\-]{7,}\d/g, '…');
  return v.length > 160 ? `${v.slice(0, 157).trimEnd()}…` : v;
}

function questionEmailData({ lang, post, serviceType, petNames, breeds, yesLink, noLink }) {
  const l = lang2(lang);
  const t = L(l);
  const fam = serviceFamily(serviceType || (post && Array.isArray(post.serviceTypes) ? post.serviceTypes[0] : ''));
  const html = `<p style="margin:0 0 12px;font-size:15px;line-height:1.5;color:#231715">${esc(t.intro)}</p>`
    + `<table role="presentation" cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin:0 0 14px">${row(t.labels.service, t.svc[fam])}${row(t.labels.dates, datesOf(post, l))}${row(t.labels.city, base.cityOfPost(post))}${row(t.labels.breed, breedLine1111(breeds))}${row(t.labels.note, noteLine1111(post))}</table>`
    + (/^https:\/\//.test(String(noLink || ''))
      ? `<p style="margin:0 0 16px;font-size:14px;line-height:1.5;color:#6E4F48">${esc(t.noLine)} <a href="${esc(noLink)}" style="color:#9E1F0B;font-weight:700">${esc(t.no)}</a></p>`
      : '');
  return {
    subjectLine: questionLine({ lang: l, post, serviceType, petNames }),
    candidatesHtml2610: html,
    ctaLabel: t.yes,
    emailLink: String(yesLink || ''),
  };
}

/** Push / cloche de la question (gabarit application_reminder_615 : titre ≠ corps). */
function questionPushData({ lang }) {
  const t = L(lang);
  return { reminderTitle: t.still, reminderBody: t.pushBody };
}

/**
 * Données de rendu du MESSAGE AU PROPRIÉTAIRE (gabarit application_new_2610).
 * @param {{lang:string, post:object, card:object, payLink:string, now?:number}} p  card = carte de applicationEmail2610.cardsFor
 */
function ownerEmailData({ lang, post, card, payLink, now = Date.now() }) {
  const l = lang2(lang);
  const t = L(l);
  const B = base.T[l] || base.T.en;
  const name = String((card && card.name) || 'HoPetSit');
  const price = base.priceLabel(l, card && card.pricing);
  const w = t.when ? t.when(day(post && post.startDate, l), day(post && (post.endDate || post.startDate), l)) : '';
  const start = post && post.startDate ? new Date(post.startDate).getTime() : NaN;
  const free72 = Number.isFinite(start) && start - now > 72 * 3600 * 1000;
  const dates = datesOf(post, l);
  const html = `<p style="margin:0 0 12px;font-size:15px;line-height:1.5;color:#231715">${esc(t.ownerLine(name, w))}${!t.when && dates ? ` <span style="white-space:nowrap">${esc(dates)}</span>` : ''}</p>`
    + base.cardsHtml(l, [{ ...card, link: '' }])
    + (/^https:\/\//.test(String(payLink || ''))
      ? `<p style="margin:0 0 12px"><a href="${esc(payLink)}" style="display:block;padding:14px 10px;background:#C92A12;color:#FFFFFF;text-decoration:none;border-radius:12px;font-size:17px;font-weight:800;text-align:center;font-family:sans-serif">${esc(t.pay)}</a></p>`
      : '')
    + (B.guar ? `<p style="margin:0 0 14px;padding:10px 12px;background:#EAF6EE;border-radius:10px;font-size:14px;font-weight:600;line-height:1.5;color:#15803D">${free72 ? `✓ ${esc(B.guar[0])}<br>` : ''}✓ ${esc(B.guar[1])}</p>` : '');
  return {
    subjectLine: [t.ownerSubject(name), price].filter(Boolean).join(' · '),
    candidatesHtml2610: html,
    ctaLabel: t.profile,
  };
}

/** Push / cloche du message au propriétaire. */
function ownerPushData({ lang, post, card }) {
  const l = lang2(lang);
  const t = L(l);
  const price = base.priceLabel(l, card && card.pricing);
  return {
    reminderTitle: t.ownerSubject(String((card && card.name) || 'HoPetSit')),
    reminderBody: [[datesOf(post, l), price].filter(Boolean).join(' · '), t.ownerPush].filter(Boolean).join(' — '),
  };
}

/**
 * Page HTML servie par le serveur (confirmation ou résultat). Aucun script, aucune ressource
 * externe ; styles en ligne (compatibles avec la politique de sécurité du serveur).
 * @param {{lang:string, title:string, lines?:string[], button?:string, action?:string, tone?:'ok'|'warn'}} p
 */
function pageHtml({ lang, title, lines = [], button = '', action = '', tone = 'ok' }) {
  const l = lang2(lang);
  const body = lines.filter(Boolean).map((x) => `<p style="margin:0 0 12px;font-size:17px;line-height:1.5;color:#231715">${esc(x)}</p>`).join('');
  const form = button && action
    ? `<form method="POST" action="${esc(action)}" style="margin:18px 0 0"><button type="submit" style="display:block;width:100%;padding:16px 12px;border:0;border-radius:14px;background:${tone === 'warn' ? '#231715' : '#C92A12'};color:#FFFFFF;font-size:18px;font-weight:800;font-family:inherit;cursor:pointer">${esc(button)}</button></form>`
    : '';
  return `<!doctype html><html lang="${esc(l)}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex, nofollow"><title>HoPetSit</title></head>`
    + '<body style="margin:0;padding:24px 16px;background:#FFF6F2;font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,Arial,sans-serif">'
    + '<div style="max-width:440px;margin:0 auto;padding:22px 18px;background:#FFFFFF;border-radius:18px">'
    + '<div style="margin:0 0 14px;font-size:15px;font-weight:800;color:#C92A12">HoPetSit</div>'
    + `<h1 style="margin:0 0 14px;font-size:22px;line-height:1.3;color:#231715">${esc(title)}</h1>${body}${form}`
    + '</div></body></html>';
}

module.exports = {
  T, L, datesOf, petPhrase, questionLine, questionEmailData, breedLine1111, noteLine1111, questionPushData, ownerEmailData, ownerPushData, pageHtml,
};
