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
 *     les candidatures déjà en attente), message dans la langue du propriétaire.
 * La logique de paiement n'est pas touchée : on refuse AVANT qu'un prix faux
 * devienne une réservation. APPLY_CURRENCY_CHECK=off coupe le contrôle.
 */
const { DEFAULT_CURRENCY } = require('./currency');
const { LANGS, localeOf } = require('./applicationDistance1610');

const enabled = () => String(process.env.APPLY_CURRENCY_CHECK || '').toLowerCase() !== 'off';

/** Devise d'un profil : champ `currency`, sinon celle du 1er tarif de balade, sinon EUR. */
function currencyOf(doc) {
  if (!doc) return DEFAULT_CURRENCY;
  const c = String(doc.currency || '').trim().toUpperCase();
  if (c) return c;
  const rates = Array.isArray(doc.walkRates) ? doc.walkRates : [];
  const r = rates.find((x) => x && x.enabled !== false && x.currency) || rates.find((x) => x && x.currency);
  return r ? String(r.currency).trim().toUpperCase() : DEFAULT_CURRENCY;
}

/** @returns {{ok:boolean, ownerCurrency:string, providerCurrency:string, reason:string}} */
function checkCurrencies(owner, provider) {
  const ownerCurrency = currencyOf(owner);
  const providerCurrency = currencyOf(provider);
  if (!enabled()) return { ok: true, ownerCurrency, providerCurrency, reason: 'disabled' };
  const ok = ownerCurrency === providerCurrency;
  return { ok, ownerCurrency, providerCurrency, reason: ok ? 'same' : 'mismatch' };
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

module.exports = { currencyOf, checkCurrencies, mismatchMessageForProvider, mismatchMessageForOwner, localeOf };
