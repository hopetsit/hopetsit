const Conversation = require('../models/Conversation');
const Booking = require('../models/Booking');
const logger = require('../utils/logger');

/**
 * Canonical rule (sprint6.5 step 3): chat is OPEN only if there is at least
 * one paid booking between owner and sitter. Otherwise blocked with
 * code='PAYMENT_REQUIRED' + bookingId (most recent unpaid/agreed one if any).
 */
const evaluateChatAccess = async ({ ownerId, sitterId }) => {
  const paidExists = await Booking.exists({
    ownerId,
    sitterId,
    paymentStatus: 'paid',
  });
  if (paidExists) return { blocked: false };
  const latest = await Booking.findOne({ ownerId, sitterId })
    .sort({ createdAt: -1 })
    .select('_id status paymentStatus')
    .lean();
  return {
    blocked: true,
    bookingId: latest?._id?.toString() || null,
    status: latest?.status || null,
    paymentStatus: latest?.paymentStatus || null,
  };
};

/**
 * Express middleware: 403 with PAYMENT_REQUIRED when chat is gated.
 * Requires :id param (conversationId) and req.user from requireAuth.
 */
const requirePaidBooking = async (req, res, next) => {
  try {
    const conversation = await Conversation.findById(req.params.id)
      .select('ownerId sitterId')
      .lean();
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }
    const access = await evaluateChatAccess({
      ownerId: conversation.ownerId,
      sitterId: conversation.sitterId,
    });
    if (access.blocked) {
      return res.status(403).json({
        error: 'Payment required',
        code: 'PAYMENT_REQUIRED',
        bookingId: access.bookingId,
      });
    }
    return next();
  } catch (e) {
    logger.error('requirePaidBooking error', e);
    return res.status(500).json({ error: 'Chat access check failed.' });
  }
};

module.exports = { requirePaidBooking, evaluateChatAccess };
