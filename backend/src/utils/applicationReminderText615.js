/**
 * 615 (ZOE, 07/10/2026) — texte du RAPPEL « tu as N candidats, choisis le tien »,
 * dans la langue du PROPRIÉTAIRE (9 langues). Fonctions pures.
 *
 * Données lues (posées par services/applicationReminder615.js) :
 *   candidates   nombre de candidatures en attente (≥ 1)
 *   serviceKind  'walk' | 'visit' | 'sitting'
 *   startWall    heure du service « murale » (enregistrée telle que choisie, lue en UTC) ou ''
 *   hasTime      '1' si l'heure a un sens (une demande du site n'a qu'un jour)
 *   sameDay      '1' si le service a lieu aujourd'hui (heure locale du propriétaire)
 * Produit {{reminderTitle}} et {{reminderBody}} pour le gabarit
 * `application_reminder_615` (locales/<lang>/notifications.json).
 */
const LOCALES = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const INTL = { fr: 'fr-FR', en: 'en-US', es: 'es-ES', de: 'de-DE', it: 'it-IT', pt: 'pt-PT', ko: 'ko-KR', ja: 'ja-JP', pl: 'pl-PL' };

const normLocale = (l) => {
  const s = String(l || '').toLowerCase().slice(0, 2);
  return LOCALES.includes(s) ? s : 'fr';
};

// Le service, tel qu'on le dit après « pour » (avec le possessif).
const KIND = {
  walk: { fr: 'ta balade', en: 'your walk', es: 'tu paseo', de: 'deinen Spaziergang', it: 'la tua passeggiata', pt: 'o teu passeio', ko: '산책', ja: 'お散歩', pl: 'Twój spacer' },
  visit: { fr: 'ta visite', en: 'your home visit', es: 'tu visita', de: 'deinen Hausbesuch', it: 'la tua visita', pt: 'a tua visita', ko: '방문 돌봄', ja: '訪問ケア', pl: 'Twoją wizytę' },
  sitting: { fr: 'ta garde', en: 'your pet sitting', es: 'tu cuidado', de: 'deine Tierbetreuung', it: 'la tua custodia', pt: 'a tua guarda', ko: '돌봄', ja: 'お世話', pl: 'Twoją opiekę' },
};

const toDate = (v) => {
  if (!v) return null;
  const d = v instanceof Date ? v : new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};

/** « 14 h 30 », « 2:30 PM », « 14:30 »… (heure murale, lue en UTC). */
const formatTime = (d, lang) => {
  if (lang === 'fr') {
    const h = d.getUTCHours();
    const m = d.getUTCMinutes();
    return m ? `${h} h ${String(m).padStart(2, '0')}` : `${h} h`;
  }
  // Espace fine insécable (ICU récent, « 6:00 PM ») → espace insécable classique, lue partout.
  return new Intl.DateTimeFormat(INTL[lang], { hour: 'numeric', minute: '2-digit', timeZone: 'UTC' }).format(d).replace(/\u202f/g, '\u00a0');
};
const formatDay = (d, lang) => new Intl.DateTimeFormat(INTL[lang], { day: 'numeric', month: 'long', timeZone: 'UTC' }).format(d);

/**
 * Le complément de temps : « de 14 h 30 » (aujourd'hui), « du 12 octobre à 14 h 30 »,
 * « du 12 octobre » (sans heure), ou '' (demande sans date).
 */
const whenPhrase = ({ start, hasTime, sameDay }, lang) => {
  if (!start) return '';
  const t = hasTime ? formatTime(start, lang) : '';
  const day = formatDay(start, lang);
  const W = {
    fr: [`de ${t}`, `du ${day} à ${t}`, `du ${day}`],
    en: [`at ${t}`, `on ${day} at ${t}`, `on ${day}`],
    es: [`de las ${t}`, `del ${day} a las ${t}`, `del ${day}`],
    de: [`um ${t}`, `am ${day} um ${t}`, `am ${day}`],
    it: [`delle ${t}`, `del ${day} alle ${t}`, `del ${day}`],
    pt: [`das ${t}`, `de ${day} às ${t}`, `de ${day}`],
    ko: [`오늘 ${t}`, `${day} ${t}`, `${day}`],
    ja: [`本日${t}`, `${day} ${t}`, `${day}`],
    pl: [`o ${t}`, `${day} o ${t}`, `${day}`],
  }[lang];
  if (hasTime && sameDay) return W[0];
  if (hasTime) return W[1];
  return W[2];
};

/** Titre + phrase, pour n candidats. */
const buildReminderText = ({ candidates, serviceKind, start, hasTime, sameDay }, locale) => {
  const lang = normLocale(locale);
  const n = Math.max(1, Math.floor(Number(candidates) || 1));
  const kind = (KIND[serviceKind] || KIND.sitting)[lang];
  const when = whenPhrase({ start: toDate(start), hasTime, sameDay }, lang);
  const sp = when ? ` ${when}` : '';
  const one = n === 1;
  switch (lang) {
    case 'en':
      return {
        title: one ? '1 candidate is waiting for you' : `${n} candidates are waiting for you`,
        body: one ? `You have 1 candidate for ${kind}${sp} — accept to book.` : `You have ${n} candidates for ${kind}${sp} — pick yours.`,
      };
    case 'es':
      return {
        title: one ? '1 candidato te espera' : `${n} candidatos te esperan`,
        body: one ? `Tienes 1 candidato para ${kind}${sp}: acéptalo para reservar.` : `Tienes ${n} candidatos para ${kind}${sp}: elige el tuyo.`,
      };
    case 'de':
      return {
        title: one ? '1 Bewerbung wartet auf dich' : `${n} Bewerbungen warten auf dich`,
        body: one ? `Du hast 1 Bewerbung für ${kind}${sp} – nimm sie an, um zu buchen.` : `Du hast ${n} Bewerbungen für ${kind}${sp} – wähle deinen Favoriten.`,
      };
    case 'it':
      return {
        title: one ? '1 candidato ti aspetta' : `${n} candidati ti aspettano`,
        body: one ? `Hai 1 candidato per ${kind}${sp}: accettalo per prenotare.` : `Hai ${n} candidati per ${kind}${sp}: scegli il tuo.`,
      };
    case 'pt':
      return {
        title: one ? '1 candidato está à tua espera' : `${n} candidatos estão à tua espera`,
        body: one ? `Tens 1 candidato para ${kind}${sp}: aceita-o para reservar.` : `Tens ${n} candidatos para ${kind}${sp}: escolhe o teu.`,
      };
    case 'ko': {
      const head = when ? `${when} ${kind}` : kind;
      return {
        title: `지원자 ${n}명이 기다리고 있어요`,
        body: one ? `${head}에 지원자가 1명 있어요. 수락하면 예약이 확정돼요.` : `${head}에 지원자가 ${n}명 있어요. 한 명을 선택해 주세요.`,
      };
    }
    case 'ja': {
      const head = when ? `${when}の${kind}` : kind;
      return {
        title: `${n}人の応募者が待っています`,
        body: one ? `${head}に1人の応募があります。承認すると予約できます。` : `${head}に${n}人の応募があります。1人を選んでください。`,
      };
    }
    case 'pl':
      // Liczebnik bez odmiany : « Kandydaci: 3 » zamiast 2-4 / 5+.
      return {
        title: one ? 'Czeka na Ciebie 1 kandydat' : `Czekają na Ciebie kandydaci: ${n}`,
        body: one ? `Masz 1 kandydata na ${kind}${sp} — zaakceptuj, aby zarezerwować.` : `Masz kandydatów na ${kind}${sp}: ${n} — wybierz swojego.`,
      };
    case 'fr':
    default:
      return {
        title: one ? '1 candidat t’attend' : `${n} candidats t’attendent`,
        body: one ? `Tu as 1 candidat pour ${kind}${sp} — accepte-le pour réserver.` : `Tu as ${n} candidats pour ${kind}${sp} — choisis le tien.`,
      };
  }
};

/** Complète les données pour le rendu du gabarit (n'écrase rien d'existant). */
const enrichReminderData = (data, locale) => {
  const d = data && typeof data === 'object' ? { ...data } : {};
  const txt = buildReminderText({
    candidates: d.candidates,
    serviceKind: d.serviceKind,
    start: d.startWall,
    hasTime: String(d.hasTime) === '1' || d.hasTime === true,
    sameDay: String(d.sameDay) === '1' || d.sameDay === true,
  }, locale);
  if (!d.reminderTitle) d.reminderTitle = txt.title;
  if (!d.reminderBody) d.reminderBody = txt.body;
  return d;
};

module.exports = { LOCALES, buildReminderText, enrichReminderData, whenPhrase, formatTime };
