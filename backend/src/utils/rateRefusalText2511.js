/**
 * 2511b (BOB, 25/11/2026 — ordre de Daniel : « je veux que les clients comprennent », constat de ZOE) — TEXTE des refus
 * « il manque un tarif » de createApplication, dans la langue du prestataire (9 langues), en tutoiement.
 *
 * Avant : le champ `error` était une phrase en anglais (« Set your price per home visit before applying… ») que l'accueil
 * de l'app affiche telle quelle. Maintenant : une phrase courte qui dit QUOI faire et OÙ (« Mes tarifs », le nom exact de
 * l'écran dans l'app : clé `my_rates_section_title`). Les codes (`RATE_REQUIRED`, `VISIT_RATE_REQUIRED`) et les statuts
 * HTTP (400) ne changent pas : seul le texte lu par l'utilisateur change.
 *
 *   noRate        gardien sans AUCUN tarif (demande autre qu'une garde à la journée / à la nuit)
 *   visitRate     gardien sans tarif par visite sur une demande de visites à domicile   (VISIT_RATE_REQUIRED)
 *   walkRate      promeneur sans aucun tarif de balade
 *   serviceRate   pas de tarif pour le service demandé                                  (RATE_REQUIRED)
 *   walkerNotWalk promeneur sur une demande dont le service principal n'est pas une balade (RATE_REQUIRED) : il n'a
 *                 aucun tarif à ajouter (un profil promeneur n'a que des tarifs de balade) — on ne l'envoie donc PAS
 *                 dans « Mes tarifs ». La règle de prix d'un promeneur sur une garde reste une décision de Daniel.
 */
const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

const TEXTS = {
  fr: {
    noRate: 'Ajoute ton tarif dans Mes tarifs pour répondre à cette demande.',
    visitRate: 'Ajoute ton tarif par visite dans Mes tarifs pour répondre à cette demande.',
    walkRate: 'Ajoute ton tarif de balade dans Mes tarifs pour répondre aux demandes.',
    serviceRate: 'Ajoute ton tarif pour ce service dans Mes tarifs pour répondre à cette demande.',
    walkerNotWalk: 'Cette demande n\'est pas une simple balade : pour l\'instant, en profil promeneur, tu réponds seulement aux demandes de balade.',
  },
  en: {
    noRate: 'Add your rate in My rates to apply to this request.',
    visitRate: 'Add your price per visit in My rates to apply to this request.',
    walkRate: 'Add your walk price in My rates to apply to requests.',
    serviceRate: 'Add your rate for this service in My rates to apply to this request.',
    walkerNotWalk: 'This request isn\'t just a walk: for now, as a walker, you can only apply to walk requests.',
  },
  es: {
    noRate: 'Añade tu tarifa en Mis tarifas para responder a esta solicitud.',
    visitRate: 'Añade tu precio por visita en Mis tarifas para responder a esta solicitud.',
    walkRate: 'Añade tu precio de paseo en Mis tarifas para responder a las solicitudes.',
    serviceRate: 'Añade tu tarifa para este servicio en Mis tarifas para responder a esta solicitud.',
    walkerNotWalk: 'Esta solicitud no es solo un paseo: por ahora, como paseador, solo puedes responder a solicitudes de paseo.',
  },
  de: {
    noRate: 'Trag deinen Preis unter „Meine Tarife“ ein, um auf diese Anfrage zu antworten.',
    visitRate: 'Trag deinen Preis pro Besuch unter „Meine Tarife“ ein, um auf diese Anfrage zu antworten.',
    walkRate: 'Trag deinen Preis für Spaziergänge unter „Meine Tarife“ ein, um auf Anfragen zu antworten.',
    serviceRate: 'Trag deinen Preis für diese Leistung unter „Meine Tarife“ ein, um auf diese Anfrage zu antworten.',
    walkerNotWalk: 'Diese Anfrage ist nicht nur ein Spaziergang: Als Gassigeher kannst du im Moment nur auf Gassi-Anfragen antworten.',
  },
  it: {
    noRate: 'Aggiungi la tua tariffa in «Le mie tariffe» per rispondere a questa richiesta.',
    visitRate: 'Aggiungi il tuo prezzo per visita in «Le mie tariffe» per rispondere a questa richiesta.',
    walkRate: 'Aggiungi il tuo prezzo per le passeggiate in «Le mie tariffe» per rispondere alle richieste.',
    serviceRate: 'Aggiungi la tua tariffa per questo servizio in «Le mie tariffe» per rispondere a questa richiesta.',
    walkerNotWalk: 'Questa richiesta non è solo una passeggiata: per ora, come dog walker, puoi rispondere solo alle richieste di passeggiata.',
  },
  pt: {
    noRate: 'Adiciona a tua tarifa em «As minhas tarifas» para responderes a este pedido.',
    visitRate: 'Adiciona o teu preço por visita em «As minhas tarifas» para responderes a este pedido.',
    walkRate: 'Adiciona o teu preço de passeio em «As minhas tarifas» para responderes aos pedidos.',
    serviceRate: 'Adiciona a tua tarifa para este serviço em «As minhas tarifas» para responderes a este pedido.',
    walkerNotWalk: 'Este pedido não é só um passeio: por agora, como passeador, só podes responder a pedidos de passeio.',
  },
  ko: {
    noRate: '이 요청에 지원하려면 ‘내 요금’에 요금을 추가하세요.',
    visitRate: '이 요청에 지원하려면 ‘내 요금’에 방문 1회 요금을 추가하세요.',
    walkRate: '요청에 지원하려면 ‘내 요금’에 산책 요금을 추가하세요.',
    serviceRate: '이 요청에 지원하려면 ‘내 요금’에 이 서비스의 요금을 추가하세요.',
    walkerNotWalk: '이 요청은 산책만이 아니에요. 지금은 산책 도우미로 산책 요청에만 지원할 수 있어요.',
  },
  ja: {
    noRate: 'この依頼に応募するには、「料金設定」で料金を追加してください。',
    visitRate: 'この依頼に応募するには、「料金設定」で訪問1回の料金を追加してください。',
    walkRate: '依頼に応募するには、「料金設定」で散歩の料金を追加してください。',
    serviceRate: 'この依頼に応募するには、「料金設定」でこのサービスの料金を追加してください。',
    walkerNotWalk: 'この依頼は散歩だけではありません。現在、散歩代行としては散歩の依頼にのみ応募できます。',
  },
  pl: {
    noRate: 'Dodaj stawkę w „Moje stawki”, aby odpowiedzieć na to zgłoszenie.',
    visitRate: 'Dodaj cenę za wizytę w „Moje stawki”, aby odpowiedzieć na to zgłoszenie.',
    walkRate: 'Dodaj cenę spaceru w „Moje stawki”, aby odpowiadać na zgłoszenia.',
    serviceRate: 'Dodaj stawkę za tę usługę w „Moje stawki”, aby odpowiedzieć na to zgłoszenie.',
    walkerNotWalk: 'To zgłoszenie to nie tylko spacer: na razie jako wyprowadzacz możesz odpowiadać tylko na zgłoszenia spacerów.',
  },
};

const KEYS = Object.keys(TEXTS.fr);

/** Langue (2 lettres) d'un profil : appLocale, sinon language ; anglais si inconnue. */
function localeOf(doc) {
  const raw = String((doc && (doc.appLocale || doc.language)) || '').trim().toLowerCase().slice(0, 2);
  return LANGS.includes(raw) ? raw : 'en';
}

/**
 * Texte d'un refus dans la langue donnée (ou celle d'un profil).
 * @param {string|object} langOrDoc  code de langue ('fr', 'pt-BR'…) ou document Sitter / Walker
 * @param {'noRate'|'visitRate'|'walkRate'|'serviceRate'|'walkerNotWalk'} key
 */
function refusalText(langOrDoc, key) {
  const lang = langOrDoc && typeof langOrDoc === 'object'
    ? localeOf(langOrDoc)
    : localeOf({ appLocale: langOrDoc });
  const k = KEYS.includes(key) ? key : 'serviceRate';
  return TEXTS[lang][k];
}

/**
 * Refus RATE_REQUIRED : un promeneur sur une demande dont le service principal n'est pas une balade n'a aucun tarif à
 * ajouter → texte dédié ; tous les autres cas → « ajoute ton tarif pour ce service ».
 * @param {{providerRole?:string, unit?:string}} p unit = unité du service principal de la demande (day|night|visit|walk)
 */
function rateRequiredKey({ providerRole, unit } = {}) {
  return providerRole === 'walker' && unit && unit !== 'walk' ? 'walkerNotWalk' : 'serviceRate';
}

module.exports = { LANGS, TEXTS, KEYS, localeOf, refusalText, rateRequiredKey };
