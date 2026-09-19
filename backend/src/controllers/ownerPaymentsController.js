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
// v568 — utilitaire partagé : un seul client Airwallex par PERSONNE, cartes
// normalisées, carte par défaut. Utilisé aussi par tous les flux de paiement.
const {
  ensureAirwallexCustomer,
  listSavedCards,
  setDefaultConsentId,
} = require('../utils/airwallexCustomer');

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
    // v568 — client Airwallex PARTAGÉ par les 3 profils (cf.
    // utils/airwallexCustomer.js) : la carte enregistrée en propriétaire
    // reste visible en gardien et en promeneur.
    const Model = _roleModel(req.user.role);
    const user = await Model.findById(req.user.id).lean();
    if (!user) {
      return res.status(404).json({
        error: 'User not found.',
        details: `No ${req.user.role} document with id ${req.user.id}`,
      });
    }
    const { customerId, defaultConsentId } = await ensureAirwallexCustomer({
      userId: req.user.id,
      role: req.user.role,
      userDoc: user,
      logTag: 'ownerPayments',
    });
    if (!customerId) {
      return res.json({ paymentMethods: [], count: 0, customerId: null, defaultId: null });
    }
    const { cards, defaultId } = await listSavedCards({ customerId, defaultConsentId });
    return res.json({
      paymentMethods: cards,
      count: cards.length,
      customerId,
      defaultId,
    });
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

    // 1. Get or create the Airwallex customer for this user (shared by the
    //    owner / sitter / walker profiles of the same person).
    const { customerId } = await ensureAirwallexCustomer({
      userId: req.user.id,
      role: req.user.role,
      userDoc: user,
      logTag: 'ownerPayments.verifyCard',
    });
    if (!customerId) {
      return res.status(502).json({
        error: 'Unable to create Airwallex customer for verification.',
      });
    }

    // v568 — « Modifier ma carte » : Airwallex ne permet PAS de changer le
    // numéro d'une carte enregistrée. Remplacer = enregistrer la nouvelle,
    // la passer par défaut, puis désactiver l'ancien consentement. L'id de
    // l'ancienne carte est transporté en métadonnée pour la traçabilité ;
    // la désactivation se fait à la confirmation côté app (DELETE).
    const replaceConsentId = String(req.body?.replaceConsentId || '').trim();

    // 2. Create a €0.50 verification PaymentIntent.
    const VERIFY_AMOUNT_CENTS = 50;
    const VERIFY_CURRENCY = 'EUR';
    const intent = await airwallex.createPlatformPaymentIntent({
      amount: VERIFY_AMOUNT_CENTS,
      currency: VERIFY_CURRENCY,
      customer_id: customerId,
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
        ...(replaceConsentId ? { replaceConsentId } : {}),
      },
    });

    logger.info(
      `[ownerPayments.verifyCard] PI ${intent.id} created (€0.50 verify) ` +
      `for ${req.user.role} ${req.user.id}, customer ${customerId}` +
      (replaceConsentId ? ` (remplace ${replaceConsentId})` : ''),
    );

    return res.json({
      paymentIntentId: intent.id,
      clientSecret: intent.client_secret,
      amount: VERIFY_AMOUNT_CENTS / 100,
      currency: VERIFY_CURRENCY,
      customerId,
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
    // v532 — IDOR : on supprimait l'identifiant reçu SANS vérifier qu'il
    // appartenait bien à l'appelant. N'importe quel compte connecté pouvait
    // donc supprimer la carte enregistrée d'un AUTRE utilisateur (et casser
    // ses paiements) rien qu'en devinant/récupérant un id de consentement.
    // On liste d'abord les cartes du client Airwallex de l'appelant et on
    // refuse tout id qui n'y figure pas.
    const Model = _roleModel(req.user.role);
    const me = await Model.findById(req.user.id).lean();
    if (!me) return res.status(404).json({ error: 'User not found.' });
    const { customerId, defaultConsentId } = await ensureAirwallexCustomer({
      userId: req.user.id,
      role: req.user.role,
      userDoc: me,
      logTag: 'ownerPayments.delete',
    });
    const { cards } = customerId
      ? await listSavedCards({ customerId, defaultConsentId })
      : { cards: [] };
    const owned = cards.some((c) => String(c.id) === String(consentId));
    if (!owned) {
      logger.warn(
        `[ownerPayments] suppression de carte refusée : consent ${consentId} n'appartient pas à ${req.user.role} ${req.user.id}`,
      );
      return res.status(404).json({ error: 'Payment method not found.' });
    }
    await airwallex.detachPaymentMethod(consentId);
    // v568 — la carte par défaut ne doit pas rester pointée sur une carte
    // supprimée : on bascule sur la suivante (ou on efface le choix).
    let newDefaultId = null;
    if (String(defaultConsentId || '') === String(consentId)) {
      const remaining = cards.filter((c) => String(c.id) !== String(consentId));
      newDefaultId = (remaining.find((c) => !c.isExpired) || remaining[0])?.id || '';
      await setDefaultConsentId({ userId: req.user.id, consentId: newDefaultId });
    }
    return res.json({ ok: true, deletedId: consentId, defaultId: newDefaultId || null });
  } catch (err) {
    logger.error('[ownerPayments] deletePaymentMethod Airwallex failed', err);
    return res.status(500).json({
      error: 'Unable to delete saved card.',
      details: err?.message || String(err),
    });
  }
};

/**
 * POST /owner/payments/methods/:id/default
 * v568 — choisit la carte par défaut. Elle est présentée en premier au
 * paiement (réservation, abonnement, boutique, don) et mémorisée sur les
 * 3 profils de la personne.
 */
const setDefaultPaymentMethod = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  try {
    const consentId = String(req.params.id || '').trim();
    if (!consentId) {
      return res.status(400).json({ error: 'Payment method id is required.' });
    }
    const Model = _roleModel(req.user.role);
    const me = await Model.findById(req.user.id).lean();
    if (!me) return res.status(404).json({ error: 'User not found.' });

    const { customerId, defaultConsentId } = await ensureAirwallexCustomer({
      userId: req.user.id,
      role: req.user.role,
      userDoc: me,
      logTag: 'ownerPayments.default',
    });
    const { cards } = customerId
      ? await listSavedCards({ customerId, defaultConsentId })
      : { cards: [] };
    // Même garde-fou que la suppression : on n'accepte qu'un consentement
    // appartenant à l'appelant.
    if (!cards.some((c) => String(c.id) === String(consentId))) {
      return res.status(404).json({ error: 'Payment method not found.' });
    }
    await setDefaultConsentId({ userId: req.user.id, consentId });
    return res.json({ ok: true, defaultId: consentId });
  } catch (err) {
    logger.error('[ownerPayments] setDefaultPaymentMethod failed', err);
    return res.status(500).json({
      error: 'Unable to set the default card.',
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
  setDefaultPaymentMethod,
  getPaymentHistory,
  attachPaymentMethod,
  verifyCard,
};
