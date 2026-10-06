/**
 * 612 (ZOE, 05/10/2026) — textes de l'alerte « nouvelle annonce » dans la langue du
 * DESTINATAIRE (9 langues) : qui est cherché, quel service, quelles dates.
 * Fonctions pures. Les gabarits (locales/<lang>/notifications.json) lisent :
 *   {{serviceLabel}}  « un promeneur » / « a dog walker » …   (après « cherche »)
 *   {{serviceName}}   « Promenade de chien » / « Dog walking » …
 *   {{dates}}         « 12 octobre – 14 octobre » ou « à convenir »
 *   {{datesSep}}      «  · 12 octobre – 14 octobre » ou « » (push, cloche)
 *   {{cityLabel}}     la ville, ou « près de chez toi » si l'annonce n'en a pas
 */
const LOCALES = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const INTL = { fr: 'fr-FR', en: 'en-US', es: 'es-ES', de: 'de-DE', it: 'it-IT', pt: 'pt-PT', ko: 'ko-KR', ja: 'ja-JP', pl: 'pl-PL' };

// Famille du service → rôle cherché.
const WALK = new Set(['dog_walking', 'dog walking', 'walking', 'walk']);
const isWalkingService = (s) => WALK.has(String(s || '').trim().toLowerCase());

const SEEKING = {
  walker: { fr: 'un promeneur', en: 'a dog walker', es: 'un paseador', de: 'einen Gassi-Service', it: 'un dog sitter per le passeggiate', pt: 'um passeador', ko: '산책 도우미', ja: 'お散歩シッター', pl: 'osoby do wyprowadzania psa' },
  sitter: { fr: 'un gardien', en: 'a pet sitter', es: 'un cuidador', de: 'eine Tierbetreuung', it: 'un pet sitter', pt: 'um cuidador', ko: '펫시터', ja: 'ペットシッター', pl: 'opiekuna dla zwierzaka' },
};

const SERVICE_NAMES = {
  dog_walking: { fr: 'Promenade de chien', en: 'Dog walking', es: 'Paseo de perros', de: 'Gassi gehen', it: 'Passeggiata con il cane', pt: 'Passeio de cães', ko: '반려견 산책', ja: '犬のお散歩', pl: 'Spacer z psem' },
  pet_sitting: { fr: 'Garde d’animaux', en: 'Pet sitting', es: 'Cuidado de mascotas', de: 'Tierbetreuung', it: 'Pet sitting', pt: 'Pet sitting', ko: '펫시팅', ja: 'ペットシッティング', pl: 'Opieka nad zwierzęciem' },
  house_sitting: { fr: 'Garde à domicile', en: 'House sitting', es: 'Cuidado a domicilio', de: 'Betreuung zu Hause', it: 'Custodia a domicilio', pt: 'Cuidado ao domicílio', ko: '방문 돌봄', ja: '在宅ペットシッティング', pl: 'Opieka w domu' },
  day_care: { fr: 'Garderie de jour', en: 'Day care', es: 'Guardería de día', de: 'Tagesbetreuung', it: 'Asilo diurno', pt: 'Creche de dia', ko: '주간 돌봄', ja: '日中のお預かり', pl: 'Opieka dzienna' },
  home_visit: { fr: 'Visite à domicile', en: 'Home visit', es: 'Visita a domicilio', de: 'Hausbesuch', it: 'Visita a domicilio', pt: 'Visita ao domicílio', ko: '방문 서비스', ja: '訪問ケア', pl: 'Wizyta domowa' },
  overnight_stay: { fr: 'Garde de nuit', en: 'Overnight stay', es: 'Cuidado nocturno', de: 'Übernachtungsbetreuung', it: 'Custodia notturna', pt: 'Estadia noturna', ko: '숙박 돌봄', ja: 'お泊まり', pl: 'Opieka nocna' },
};
const SERVICE_ALIASES = { 'dog walking': 'dog_walking', 'pet sitting': 'pet_sitting', 'house sitting': 'house_sitting', 'day care': 'day_care', daycare: 'day_care', sitting: 'pet_sitting', boarding: 'overnight_stay', overnight: 'overnight_stay' };

const NEARBY = { fr: 'près de chez toi', en: 'near you', es: 'cerca de ti', de: 'in deiner Nähe', it: 'vicino a te', pt: 'perto de ti', ko: '내 근처', ja: 'お近く', pl: 'w Twojej okolicy' };
const AN_OWNER = { fr: 'Un propriétaire', en: 'A pet owner', es: 'Un propietario', de: 'Ein Tierhalter', it: 'Un proprietario', pt: 'Um dono', ko: '한 보호자', ja: '飼い主', pl: 'Właściciel' };
const FLEXIBLE = { fr: 'à convenir', en: 'to be agreed', es: 'por acordar', de: 'nach Absprache', it: 'da concordare', pt: 'a combinar', ko: '협의', ja: '応相談', pl: 'do uzgodnienia' };

const normLocale = (l) => {
  const s = String(l || '').toLowerCase().slice(0, 2);
  return LOCALES.includes(s) ? s : 'fr';
};
const serviceKey = (s) => {
  const k = String(s || '').trim().toLowerCase();
  if (SERVICE_NAMES[k]) return k;
  return SERVICE_ALIASES[k] || '';
};

const toDate = (v) => {
  if (!v) return null;
  const d = v instanceof Date ? v : new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};

/**
 * Jour et mois dans la langue demandée. L'heure choisie par le propriétaire est
 * enregistrée telle quelle (heure « murale ») : on formate donc en UTC pour
 * retrouver SON jour, quel que soit le fuseau du serveur.
 */
const formatDay = (d, locale) => new Intl.DateTimeFormat(INTL[normLocale(locale)], {
  day: 'numeric', month: 'long', timeZone: 'UTC',
}).format(d);

const formatDates = (start, end, locale) => {
  const s = toDate(start);
  const e = toDate(end);
  if (!s && !e) return '';
  if (s && !e) return formatDay(s, locale);
  if (!s && e) return formatDay(e, locale);
  const a = formatDay(s, locale);
  const b = formatDay(e, locale);
  return a === b ? a : `${a} – ${b}`;
};

/**
 * Complète les données d'une alerte d'annonce pour UNE langue. N'écrase jamais
 * une valeur déjà fournie. Tolère des données anciennes (sans dates ni service).
 */
const enrichRequestAlertData = (data, locale) => {
  const d = data && typeof data === 'object' ? { ...data } : {};
  const lang = normLocale(locale);
  const key = serviceKey(d.serviceType);
  const role = isWalkingService(d.serviceType) || key === 'dog_walking' ? 'walker' : 'sitter';
  if (!d.serviceLabel) d.serviceLabel = SEEKING[role][lang];
  if (!d.serviceName) d.serviceName = key ? SERVICE_NAMES[key][lang] : SERVICE_NAMES[role === 'walker' ? 'dog_walking' : 'pet_sitting'][lang];
  const dates = formatDates(d.startDate, d.endDate, lang);
  d.datesSep = dates ? ` · ${dates}` : '';
  d.dates = dates || FLEXIBLE[lang];
  if (d.city == null) d.city = '';
  // Ville affichée (« près de chez toi » si l'annonce n'en porte pas) et nom du
  // propriétaire (jamais une phrase qui commence par un blanc).
  d.cityLabel = String(d.city || '').trim() || NEARBY[lang];
  if (!String(d.ownerName || '').trim()) d.ownerName = AN_OWNER[lang];
  return d;
};

const REQUEST_ALERT_TYPES = new Set(['new_request_nearby', 'new_request_for_you']);

module.exports = {
  LOCALES, SEEKING, SERVICE_NAMES, FLEXIBLE, NEARBY, AN_OWNER, REQUEST_ALERT_TYPES,
  isWalkingService, serviceKey, formatDates, enrichRequestAlertData,
};
