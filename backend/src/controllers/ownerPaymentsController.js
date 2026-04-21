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
const Booking = require('../models/Booking');
const {
  getOrCreateStripeCustomerForOwner,
  createSetupIntentForOwner,
  listOwnerPaymentMethods,
  detachOwnerPaymentMethod,
} = require('../services/stripeService');
const { sanitizeBooking } = require('../utils/sanitize');
const logger = require('../utils/logger');

const assertOwner = (req) => {
  if (!req.user?.id) {
    return { status: 401, error: 'Authentication required.' };
  }
  if (req.user.role !== 'owner') {
    return { status: 403, error: 'Only owners can manage payment methods.' };
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
    const owner = await Owner.findById(req.user.id);
    if (!owner) return res.status(404).json({ error: 'Owner not found.' });

    if (!owner.stripeCustomerId) {
      // No customer yet means no saved cards — return an empty list instead
      // of eagerly creating a Customer on a mere GET.
      return res.json({ paymentMethods: [], count: 0 });
    }

    const methods = await listOwnerPaymentMethods(owner.stripeCustomerId);
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
    const owner = await Owner.findById(req.user.id);
    if (!owner) return res.status(404).json({ error: 'Owner not found.' });

    const customerId = await getOrCreateStripeCustomerForOwner({
      ownerId: owner._id.toString(),
      email: owner.email,
      name: owner.name,
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
    const owner = await Owner.findById(req.user.id);
    if (!owner) return res.status(404).json({ error: 'Owner not found.' });
    if (!owner.stripeCustomerId) {
      return res.status(404).json({ error: 'No saved payment methods.' });
    }

    // Verify the card belongs to this customer before detaching.
    const methods = await listOwnerPaymentMethods(owner.stripeCustomerId);
    const found = methods.find((m) => m.id === id);
    if (!found) {
      return res.status(404).json({ error: 'Payment method not found for this owner.' });
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
    const ownerId = req.user.id;
    const bookings = await Booking.find({
      ownerId,
      paymentStatus: 'paid',
    })
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
};
