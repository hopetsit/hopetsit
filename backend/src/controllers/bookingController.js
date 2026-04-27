/* eslint-disable handle-callback-err */
const Booking = require('../models/Booking');
const Notification = require('../models/Notification');
const Walker = require('../models/Walker');
const Sitter = require('../models/Sitter');
const Owner = require('../models/Owner');
const Post = require('../models/Post');
const Pet = require('../models/Pet');
const Message = require('../models/Message');
const { sendSMS } = require('../services/smsService');
const logger = require('../../logger');
const AirwallexPaymentHandler = require('../services/payment/AirwallexPaymentHandler');
const { sendOwnerNotificationPush } = require('./notificationController');
const IdentityController = require('./identityController');
const { publishNewApplicationNotificationToFollowers } = require('./postController');
const { onBookingCompleted } = require('../services/loyaltyService');
const { createAirwallexPayout } = require('../services/payment/airwallexPayoutService');
const { BadRequest, InternalServerError } = require('../errors');
const BaseError = require('../errors/BaseError');

const logger_v2 = require('../utils/logger_v2');

// Session v17 — payout to user (sitter or walker). Renamed from
// processSitterPayoutForBooking.
async function processProviderPayoutForBooking(booking, manualRetry = false) {
  try {
    if (!booking) {
      logger.warn('processProviderPayoutForBooking: no booking');
      return;
    }
    const provider = getBookingProvider(booking);
    if (!provider || !provider.doc) {
      logger.warn(
        `processProviderPayoutForBooking: no provider for booking ${booking._id}`
      );
      return;
    }

    // Determine which payout method(s) to use for this provider. Candidates are
    // IBAN, PayPal, Stripe Connect. On session v17 we prefer IBAN then PayPal,
    // ignoring Stripe Connect (field deleted during purge).
    const IBAN = provider.doc.ibanNumber?.trim();
    const PP = provider.doc.paypalEmail?.trim();

    if (IBAN) {
      // ... send to IBAN ...
      await createAirwallexPayout(booking._id, provider.type, IBAN, 'iban');
      logger.info(
        `✈️  payout IBAN for booking ${booking._id.toString()} — provider ${provider.type}:${provider.doc._id}`
      );
      return;
    }

    if (PP) {
      // ... send to PayPal (if we support it) ...
      await createAirwallexPayout(booking._id, provider.type, PP, 'paypal');
      logger.info(
        `✈️  payout PayPal for booking ${booking._id.toString()} — provider ${provider.type}:${provider.doc._id}`
      );
      return;
    }

    // Both blank — hold and retry later.
    logger.warn(
      `⏸️  processProviderPayoutForBooking: holding booking ${booking._id} — no IBAN or PayPal configured on ${provider.type}`
    );
    booking.payoutStatus = 'held';
    booking.heldReason = 'No payout method configured';
    booking.heldAt = new Date();
    await booking.save();
  } catch (err) {
    logger.error('processProviderPayoutForBooking', err);
    if (!manualRetry) {
      throw err;
    }
  }
}

// Helper to determine which provider (sitter or walker) owns a booking.
// Session v17 — supports both sitter and walker.
function getBookingProvider(booking) {
  if (!booking) return null;
  if (
    booking.sitterId &&
    (booking.type === 'sitting' || booking.type === 'day_care')
  ) {
    return { type: 'sitter', doc: booking.sitterId };
  }
  if (booking.walkerId && booking.type === 'walking') {
    return { type: 'walker', doc: booking.walkerId };
  }
  return null;
}

const createBooking = async (req, res) => {
  try {
    const {
      ownerId,
      petIds,
      sitterId,
      walkerId,
      type,
      startDate,
      endDate,
      rate,
      totalPrice,
      instruction,
    } = req.body;

    if (!type || !['sitting', 'day_care', 'walking'].includes(type)) {
      return res.status(400).json({ error: 'Invalid type' });
    }

    // Normalize rate to integer cents
    let rateInCents = rate;
    if (typeof rate === 'string' && rate.includes('.')) {
      const parts = rate.split('.');
      rateInCents =
        parseInt(parts[0]) * 100 + parseInt(parts[1].padEnd(2, '0'));
    } else if (typeof rate === 'number') {
      rateInCents = Math.round(rate * 100);
    }
    if (!Number.isInteger(rateInCents) || rateInCents < 0) {
      return res.status(400).json({ error: 'Invalid rate' });
    }

    // Verify pets exist and belong to owner
    const pets = await Pet.find({ _id: { $in: petIds }, ownerId });
    if (pets.length !== petIds.length) {
      return res
        .status(400)
        .json({ error: 'One or more pets do not belong to the owner' });
    }

    // Verify sitter or walker exists and matches type
    let provider;
    if (type === 'walking') {
      if (!walkerId) return res.status(400).json({ error: 'walkerId required' });
      provider = await Walker.findById(walkerId);
      if (!provider) {
        return res.status(404).json({ error: 'Walker not found' });
      }
    } else {
      if (!sitterId) return res.status(400).json({ error: 'sitterId required' });
      provider = await Sitter.findById(sitterId);
      if (!provider) {
        return res.status(404).json({ error: 'Sitter not found' });
      }
    }

    // Create booking
    const booking = new Booking({
      ownerId,
      petIds,
      sitterId: type === 'walking' ? null : sitterId,
      walkerId: type === 'walking' ? walkerId : null,
      type,
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      rate: rateInCents,
      totalPrice: totalPrice ? Math.round(totalPrice * 100) : null,
      instruction,
      status: 'pending',
    });

    await booking.save();
    const populated = await booking.populate('petIds');
    return res.status(201).json({ booking: populated });
  } catch (err) {
    logger.error('createBooking error', err);
    return res.status(500).json({ error: 'Failed to create booking' });
  }
};

const listBookings = async (req, res) => {
  try {
    const { skip = 0, limit = 10 } = req.query;
    const bookings = await Booking.find()
      .skip(parseInt(skip))
      .limit(parseInt(limit))
      .populate('ownerId', 'name email')
      .populate('sitterId', 'name email')
      .populate('walkerId', 'name email')
      .populate('petIds');

    return res.json({ bookings });
  } catch (err) {
    logger.error('listBookings error', err);
    return res.status(500).json({ error: 'Failed to fetch bookings' });
  }
};

const getMyBookings = async (req, res) => {
  try {
    const userId = req.user.id;
    const role = req.query.role; // 'owner', 'sitter', 'walker'

    let query = {};
    if (role === 'owner') {
      query = { ownerId: userId };
    } else if (role === 'sitter') {
      query = { sitterId: userId, type: { $in: ['sitting', 'day_care'] } };
    } else if (role === 'walker') {
      query = { walkerId: userId, type: 'walking' };
    } else {
      query = {
        $or: [
          { ownerId: userId },
          { sitterId: userId, type: { $in: ['sitting', 'day_care'] } },
          { walkerId: userId, type: 'walking' },
        ],
      };
    }

    const bookings = await Booking.find(query)
      .populate('ownerId', 'name email avatar')
      .populate('sitterId', 'name email avatar')
      .populate('walkerId', 'name email avatar')
      .populate('petIds')
      .sort({ startDate: -1 });

    return res.json({ bookings });
  } catch (err) {
    logger.error('getMyBookings error', err);
    return res.status(500).json({ error: 'Failed to fetch bookings' });
  }
};

const cancelBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.query;

    if (!role || !['sitter', 'walker'].includes(role)) {
      return res
        .status(400)
        .json({ error: 'sitter or walker role query parameter is required' });
    }

    const booking = await Booking.findById(id);
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    // Check authority
    const isProvider =
      (role === 'sitter' && String(booking.sitterId) === req.user.id) ||
      (role === 'walker' && String(booking.walkerId) === req.user.id);

    if (!isProvider) {
      return res
        .status(403)
        .json({ error: 'Only the provider can cancel this booking' });
    }

    if (!['pending', 'accepted'].includes(booking.status)) {
      return res
        .status(400)
        .json({ error: 'Only pending or accepted bookings can be cancelled' });
    }

    // Calculate refund
    let refund = 0;
    const now = new Date();
    const startDate = new Date(booking.startDate);
    const msDiff = startDate - now;
    const daysDiff = msDiff / (1000 * 60 * 60 * 24);

    if (daysDiff > 7) {
      refund = booking.totalPrice;
    } else if (daysDiff > 1) {
      refund = Math.floor(booking.totalPrice * 0.5);
    }

    booking.status = 'cancelled';
    booking.refundAmount = refund;
    booking.cancellationReason = `Cancelled by ${role}`;
    booking.cancelledAt = now;
    await booking.save();

    // TODO: Process refund

    return res.json({ booking, refundAmount: refund });
  } catch (err) {
    logger.error('cancelBooking error', err);
    return res.status(500).json({ error: 'Failed to cancel booking' });
  }
};

const cancelOwnerSentBookingRequest = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const booking = await Booking.findById(id);
    if (!booking) {
      return res.status(404).json({ error: 'Booking request not found' });
    }

    if (String(booking.ownerId) !== userId) {
      return res.status(403).json({ error: 'Only owner can cancel their request' });
    }

    if (booking.status !== 'pending') {
      return res
        .status(400)
        .json({
          error:
            'Only pending booking requests (awaiting response) can be cancelled',
        });
    }

    booking.status = 'cancelled';
    booking.cancelledAt = new Date();
    await booking.save();

    return res.json({ booking });
  } catch (err) {
    logger.error('cancelOwnerSentBookingRequest error', err);
    return res.status(500).json({ error: 'Failed to cancel booking request' });
  }
};

const selfCancelWithRefund = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (String(booking.ownerId._id) !== userId) {
      return res
        .status(403)
        .json({ error: 'Only owner can cancel their own booking' });
    }

    if (!['accepted', 'paid'].includes(booking.status)) {
      return res
        .status(400)
        .json({ error: 'Only accepted or paid bookings can be self-cancelled' });
    }

    // Calculate refund
    let refund = 0;
    const now = new Date();
    const startDate = new Date(booking.startDate);
    const msDiff = startDate - now;
    const daysDiff = msDiff / (1000 * 60 * 60 * 24);

    if (daysDiff > 7) {
      refund = booking.totalPrice;
    } else if (daysDiff > 1) {
      refund = Math.floor(booking.totalPrice * 0.5);
    }

    booking.status = 'cancelled';
    booking.refundAmount = refund;
    booking.cancellationReason = 'Cancelled by owner';
    booking.cancelledAt = now;
    await booking.save();

    // TODO: Send notification to sitter/walker
    // TODO: Process refund

    return res.json({ booking, refundAmount: refund });
  } catch (err) {
    logger.error('selfCancelWithRefund error', err);
    return res.status(500).json({ error: 'Failed to cancel booking' });
  }
};

const respondBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const { accepted, reason } = req.body;

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    const userId = req.user.id;
    const isProvider =
      (booking.sitterId && String(booking.sitterId._id) === userId) ||
      (booking.walkerId && String(booking.walkerId._id) === userId);

    if (!isProvider) {
      return res
        .status(403)
        .json({ error: 'Only the provider can respond to this booking' });
    }

    if (booking.status !== 'pending') {
      return res
        .status(400)
        .json({ error: 'Only pending bookings can be responded to' });
    }

    if (accepted) {
      booking.status = 'accepted';
      booking.respondedAt = new Date();

      // Send notification to owner
      const notif = new Notification({
        userId: booking.ownerId._id,
        type: 'booking_response',
        title:
          booking.sitterId && booking.sitterId._id === userId
            ? 'Your sitter accepted'
            : 'Your walker accepted',
        message: `${
          booking.sitterId && booking.sitterId._id === userId
            ? booking.sitterId.name
            : booking.walkerId.name
        } accepted your booking request`,
        relatedBookingId: booking._id,
        read: false,
      });
      await notif.save();

      try {
        await sendOwnerNotificationPush(notif);
      } catch (e) {
        logger.warn('Push notification failed', e.message);
      }
    } else {
      booking.status = 'rejected';
      booking.rejectionReason = reason || '';
      booking.respondedAt = new Date();

      // Send notification to owner
      const notif = new Notification({
        userId: booking.ownerId._id,
        type: 'booking_response',
        title:
          booking.sitterId && booking.sitterId._id === userId
            ? 'Your sitter declined'
            : 'Your walker declined',
        message: `${
          booking.sitterId && booking.sitterId._id === userId
            ? booking.sitterId.name
            : booking.walkerId.name
        } declined your booking request`,
        relatedBookingId: booking._id,
        read: false,
      });
      await notif.save();

      try {
        await sendOwnerNotificationPush(notif);
      } catch (e) {
        logger.warn('Push notification failed', e.message);
      }
    }

    await booking.save();
    return res.json({ booking });
  } catch (err) {
    logger.error('respondBooking error', err);
    return res.status(500).json({ error: 'Unable to respond to booking' });
  }
};

const agreeToBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (String(booking.ownerId._id) !== userId) {
      return res
        .status(403)
        .json({ error: 'Only owner can agree to booking' });
    }

    if (booking.status !== 'accepted') {
      return res
        .status(400)
        .json({ error: 'Only accepted bookings can be agreed to' });
    }

    booking.status = 'agreed';
    booking.agreedAt = new Date();
    await booking.save();

    // Fire immediate payment intent if available (Session v18.1)
    let paymentData = null;
    try {
      const data = await _prepareOwnerPaymentForAgreedBooking(booking);
      paymentData = data;
    } catch (e) {
      logger.warn(
        `agreeToBooking: _prepareOwnerPaymentForAgreedBooking failed, continuing`,
        e.message
      );
    }

    return res.json({
      booking,
      paymentData,
    });
  } catch (err) {
    logger.error('agreeToBooking error', err);
    return res.status(500).json({ error: 'Unable to agree to booking' });
  }
};

const createBookingPaymentIntent = async (req, res) => {
  try {
    const { id } = req.params;

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (String(booking.ownerId._id) !== req.user.id) {
      return res
        .status(403)
        .json({ error: 'Only owner can create payment' });
    }

    if (!['agreed', 'paid'].includes(booking.status)) {
      return res
        .status(400)
        .json({ error: 'Booking must be agreed or paid first' });
    }

    const airwallex = new AirwallexPaymentHandler();
    const clientSecret = await airwallex.createPaymentIntent(
      booking.totalPrice,
      booking._id.toString(),
      booking.ownerId.email
    );

    return res.json({
      clientSecret,
      bookingId: booking._id,
      amount: booking.totalPrice,
    });
  } catch (err) {
    logger.error('createBookingPaymentIntent error', err);
    return res.status(500).json({ error: 'Unable to create payment intent' });
  }
};

const confirmBookingPayment = async (req, res) => {
  try {
    const { id } = req.params;
    const { paymentIntentId } = req.body;

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
      .populate('petIds');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (String(booking.ownerId._id) !== req.user.id) {
      return res
        .status(403)
        .json({ error: 'Only owner can confirm payment' });
    }

    // Verify payment with Airwallex
    const airwallex = new AirwallexPaymentHandler();
    const paymentStatus = await airwallex.getPaymentIntent(paymentIntentId);

    if (paymentStatus.status !== 'succeeded') {
      return res.status(400).json({ error: 'Payment not successful' });
    }

    booking.paymentStatus = 'paid';
    booking.status = 'paid';
    booking.paymentIntentId = paymentIntentId;
    booking.paidAt = new Date();
    await booking.save();

    // Send SMS to sitter/walker
    const provider = getBookingProvider(booking);
    if (provider && provider.doc && provider.doc.phone) {
      try {
        await sendSMS(
          provider.doc.phone,
          `HoPetSit: ${booking.ownerId.name} paid for their ${booking.type} booking. Check your app for details.`
        );
      } catch (e) {
        logger.warn('SMS send failed', e.message);
      }
    }

    // Send notification to sitter/walker
    const notif = new Notification({
      userId:
        provider.type === 'sitter'
          ? booking.sitterId._id
          : booking.walkerId._id,
      type: 'booking_paid',
      title: 'Booking payment confirmed',
      message: `${booking.ownerId.name} paid for the ${booking.type} booking`,
      relatedBookingId: booking._id,
      read: false,
    });
    await notif.save();

    try {
      // TODO: Send push notification to provider
    } catch (e) {
      logger.warn('Push notification failed', e.message);
    }

    // Send message to chat
    const chat = await Message.findOne({
      $or: [
        { bookingId: booking._id },
        {
          participantIds: {
            $all: [booking.ownerId._id, provider.doc._id],
          },
        },
      ],
    });

    if (chat) {
      const msg = new Message({
        bookingId: booking._id,
        senderId: booking.ownerId._id,
        participantIds: [booking.ownerId._id, provider.doc._id],
        type: 'system',
        text: `Payment confirmed for ${booking.type} booking from ${booking.startDate.toLocaleDateString()} to ${booking.endDate.toLocaleDateString()}`,
        createdAt: new Date(),
      });
      await msg.save();
      await Message.updateOne(
        { _id: chat._id },
        {
          $push: { messages: msg._id },
          lastMessageAt: msg.createdAt,
        }
      );
    }

    return res.json({ booking: booking });
  } catch (err) {
    logger.error('confirmBookingPayment error', err);
    return res.status(500).json({ error: 'Unable to confirm payment' });
  }
};

const createBookingPaypalOrder = async (req, res) => {
  try {
    const { id } = req.params;

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (String(booking.ownerId._id) !== req.user.id) {
      return res
        .status(403)
        .json({ error: 'Only owner can create PayPal order' });
    }

    if (!['agreed', 'paid'].includes(booking.status)) {
      return res
        .status(400)
        .json({ error: 'Booking must be agreed or already paid' });
    }

    // Create PayPal order
    // (for now, return a stub)
    return res.json({
      paypalOrderId: null,
      bookingId: booking._id,
      amount: booking.totalPrice,
    });
  } catch (err) {
    logger.error('createBookingPaypalOrder error', err);
    return res.status(500).json({ error: 'Unable to create PayPal order' });
  }
};

const captureBookingPaypalPayment = async (req, res) => {
  try {
    const { id } = req.params;
    const { paypalOrderId } = req.body;

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (String(booking.ownerId._id) !== req.user.id) {
      return res
        .status(403)
        .json({ error: 'Only owner can capture PayPal payment' });
    }

    // Capture PayPal order
    // (for now, just mark as paid)
    booking.paymentStatus = 'paid';
    booking.status = 'paid';
    booking.paymentIntentId = paypalOrderId;
    booking.paidAt = new Date();
    await booking.save();

    return res.json({ booking });
  } catch (err) {
    logger.error('captureBookingPaypalPayment error', err);
    return res.status(500).json({ error: 'Unable to capture PayPal payment' });
  }
};

const getBookingAgreement = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const booking = await Booking.findById(id)
      .populate('ownerId', 'name email avatar address')
      .populate('sitterId', 'name email avatar')
      .populate('walkerId', 'name email avatar')
      .populate('petIds');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    // Permission check: owner OR sitter OR walker
    const isOwner = String(booking.ownerId?._id) === userId;
    const isSitter = booking.sitterId && String(booking.sitterId._id) === userId;
    const isWalker = booking.walkerId && String(booking.walkerId._id) === userId;

    if (!isOwner && !isSitter && !isWalker) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    // Extract provider safely
    const sitterId = booking.sitterId?._id?.toString() || null;
    const walkerId = booking.walkerId?._id?.toString() || null;

    return res.json({
      booking,
      sitterId,
      walkerId,
      ownerId: booking.ownerId._id.toString(),
    });
  } catch (err) {
    logger.error('Get booking agreement error', err);
    return res.status(500).json({ error: 'Get booking agreement error' });
  }
};

const requestCancellation = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const userId = req.user.id;

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    const isOwner = String(booking.ownerId._id) === userId;
    const isProvider =
      (booking.sitterId && String(booking.sitterId._id) === userId) ||
      (booking.walkerId && String(booking.walkerId._id) === userId);

    if (!isOwner && !isProvider) {
      return res
        .status(403)
        .json({ error: 'Only owner or provider can request cancellation' });
    }

    if (!['accepted', 'paid', 'agreed'].includes(booking.status)) {
      return res
        .status(400)
        .json({
          error: 'Only accepted, agreed, or paid bookings can request cancellation',
        });
    }

    booking.cancellationRequested = true;
    booking.cancellationRequestReason = reason;
    booking.cancellationRequestedBy = userId;
    booking.cancellationRequestedAt = new Date();
    await booking.save();

    // Send notification to the other party
    if (isOwner) {
      const provider = getBookingProvider(booking);
      const providerId =
        provider.type === 'sitter'
          ? booking.sitterId._id
          : booking.walkerId._id;
      const notif = new Notification({
        userId: providerId,
        type: 'cancellation_request',
        title: 'Cancellation requested',
        message: `${booking.ownerId.name} requested to cancel the booking. Reason: ${reason}`,
        relatedBookingId: booking._id,
        read: false,
      });
      await notif.save();
    } else {
      const notif = new Notification({
        userId: booking.ownerId._id,
        type: 'cancellation_request',
        title: 'Cancellation requested',
        message: `Your ${
          booking.sitterId && booking.sitterId._id === userId
            ? 'sitter'
            : 'walker'
        } requested to cancel the booking. Reason: ${reason}`,
        relatedBookingId: booking._id,
        read: false,
      });
      await notif.save();
    }

    return res.json({ booking });
  } catch (err) {
    logger.error('requestCancellation error', err);
    return res.status(500).json({ error: 'Unable to request cancellation' });
  }
};

const getPaymentStatus = async (req, res) => {
  try {
    const { id } = req.params;

    const booking = await Booking.findById(id);
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    return res.json({
      paymentStatus: booking.paymentStatus,
      status: booking.status,
      totalPrice: booking.totalPrice,
    });
  } catch (err) {
    logger.error('getPaymentStatus error', err);
    return res.status(500).json({ error: 'Unable to get payment status' });
  }
};

const retryBookingPayout = async (req, res) => {
  try {
    const { id } = req.params;

    const booking = await Booking.findById(id)
      .populate('sitterId')
      .populate('walkerId');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (booking.payoutStatus !== 'held') {
      return res
        .status(400)
        .json({ error: 'Only held payouts can be retried' });
    }

    // Retry payout
    booking.payoutStatus = 'pending';
    booking.heldReason = null;
    booking.heldAt = null;
    await booking.save();

    await processProviderPayoutForBooking(booking, true);

    return res.json({ booking });
  } catch (err) {
    logger.error('retryBookingPayout error', err);
    return res.status(500).json({ error: 'Unable to retry payout' });
  }
};

const processScheduledSitterPayouts = async (req, res) => {
  try {
    const bookings = await Booking.find({
      status: 'completed',
      payoutStatus: 'pending',
      sitterId: { $exists: true, $ne: null },
    })
      .populate('sitterId')
      .populate('walkerId');

    let processed = 0;
    for (const booking of bookings) {
      try {
        await processProviderPayoutForBooking(booking);
        processed += 1;
      } catch (err) {
        logger.error(`Failed to process payout for booking ${booking._id}`, err);
      }
    }

    return res.json({
      message: 'Scheduled sitter payouts processed',
      processed,
    });
  } catch (err) {
    logger.error('processScheduledSitterPayouts error', err);
    return res.status(500).json({ error: 'Unable to process payouts' });
  }
};

// Sprint v18.5 #3 — hold admin: released in background when provider configures
// their IBAN/PayPal.
const processHeldPayouts = async () => {
  try {
    const heldBookings = await Booking.find({ payoutStatus: 'held' })
      .populate('sitterId')
      .populate('walkerId')
      .populate('petIds');

    if (!heldBookings.length) return { released: 0, stillHeld: 0 };

    let released = 0;
    let stillHeld = 0;
    for (const booking of heldBookings) {
      try {
        const provider = getBookingProvider(booking);
        if (!provider.doc) {
          stillHeld += 1;
          continue;
        }
        const doc = provider.doc;
        const hasIban = !!(
          doc.ibanNumber && String(doc.ibanNumber).trim().length > 0
        );
        const hasPaypal = !!(
          doc.paypalEmail && String(doc.paypalEmail).trim().length > 0
        );
        const hasStripeConnectActive =
          doc.stripeConnectAccountId &&
          doc.stripeConnectAccountStatus === 'active';

        if (!hasIban && !hasPaypal && !hasStripeConnectActive) {
          // Still nothing configured — leave held, next tick will retry.
          stillHeld += 1;
          continue;
        }

        // Provider has configured something. Mark released and trigger
        // processProviderPayoutForBooking which will pick the right method.
        booking.heldReleasedAt = new Date();
        // Reset to pending so processProviderPayoutForBooking enters the
        // actual transfer path instead of re-marking held.
        booking.payoutStatus = 'pending';
        await booking.save();
        logger.info(
          `🔓 HELD payout released for booking ${booking._id.toString()} — provider ${provider.type}:${doc._id} just configured payout. Processing transfer now.`
        );
        await processProviderPayoutForBooking(booking);
        released += 1;
      } catch (err) {
        logger.error(
          `⚠️  processHeldPayouts: failed for booking ${booking._id}`,
          err
        );
        stillHeld += 1;
      }
    }
    logger.info(
      `⏸️  processHeldPayouts: released=${released}, stillHeld=${stillHeld}`
    );
    return { released, stillHeld };
  } catch (err) {
    logger.error('processHeldPayouts error', err);
    throw err;
  }
};


// Sprint 7 step 1 — mark a paid booking as completed (owner action) and fire loyalty hooks.
const completeBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const booking = await Booking.findById(id);
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (String(booking.ownerId) !== req.user.id) {
      return res.status(403).json({ error: 'Only the owner can mark this booking as completed.' });
    }
    if (booking.paymentStatus !== 'paid') {
      return res.status(400).json({ error: 'Booking must be paid before completion.' });
    }
    if (booking.status === 'completed') {
      return res.json({ booking: sanitizeBooking(booking), alreadyCompleted: true });
    }
    booking.status = 'completed';
    await booking.save();
    try {
      await onBookingCompleted(booking);
    } catch (e) {
      logger.warn('loyalty hook failed', e.message);
    }
    return res.json({ booking: sanitizeBooking(booking) });
  } catch (e) {
    logger.error('completeBooking error', e);
    return res.status(500).json({ error: 'Unable to complete booking.' });
  }
};

// Shared helper — used by applicationController to offer the owner an
// immediate Stripe PaymentSheet right after accepting an application.
const _prepareOwnerPaymentForAgreedBooking = async (booking, ownerId = null, opts = {}) => {
  // Stub implementation — returns null for now. In full implementation,
  // this would create a payment intent and return payment details.
  return null;
};

module.exports = {
  createBooking,
  listBookings,
  getMyBookings,
  cancelBooking,
  cancelOwnerSentBookingRequest,
  selfCancelWithRefund,
  respondBooking,
  agreeToBooking,
  createBookingPaymentIntent,
  confirmBookingPayment,
  createBookingPaypalOrder,
  captureBookingPaypalPayment,
  getBookingAgreement,
  requestCancellation,
  getPaymentStatus,
  retryBookingPayout,
  processScheduledSitterPayouts,
  // v18.5 — #3 hold admin : released en background quand provider config
  // son IBAN/PayPal.
  processHeldPayouts,
  completeBooking,
  // Session v17 — payout helper now supports walker too. Renamed from
  // processSitterPayoutForBooking. The legacy export below keeps existing
  // call sites (e.g. adminRoutes.js) working without modification.
  processProviderPayoutForBooking,
  processSitterPayoutForBooking: processProviderPayoutForBooking,
  // Shared helper — used by applicationController to offer the owner an
  // immediate Stripe PaymentSheet right after accepting an application.
  _prepareOwnerPaymentForAgreedBooking,
};
