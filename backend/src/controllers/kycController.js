/**
 * KYC Controller
 * v23.1 part 36 — flow KYC payant pour sitter/walker.
 *
 * Endpoints :
 *   POST /kyc/initiate-payment  → crée Airwallex PI 3 EUR pour KYC
 *   POST /kyc/start             → après paiement, crée inquiry Persona + retourne URL hosted
 *   GET  /kyc/status            → retourne kycStatus de l'utilisateur courant
 *   POST /webhooks/persona      → reçoit inquiry.completed/approved/declined
 *   POST /webhooks/airwallex/kyc → reçoit kyc payment success (déclenche la suite du flow)
 *
 * Workflow :
 *   1. User (sitter/walker) tape "Vérifier mon identité" → POST /kyc/initiate-payment
 *      → backend crée Airwallex PI tagged metadata.type='kyc'
 *      → User paie via HPP webview Airwallex
 *   2. Webhook Airwallex (existant) détecte metadata.type='kyc' → marque
 *      User.kycStatus='pending_verification' + User.kycPaidAt + crée inquiry Persona
 *      + sauvegarde User.kycApplicantId (via /kyc/start endpoint async)
 *   3. Frontend appelle GET /kyc/status puis POST /kyc/start si pending_verification
 *      → backend retourne URL hosted Persona
 *      → frontend ouvre WebView Persona
 *   4. User scan ID + selfie sur Persona → Persona traite
 *   5. Webhook /webhooks/persona reçoit inquiry.completed → backend met
 *      User.kycStatus='verified' (si approved) ou 'rejected' (si declined)
 *      + envoie notification au user
 */
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const airwallex = require('../services/airwallexService');
const persona = require('../services/personaService');
const logger = require('../utils/logger');

const KYC_PRICE_EUR = 3; // 3 EUR fixed price

const _modelForRole = (role) => {
  if (role === 'sitter') return Sitter;
  if (role === 'walker') return Walker;
  return null;
};

/**
 * POST /kyc/initiate-payment
 * Body: {} (auth required, role sitter/walker)
 * Returns: { paymentIntent: { id, client_secret }, amount, currency }
 */
const initiatePayment = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const role = (req.user.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model) {
      return res.status(403).json({ error: 'Only sitter or walker can verify identity.' });
    }
    // v23.1 part 66 — Daniel : "verification identite ne marche pas".
    // Surface a clear error if the Persona env vars are missing so the
    // frontend doesn't fall through to a generic 500. Operators just need
    // to set PERSONA_API_KEY (live or sandbox) + PERSONA_TEMPLATE_ID on
    // Render for live mode.
    if (!process.env.PERSONA_API_KEY || !process.env.PERSONA_TEMPLATE_ID) {
      logger.error(
        '[kyc.initiatePayment] PERSONA env vars missing — KYC disabled until configured.',
      );
      return res.status(503).json({
        error: 'Identity verification is temporarily unavailable. Please try again later.',
        code: 'KYC_NOT_CONFIGURED',
      });
    }
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    // Idempotence : si déjà vérifié ou en cours, on ne paie pas une 2e fois.
    if (user.kycStatus === 'verified') {
      return res.status(400).json({ error: 'Already verified.', kycStatus: 'verified' });
    }
    if (user.kycStatus === 'pending_verification' && user.kycPaidAt) {
      return res.status(400).json({
        error: 'Payment already done. Use /kyc/start to launch verification.',
        kycStatus: 'pending_verification',
      });
    }

    // v23.1 part 67 — Daniel : "verification identite ne marche pas" /
    // "page Airwallex vide". Same fix as boutique : ALWAYS attach
    // customer_id so the HPP renders the payment-method picker.
    let airwallexCustomerId = null;
    try {
      const customer = await airwallex.findOrCreateCustomer({
        userId: user._id.toString(),
        email: user.email,
        firstName: (user.name || '').split(' ')[0] || user.name || '',
        lastName: (user.name || '').split(' ').slice(1).join(' ') || '',
      });
      airwallexCustomerId = customer?.id || null;
    } catch (custErr) {
      logger.warn(`[kyc.initiatePayment] customer ensure failed : ${custErr?.message || custErr}`);
    }

    // Crée Airwallex PI tagged metadata.type='kyc'
    const amountInCents = KYC_PRICE_EUR * 100;
    const paymentIntent = await airwallex.createPlatformPaymentIntent({
      amount: amountInCents,
      currency: 'EUR',
      ...(airwallexCustomerId ? { customer_id: airwallexCustomerId } : {}),
      metadata: {
        type: 'kyc',
        userId: user._id.toString(),
        role,
        userEmail: user.email || '',
      },
    });
    logger.info(`[kyc.initiatePayment] PI ${paymentIntent.id} created for ${role} ${user._id}`);

    user.kycStatus = 'pending_payment';
    user.kycPaymentIntentId = paymentIntent.id;
    await user.save();

    return res.status(201).json({
      paymentIntent: {
        id: paymentIntent.id,
        clientSecret: paymentIntent.client_secret,
      },
      amount: KYC_PRICE_EUR,
      currency: 'EUR',
    });
  } catch (err) {
    logger.error('[kyc.initiatePayment]', err);
    return res.status(500).json({ error: 'Unable to initiate KYC payment.', details: err.message });
  }
};

/**
 * POST /kyc/start
 * Body: {} (auth required, status must be pending_verification)
 * Returns: { inquiryId, oneTimeLink, kycStatus }
 */
const startVerification = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const role = (req.user.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model) return res.status(403).json({ error: 'Only sitter or walker.' });
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    if (user.kycStatus === 'verified') {
      return res.status(400).json({ error: 'Already verified.' });
    }
    if (user.kycStatus !== 'pending_verification' || !user.kycPaidAt) {
      return res.status(400).json({
        error: 'Payment required first. Call /kyc/initiate-payment.',
        kycStatus: user.kycStatus,
      });
    }

    // Crée Persona inquiry si pas déjà fait
    let inquiryId = user.kycApplicantId;
    if (!inquiryId) {
      const fullName = (user.name || '').trim();
      const firstName = fullName.split(' ')[0] || '';
      const lastName = fullName.split(' ').slice(1).join(' ') || '';
      const inquiry = await persona.createInquiry({
        userId: user._id.toString(),
        firstName,
        lastName,
        email: user.email,
        role,
      });
      inquiryId = inquiry?.data?.id;
      if (!inquiryId) {
        return res.status(502).json({ error: 'Persona inquiry creation failed.', details: inquiry });
      }
      user.kycApplicantId = inquiryId;
      await user.save();
      logger.info(`[kyc.start] Persona inquiry ${inquiryId} created for ${role} ${user._id}`);
    }

    // Generate one-time hosted URL
    const linkResp = await persona.generateOneTimeLink(inquiryId);
    const oneTimeLink = linkResp?.meta?.['one-time-link'] || linkResp?.data?.attributes?.url;

    return res.json({
      inquiryId,
      oneTimeLink,
      kycStatus: user.kycStatus,
    });
  } catch (err) {
    logger.error('[kyc.start]', err);
    // v23.1 part 66 — surface "missing env" as a clean 503 with a code so
    // the frontend can show a friendly "indisponible" message instead of
    // the raw stack-trace.
    if (err.message && err.message.includes('env var is not configured')) {
      return res.status(503).json({
        error: 'Identity verification is temporarily unavailable. Please try again later.',
        code: 'KYC_NOT_CONFIGURED',
      });
    }
    return res.status(500).json({ error: 'Unable to start KYC verification.', details: err.message });
  }
};

/**
 * GET /kyc/status
 * Returns: { kycStatus, kycPaidAt, kycVerifiedAt, kycRejectionReason }
 */
const getStatus = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const role = (req.user.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model) return res.status(403).json({ error: 'Only sitter or walker.' });
    const user = await Model.findById(req.user.id).lean();
    if (!user) return res.status(404).json({ error: 'User not found.' });

    return res.json({
      kycStatus: user.kycStatus || 'none',
      kycPaidAt: user.kycPaidAt || null,
      kycVerifiedAt: user.kycVerifiedAt || null,
      kycRejectionReason: user.kycRejectionReason || null,
      isVerified: user.kycStatus === 'verified',
      price: KYC_PRICE_EUR,
      currency: 'EUR',
    });
  } catch (err) {
    logger.error('[kyc.getStatus]', err);
    return res.status(500).json({ error: 'Unable to fetch KYC status.' });
  }
};

/**
 * v23.1 part 75 — POST /kyc/confirm-payment
 * Body: {} (auth, sitter/walker)
 * Returns: { kycStatus, kycPaidAt }
 *
 * Daniel : "sa as debiter et sa menvoi pas a la verification id". The
 * Airwallex webhook is unreliable in some setups (signature mismatch,
 * URL not yet configured, transient 5xx). This endpoint lets the
 * frontend force-confirm the KYC payment after the payment WebView
 * closes with success — we re-fetch the PI from Airwallex to verify
 * status, and if SUCCEEDED we run the same activation logic the
 * webhook would have. Fully idempotent : safe to call from both the
 * webhook AND the frontend without double-effects.
 */
const confirmPayment = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const role = (req.user.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model) return res.status(403).json({ error: 'Only sitter or walker.' });
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    // Already verified or in flight → just return current status (idempotent).
    if (user.kycStatus === 'verified' || user.kycStatus === 'pending_verification') {
      return res.json({
        kycStatus: user.kycStatus,
        kycPaidAt: user.kycPaidAt || null,
        alreadyConfirmed: true,
      });
    }

    const piId = user.kycPaymentIntentId;
    if (!piId) {
      return res.status(400).json({
        error: 'No KYC payment intent recorded. Call /kyc/initiate-payment first.',
        kycStatus: user.kycStatus || 'none',
      });
    }

    let pi;
    try {
      pi = await airwallex.retrievePaymentIntent(piId);
    } catch (e) {
      logger.error(`[kyc.confirmPayment] Airwallex retrieve failed for ${piId} : ${e.message}`);
      return res.status(502).json({ error: 'Unable to verify payment with Airwallex.' });
    }

    const status = (pi?.status || '').toUpperCase();
    if (status !== 'SUCCEEDED') {
      return res.status(409).json({
        error: `Payment not yet succeeded (status=${status}).`,
        kycStatus: user.kycStatus || 'none',
        airwallexStatus: status,
      });
    }

    // Run the same logic as the webhook handler.
    await onKycPaymentSucceeded(pi);

    // Reload to return fresh status.
    const fresh = await Model.findById(req.user.id).lean();
    return res.json({
      kycStatus: fresh?.kycStatus || 'pending_verification',
      kycPaidAt: fresh?.kycPaidAt || null,
      forced: true,
    });
  } catch (err) {
    logger.error('[kyc.confirmPayment]', err);
    return res.status(500).json({ error: 'Unable to confirm KYC payment.', details: err.message });
  }
};

/**
 * Internal helper: called by airwallexWebhookController when a KYC payment
 * succeeds (metadata.type === 'kyc'). Marks user kycStatus='pending_verification'
 * + kycPaidAt = now. Frontend must then POST /kyc/start to launch the inquiry.
 */
const onKycPaymentSucceeded = async (paymentIntent) => {
  try {
    const userId = paymentIntent?.metadata?.userId;
    const role = (paymentIntent?.metadata?.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model || !userId) {
      logger.warn(`[kyc.onPaymentSucceeded] missing userId or role in PI metadata`);
      return;
    }
    const user = await Model.findById(userId);
    if (!user) return;
    if (user.kycStatus === 'verified') return; // idempotent
    user.kycStatus = 'pending_verification';
    user.kycPaidAt = new Date();
    user.kycPaymentIntentId = paymentIntent.id;
    await user.save();
    logger.info(`✅ [kyc.onPaymentSucceeded] ${role} ${userId} → pending_verification`);

    // Notif user : "Paiement confirmé, complète maintenant ta vérification"
    try {
      const { sendNotification } = require('../services/notificationSender');
      sendNotification({
        userId: userId.toString(),
        role,
        type: 'kyc_payment_succeeded',
        data: { kycStatus: 'pending_verification' },
        actor: { role: 'system', id: null },
      }).catch(() => {});
    } catch (_) { /* noop */ }
  } catch (e) {
    logger.error(`[kyc.onPaymentSucceeded] ${e.message}`);
  }
};

/**
 * POST /webhooks/persona
 * Reçoit inquiry.completed / approved / declined / failed events de Persona.
 * Met à jour User.kycStatus et envoie notif.
 *
 * IMPORTANT : ce route doit utiliser express.raw() pour preserver le rawBody
 * et permettre la signature HMAC verify.
 */
const personaWebhook = async (req, res) => {
  try {
    const rawBody = req.rawBody || (req.body instanceof Buffer ? req.body.toString('utf8') : JSON.stringify(req.body));
    const signature = req.headers['persona-signature'];
    if (!persona.verifyWebhookSignature(rawBody, signature)) {
      logger.warn(`[persona.webhook] signature mismatch`);
      return res.status(401).json({ error: 'Invalid signature' });
    }
    const payload = typeof rawBody === 'string' ? JSON.parse(rawBody) : req.body;
    const eventName = payload?.data?.attributes?.name;
    const inquiry = payload?.data?.attributes?.payload?.data;
    const inquiryId = inquiry?.id;
    const inquiryStatus = (inquiry?.attributes?.status || '').toLowerCase();
    const referenceId = inquiry?.attributes?.['reference-id'] || '';
    logger.info(`[persona.webhook] event=${eventName} inquiry=${inquiryId} status=${inquiryStatus} ref=${referenceId}`);

    // Parse reference-id "role_userId"
    const [role, userId] = referenceId.split('_');
    const Model = _modelForRole(role);
    if (!Model || !userId) {
      logger.warn(`[persona.webhook] invalid reference-id ${referenceId}`);
      return res.status(200).json({ ok: true });
    }
    const user = await Model.findById(userId);
    if (!user) return res.status(200).json({ ok: true });
    if (user.kycApplicantId !== inquiryId) {
      logger.warn(`[persona.webhook] inquiry mismatch user=${userId} stored=${user.kycApplicantId} got=${inquiryId}`);
    }

    // Map Persona status → kycStatus
    let newStatus = user.kycStatus;
    let rejectionReason = null;
    if (inquiryStatus === 'approved' || inquiryStatus === 'completed') {
      // Approved or completed (auto-approval): verified
      // Note: Persona returns 'completed' if the inquiry finished and 'approved'
      //       if a Decision rule auto-marked it OK.
      const decisions = inquiry?.relationships?.decisions?.data;
      const declined = Array.isArray(decisions) && decisions.length > 0 &&
        (inquiry?.attributes?.['decision-status'] || '').toLowerCase() === 'declined';
      if (declined) {
        newStatus = 'rejected';
        rejectionReason = 'Document or selfie verification failed.';
      } else {
        newStatus = 'verified';
        user.kycVerifiedAt = new Date();
        user.verified = true; // sync with legacy `verified` field
      }
    } else if (inquiryStatus === 'declined' || inquiryStatus === 'failed') {
      newStatus = 'rejected';
      rejectionReason = 'Verification declined by Persona.';
    } else if (inquiryStatus === 'expired') {
      newStatus = 'rejected';
      rejectionReason = 'Verification link expired.';
    }
    user.kycStatus = newStatus;
    user.kycRejectionReason = rejectionReason;
    await user.save();
    logger.info(`✅ [persona.webhook] ${role} ${userId} → kycStatus=${newStatus}`);

    // Notif user
    try {
      const { sendNotification } = require('../services/notificationSender');
      const notifType = newStatus === 'verified' ? 'kyc_verified' : 'kyc_rejected';
      sendNotification({
        userId: userId.toString(),
        role,
        type: notifType,
        data: { kycStatus: newStatus, reason: rejectionReason },
        actor: { role: 'system', id: null },
      }).catch(() => {});
    } catch (_) { /* noop */ }

    return res.status(200).json({ ok: true });
  } catch (e) {
    logger.error(`[persona.webhook] ${e.message}`);
    return res.status(500).json({ error: 'Webhook processing failed.' });
  }
};

module.exports = {
  initiatePayment,
  startVerification,
  getStatus,
  confirmPayment, // v23.1 part 75 — client-side KYC payment confirmation fallback
  onKycPaymentSucceeded,
  personaWebhook,
};
