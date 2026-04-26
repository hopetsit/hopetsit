/**
 * v21 — Airwallex webhook controller.
 *
 * Receives PaymentIntent / Payout / Refund events from Airwallex and
 * updates the matching Booking / WalletTransaction / etc. accordingly.
 *
 * Mirror of stripeWebhookController, narrower scope :
 *   - payment_intent.succeeded     → booking paymentStatus = 'paid', enqueue payout
 *   - payment_intent.failed        → booking paymentStatus = 'failed'
 *   - payout.succeeded / completed → booking payoutStatus  = 'completed'
 *   - payout.failed                → booking payoutStatus  = 'failed'
 *
 * The endpoint is mounted at POST /webhooks/airwallex and uses the raw body
 * (no JSON middleware) so signature verification can read the exact bytes
 * Airwallex signed.
 */
const airwallex = require('../services/airwallexService');
const Booking = require('../models/Booking');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');

const handleAirwallexWebhook = async (req, res) => {
  // 1. Verify signature.
  let event;
  try {
    event = airwallex.constructWebhookEvent(req.body, req.headers);
  } catch (err) {
    logger.warn(`[airwallex.webhook] signature failed : ${err.message}`);
    return res.status(400).json({ error: 'Invalid webhook signature' });
  }

  const eventName = event?.name || event?.type || '';
  const data      = event?.data || event;

  try {
    switch (eventName) {
      // ─── PaymentIntent ─────────────────────────────────────────────────
      case 'payment_intent.succeeded': {
        const piId = data?.id || data?.payment_intent_id;
        if (!piId) break;
        const booking = await Booking.findOne({ stripePaymentIntentId: piId });
        if (!booking) {
          logger.info(`[airwallex.webhook] no booking found for PI ${piId} (donation/boost/premium ?)`);
          break;
        }
        booking.paymentStatus = 'paid';
        booking.paidAt = new Date();
        await booking.save();
        logger.info(`✅ [airwallex.webhook] booking ${booking._id} marked as paid (PI ${piId})`);

        // v22.1 — Bug 14c : auto-message système dans le chat owner+provider
        // pour confirmer le paiement aux 2 parties, fiable (déclenché par
        // webhook, pas par UI conditionnel).
        try {
          const Conversation = require('../models/Conversation');
          const Message = require('../models/Message');
          const { emitToUser } = require('../sockets');

          const ownerId = booking.ownerId;
          const sitterId = booking.sitterId || null;
          const walkerId = booking.walkerId || null;
          const providerId = sitterId || walkerId;

          if (ownerId && providerId) {
            const providerField = sitterId ? 'sitterId' : 'walkerId';
            const providerRole  = sitterId ? 'sitter'   : 'walker';

            let conversation = await Conversation.findOne({
              ownerId,
              [providerField]: providerId,
            });

            if (!conversation) {
              conversation = await Conversation.create({
                ownerId,
                [providerField]: providerId,
                bookingId: booking._id,
              });
              logger.info(`[airwallex.webhook] conversation created ${conversation._id} for booking ${booking._id}`);
            }

            const systemMessage = await Message.create({
              conversationId: conversation._id,
              senderRole: 'system',
              senderId: ownerId, // requis par schema, on met l'owner
              body: '✅ Paiement confirmé. La réservation est active — vous pouvez désormais discuter ici.',
              type: 'text',
            });

            // Push temps réel vers les 2 parties.
            try {
              emitToUser('owner', ownerId.toString(), 'message.new', {
                conversationId: conversation._id.toString(),
                message: systemMessage.toObject(),
              });
              emitToUser(providerRole, providerId.toString(), 'message.new', {
                conversationId: conversation._id.toString(),
                message: systemMessage.toObject(),
              });
            } catch (_) { /* socket non-critique */ }

            logger.info(`✅ [airwallex.webhook] system message sent in conv ${conversation._id} (booking ${booking._id})`);
          }
        } catch (e) {
          logger.error(`[airwallex.webhook] auto chat message failed : ${e.message}`);
        }

        // Trigger the existing payout flow which now routes to Airwallex
        // Payout API when sitter has airwallexBeneficiaryId.
        try {
          const { processProviderPayoutForBooking } =
            require('./bookingController');
          if (typeof processProviderPayoutForBooking === 'function') {
            await processProviderPayoutForBooking(booking);
          }
        } catch (e) {
          logger.error(`[airwallex.webhook] payout trigger failed : ${e.message}`);
        }
        break;
      }

      case 'payment_intent.failed':
      case 'payment_intent.cancelled': {
        const piId = data?.id || data?.payment_intent_id;
        if (!piId) break;
        const booking = await Booking.findOne({ stripePaymentIntentId: piId });
        if (!booking) break;
        booking.paymentStatus = eventName.endsWith('.failed') ? 'failed' : 'cancelled';
        await booking.save();
        logger.warn(`⚠️ [airwallex.webhook] booking ${booking._id} → ${booking.paymentStatus}`);
        break;
      }

      // ─── Payouts (sitter cut) ──────────────────────────────────────────
      // Airwallex names these events `payment.*` (not `payout.*`) — they
      // refer to outgoing payments from our wallet to a beneficiary.
      // payment.dispatched = bank received it → payout completed
      // payment.failed     = could not be sent
      // payment.recalled   = bank returned the funds after dispatch
      case 'payment.dispatched':
      case 'payout.succeeded':       // legacy / alternative naming
      case 'payout.completed': {
        const payoutId = data?.id;
        if (!payoutId) break;
        const booking = await Booking.findOne({ airwallexPayoutId: payoutId });
        if (!booking) break;
        booking.payoutStatus = 'completed';
        booking.payoutCompletedAt = new Date();
        await booking.save();
        logger.info(`✅ [airwallex.webhook] payout ${payoutId} → booking ${booking._id} marked paid out`);
        break;
      }

      case 'payment.failed':
      case 'payment.recalled':
      case 'payout.failed': {
        const payoutId = data?.id;
        if (!payoutId) break;
        const booking = await Booking.findOne({ airwallexPayoutId: payoutId });
        if (!booking) break;
        booking.payoutStatus = 'failed';
        booking.payoutError =
          (data?.failure_reason || data?.last_error || `airwallex ${eventName}`).toString();
        await booking.save();
        logger.error(
          `❌ [airwallex.webhook] payout ${payoutId} (${eventName}) for booking ${booking._id} : ${booking.payoutError}`,
        );
        break;
      }

      // ─── Beneficiary side-effects (rare) ───────────────────────────────
      case 'beneficiary.created':
      case 'beneficiary.updated':
      case 'beneficiary.deleted':
        // Already handled inline in iban routes ; no-op here.
        break;

      default:
        logger.info(`[airwallex.webhook] unhandled event ${eventName}`);
    }

    return res.status(200).json({ received: true });
  } catch (e) {
    logger.error(`[airwallex.webhook] handler error : ${e.message}`);
    // Return 200 anyway so Airwallex doesn't retry endlessly on transient
    // bugs ; we have logs to investigate.
    return res.status(200).json({ received: true, error: e.message });
  }
};

module.exports = { handleAirwallexWebhook };
// touch Sitter/Walker imports to silence lint (kept for future enrichments)
void Sitter; void Walker;
