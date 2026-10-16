/**
 * 16/10/2026 (ADA, décision BOB sur ordre de Daniel, mesure de FLO) — DEVISE DU
 * CANDIDAT ≠ DEVISE DU PROPRIÉTAIRE = CANDIDATURE REFUSÉE.
 *
 * Mesuré en production : une gardienne de Busan a sa fiche en wons (80 000 KRW
 * par jour). Le serveur ne convertit pas les devises : il prend ses tarifs tels
 * quels dans la devise du propriétaire (applicationController ≈ l. 364,
 * utils/tierPricing.js). Si le propriétaire new-yorkais l'acceptait, l'app lui
 * demanderait 1 851 428 $ pour 24 jours de garde.
 *
 *   · à la CRÉATION d'une candidature : refus 403 CURRENCY_MISMATCH, message
 *     dans la langue du prestataire ;
 *   · à l'ACCEPTATION par le propriétaire : refus 409 CURRENCY_MISMATCH (couvre
 *     les candidatures déjà en attente), message dans la langue du propriétaire ;
 *   · décision BOB (16/10) : une devise restée sur la valeur PAR DÉFAUT (EUR,
 *     jamais réglée) est DÉDUITE du pays / indicatif / position du prestataire
 *     (New York → USD) ; ses montants sont alors lus dans cette devise.
 * La logique de paiement n'est pas touchée : on refuse AVANT qu'un prix faux
 * devienne une réservation. APPLY_CURRENCY_CHECK=off coupe le contrôle.
 */
const { DEFAULT_CURRENCY } = require('./currency');
const { LANGS, localeOf, profileCoords } = require('./applicationDistance1610');

const enabled = () => String(process.env.APPLY_CURRENCY_CHECK || '').toLowerCase() !== 'off';

/** Devise STOCKÉE d'un profil : champ `currency`, sinon celle du 1er tarif de balade, sinon EUR. */
function currencyOf(doc) {
  if (!doc) return DEFAULT_CURRENCY;
  const c = String(doc.currency || '').trim().toUpperCase();
  if (c) return c;
  const rates = Array.isArray(doc.walkRates) ? doc.walkRates : [];
  const r = rates.find((x) => x && x.enabled !== false && x.currency) || rates.find((x) => x && x.currency);
  return r ? String(r.currency).trim().toUpperCase() : DEFAULT_CURRENCY;
}

// Décision BOB du 16/10 : la devise par défaut (EUR) d'un profil JAMAIS réglé ne
// vaut pas un choix. Aucun horodatage ne dit si elle a été réglée (vérifié :
// Sitter/Walker/Owner n'ont que `currency`, `walletCurrency`, `country`,
// `countryCode`). Donc : devise == EUR → on la DÉDUIT du pays (ISO), sinon de
// l'indicatif téléphonique, sinon du fuseau de ses coordonnées (ou de sa ville
// géocodée). Déduction dans la zone euro ou inconnue → EUR (même résultat).
// Mesuré en prod : 51 gardiens en EUR sans pays ; Nieheem (New York) = EUR,
// pays vide, indicatif +1 → USD.
const EURO_COUNTRIES = new Set(['AT', 'BE', 'CY', 'DE', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 'IE', 'IT', 'LT', 'LU', 'LV', 'MC', 'MT', 'NL', 'PT', 'SI', 'SK', 'AD', 'SM', 'VA', 'ME', 'XK', 'BG']);
const COUNTRY_CURRENCY = { US: 'USD', PR: 'USD', GB: 'GBP', UK: 'GBP', CH: 'CHF', LI: 'CHF', KR: 'KRW', JP: 'JPY' };
const PHONE_CURRENCY = { '+1': 'USD', '+44': 'GBP', '+41': 'CHF', '+82': 'KRW', '+81': 'JPY' };
const EURO_PHONES = new Set(['+33', '+49', '+34', '+39', '+351', '+32', '+31', '+43', '+353', '+358', '+30', '+352', '+370', '+371', '+372', '+386', '+421', '+385', '+356', '+357', '+377']);
const TZ_CURRENCY = { 'America/New_York': 'USD', 'America/Chicago': 'USD', 'America/Denver': 'USD', 'America/Los_Angeles': 'USD', 'Europe/London': 'GBP', 'Europe/Paris': 'EUR', 'Europe/Athens': 'EUR' };

function currencyFromCountry(doc) {
  const iso = String((doc && doc.country) || '').trim().toUpperCase();
  if (iso) {
    if (COUNTRY_CURRENCY[iso]) return COUNTRY_CURRENCY[iso];
    if (EURO_COUNTRIES.has(iso)) return 'EUR';
  }
  const phone = String((doc && doc.countryCode) || '').trim().replace(/\s+/g, '');
  if (phone) {
    if (PHONE_CURRENCY[phone]) return PHONE_CURRENCY[phone];
    if (EURO_PHONES.has(phone)) return 'EUR';
  }
  return null;
}
function currencyFromCoords(lat, lng) {
  try {
    const tz = require('../services/plushService607').timeZoneFor(lat, lng);
    return (tz && TZ_CURRENCY[tz]) || null;
  } catch (_) { return null; }
}

/**
 * Devise EFFECTIVE d'un prestataire (sans réseau) :
 *  { currency, stored, inferred: bool, via: 'explicit'|'country'|'phone'|'coords'|'default' }
 */
function resolveCurrency(doc) {
  const stored = currencyOf(doc);
  if (stored !== DEFAULT_CURRENCY) return { currency: stored, stored, inferred: false, via: 'explicit' };
  const byCountry = currencyFromCountry(doc);
  if (byCountry) return { currency: byCountry, stored, inferred: byCountry !== stored, via: String((doc && doc.country) || '').trim() ? 'country' : 'phone' };
  const c = profileCoords(doc);
  const byCoords = c ? currencyFromCoords(c.lat, c.lng) : null;
  if (byCoords) return { currency: byCoords, stored, inferred: byCoords !== stored, via: 'coords' };
  return { currency: stored, stored, inferred: false, via: 'default' };
}

/** Même chose, avec un dernier recours : géocoder la ville du profil (réseau, mémorisé). */
async function resolveCurrencyAsync(doc, geocode) {
  const r = resolveCurrency(doc);
  if (r.via !== 'default') return r;
  const city = String((doc && (doc.city || (doc.location && doc.location.city) || doc.coverageCity)) || '').trim();
  if (!city) return r;
  try {
    const geo = typeof geocode === 'function' ? geocode : require('./geocodeCity').geocodeCity;
    const g = await geo(city);
    const byCity = g ? currencyFromCoords(Number(g.lat), Number(g.lng)) : null;
    if (byCity) return { currency: byCity, stored: r.stored, inferred: byCity !== r.stored, via: 'city' };
  } catch (_) { /* sans réseau : défaut */ }
  return r;
}

/** @returns {{ok:boolean, ownerCurrency:string, providerCurrency:string, providerStored:string, inferred:boolean, via:string, reason:string}} */
async function checkCurrencies(owner, provider, geocode) {
  const ownerCurrency = currencyOf(owner);
  const p = await resolveCurrencyAsync(provider, geocode);
  const base = { ownerCurrency, providerCurrency: p.currency, providerStored: p.stored, inferred: p.inferred, via: p.via };
  if (!enabled()) return { ok: true, ...base, reason: 'disabled' };
  const ok = ownerCurrency === p.currency;
  return { ok, ...base, reason: ok ? 'same' : 'mismatch' };
}

const FOR_PROVIDER = {
  fr: 'Ta fiche est en {prov} et cette demande se paie en {own} : tu ne peux pas candidater. Change la devise de ton profil pour les demandes en {own}.',
  en: 'Your profile is in {prov} and this request is paid in {own}: you cannot apply. Switch your profile currency to apply to {own} requests.',
  es: 'Tu perfil está en {prov} y esta solicitud se paga en {own}: no puedes presentarte. Cambia la divisa de tu perfil para las solicitudes en {own}.',
  de: 'Dein Profil ist in {prov}, diese Anfrage wird in {own} bezahlt: du kannst dich nicht bewerben. Ändere die Währung deines Profils für Anfragen in {own}.',
  it: 'Il tuo profilo è in {prov} e questa richiesta si paga in {own}: non puoi candidarti. Cambia la valuta del tuo profilo per le richieste in {own}.',
  pt: 'O teu perfil está em {prov} e este pedido paga-se em {own}: não podes candidatar-te. Muda a moeda do teu perfil para pedidos em {own}.',
  ko: '회원님의 프로필 통화는 {prov}이고 이 요청은 {own}으로 결제됩니다. 지원할 수 없습니다. {own} 요청에 지원하려면 프로필 통화를 변경하세요.',
  ja: 'あなたのプロフィールは {prov} 建て、この依頼は {own} で支払われます。応募できません。{own} の依頼に応募するにはプロフィールの通貨を変更してください。',
  pl: 'Twój profil jest w {prov}, a to zgłoszenie jest płatne w {own}: nie możesz się zgłosić. Zmień walutę profilu, aby zgłaszać się do ofert w {own}.',
};
const FOR_OWNER = {
  fr: 'Ce prestataire affiche ses tarifs en {prov} et tu paies en {own} : le prix ne peut pas être calculé correctement. Choisis un prestataire en {own}.',
  en: 'This provider lists prices in {prov} and you pay in {own}: the price cannot be calculated correctly. Choose a provider in {own}.',
  es: 'Este cuidador tiene sus tarifas en {prov} y tú pagas en {own}: el precio no se puede calcular correctamente. Elige un cuidador en {own}.',
  de: 'Dieser Anbieter rechnet in {prov} ab und du zahlst in {own}: der Preis kann nicht korrekt berechnet werden. Wähle einen Anbieter in {own}.',
  it: 'Questo prestatore ha tariffe in {prov} e tu paghi in {own}: il prezzo non può essere calcolato correttamente. Scegli un prestatore in {own}.',
  pt: 'Este prestador tem preços em {prov} e tu pagas em {own}: o preço não pode ser calculado corretamente. Escolhe um prestador em {own}.',
  ko: '이 제공자는 {prov}로 요금을 표시하고 회원님은 {own}으로 결제합니다. 가격을 정확히 계산할 수 없습니다. {own} 제공자를 선택하세요.',
  ja: 'このプロバイダーは {prov} 建てで、あなたは {own} で支払います。価格を正しく計算できません。{own} のプロバイダーを選んでください。',
  pl: 'Ten opiekun podaje ceny w {prov}, a Ty płacisz w {own}: cena nie może zostać poprawnie obliczona. Wybierz opiekuna rozliczającego się w {own}.',
};

const fill = (tpl, own, prov) => tpl.split('{own}').join(own).split('{prov}').join(prov);
const mismatchMessageForProvider = (lang, own, prov) => fill(FOR_PROVIDER[LANGS.includes(lang) ? lang : 'en'], own, prov);
const mismatchMessageForOwner = (lang, own, prov) => fill(FOR_OWNER[LANGS.includes(lang) ? lang : 'en'], own, prov);

module.exports = { currencyOf, resolveCurrency, resolveCurrencyAsync, checkCurrencies, mismatchMessageForProvider, mismatchMessageForOwner, localeOf };
