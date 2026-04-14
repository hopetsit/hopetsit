const Conversation = require('../models/Conversation');
const Booking = require('../models/Booking');

/**
 * Returns { blocked: false } or { blocked: true, bookingId, status, paymentStatus }.
 * Chat is blocked when the latest booking between the two parties is in status
 * 'agreed' (doubly accepted) but paymentStatus is not 'paid'.
 * If no booking exists yet, chat is allowed (pre-booking discussion).
 */
const evaluateChatAccess = async ({ ownerId, sitterId }) => {
  const booking = await Booking.findOne({ ownerId, sitterId })
    .sort({ createdAt: -1 })
    .select('_id status paymentStatus')
    .lean();
  if (!booking) return { blocked: false };
  if (booking.status === 'agreed' && booking.paymentStatus !== 'paid') {
    return {
      blocked: true,
      bookingId: booking._id.toString(),
      status: booking.status,
      paymentStatus: booking.paymentStatus,
    };
  }
  return { blocked: false };
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
    console.error('requirePaidBooking error', e);
    return res.status(500).json({ error: 'Chat access check failed.' });
  }
};

module.exports = { requirePaidBooking, evaluateChatAccess };
