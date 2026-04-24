/**
 * Stripe Webhook Handler
 * 
 * Handles Stripe webhook events for payment processing
 * Single source of truth for payment status updates
 */

const Booking = require('../models/Booking');
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const path = require('path');
const fs = require('fs');
const { constructWebhookEvent } = require('../services/stripeService');
const { createNotificationSafe } = require('../services/notificationService');
const { sendNotification } = require('../services/notificationSender');
const { emitToUser } = require('../sockets/emitter');
const logger = require('../utils/logger');

// v18.6 — helper léger pour récupérer la langue d'un user (fallback 'fr').
const _getUserLanguage = async (role, userId) => {
  try {
    const Model =
      role === 'sitter' ? Sitter :
      role === 'walker' ? Walker :
      role === 'owner' ? Owner : null;
    if (!Model || !userId) return 'fr';
    const u = await Model.findById(userId).select('language').lean();
    const raw = String(u?.language || '').toLowerCase().slice(0, 2);
    return ['fr', 'en', 'es', 'de', 'it', 'pt'].includes(raw) ? raw : 'fr';
  } catch (_) {
    return 'fr';
  }
};

// v18.6 — lit le body de CHAT_AUTO_WELCOME dans la locale de l'user.
const _loadWelcomeMessage = (locale) => {
  try {
    const file = path.join(__dirname, '..', 'locales', locale, 'notifications.json');
    const json = JSON.parse(fs.readFileSync(file, 'utf8') || '{}');
    return json?.CHAT_AUTO_WELCOME?.body
      || "Bonjour 👋 Échangeons ici pour convenir du lieu exact et des détails de la prestation.";
  } catch (_) {
    return "Bonjour 👋 Échangeons ici pour convenir du lieu exact et des détails de la prestation.";
  }
};

/**
 * v18.6 — chat unlock + welcome message + notifs BOOKING_PAID_CHAT_UNLOCKED.
 * Appelé par le webhook Stripe quand payment_intent.succeeded.
 */
const _unlockChatAndWelcome = async ({ ownerId, providerId, providerRole, bookingId }) => {
  if (!ownerId || !providerId || !providerRole) return;

  // 1) Get or create Conversation (walker aware depuis v18.6).
  const query = { ownerId };
  if (providerRole === 'walker') {
    query.walkerId = providerId;
  } else {
    query.sitterId = providerId;
  }
  let convo = await Conversation.findOne(query);
  if (!convo) {
    convo = await Conversation.create({
      ownerId,
      sitterId: providerRole === 'sitter' ? providerId : null,
      walkerId: providerRole === 'walker' ? providerId : null,
      ownerUnreadCount: 1,
      sitterUnreadCount: providerRole === 'sitter' ? 1 : 0,
    });
  }

  // 2) Post welcome message from 'system' sender. On choisit la locale de
  // l'owner comme langue du message visible (le chat est partagé donc un
  // seul texte). Les notifs elles sont traduites par destinataire.
  const ownerLocale = await _getUserLanguage('owner', ownerId);
  const welcomeBody = _loadWelcomeMessage(ownerLocale);
  const sysMessage = await Message.create({
    conversationId: convo._id,
    senderRole: 'system',
    senderId: convo._id, // placeholder, pas d'user — on met l'id du convo.
    body: welcomeBody,
    type: 'text',
  });
  convo.lastMessage = welcomeBody;
  convo.lastMessageAt = new Date();
  if (providerRole === 'sitter') {
    convo.sitterUnreadCount = (convo.sitterUnreadCount || 0) + 1;
  }
  convo.ownerUnreadCount = (convo.ownerUnreadCount || 0) + 1;
  await convo.save();

  // Real-time socket push.
  try {
    emitToUser('owner', ownerId, 'message:new', {
      conversationId: convo._id.toString(),
      messageId: sysMessage._id.toString(),
      body: welcomeBody,
    });
    emitToUser(providerRole, providerId, 'message:new', {
      conversationId: convo._id.toString(),
      messageId: sysMessage._id.toString(),
      body: welcomeBody,
    });
  } catch (_) {}

  // 3) Send BOOKING_PAID_CHAT_UNLOCKED to both (in-app + FCM + email).
  await Promise.allSettled([
    sendNotification({
      userId: ownerId,
      role: 'owner',
      type: 'BOOKING_PAID_CHAT_UNLOCKED',
      data: { bookingId, conversationId: convo._id.toString() },
    }),
    sendNotification({
      userId: providerId,
      role: providerRole,
      type: 'BOOKING_PAID_CHAT_UNLOCKED',
      data: { bookingId, conversationId: convo._id.toString() },
    }),
  ]);
};

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
    logger.error('Webhook signature verification failed:', err.message);
    logger.error('Signature header:', sig);
    logger.error('Body type:', typeof req.body, 'Is Buffer:', Buffer.isBuffer(req.body));
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
        logger.info(`Unhandled event type: ${event.type}`);
    }

    // Return a response to acknowledge receipt of the event
    res.json({ received: true });
  } catch (error) {
    logger.error('Error handling webhook:', error);
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
      logger.error('No booking_id in payment intent metadata');
      return;
    }

    const booking = await Booking.findById(bookingId);

    if (!booking) {
      logger.error(`Booking not found: ${bookingId}`);
      return;
    }

    // Update booking status to PAID
    booking.status = 'paid';
    booking.paymentStatus = 'paid';
    booking.paidAt = new Date();
    // Stripe destination charges automatically transfer funds to sitter's
    // connected account, so mark payout as completed for Stripe payments.
    if (booking.paymentProvider === 'stripe' && booking.petsitterConnectedAccountId) {
      booking.payoutStatus = 'completed';
      booking.payoutAt = new Date();
    }
    // Store charge ID (can be a string or Charge object)
    if (paymentIntent.latest_charge) {
      booking.stripeChargeId = typeof paymentIntent.latest_charge === 'string' 
        ? paymentIntent.latest_charge 
        : paymentIntent.latest_charge.id;
    }
    
    // Verify the payment intent ID matches
    if (booking.stripePaymentIntentId !== paymentIntent.id) {
      logger.error(`PaymentIntent ID mismatch for booking ${bookingId}`);
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

    // Sprint 4 step 3 — PAYMENT_SUCCESS to owner + provider
    // v18.6 — walker parity : router vers sitter OU walker selon la booking.
    const providerId = booking.walkerId
      ? (booking.walkerId.toString?.() || String(booking.walkerId))
      : (booking.sitterId?.toString?.() || String(booking.sitterId));
    const providerRole = booking.walkerId ? 'walker' : 'sitter';

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
      providerId
        ? sendNotification({
            userId: providerId,
            role: providerRole,
            type: 'PAYMENT_SUCCESS',
            data: paymentData,
          })
        : Promise.resolve(),
    ]).catch(() => {});

    // v18.6 — chat unlock + auto-welcome message en langue du destinataire.
    // Crée (ou récupère) la Conversation owner↔provider puis insert un
    // message système "Bonjour 👋 Échangeons ici...". Envoie aussi
    // BOOKING_PAID_CHAT_UNLOCKED (bell + FCM + email) aux 2.
    try {
      await _unlockChatAndWelcome({
        ownerId: booking.ownerId?.toString?.() || String(booking.ownerId),
        providerId,
        providerRole,
        bookingId: booking._id.toString(),
      });
    } catch (chatErr) {
      logger.warn('[webhook paid] chat unlock failed (non-blocking)', chatErr?.message || chatErr);
    }

    // v19.0 — Wallet Vinted-style : crédite le provider avec son netPayout
    // dès que Stripe confirme le paiement. Le provider voit le montant
    // apparaître dans "Mon portefeuille" immédiatement et peut retirer
    // vers IBAN/PayPal ou l'utiliser pour acheter des boost/premium.
    try {
      const netPayout = booking.pricing?.netPayout;
      const walletCurrency = (booking.pricing?.currency || 'EUR').toUpperCase();
      if (providerId && typeof netPayout === 'number' && netPayout > 0) {
        const { creditWallet } = require('../services/walletService');
        await creditWallet({
          userId: providerId,
          userRole: providerRole,
          amount: netPayout,
          currency: walletCurrency,
          type: 'credit_booking',
          bookingId: booking._id.toString(),
          referenceId: paymentIntent.id,
          meta: {
            ownerId: booking.ownerId?.toString?.() || String(booking.ownerId),
            serviceType: booking.serviceType || '',
          },
        });
      }
    } catch (walletErr) {
      logger.error('[webhook paid] wallet credit failed (non-blocking)', walletErr?.message || walletErr);
      // Non-bloquant : si le credit échoue on log et on continue. Le retry
      // du webhook Stripe re-appellera et la clé unique bookingId+type de
      // WalletTransaction empêche un double crédit.
    }

    logger.info(`✅ Booking ${bookingId} marked as PAID via webhook (payment_status: paid)`);
  } catch (error) {
    logger.error('Error handling payment_intent.succeeded:', error);
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
      logger.error('No booking_id in payment intent metadata');
      return;
    }

    const booking = await Booking.findById(bookingId);

    if (!booking) {
      logger.error(`Booking not found: ${bookingId}`);
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

    logger.info(`⚠️ Booking ${bookingId} marked as PAYMENT_FAILED via webhook`);
  } catch (error) {
    logger.error('Error handling payment_intent.payment_failed:', error);
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
      logger.error(`Booking not found for charge: ${charge.id}`);
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

    logger.info(`💰 Booking ${booking._id} marked as REFUNDED via webhook (payment_status: refund)`);
  } catch (error) {
    logger.error('Error handling charge.refunded:', error);
    throw error;
  }
};

module.exports = {
  handleStripeWebhook,
  // v18.7 — exporté pour pouvoir être appelé depuis confirmBookingPayment
  // en fallback si le webhook Stripe n'arrive pas (cold start Render,
  // reseau flaky). Idempotent.
  _unlockChatAndWelcome,
};

