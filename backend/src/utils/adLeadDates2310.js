/**
 * 23/10/2026 (BOB, demande de Daniel « sur les annonces publiées il faut les dates ») —
 * dates d'une demande issue de la pub à formulaire Meta.
 *
 *   datesFor(lead, now) → { startDate, endDate, source } | null
 *     1. `startText` / `endText` (réponses libres du formulaire : « 24/12/2026 », « 24/12 »,
 *        « 24 décembre », « Dec 24 », « 12/24 » en anglais, « du 24/12 au 2/1 » dans un seul champ)
 *     2. sinon le choix « quand » : bientot → J+7 → J+14 ; fetes → 20/12 → 03/01 (prochaine occurrence)
 *     3. sinon null (plus_tard sans dates : l'annonce reste sans dates, signalé dans leads.json)
 * Lecture seule, aucune I/O.
 */
const MONTHS = {
  fr: ['janv', 'fevr', 'mars', 'avr', 'mai', 'juin', 'juil', 'aout', 'sept', 'oct', 'nov', 'dec'],
  en: ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'],
};
const strip = (s) => String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
const utc = (y, m, d) => new Date(Date.UTC(y, m, d));
const valid = (dt) => dt instanceof Date && !Number.isNaN(dt.getTime());

/** Une date dans un texte, ou null. `after` : si l'année manque, la prochaine occurrence ≥ after. */
function parseOne(text, lang, after) {
  // 24/10 (BOB, saisies réelles du formulaire : « 01/11/ 2026 », « 05  07 ») — espaces autour des
  // séparateurs retirés, et des nombres séparés par des espaces seuls deviennent « 05/07 ».
  let t = strip(text).trim().replace(/\s*([\/.\-])\s*/g, '$1');
  if (/^\d{1,2}\s+\d{1,2}(\s+\d{2,4})?$/.test(t)) t = t.replace(/\s+/g, '/');
  if (!t) return null;
  const ref = after || new Date();
  let y = null; let m = null; let d = null;
  let mm = t.match(/(\d{1,2})[\/.\-](\d{1,2})(?:[\/.\-](\d{2,4}))?/);
  if (mm) {
    let a = +mm[1]; let b = +mm[2];
    if (lang === 'en') { [a, b] = [b, a]; } // US : mois/jour
    if (a > 31 && b <= 12) { [a, b] = [b, a]; }
    d = a; m = b - 1; y = mm[3] ? +mm[3] : null;
    if (y !== null && y < 100) y += 2000;
  } else {
    const names = MONTHS[lang === 'en' ? 'en' : 'fr'].concat(MONTHS[lang === 'en' ? 'fr' : 'en']);
    const m2 = t.match(/(\d{1,2})(?:er|st|nd|rd|th)?\s*([a-z]{3,})\.?\s*(\d{4})?/) || t.match(/([a-z]{3,})\.?\s*(\d{1,2})(?:er|st|nd|rd|th)?,?\s*(\d{4})?/);
    if (!m2) return null;
    const dayFirst = /^\d/.test(m2[1]);
    const dayS = dayFirst ? m2[1] : m2[2]; const monS = dayFirst ? m2[2] : m2[1];
    const idx = names.findIndex((n) => monS.startsWith(n));
    if (idx < 0) return null;
    d = +dayS; m = idx % 12; y = m2[3] ? +m2[3] : null;
  }
  if (!(d >= 1 && d <= 31 && m >= 0 && m <= 11)) return null;
  if (y === null) {
    y = ref.getUTCFullYear();
    if (utc(y, m, d) < utc(ref.getUTCFullYear(), ref.getUTCMonth(), ref.getUTCDate())) y += 1;
  }
  const dt = utc(y, m, d);
  if (!valid(dt) || dt.getUTCMonth() !== m) return null;
  return dt;
}

const DAY = 86400000;
/** « du 24/12 au 2/1 » ou « 24/12 - 2/1 » dans UN champ → [début, fin]. */
function splitRange(text) {
  const t = String(text || '');
  const m = t.match(/^\s*(?:du|from|de)?\s*(.+?)\s*(?:au|to|-|–|→|a|al|jusqu'au)\s+(.+?)\s*$/i);
  return m ? [m[1], m[2]] : [t, ''];
}

function datesFor(lead, now = new Date()) {
  const lang = lead && lead.lang === 'en' ? 'en' : 'fr';
  let a = lead && lead.startText; let b = lead && lead.endText;
  if (a && !b) [a, b] = splitRange(a);
  const start = parseOne(a, lang, now);
  let end = parseOne(b, lang, start || now);
  // fin avant début avec une année écrite (« 01/11/2026 → 30/06/2026 ») : l'année de fin est un lapsus → +1 an
  if (start && end && end < start && /\d{4}/.test(String(b || ''))) {
    const e2 = new Date(Date.UTC(end.getUTCFullYear() + 1, end.getUTCMonth(), end.getUTCDate()));
    // seulement si la garde ainsi corrigée reste courte (≤ 92 jours) ; au-delà c'est ambigu → pas de dates
    if (e2 >= start && (e2 - start) / DAY <= 92) end = e2;
  }
  if (start && end && end >= start) return { startDate: start, endDate: end, source: 'form' };
  if (start && !b) return { startDate: start, endDate: start, source: 'form' };
  const q = lead && lead.quand;
  const today = utc(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  if (q === 'bientot') return { startDate: new Date(today.getTime() + 7 * DAY), endDate: new Date(today.getTime() + 14 * DAY), source: 'quand' };
  if (q === 'fetes') {
    let y = now.getUTCFullYear();
    if (utc(y, 11, 20) < today) y += 1;
    return { startDate: utc(y, 11, 20), endDate: utc(y + 1, 0, 3), source: 'quand' };
  }
  return null;
}

module.exports = { datesFor, parseOne, splitRange };
