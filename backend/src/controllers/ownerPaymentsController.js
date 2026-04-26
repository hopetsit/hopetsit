/**
 * Owner Payments Controller — Session v18.2
 *
 * Powers the "Mes paiements" screen in the owner profile:
 *  - GET    /owner/payments/methods          list saved cards
 *  - POST   /owner/payments/setup-intent     create a SetupIntent so the
 *                                            owner can add a new card
 *                                            without being charged
 *  - DELETE /owner/payments/methods/:id      detach a saved PaymentMethod
 *  - GET    /owner/payments/history          list past paid bookings
 *
 * The Stripe Customer is created lazily on the owner's first action (add
 * a card OR first booking payment) via getOrCreateStripeCustomerForOwner.
 */

const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const Booking = require('../models/Booking');
// v21.1.1 — Stripe disabled (Airwallex only). Removed all stripeService imports.

// v18.9 — helper role-agnostic. Retourne le model ET le doc chargé.
const _roleModel = (role) =>
  role === 'owner' ? Owner : role === 'walker' ? Walker : Sitter;
const { sanitizeBooking } = require('../utils/sanitize');
const logger = require('../utils/logger');

// v18.9 — accepte désormais owner / sitter / walker (les 3 peuvent avoir
// des cartes enregistrées Stripe Customer).
const assertOwner = (req) => {
  if (!req.user?.id) {
    return { status: 401, error: 'Authentication required.' };
  }
  if (!['owner', 'sitter', 'walker'].includes(req.user.role)) {
    return { status: 403, error: 'Only authenticated users can manage payment methods.' };
  }
  return null;
};

/**
 * GET /owner/payments/methods
 * v21.1.1 — Stripe disabled (Airwallex only). Returns empty list for compatibility.
 */
const getPaymentMethods = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  return res.json({ paymentMethods: [], count: 0 });
};

/**
 * POST /owner/payments/setup-intent
 * v21.1.1 — Stripe disabled (Airwallex only). Cards are auto-saved on first payment.
 */
const createSetupIntent = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  return res.status(501).json({
    error: 'Add card flow disabled — cards are auto-saved at first Airwallex payment.',
  });
};

/**
 * POST /owner/payments/methods/attach
 * v21.1.1 — Stripe disabled (Airwallex only).
 */
const attachPaymentMethod = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  return res.status(501).json({ error: 'Card management disabled in v21.1.1.' });
};

/**
 * DELETE /owner/payments/methods/:id
 * v21.1.1 — Stripe disabled (Airwallex only).
 */
const deletePaymentMethod = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  return res.status(501).json({ error: 'Card management disabled in v21.1.1.' });
};

/**
 * GET /owner/payments/history
 * Returns the owner's past paid bookings in reverse chronological order.
 * Each entry includes the provider name, amount, currency and date — what
 * the "Historique" section of the Mes Paiements screen needs.
 */
const getPaymentHistory = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  try {
    // v18.9 — historique role-aware : owner voit ses paiements sortants ;
    // sitter/walker voit les versements reçus (tous les bookings payés où
    // ils sont le provider).
    const userId = req.user.id;
    const role = req.user.role;
    const match = { paymentStatus: 'paid' };
    if (role === 'owner') {
      match.ownerId = userId;
    } else if (role === 'walker') {
      match.walkerId = userId;
    } else {
      match.sitterId = userId;
    }
    const bookings = await Booking.find(match)
      .sort({ paidAt: -1, updatedAt: -1 })
      .limit(100)
      .populate('ownerId', 'name email avatar')
      .populate('sitterId', 'name avatar')
      .populate('walkerId', 'name avatar')
      .populate('petIds');

    const history = bookings.map((b) => {
      const sanitized = sanitizeBooking(b);
      return {
        id: sanitized.id,
        providerName:
          sanitized.walker?.name ||
          sanitized.sitter?.name ||
          '',
        providerRole: sanitized.walker ? 'walker' : sanitized.sitter ? 'sitter' : null,
        serviceType: sanitized.serviceType || '',
        amount: sanitized.pricing?.totalPrice || 0,
        currency: sanitized.pricing?.currency || 'EUR',
        paidAt: sanitized.paidAt || sanitized.updatedAt || sanitized.createdAt,
        status: sanitized.status,
      };
    });

    return res.json({ history, count: history.length });
  } catch (err) {
    logger.error('[ownerPayments] getPaymentHistory failed', err);
    return res.status(500).json({ error: 'Unable to fetch payment history.' });
  }
};

module.exports = {
  getPaymentMethods,
  createSetupIntent,
  deletePaymentMethod,
  getPaymentHistory,
  attachPaymentMethod,
};
