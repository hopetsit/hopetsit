'use strict';

/**
 * v566 — montant / devise RÉELLEMENT payés et vrai prestataire, lus sur
 * l'intention Airwallex vérifiée (mêmes règles que subscriptionRoutes).
 */
function resolvePaidAmount(pi, pricing) {
  const candidates = [pi?.amount, pi?.metadata?.paidAmount];
  for (const c of candidates) {
    const n = Number(c);
    if (c !== undefined && c !== null && c !== '' && Number.isFinite(n) && n >= 0) {
      return {
        amount: n,
        currency: String(pi?.currency || pi?.metadata?.currency || pricing.currency).toUpperCase(),
        fromProvider: true,
      };
    }
  }
  return { amount: pricing.amount, currency: pricing.currency, fromProvider: false };
}

function resolveProvider(pi) {
  const raw = String(pi?.metadata?.provider || '').toLowerCase();
  if (raw === 'paypal') return 'paypal';
  if (raw === 'wallet') return 'wallet';
  return 'airwallex';
}

module.exports = { resolvePaidAmount, resolveProvider };
