/**
 * 617 (ADA, 16/10/2026) — §D.3 : texte de la notification « candidature reçue »
 * envoyée au PROPRIÉTAIRE : « <Prénom du candidat> a répondu » / « <total>
 * candidat(s) sur ta demande · choisis et paie en 2 minutes ».
 *
 * Le type reste `application_new` (l'app et le site ouvrent déjà Choisir → Payer
 * avec `data.applicationId` / `postId`) ; seul le GABARIT change :
 * `application_new_617`, choisi par `templateType` à l'envoi et par le marqueur
 * `data.appNew617` quand la cloche re-rend le texte (renderNotificationContent).
 * Les anciennes notifications (sans marqueur) gardent l'ancien gabarit : rien ne
 * casse. Le rappel 615 (`application_reminder_615`) n'est pas concerné.
 */
const { deriveNameParts } = require('../utils/personName');

const TEMPLATE = 'application_new_617';

const firstNameOf = (doc) => {
  const { firstName } = deriveNameParts(doc || {});
  return firstName || String((doc && doc.name) || '').trim().split(/\s+/)[0] || '';
};

/**
 * Données à ajouter au `data` de la notification `application_new`.
 * @param {{provider:Object, pendingCount:number}} p provider = doc Sitter/Walker ; pendingCount = candidatures en attente sur la demande
 */
const applicationNewData617 = ({ provider, pendingCount }) => ({
  candidateName: firstNameOf(provider) || 'HoPetSit',
  candidates: String(Math.max(1, Math.floor(Number(pendingCount) || 1))),
  appNew617: '1',
});

// ── 620 (ZOE, 24/10/2026) — prix dans la notification « candidature reçue » ──────────
// Données BRUTES ajoutées à `data` (jamais de texte traduit en base) :
//   priceAmount, priceUnit (day | night | visit | walk | hour | …), priceCurrency,
//   priceIndicative ('1' = demande « dates à prévoir » : tarif unitaire seul).
// `enrichPrice620(data, locale)` produit `priceText` au rendu (envoi ET cloche) :
//   « · 12 €/visite » (indicatif) ou « · 72 € au total » (demande datée) ; '' si absent.
const UNIT_WORDS = {
  fr: { day: 'jour', night: 'nuit', visit: 'visite', walk: 'balade', hour: 'heure', week: 'semaine', month: 'mois', total: 'au total' },
  en: { day: 'day', night: 'night', visit: 'visit', walk: 'walk', hour: 'hour', week: 'week', month: 'month', total: 'in total' },
  es: { day: 'día', night: 'noche', visit: 'visita', walk: 'paseo', hour: 'hora', week: 'semana', month: 'mes', total: 'en total' },
  de: { day: 'Tag', night: 'Nacht', visit: 'Besuch', walk: 'Spaziergang', hour: 'Stunde', week: 'Woche', month: 'Monat', total: 'insgesamt' },
  it: { day: 'giorno', night: 'notte', visit: 'visita', walk: 'passeggiata', hour: 'ora', week: 'settimana', month: 'mese', total: 'in totale' },
  pt: { day: 'dia', night: 'noite', visit: 'visita', walk: 'passeio', hour: 'hora', week: 'semana', month: 'mês', total: 'no total' },
  ko: { day: '일', night: '박', visit: '회', walk: '회', hour: '시간', week: '주', month: '개월', total: '총액' },
  ja: { day: '日', night: '泊', visit: '回', walk: '回', hour: '時間', week: '週', month: 'か月', total: '合計' },
  pl: { day: 'dzień', night: 'noc', visit: 'wizyta', walk: 'spacer', hour: 'godzina', week: 'tydzień', month: 'miesiąc', total: 'łącznie' },
};
const CURRENCY_SYMBOL = { EUR: '€', USD: '$', GBP: '£', CHF: 'CHF', KRW: '₩', JPY: '¥', PLN: 'zł' };

// 2610 (ZOE, test de FLO) — montant au format de la LANGUE du lecteur : « 14,40 € » en
// français, « €14.40 » en anglais ; sans centimes quand le montant est rond (« 18 € »).
// Espaces insécables d'Intl remplacées par des espaces simples (textes de push et d'e-mail).
const fmtAmount = (n, currency, locale = 'fr') => {
  const v = Number(n);
  if (!Number.isFinite(v)) return '';
  const cur = String(currency || 'EUR').toUpperCase();
  const lang = String(locale || 'fr').slice(0, 2) || 'fr';
  const digits = Number.isInteger(Math.round(v * 100) / 100) ? 0 : 2;
  try {
    return new Intl.NumberFormat(lang, {
      style: 'currency', currency: cur, currencyDisplay: 'narrowSymbol',
      minimumFractionDigits: digits, maximumFractionDigits: digits,
    }).format(v).replace(/[\u00A0\u202F]/g, ' ');
  } catch (_) {
    const txt = digits ? v.toFixed(2) : String(Math.round(v));
    const sym = CURRENCY_SYMBOL[cur] || cur;
    return sym === '$' || sym === '£' || sym === '₩' || sym === '¥' ? `${sym}${txt}` : `${txt} ${sym}`;
  }
};

const round2 = (x) => Math.round((Number(x) || 0) * 100) / 100;

/**
 * 2610 (ZOE, test de FLO) — tarif unitaire FRAIS COMPRIS, celui que le propriétaire paiera
 * (« 24 €/jour » pour un gardien à 20 €/jour avec 20 % de frais ; 15 % pour un Top).
 */
const ownerUnitRate = (pricing) => {
  const p = pricing || {};
  const rate = Number(p.appliedRate);
  if (!(rate > 0)) return 0;
  const c = Number(p.commissionRate);
  return round2(rate * (1 + (Number.isFinite(c) && c >= 0 && c < 1 ? c : 0.2)));
};

const priceData620 = (pricing) => {
  const p = pricing || {};
  if (p.indicative === true) {
    return Number(p.appliedRate) > 0
      ? { priceAmount: String(ownerUnitRate(p)), priceUnit: String(p.unit || ''), priceCurrency: String(p.currency || 'EUR'), priceIndicative: '1' }
      : {};
  }
  return Number(p.totalPrice) > 0
    ? { priceAmount: String(p.totalPrice), priceUnit: 'total', priceCurrency: String(p.currency || 'EUR'), priceIndicative: '0' }
    : {};
};

const enrichPrice620 = (data, locale) => {
  const d = data && typeof data === 'object' ? { ...data } : {};
  if (d.priceText !== undefined) return d;
  const amount = fmtAmount(d.priceAmount, d.priceCurrency, locale);
  if (!amount) { d.priceText = ''; return d; }
  const words = UNIT_WORDS[String(locale || '').slice(0, 2)] || UNIT_WORDS.en;
  const unit = String(d.priceUnit || '');
  if (d.priceIndicative === '1') d.priceText = words[unit] ? ` · ${amount}/${words[unit]}` : ` · ${amount}`;
  else d.priceText = ` · ${amount} ${words.total}`;
  return d;
};

module.exports = { TEMPLATE, applicationNewData617, firstNameOf, priceData620, enrichPrice620, fmtAmount, ownerUnitRate };
