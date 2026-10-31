/**
 * 3110 (FLO, alerte prix de BOB du 31/10/2026) — GARDE-FOU « PRIX À CONFIRMER ».
 *
 * Constat en prod (demandes réelles de Saint-Maur et d'Égly) : un propriétaire voyait 2,70 € ou
 * 7,50 € pour 8 mois de visites (anciens prix calculés « 1 heure », avant le correctif du 26/10,
 * restés sur des candidatures refusées), et 36 € contre 216 € sur une garde de 2 nuits (gardien
 * à 10 €/jour). Un prix ridicule détruit la confiance et pourrait faire payer 2,70 € une garde
 * de 8 mois. Ce module ne CHANGE AUCUN prix ni aucune commission : il MARQUE un total suspect.
 *
 * Un total est « à vérifier » (non payable, la carte affiche « prix à confirmer par le gardien ») :
 *   · 'too_low'      : total < 10 (dans la devise de la candidature) pour une période d'au moins
 *                      2 jours calendaires (au moins une nuit) ;
 *   · 'outlier_low'  : total plus de 5 fois inférieur à la médiane des AUTRES candidats ;
 *   · 'outlier_high' : total plus de 5 fois supérieur à la médiane des autres candidats, quand il
 *                      y en a au moins 2 (avec un seul autre candidat, l'écart ne dit pas lequel
 *                      des deux est faux : seul le moins cher, le risque pour la confiance et
 *                      pour l'argent, est marqué).
 * « Autres candidats » = candidatures de la même demande, ni refusées ni annulées, avec un vrai
 * total (pas « dates à prévoir », pas « tarif à venir »).
 * Lecture pure, aucune I/O.
 */
const { dayCount, effectiveDateMode } = require('./pricingEngine620');

const MIN_TOTAL = 10;
const MAX_RATIO = 5;
const EXCLUDED_STATUSES = new Set(['rejected', 'cancelled', 'canceled', 'withdrawn', 'expired']);

const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : (v != null && v !== '' && Number.isFinite(Number(v)) ? Number(v) : null));

/** Total « réel » d'une candidature (null quand indicatif, en attente de tarif ou absent). */
const realTotalOf = (app) => {
  const p = (app && app.pricing) || {};
  if (p.indicative === true || p.stale === true) return null;
  const t = num(p.totalPrice);
  return t != null && t > 0 ? t : null;
};

const median = (list) => {
  const s = list.slice().sort((a, b) => a - b);
  if (!s.length) return null;
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

/**
 * @param {{ total:number|null, days:number|null, otherTotals?:number[] }} p
 * @returns {{ toVerify:boolean, reason:string|null, median:number|null }}
 */
function checkTotal({ total, days, otherTotals = [] } = {}) {
  const t = num(total);
  if (t == null || !(t > 0)) return { toVerify: false, reason: null, median: null };
  const others = (Array.isArray(otherTotals) ? otherTotals : []).map(num).filter((x) => x != null && x > 0);
  const med = median(others);
  if (num(days) != null && days >= 2 && t < MIN_TOTAL) return { toVerify: true, reason: 'too_low', median: med };
  if (med != null && t * MAX_RATIO < med) return { toVerify: true, reason: 'outlier_low', median: med };
  if (med != null && others.length >= 2 && t > med * MAX_RATIO) return { toVerify: true, reason: 'outlier_high', median: med };
  return { toVerify: false, reason: null, median: med };
}

/**
 * Contrôle d'une candidature parmi celles de sa demande.
 * @param {object} app      candidature (pricing.totalPrice, status, _id)
 * @param {object} post     demande (startDate, endDate, dateMode)
 * @param {object[]} siblings toutes les candidatures de la demande (app peut en faire partie)
 */
function checkApplication(app, post, siblings = []) {
  const total = realTotalOf(app);
  if (total == null || !post || effectiveDateMode(post) === 'tbd') return { toVerify: false, reason: null, median: null };
  const id = String(app && (app._id || app.id));
  const otherTotals = (siblings || [])
    .filter((s) => s && String(s._id) !== id && !EXCLUDED_STATUSES.has(String(s.status || '').toLowerCase()))
    .map(realTotalOf)
    .filter((x) => x != null);
  return checkTotal({ total, days: dayCount(post), otherTotals });
}

const MSG = {
  fr: 'Prix à confirmer par le gardien : ce total paraît anormal pour ces dates. Écris-lui pour qu’il le confirme, ou choisis un autre candidat.',
  en: 'Price to be confirmed by the sitter: this total looks wrong for these dates. Message them to confirm it, or choose another candidate.',
  es: 'Precio por confirmar por el cuidador: este total parece anómalo para estas fechas. Escríbele para que lo confirme o elige otro candidato.',
  de: 'Preis vom Sitter zu bestätigen: dieser Gesamtpreis wirkt für diese Daten ungewöhnlich. Schreib ihm zur Bestätigung oder wähle einen anderen Kandidaten.',
  it: 'Prezzo da confermare dal pet sitter: questo totale sembra anomalo per queste date. Scrivigli per confermarlo o scegli un altro candidato.',
  pt: 'Preço a confirmar pelo cuidador: este total parece anormal para estas datas. Escreve-lhe para o confirmar ou escolhe outro candidato.',
  nl: 'Prijs nog te bevestigen door de oppas: dit totaal lijkt niet te kloppen voor deze data. Stuur een bericht om het te bevestigen, of kies een andere kandidaat.',
  pl: 'Cena do potwierdzenia przez opiekuna: ta kwota wygląda nietypowo dla tych dat. Napisz do niego, aby ją potwierdził, lub wybierz innego kandydata.',
  ko: '펫시터 확인이 필요한 가격입니다: 이 날짜에 비해 총액이 비정상적으로 보입니다. 메시지로 확인하거나 다른 후보를 선택하세요.',
  ja: 'シッターの確認が必要な料金です：この日程に対して合計が不自然です。メッセージで確認するか、別の候補者を選んでください。',
};
const SHORT = {
  fr: 'Prix à confirmer par le gardien', en: 'Price to be confirmed by the sitter', es: 'Precio por confirmar por el cuidador',
  de: 'Preis vom Sitter zu bestätigen', it: 'Prezzo da confermare dal pet sitter', pt: 'Preço a confirmar pelo cuidador',
  nl: 'Prijs nog te bevestigen door de oppas', pl: 'Cena do potwierdzenia przez opiekuna', ko: '펫시터 확인 필요 가격', ja: 'シッター確認待ちの料金',
};
const pick = (table, locale) => table[String(locale || '').slice(0, 2)] || table.en;
const priceToConfirmMessage = (locale) => pick(MSG, locale);
const priceToConfirmLabel = (locale) => pick(SHORT, locale);

module.exports = { MIN_TOTAL, MAX_RATIO, checkTotal, checkApplication, realTotalOf, median, priceToConfirmMessage, priceToConfirmLabel };
