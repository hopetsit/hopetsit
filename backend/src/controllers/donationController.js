/**
 * Donations Controller — v18.9.3
 *
 * POST /donations/create-intent  (owner / sitter / walker)
 *   body: { amount: number, currency?: 'EUR' | 'USD' }
 *   → returns { clientSecret, paymentIntentId } pour confirmPayment côté app.
 *
 * Un don est un PaymentIntent direct vers le compte HoPetSit (pas d'application
 * fee, pas de transfer : c'est nous qui encaissons). On attache au
 * stripeCustomerId du user si présent pour qu'il voie la charge dans ses
 * Mes paiements + pour qu'il puisse utiliser une saved card.
 */
const Stripe = require('stripe');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { getOrCreateStripeCustomerForProvider } = require('../services/stripeService');
const logger = require('../utils/logger');

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_placeholder');

const _modelForRole = (role) =>
  role === 'owner' ? Owner : role === 'walker' ? Walker : Sitter;

const ALLOWED_AMOUNTS_EUR = [2, 5, 10, 20];

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

    // v18.9.3 — on accepte n'importe quel montant > 0, mais on logge quand
    // l'user pousse un montant non-standard (au cas où un bug UI le permet).
    if (!ALLOWED_AMOUNTS_EUR.includes(rawAmount) && currency === 'EUR') {
      logger.warn(
        `[donations] non-standard amount: ${rawAmount} ${currency} from ${role} ${userId}`,
      );
    }

    const Model = _modelForRole(role);
    const doc = await Model.findById(userId);
    if (!doc) return res.status(404).json({ error: 'User not found.' });

    // Lazy create Stripe Customer pour que le don apparaisse bien sur son compte.
    const customerId = await getOrCreateStripeCustomerForProvider({
      userId: doc._id.toString(),
      role,
      email: doc.email,
      name: doc.name,
    });

    const amountCents = Math.round(rawAmount * 100);
    const intent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: currency.toLowerCase(),
      customer: customerId,
      setup_future_usage: 'off_session',
      description: `HoPetSit donation ${rawAmount} ${currency} by ${role} ${doc.name}`,
      metadata: {
        type: 'donation',
        userId: doc._id.toString(),
        userRole: role,
        currency,
      },
      automatic_payment_methods: { enabled: true },
    });

    return res.json({
      clientSecret: intent.client_secret,
      paymentIntentId: intent.id,
      amount: rawAmount,
      currency,
    });
  } catch (err) {
    logger.error('[donations] createDonationIntent failed', err);
    return res.status(500).json({
      error: 'Unable to start donation. Please try again later.',
    });
  }
};

module.exports = { createDonationIntent };
