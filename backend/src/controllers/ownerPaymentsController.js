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
const {
  getOrCreateStripeCustomerForOwner,
  getOrCreateStripeCustomerForProvider,
  createSetupIntentForOwner,
  listOwnerPaymentMethods,
  detachOwnerPaymentMethod,
  attachOwnerPaymentMethod,
} = require('../services/stripeService');

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
 * Returns the list of cards attached to the owner's Stripe Customer.
 */
const getPaymentMethods = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  try {
    const Model = _roleModel(req.user.role);
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    if (!user.stripeCustomerId) {
      return res.json({ paymentMethods: [], count: 0 });
    }

    const methods = await listOwnerPaymentMethods(user.stripeCustomerId);
    return res.json({ paymentMethods: methods, count: methods.length });
  } catch (err) {
    logger.error('[ownerPayments] getPaymentMethods failed', err);
    return res.status(500).json({ error: 'Unable to fetch payment methods.' });
  }
};

/**
 * POST /owner/payments/setup-intent
 * Creates a SetupIntent so the Flutter client can open the Stripe
 * PaymentSheet in "add card" mode (no charge). On success, Stripe
 * automatically attaches the new PaymentMethod to the Customer.
 */
const createSetupIntent = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  try {
    const Model = _roleModel(req.user.role);
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    // v18.9 — helper role-agnostic.
    const customerId = await getOrCreateStripeCustomerForProvider({
      userId: user._id.toString(),
      role: req.user.role,
      email: user.email,
      name: user.name,
    });

    const setupIntent = await createSetupIntentForOwner(customerId);

    return res.json({
      customerId,
      setupIntentId: setupIntent.id,
      clientSecret: setupIntent.client_secret,
    });
  } catch (err) {
    logger.error('[ownerPayments] createSetupIntent failed', err);
    return res.status(500).json({ error: 'Unable to start card setup.' });
  }
};

/**
 * POST /owner/payments/methods/attach   (v20.0.3)
 * After the user ticks "Enregistrer cette carte" on ModernCardPaymentScreen
 * (post-confirmPayment), we attach that PaymentMethod to the user's Stripe
 * Customer so it shows up in "Mes paiements" for the next purchase.
 *
 * Body: { paymentMethodId: 'pm_...' }
 */
const attachPaymentMethod = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  const { paymentMethodId } = req.body || {};
  if (!paymentMethodId || !String(paymentMethodId).startsWith('pm_')) {
    return res.status(400).json({ error: 'Invalid payment method id.' });
  }

  try {
    const Model = _roleModel(req.user.role);
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const customerId = await getOrCreateStripeCustomerForProvider({
      userId: user._id.toString(),
      role: req.user.role,
      email: user.email,
      name: user.name,
    });

    await attachOwnerPaymentMethod(paymentMethodId, customerId);
    return res.json({
      message: 'Payment method saved.',
      paymentMethodId,
    });
  } catch (err) {
    logger.error('[ownerPayments] attachPaymentMethod failed', err);
    return res.status(500).json({ error: 'Unable to save payment method.' });
  }
};

/**
 * DELETE /owner/payments/methods/:id
 * Detaches a PaymentMethod from the owner's Stripe Customer.
 */
const deletePaymentMethod = async (req, res) => {
  const guard = assertOwner(req);
  if (guard) return res.status(guard.status).json({ error: guard.error });

  const { id } = req.params;
  if (!id || !String(id).startsWith('pm_')) {
    return res.status(400).json({ error: 'Invalid payment method id.' });
  }

  try {
    const Model = _roleModel(req.user.role);
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });
    if (!user.stripeCustomerId) {
      return res.status(404).json({ error: 'No saved payment methods.' });
    }

    // Verify the card belongs to this customer before detaching.
    const methods = await listOwnerPaymentMethods(user.stripeCustomerId);
    const found = methods.find((m) => m.id === id);
    if (!found) {
      return res.status(404).json({ error: 'Payment method not found for this user.' });
    }

    await detachOwnerPaymentMethod(id);
    return res.json({ message: 'Payment method removed.', paymentMethodId: id });
  } catch (err) {
    logger.error('[ownerPayments] deletePaymentMethod failed', err);
    return res.status(500).json({ error: 'Unable to delete payment method.' });
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
};
