/**
 * Donations Controller — v20.1 (Stripe → Airwallex transition)
 *
 * POST /donations/create-intent  (owner / sitter / walker)
 *   body: { amount: number, currency?: 'EUR' | 'USD' | 'GBP' | 'CHF' }
 *   → returns { clientSecret, paymentIntentId, provider, amount, currency }
 *
 * Un don est un PaymentIntent direct vers le compte HoPetSit (pas
 * d'application fee, pas de transfer : c'est nous qui encaissons).
 *
 * v20.1 — Bascule provider via env var PAYMENT_PROVIDER:
 *   - 'stripe'    (défaut) → flux Stripe historique, intact
 *   - 'airwallex'           → nouveau flux Airwallex (test endpoint)
 * On garde le code Stripe pour rollback instantané si besoin pendant la
 * période de bascule.
 */
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const airwallex = require('../services/airwallexService');
const logger = require('../utils/logger');

const _modelForRole = (role) =>
  role === 'owner' ? Owner : role === 'walker' ? Walker : Sitter;

const ALLOWED_AMOUNTS_EUR = [2, 5, 10, 20];

// v21.1.1 — Stripe purgé. Default passe à 'airwallex' (compte Stripe fermé,
// tomber sur Stripe par défaut casserait toute donation).
const PROVIDER = (process.env.PAYMENT_PROVIDER || 'airwallex').toLowerCase();

const createDonationIntent = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    if (!userId) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    if (!['owner', 'sitter', 'walker'].includes(role)) {
      return res.status(403).json({ error: 'Invalid role.' });
    }

    const rawAmount = Number(req.body?.amount);
    if (!Number.isFinite(rawAmount) || rawAmount <= 0) {
      return res.status(400).json({ error: 'amount must be a positive number.' });
    }
    const currency = (req.body?.currency || 'EUR').toString().toUpperCase();
    if (!['EUR', 'USD', 'GBP', 'CHF'].includes(currency)) {
      return res.status(400).json({ error: 'Unsupported currency.' });
    }

    if (!ALLOWED_AMOUNTS_EUR.includes(rawAmount) && currency === 'EUR') {
      logger.warn(
        `[donations] non-standard amount: ${rawAmount} ${currency} from ${role} ${userId}`,
      );
    }

    const Model = _modelForRole(role);
    const doc = await Model.findById(userId);
    if (!doc) return res.status(404).json({ error: 'User not found.' });

    const amountCents = Math.round(rawAmount * 100);

    // ─── Airwallex flow ────────────────────────────────────────────────────
    if (PROVIDER === 'airwallex') {
      try {
        const intent = await airwallex.createPlatformPaymentIntent({
          amount: amountCents,
          currency,
          metadata: {
            type:      'donation',
            userId:    doc._id.toString(),
            userRole:  role,
            currency,
            userEmail: doc.email || '',
            userName:  doc.name  || '',
            // Surface so admin can find the donation easily in the AWX dashboard.
            description: `HoPetSit donation ${rawAmount} ${currency} by ${role} ${doc.name}`,
          },
        });

        logger.info(
          `[donations] airwallex PI created ${intent.id} ${rawAmount} ${currency} ` +
          `by ${role} ${userId}`,
        );

        return res.json({
          clientSecret:    intent.client_secret,
          paymentIntentId: intent.id,
          provider:        'airwallex',
          amount:          rawAmount,
          currency,
        });
      } catch (e) {
        logger.error('[donations] airwallex create-intent failed', e);
        return res.status(502).json({
          error: 'Unable to start donation right now. Please try again later.',
        });
      }
    }

    // ─── Stripe disabled (v21.1.1 purge) ─────────────────────────────────
    return res.status(502).json({ error: 'Stripe payment disabled — Airwallex only' });
  } catch (err) {
    logger.error('[donations] createDonationIntent failed', err);
    return res.status(500).json({
      error: 'Unable to start donation. Please try again later.',
    });
  }
};

module.exports = { createDonationIntent };
