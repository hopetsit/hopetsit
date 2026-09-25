// v587 (25/09/2026) — BUDGET d'une demande (décision de Daniel, option A).
//
// Champ FACULTATIF « Mon budget » dans « Publier une annonce » (app + site) :
// un montant saisi par le propriétaire, dans SA devise. Il s'affiche dans la
// bulle orange de la PawMap (« 35 € »), sur la carte d'annonce et la fiche.
// Sans budget : rien (l'app et le site montrent l'icône du service, jamais
// « 0 € »).
//
// RÉTROCOMPATIBLE : une ancienne app qui n'envoie rien ne touche à rien.
const { SUPPORTED_CURRENCIES } = require('./currency');

const BUDGET_MAX = 100000;

/**
 * Champs à écrire à partir du corps de requête.
 *   · champ absent → {} (rien à écrire) ;
 *   · vide / 0 / invalide → { budget: null, budgetCurrency: '' } (effacé) ;
 *   · montant > 0 → { budget, budgetCurrency } (devise envoyée si connue,
 *     sinon celle du propriétaire, sinon EUR). Arrondi au centime.
 */
function resolveBudget(body, ownerCurrency) {
  const b = body || {};
  if (!Object.prototype.hasOwnProperty.call(b, 'budget')) return {};
  const raw = b.budget;
  const n = typeof raw === 'number'
    ? raw
    : Number(String(raw == null ? '' : raw).replace(/\s/g, '').replace(',', '.'));
  if (!Number.isFinite(n) || n <= 0) return { budget: null, budgetCurrency: '' };
  const amount = Math.round(Math.min(n, BUDGET_MAX) * 100) / 100;
  const want = String(b.budgetCurrency || '').trim().toUpperCase();
  const own = String(ownerCurrency || '').trim().toUpperCase();
  const cur = SUPPORTED_CURRENCIES.includes(want)
    ? want
    : (SUPPORTED_CURRENCIES.includes(own) ? own : 'EUR');
  return { budget: amount, budgetCurrency: cur };
}

/** Budget public d'une annonce : `{ budget, budgetCurrency }` (0 / '' sans budget). */
function publicBudget(post, ownerCurrency) {
  const n = Number(post && post.budget);
  if (!Number.isFinite(n) || n <= 0) return { budget: 0, budgetCurrency: '' };
  const cur = String((post && post.budgetCurrency) || ownerCurrency || 'EUR').toUpperCase();
  return { budget: n, budgetCurrency: cur };
}

module.exports = { resolveBudget, publicBudget, BUDGET_MAX };
