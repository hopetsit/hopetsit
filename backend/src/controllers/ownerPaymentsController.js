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
 * v23.1 — list owner's saved Airwallex cards (payment_consents). Lazy-creates
 * the Airwallex customer on first call so the same record is reused across
 * subsequent payments.
 */
const getPaymentMethods = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  try {
    const airwallex = require('../services/airwallexService');
    // v23.1 — role-aware lookup. Sitters and walkers can also have saved
    // cards (e.g. for paying premium subscriptions). Forcing Owner.findById
    // returned 404 "Owner not found" for them. Use the right model.
    const Model = _roleModel(req.user.role);
    const user = await Model.findById(req.user.id).lean();
    if (!user) {
      return res.status(404).json({
        error: 'User not found.',
        details: `No ${req.user.role} document with id ${req.user.id}`,
      });
    }
    const customer = await airwallex.findOrCreateCustomer({
      userId: user._id.toString(),
      email: user.email,
      firstName: (user.name || '').split(' ')[0] || user.name,
      lastName: (user.name || '').split(' ').slice(1).join(' ') || '',
    });
    const customerId = customer?.id;
    if (!customerId) {
      return res.json({ paymentMethods: [], count: 0, customerId: null });
    }
    const consents = await airwallex.listPaymentMethods(customerId);
    const items = (consents?.items || []).map((c) => ({
      id: c.id,
      brand: c.payment_method?.card?.brand || '',
      last4: c.payment_method?.card?.last4 || '',
      expiryMonth: c.payment_method?.card?.expiry_month || null,
      expiryYear: c.payment_method?.card?.expiry_year || null,
      cardholder: c.payment_method?.card?.name || '',
      createdAt: c.created_at || null,
    }));
    return res.json({ paymentMethods: items, count: items.length, customerId });
  } catch (err) {
    logger.error('[ownerPayments] getPaymentMethods Airwallex failed', err);
    return res.status(500).json({
      error: 'Unable to fetch saved cards.',
      details: err?.message || String(err),
    });
  }
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
 * POST /owner/payments/methods/verify-card
 * v23.1 — Real "Add card without payment" flow:
 *   1. Lazy-create the user's Airwallex customer.
 *   2. Create a tiny verification PaymentIntent (€0.50) attached to that
 *      customer, with `payment_consent` so the card is saved on success.
 *   3. metadata.verifyCardAutoRefund = true → the webhook
 *      (`payment_intent.succeeded`) detects this flag and immediately fires
 *      a full refund, so the user is not actually charged.
 *
 * The frontend opens the existing Airwallex WebView with the returned
 * intent + client secret. From the user's perspective: "Verify card with
 * €0.50 (refunded immediately)" → enters card details → 3DS if needed →
 * card appears in SavedCardsScreen.
 */
const verifyCard = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  try {
    const airwallex = require('../services/airwallexService');
    const Model = _roleModel(req.user.role);
    const user = await Model.findById(req.user.id).lean();
    if (!user) {
      return res.status(404).json({
        error: 'User not found.',
        details: `No ${req.user.role} document with id ${req.user.id}`,
      });
    }

    // 1. Get or create the Airwallex customer for this user.
    const customer = await airwallex.findOrCreateCustomer({
      userId: user._id.toString(),
      email: user.email,
      firstName: (user.name || '').split(' ')[0] || user.name || 'Customer',
      lastName: (user.name || '').split(' ').slice(1).join(' ') || '',
    });
    if (!customer?.id) {
      return res.status(502).json({
        error: 'Unable to create Airwallex customer for verification.',
      });
    }

    // 2. Create a €0.50 verification PaymentIntent.
    const VERIFY_AMOUNT_CENTS = 50;
    const VERIFY_CURRENCY = 'EUR';
    const intent = await airwallex.createPlatformPaymentIntent({
      amount: VERIFY_AMOUNT_CENTS,
      currency: VERIFY_CURRENCY,
      customer_id: customer.id,
      // v23.1 part 44 — same fix as bookingController.createPaymentIntent.
      // `type: 'one_off'` produced a single-use consent that disappeared
      // after the verification charge, so the "Add card" flow ended with
      // an unusable saved card. `recurring` + `next_triggered_by: customer`
      // creates a reusable card-on-file consent that auto-flips to
      // VERIFIED once the verification PI succeeds.
      payment_consent: {
        type: 'recurring',
        next_triggered_by: 'customer',
        merchant_trigger_reason: 'unscheduled',
      },
      metadata: {
        type: 'card_verification',
        verifyCardAutoRefund: 'true',
        userId: String(req.user.id),
        role: req.user.role,
      },
    });

    logger.info(
      `[ownerPayments.verifyCard] PI ${intent.id} created (€0.50 verify) ` +
      `for ${req.user.role} ${req.user.id}, customer ${customer.id}`,
    );

    return res.json({
      paymentIntentId: intent.id,
      clientSecret: intent.client_secret,
      amount: VERIFY_AMOUNT_CENTS / 100,
      currency: VERIFY_CURRENCY,
      customerId: customer.id,
    });
  } catch (err) {
    logger.error('[ownerPayments.verifyCard] failed', err);
    return res.status(500).json({
      error: 'Unable to start card verification.',
      details: err?.message || String(err),
    });
  }
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
 * v23.1 — detach an Airwallex saved card (payment_consent).
 */
const deletePaymentMethod = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  try {
    const airwallex = require('../services/airwallexService');
    const consentId = req.params.id;
    if (!consentId) {
      return res.status(400).json({ error: 'Payment method id is required.' });
    }
    await airwallex.detachPaymentMethod(consentId);
    return res.json({ ok: true, deletedId: consentId });
  } catch (err) {
    logger.error('[ownerPayments] deletePaymentMethod Airwallex failed', err);
    return res.status(500).json({
      error: 'Unable to delete saved card.',
      details: err?.message || String(err),
    });
  }
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
  verifyCard,
};
