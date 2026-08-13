/**
 * v532 — Garde de sécurité des achats boutique.
 *
 * FAILLE CORRIGÉE : les 5 endpoints `/confirm` de la boutique (abonnements,
 * boost profil, boost carte, add-on chat, PawSpot) activaient le produit sur
 * simple présentation d'un `paymentIntentId` dans le corps de la requête,
 * SANS jamais interroger Airwallex. Concrètement, avec un simple jeton
 * utilisateur valide :
 *
 *   POST /subscriptions/confirm {"plan":"premium_yearly","paymentIntentId":"x"}
 *
 * activait un an de PawPremium gratuitement — et l'appel étant rejouable,
 * chaque répétition empilait 365 jours de plus.
 *
 * Ce helper vérifie, auprès d'Airwallex, que le PaymentIntent :
 *   1. existe et est réellement SUCCEEDED ;
 *   2. appartient bien à l'utilisateur qui appelle (metadata.userId) ;
 *   3. n'a pas déjà été consommé par un autre achat (anti-rejeu).
 *
 * Le contrôle du montant est volontairement souple (les prix peuvent changer,
 * des remises existent) : on journalise un écart au lieu de bloquer.
 */
const logger = require('./logger');
const airwallex = require('../services/airwallexService');
const ProcessedWebhook = require('../models/ProcessedWebhook');

class PaymentNotVerifiedError extends Error {
  constructor(message, code, status = 402) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

/**
 * @param {object} p
 * @param {string} p.paymentIntentId   id renvoyé par le SDK Airwallex
 * @param {string} p.userId            utilisateur authentifié (req.user.id)
 * @param {string} p.purpose           libellé pour les logs et l'anti-rejeu
 * @param {number} [p.expectedAmount]  montant attendu (unités majeures)
 * @returns {Promise<object>} le PaymentIntent Airwallex
 */
async function assertPaidIntent({ paymentIntentId, userId, purpose, expectedAmount }) {
  const piId = String(paymentIntentId || '').trim();
  if (!piId) {
    throw new PaymentNotVerifiedError('paymentIntentId is required.', 'PAYMENT_INTENT_MISSING', 400);
  }

  let pi;
  try {
    pi = await airwallex.retrievePaymentIntent(piId);
  } catch (e) {
    logger.error(`[assertPaidIntent] ${purpose} : retrieve ${piId} failed — ${e.message}`);
    throw new PaymentNotVerifiedError(
      'Unable to verify the payment. Please try again.',
      'PAYMENT_VERIFICATION_FAILED',
      502,
    );
  }

  const status = String(pi?.status || '').toUpperCase();
  if (status !== 'SUCCEEDED') {
    logger.warn(`[assertPaidIntent] ${purpose} : PI ${piId} status=${status} (refus)`);
    throw new PaymentNotVerifiedError('Payment not completed.', 'PAYMENT_NOT_SUCCEEDED', 402);
  }

  // Le PaymentIntent doit appartenir à l'appelant.
  const piUserId = String(pi?.metadata?.userId || pi?.metadata?.user_id || '').trim();
  if (piUserId && piUserId !== String(userId)) {
    logger.warn(
      `[assertPaidIntent] ${purpose} : PI ${piId} appartient a ${piUserId}, appelant ${userId} (refus)`,
    );
    throw new PaymentNotVerifiedError(
      'This payment does not belong to you.',
      'PAYMENT_INTENT_FOREIGN',
      403,
    );
  }

  // Anti-rejeu : un même PaymentIntent ne peut activer qu'un seul achat.
  // On réutilise la collection ProcessedWebhook (clé unique) comme registre.
  try {
    await ProcessedWebhook.create({ eventId: `purchase:${piId}` });
  } catch (e) {
    if (e && e.code === 11000) {
      logger.warn(`[assertPaidIntent] ${purpose} : PI ${piId} deja consomme (rejeu refuse)`);
      throw new PaymentNotVerifiedError(
        'This payment has already been used.',
        'PAYMENT_INTENT_ALREADY_USED',
        409,
      );
    }
    // Toute autre erreur de journalisation ne doit pas bloquer un achat
    // légitime déjà encaissé par Airwallex.
    logger.warn(`[assertPaidIntent] ${purpose} : registre anti-rejeu indisponible — ${e.message}`);
  }

  if (Number.isFinite(expectedAmount) && Number.isFinite(Number(pi?.amount))) {
    const paid = Number(pi.amount);
    if (Math.abs(paid - Number(expectedAmount)) > 0.5) {
      logger.warn(
        `[assertPaidIntent] ${purpose} : montant paye ${paid} != attendu ${expectedAmount} (PI ${piId})`,
      );
    }
  }

  logger.info(`[assertPaidIntent] ${purpose} : PI ${piId} verifie pour ${userId}`);
  return pi;
}

module.exports = { assertPaidIntent, PaymentNotVerifiedError };
