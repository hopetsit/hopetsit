'use strict';

/**
 * 17/11/2026 (BOB) — vérification d'identité OFFERTE aux gardiens et promeneurs.
 *
 * Mesure du 17/11 : 461 gardiens/promeneurs réels, 10 identités vérifiées (2 %),
 * 24 arrêtés à l'étape « payer 3 € », 0 avis. 41 propriétaires ont ouvert la page de
 * leurs candidats en 30 jours, aucun n'a choisi : on leur demande de payer d'avance un
 * inconnu sans badge ni avis. Le badge « Identité vérifiée » est le seul signal de
 * confiance qu'on peut créer sans première garde.
 *
 * Fonctionnement (aucun changement dans l'app) : l'écran de l'app lit GET /kyc/status ;
 * un compte « none » ou « pending_payment » passe directement à « pending_verification »,
 * donc l'app affiche « Lancer la vérification » sans étape de paiement.
 *
 * On NE pose PAS kycPaidAt : toutes les vues d'argent de l'admin (revenus KYC, liste
 * des paiements, « payés non vérifiés ») filtrent sur kycPaidAt — une vérification
 * offerte n'y apparaît donc jamais comme 3 € encaissés. Le repère est la référence
 * `free_1711_<horodatage>` dans kycPaymentIntentId.
 *
 * Coupe-circuit sans republier : KYC_FREE_1711=off sur Render (retour aux 3 €).
 * Les comptes déjà passés en offert gardent le droit de lancer leur vérification.
 *
 * Fonctions pures, testées dans tests/kycFree1711.test.js.
 */

const FREE_REF_PREFIX = 'free_1711';

const isFreeEnabled = (env = process.env) =>
  String(env.KYC_FREE_1711 || 'on').trim().toLowerCase() !== 'off';

const isFreeRef = (user) =>
  String((user && user.kycPaymentIntentId) || '').startsWith(FREE_REF_PREFIX);

const newFreeRef = (now = Date.now()) => `${FREE_REF_PREFIX}_${now}`;

/** Ce compte doit-il passer en « offert » maintenant ? */
function shouldGrantFree(user, env = process.env) {
  if (!user || !isFreeEnabled(env)) return false;
  if (user.kycPaidAt) return false; // a déjà payé : son parcours ne change pas
  const s = user.kycStatus || 'none';
  return s === 'none' || s === 'pending_payment';
}

/** Le compte a-t-il le droit de lancer la vérification (payée OU offerte) ? */
function canStartVerification(user) {
  if (!user || user.kycStatus !== 'pending_verification') return false;
  return !!user.kycPaidAt || isFreeRef(user);
}

/** Prix affiché par l'app (elle lit `price` dans GET /kyc/status). */
const displayedPrice = (basePrice, env = process.env) => (isFreeEnabled(env) ? 0 : basePrice);

module.exports = {
  FREE_REF_PREFIX,
  isFreeEnabled,
  isFreeRef,
  newFreeRef,
  shouldGrantFree,
  canStartVerification,
  displayedPrice,
};
