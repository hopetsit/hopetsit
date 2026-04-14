/**
 * Stripe Webhook Handler
 * 
 * Handles Stripe webhook events for payment processing
 * Single source of truth for payment status updates
 */

const Booking = require('../models/Booking');
const { constructWebhookEvent } = require('../services/stripeService');
const { createNotificationSafe } = require('../services/notificationService');
const { sendNotification } = require('../services/notificationSender');

/**
 * Handle Stripe webhook events
 * POST /webhooks/stripe
 */
const handleStripeWebhook = async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    // Get raw body - use rawBody if available, otherwise use body
    const rawBody = req.rawBody || req.body;
    
    // Ensure it's a Buffer for signature verification
    if (!Buffer.isBuffer(rawBody)) {
      throw new Error('Webhook body must be a Buffer for signature verification');
    }
    
    // Construct webhook event from raw body
    event = constructWebhookEvent(rawBody, sig);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    console.error('Signature header:', sig);
    console.error('Body type:', typeof req.body, 'Is Buffer:', Buffer.isBuffer(req.body));
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    // Handle the event
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentIntentSucceeded(event.data.object);
        break;

      case 'payment_intent.payment_failed':
        await handlePaymentIntentFailed(event.data.object);
        break;

      case 'charge.refunded':
        await handleChargeRefunded(event.data.object);
        break;

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    // Return a response to acknowledge receipt of the event
    res.json({ received: true });
  } catch (error) {
    console.error('Error handling webhook:', error);
    res.status(500).json({ error: 'Webhook handler failed' });
  }
};

/**
 * Handle payment_intent.succeeded event
 * Update booking status to PAID
 */
const handlePaymentIntentSucceeded = async (paymentIntent) => {
  try {
    const bookingId = paymentIntent.metadata.booking_id;

    if (!bookingId) {
      console.error('No booking_id in payment intent metadata');
      return;
    }

    const booking = await Booking.findById(bookingId);

    if (!booking) {
      console.error(`Booking not found: ${bookingId}`);
      return;
    }

    // Update booking status to PAID
    booking.status = 'paid';
    booking.paymentStatus = 'paid'; // Update payment status
    booking.paidAt = new Date();
    // Store charge ID (can be a string or Charge object)
    if (paymentIntent.latest_charge) {
      booking.stripeChargeId = typeof paymentIntent.latest_charge === 'string' 
        ? paymentIntent.latest_charge 
        : paymentIntent.latest_charge.id;
    }
    
    // Verify the payment intent ID matches
    if (booking.stripePaymentIntentId !== paymentIntent.id) {
      console.error(`PaymentIntent ID mismatch for booking ${bookingId}`);
      return;
    }

    await booking.save();

    await createNotificationSafe({
      recipientRole: 'sitter',
      recipientId: booking.sitterId?.toString ? booking.sitterId.toString() : String(booking.sitterId),
      actorRole: 'owner',
      actorId: booking.ownerId?.toString ? booking.ownerId.toString() : String(booking.ownerId),
      type: 'booking_paid',
      title: 'Booking paid',
      body: 'A booking was paid successfully.',
      data: {
        bookingId: booking._id.toString(),
        paymentProvider: 'stripe',
        paymentIntentId: paymentIntent.id,
      },
    });

    // Sprint 4 step 3 — PAYMENT_SUCCESS to owner + sitter
    const paymentData = {
      bookingId: booking._id.toString(),
      amount: (paymentIntent.amount / 100).toFixed(2),
      currency: (paymentIntent.currency || '').toUpperCase(),
    };
    Promise.allSettled([
      sendNotification({
        userId: booking.ownerId?.toString(),
        role: 'owner',
        type: 'PAYMENT_SUCCESS',
        data: paymentData,
      }),
      sendNotification({
        userId: booking.sitterId?.toString(),
        role: 'sitter',
        type: 'PAYMENT_SUCCESS',
        data: paymentData,
      }),
    ]).catch(() => {});

    console.log(`✅ Booking ${bookingId} marked as PAID via webhook (payment_status: paid)`);
  } catch (error) {
    console.error('Error handling payment_intent.succeeded:', error);
    throw error;
  }
};

/**
 * Handle payment_intent.payment_failed event
 * Update booking status to PAYMENT_FAILED
 */
const handlePaymentIntentFailed = async (paymentIntent) => {
  try {
    const bookingId = paymentIntent.metadata.booking_id;

    if (!bookingId) {
      console.error('No booking_id in payment intent metadata');
      return;
    }

    const booking = await Booking.findById(bookingId);

    if (!booking) {
      console.error(`Booking not found: ${bookingId}`);
      return;
    }

    // Update booking status to PAYMENT_FAILED
    booking.status = 'payment_failed';
    booking.paymentStatus = 'pending'; // Keep payment status as pending if payment failed
    booking.paymentFailedAt = new Date();
    await booking.save();

    // Sprint 4 step 3 — PAYMENT_FAILED to owner only
    sendNotification({
      userId: booking.ownerId?.toString(),
      role: 'owner',
      type: 'PAYMENT_FAILED',
      data: {
        bookingId: booking._id.toString(),
        amount: (paymentIntent.amount / 100).toFixed(2),
        currency: (paymentIntent.currency || '').toUpperCase(),
      },
    }).catch(() => {});

    console.log(`⚠️ Booking ${bookingId} marked as PAYMENT_FAILED via webhook`);
  } catch (error) {
    console.error('Error handling payment_intent.payment_failed:', error);
    throw error;
  }
};

/**
 * Handle charge.refunded event
 * Update booking status to REFUNDED
 */
const handleChargeRefunded = async (charge) => {
  try {
    // Find booking by charge ID
    const booking = await Booking.findOne({ stripeChargeId: charge.id });

    if (!booking) {
      console.error(`Booking not found for charge: ${charge.id}`);
      return;
    }

    // Update booking status to REFUNDED
    booking.status = 'refunded';
    booking.paymentStatus = 'refund'; // Update payment status to refund
    
    // Update cancellation refund ID if not already set
    if (charge.refunds && charge.refunds.data && charge.refunds.data.length > 0) {
      booking.cancellation.refundId = charge.refunds.data[0].id;
    }

    await booking.save();

    console.log(`💰 Booking ${booking._id} marked as REFUNDED via webhook (payment_status: refund)`);
  } catch (error) {
    console.error('Error handling charge.refunded:', error);
    throw error;
  }
};

module.exports = {
  handleStripeWebhook,
};

