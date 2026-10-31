/**
 * 3110 (FLO, alerte prix de BOB du 31/10/2026) — GARDE-FOU « PRIX À CONFIRMER ».
 *
 * Constat en prod (Saint-Maur) : 2,70 € et 7,50 € pour 8 mois de visites, anciens prix calculés
 * « 1 heure » (avant le correctif du 26/10) restés en base. Ce module ne CHANGE AUCUN prix ni
 * aucune commission : il MARQUE un total PÉRIMÉ et absurde.
 *
 * Décision de BOB (31/10 soir, « le garde-fou ne doit JAMAIS bloquer un vrai tarif de gardien ») :
 * un total est « à vérifier » (non payable, la carte affiche « prix à confirmer par le gardien »)
 * UNIQUEMENT quand les DEUX conditions sont réunies :
 *   · total < 10 (devise de la candidature) pour une période d'au moins 2 jours calendaires ;
 *   · ET ce total ≠ le prix recalculé au tarif ACTUEL du gardien (prix périmé), ou le gardien n'a
 *     plus de tarif pour ce service.
 * Un petit prix qui correspond au vrai tarif du gardien (ex. 10 €/jour) n'est JAMAIS bloqué.
 * L'écart à la médiane des autres candidats (× 5) n'est plus qu'une INDICATION (`outlierHint`),
 * réservée à l'admin, jamais montrée au propriétaire ni bloquante.
 * Lecture pure, aucune I/O.
 */
const { dayCount, effectiveDateMode } = require('./pricingEngine620');

const MIN_TOTAL = 10;
const MAX_RATIO = 5;

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
 * Indication admin seulement : écart de plus de 5 fois à la médiane des autres candidats.
 * @returns {{ outlier:string|null, median:number|null }}
 */
function outlierHint(total, otherTotals = []) {
  const t = num(total);
  const others = (Array.isArray(otherTotals) ? otherTotals : []).map(num).filter((x) => x != null && x > 0);
  const med = median(others);
  if (t == null || !(t > 0) || med == null) return { outlier: null, median: med };
  if (t * MAX_RATIO < med) return { outlier: 'low', median: med };
  if (others.length >= 2 && t > med * MAX_RATIO) return { outlier: 'high', median: med };
  return { outlier: null, median: med };
}

/**
 * @param {{ total:number|null, days:number|null, recalculated?:number|null }} p
 *   recalculated : total au tarif ACTUEL du gardien (null = plus de tarif pour ce service)
 * @returns {{ toVerify:boolean, reason:string|null }}
 */
function checkTotal({ total, days, recalculated } = {}) {
  const t = num(total);
  if (t == null || !(t > 0)) return { toVerify: false, reason: null };
  if (!(num(days) != null && days >= 2 && t < MIN_TOTAL)) return { toVerify: false, reason: null };
  const r = num(recalculated);
  const stalePrice = r == null || Math.abs(r - t) > 0.011;
  return stalePrice ? { toVerify: true, reason: 'stale_too_low' } : { toVerify: false, reason: null };
}

/**
 * Contrôle d'une candidature.
 * @param {object} app       candidature (pricing.totalPrice, _id)
 * @param {object} post      demande COMPLÈTE (lean) : dates, services, lieu
 * @param {object|null} provider  gardien / promeneur (tarifs actuels), null s'il n'existe plus
 * @param {'sitter'|'walker'} providerRole
 */
function checkApplication(app, post, provider, providerRole) {
  const total = realTotalOf(app);
  if (total == null || !post || effectiveDateMode(post) === 'tbd') return { toVerify: false, reason: null };
  const days = dayCount(post);
  if (!(days >= 2 && total < MIN_TOTAL)) return { toVerify: false, reason: null };
  let recalculated = null;
  if (provider) {
    try {
      const { priceApplication } = require('../services/applicationRepricing620');
      const pr = priceApplication({ application: app, post, provider, providerRole });
      recalculated = pr && pr.indicative !== true ? pr.totalPrice : null;
    } catch (e) {
      recalculated = null;
    }
  }
  return checkTotal({ total, days, recalculated });
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

module.exports = { MIN_TOTAL, MAX_RATIO, checkTotal, checkApplication, outlierHint, realTotalOf, median, priceToConfirmMessage, priceToConfirmLabel };
