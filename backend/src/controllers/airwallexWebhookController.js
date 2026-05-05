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
    // v23.1 part 41 — verbose diagnostic to help Daniel pinpoint why the
    // signature mismatch persists (most likely : wrong secret in Render env).
    const secretEnv = process.env.AIRWALLEX_WEBHOOK_SECRET || '';
    const sigHeader = req.headers['x-signature'] || req.headers['X-Signature'] || '';
    const tsHeader  = req.headers['x-timestamp'] || req.headers['X-Timestamp'] || '';
    const bodyLen   = Buffer.isBuffer(req.body) ? req.body.length : (req.body || '').length;
    logger.warn(
      `[airwallex.webhook] signature failed : ${err.message} | ` +
      `secret_set=${secretEnv ? 'yes' : 'NO'} | ` +
      `secret_starts=${secretEnv ? secretEnv.slice(0, 6) + '...' : 'EMPTY'} | ` +
      `secret_len=${secretEnv.length} | ` +
      `x-timestamp=${tsHeader || 'MISSING'} | ` +
      `x-signature_len=${(sigHeader || '').length} | ` +
      `body_bytes=${bodyLen}`
    );
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

        // v23.1 — route by metadata.type so non-booking purchases
        // (map_boost / subscription / premium / coins) are activated server-side
        // even if the client-side /confirm call never fires.
        const piMetadata = data?.metadata || {};
        const purchaseType = (piMetadata.type || '').toLowerCase();

        if (purchaseType === 'map_boost_purchase') {
          try {
            const { activateMapBoostFromWebhook } = require('./purchaseActivationController');
            await activateMapBoostFromWebhook({ piId, metadata: piMetadata });
            logger.info(`✅ [airwallex.webhook] map_boost activated from PI ${piId} for user ${piMetadata.userId}`);
          } catch (e) {
            logger.error(`[airwallex.webhook] map_boost activation failed for PI ${piId} : ${e.message}`);
          }
          break;
        }

        if (purchaseType === 'subscription_purchase' || purchaseType === 'premium_purchase') {
          try {
            const { activateSubscriptionFromWebhook } = require('./purchaseActivationController');
            await activateSubscriptionFromWebhook({ piId, metadata: piMetadata });
            logger.info(`✅ [airwallex.webhook] subscription activated from PI ${piId} for user ${piMetadata.userId}`);
          } catch (e) {
            logger.error(`[airwallex.webhook] subscription activation failed for PI ${piId} : ${e.message}`);
          }
          break;
        }

        // v23.1 part 36 — KYC payment (3 EUR sitter/walker identity verification).
        if (purchaseType === 'kyc' || piMetadata.type === 'kyc') {
          try {
            const { onKycPaymentSucceeded } = require('./kycController');
            await onKycPaymentSucceeded({ id: piId, metadata: piMetadata });
            logger.info(`✅ [airwallex.webhook] KYC payment activated from PI ${piId} for ${piMetadata.role} ${piMetadata.userId}`);
          } catch (e) {
            logger.error(`[airwallex.webhook] KYC activation failed for PI ${piId} : ${e.message}`);
          }
          break;
        }

        // v23.1 — card verification flow ("Add card without payment").
        // We charged €0.50 just to attach a payment_consent ; the user
        // never agreed to be charged. Refund immediately so the bank entry
        // disappears and only the saved card remains.
        if (purchaseType === 'card_verification' || piMetadata.verifyCardAutoRefund === 'true') {
          try {
            const refund = await airwallex.createRefund({
              paymentIntentId: piId,
              amount: data?.amount || 50, // refund full amount
              reason: 'requested_by_customer',
              metadata: {
                type: 'card_verification_refund',
                originalPiId: piId,
                userId: piMetadata.userId || '',
              },
            });
            logger.info(
              `✅ [airwallex.webhook] auto-refund issued for card verification ` +
              `PI ${piId} → refund ${refund?.id || '?'} (user ${piMetadata.userId})`,
            );
          } catch (e) {
            logger.error(
              `[airwallex.webhook] auto-refund failed for verification PI ${piId} : ${e.message}`,
            );
          }
          break;
        }

        const booking = await Booking.findOne({ airwallexPaymentIntentId: piId });
        if (!booking) {
          logger.info(`[airwallex.webhook] no booking found for PI ${piId} (purchaseType=${purchaseType || 'unknown'})`);
          break;
        }
        // v23.1 part 45 — fix Daniel "wallet, notif paiement, page Payée
        // tout cassé". Root cause : the webhook flipped paymentStatus to
        // 'paid' but left booking.status at 'accepted' / 'agreed'. The
        // downstream gate processProviderPayoutForBooking checks
        // `booking.status === 'paid' && booking.paymentStatus === 'paid'`
        // (PayPal flow sets BOTH, see line ~2944), so the payout was
        // silently skipped — no Airwallex Payout, no creditWallet, no
        // sitterPayoutCompleted notif. Setting status='paid' here mirrors
        // what PayPal already does and unblocks the rest of the chain.
        booking.status = 'paid';
        booking.paymentStatus = 'paid';
        booking.paidAt = new Date();
        await booking.save();
        logger.info(`✅ [airwallex.webhook] booking ${booking._id} marked as paid (PI ${piId})`);

        // v23.1 — push FCM + email + bell to BOTH parties on payment success.
        try {
          const { sendNotification } = require('../services/notificationSender');
          const providerRole2 = booking.walkerId ? 'walker' : 'sitter';
          const providerId2 = booking.walkerId
            ? booking.walkerId.toString()
            : (booking.sitterId ? booking.sitterId.toString() : null);
          const ownerId2 = booking.ownerId ? booking.ownerId.toString() : null;
          if (providerId2) {
            sendNotification({
              userId: providerId2,
              role: providerRole2,
              type: 'booking_paid',
              data: { bookingId: booking._id.toString(), providerRole: providerRole2 },
              actor: { role: 'owner', id: ownerId2 },
            }).catch((e) => {
              logger.warn(
                `[airwallex.webhook] booking_paid notif failed for ${providerRole2}=${providerId2} : ${e?.message || e}`,
              );
            });
          }
          if (ownerId2) {
            sendNotification({
              userId: ownerId2,
              role: 'owner',
              type: 'booking_paid_owner',
              data: { bookingId: booking._id.toString(), providerRole: providerRole2 },
              actor: { role: providerRole2, id: providerId2 },
            }).catch((e) => {
              logger.warn(
                `[airwallex.webhook] booking_paid_owner notif failed for owner=${ownerId2} : ${e?.message || e}`,
              );
            });
          }
        } catch (e) {
          logger.warn(`[airwallex.webhook] sendNotification failed : ${e.message}`);
        }

        // v22.4 — Bug A2 : push real-time event to owner so the
        // "Action requise" banner refreshes immediately (instead of
        // waiting up to 30s for the periodic refresh).
        try {
          const { emitToUser } = require('../sockets');
          if (booking.ownerId) {
            emitToUser('owner', booking.ownerId.toString(), 'booking:paid', {
              bookingId: booking._id.toString(),
              paymentStatus: 'paid',
            });
          }
        } catch (e) {
          logger.warn(`[airwallex.webhook] booking:paid emit failed : ${e.message}`);
        }

        // v22.1 — Bug 14c : auto-message système dans le chat owner+provider
        // pour confirmer le paiement aux 2 parties, fiable (déclenché par
        // webhook, pas par UI conditionnel).
        // v23.1 — body localisé selon la langue de l'owner (was: hardcoded FR
        // → emoji prefix could render as empty in some Flutter setups).
        try {
          const Conversation = require('../models/Conversation');
          const Message = require('../models/Message');
          const { emitToUser } = require('../sockets');
          const Owner = require('../models/Owner');

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

            // v23.1 — localise le body selon la langue de l'owner.
            const ownerDoc = await Owner.findById(ownerId).select('language').lean();
            const ownerLang = (ownerDoc?.language || 'fr').slice(0, 2).toLowerCase();
            const PAYMENT_CONFIRMED_BODY = {
              fr: 'Paiement confirmé. La réservation est active — vous pouvez désormais discuter ici.',
              en: 'Payment confirmed. Your booking is active — you can now chat here.',
              es: 'Pago confirmado. La reserva está activa — ya pueden hablar aquí.',
              de: 'Zahlung bestätigt. Die Buchung ist aktiv — ihr könnt jetzt hier chatten.',
              it: 'Pagamento confermato. La prenotazione è attiva — potete ora chattare qui.',
              pt: 'Pagamento confirmado. A reserva está ativa — já podem conversar aqui.',
            };
            const localizedBody =
              PAYMENT_CONFIRMED_BODY[ownerLang] || PAYMENT_CONFIRMED_BODY.en;

            const systemMessage = await Message.create({
              conversationId: conversation._id,
              senderRole: 'system',
              senderId: ownerId, // requis par schema, on met l'owner
              body: localizedBody,
              type: 'text',
            });

            // v23.1 part 37 — 2e system message "Bonjour, discutons du lieu
            // de rencontre" pour inviter les 2 parties à briser la glace.
            const RENDEZVOUS_BODY = {
              fr: '👋 Bonjour ! Discutons ici pour convenir du lieu et de l\'heure de rencontre.',
              en: '👋 Hello! Let\'s chat here to agree on the meeting place and time.',
              es: '👋 ¡Hola! Hablemos aquí para acordar el lugar y la hora del encuentro.',
              de: '👋 Hallo! Lass uns hier den Treffpunkt und die Uhrzeit besprechen.',
              it: '👋 Ciao! Parliamo qui per concordare il luogo e l\'ora dell\'incontro.',
              pt: '👋 Olá! Vamos conversar aqui para combinar o local e a hora do encontro.',
            };
            const rendezvousBody =
              RENDEZVOUS_BODY[ownerLang] || RENDEZVOUS_BODY.en;
            const rendezvousMessage = await Message.create({
              conversationId: conversation._id,
              senderRole: 'system',
              senderId: ownerId,
              body: rendezvousBody,
              type: 'text',
            });

            // v23.1 part 41 — fix Daniel "badge message marche pas" :
            // increment BOTH ownerUnreadCount and sitterUnreadCount (the
            // schema uses sitterUnreadCount as a generic provider field, even
            // when the actual provider is a walker — see Conversation.js).
            // 2 system messages = +2 each, plus update lastMessage/lastMessageAt
            // so the conversation list shows the right preview.
            try {
              conversation.lastMessage = rendezvousBody;
              conversation.lastMessageAt = new Date();
              conversation.ownerUnreadCount = (conversation.ownerUnreadCount || 0) + 2;
              conversation.sitterUnreadCount = (conversation.sitterUnreadCount || 0) + 2;
              await conversation.save();
            } catch (e) {
              logger.warn(`[airwallex.webhook] conversation badge update failed : ${e.message}`);
            }

            // Push temps réel vers les 2 parties (les 2 messages).
            try {
              for (const msg of [systemMessage, rendezvousMessage]) {
                emitToUser('owner', ownerId.toString(), 'message:new', {
                  conversationId: conversation._id.toString(),
                  message: msg.toObject(),
                });
                emitToUser(providerRole, providerId.toString(), 'message:new', {
                  conversationId: conversation._id.toString(),
                  message: msg.toObject(),
                });
              }
            } catch (_) { /* socket non-critique */ }

            // v23.1 — fire NEW_MESSAGE notification (in-app badge + FCM
            // push + email) to BOTH parties so the chat tab badge bumps
            // and the user gets a phone push + email even if the app is
            // closed. Previously only emitToUser was called → silent if
            // app in background.
            try {
              const { sendNotification } = require('../services/notificationSender');
              const senderName = 'HoPetSit';
              const previewText = (localizedBody || '').slice(0, 120);
              await Promise.allSettled([
                sendNotification({
                  userId: ownerId.toString(),
                  role: 'owner',
                  type: 'NEW_MESSAGE',
                  data: {
                    conversationId: conversation._id.toString(),
                    messageId: systemMessage._id.toString(),
                    senderName,
                    preview: previewText,
                  },
                  actor: { role: 'system', id: null },
                }),
                sendNotification({
                  userId: providerId.toString(),
                  role: providerRole,
                  type: 'NEW_MESSAGE',
                  data: {
                    conversationId: conversation._id.toString(),
                    messageId: systemMessage._id.toString(),
                    senderName,
                    preview: previewText,
                  },
                  actor: { role: 'system', id: null },
                }),
              ]);
            } catch (e) {
              logger.warn(`[airwallex.webhook] system message notification failed: ${e.message}`);
            }

            logger.info(`✅ [airwallex.webhook] system message sent in conv ${conversation._id} (booking ${booking._id})`);
          }
        } catch (e) {
          logger.error(`[airwallex.webhook] auto chat message failed : ${e.message}`);
        }

        // v23.1 — schedule payout for endDate + 24h (policy submitted to
        // Airwallex risk team). Previously this directly triggered the
        // payout, which violated the dispute window policy. The scheduler
        // will now release the funds once the 24h window has elapsed.
        // For legacy bookings whose endDate + 24h is already in the past,
        // schedulePayoutForBooking() releases immediately.
        try {
          const {
            schedulePayoutForBooking,
          } = require('./bookingController');
          if (typeof schedulePayoutForBooking === 'function') {
            await schedulePayoutForBooking(booking);
          }
        } catch (e) {
          logger.error(`[airwallex.webhook] payout scheduling failed : ${e.message}`);
        }

        // v23.1 — auto-create the Invoice so it appears under
        // "Mes Réservations → Factures" for owner + provider in real time.
        try {
          const {
            createInvoiceForBooking,
          } = require('./invoiceController');
          // Reload with populated parties so invoice can snapshot names/emails.
          const populated = await Booking.findById(booking._id)
            .populate('ownerId')
            .populate('sitterId')
            .populate('walkerId')
            .populate('petIds');
          await createInvoiceForBooking(populated);
        } catch (e) {
          logger.error(`[airwallex.webhook] invoice auto-creation failed : ${e.message}`);
        }
        break;
      }

      case 'payment_intent.failed':
      case 'payment_intent.cancelled': {
        const piId = data?.id || data?.payment_intent_id;
        if (!piId) break;
        const booking = await Booking.findOne({ airwallexPaymentIntentId: piId });
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
