/**
 * Identity Verification Routes — session v3.3.
 *
 * Thin wrapper around Stripe Identity. Two pairs of endpoints:
 *
 *   POST /identity-verification/session      → creates a Stripe Identity
 *                                               VerificationSession for the
 *                                               authenticated user (sitter or
 *                                               walker) and returns the
 *                                               client_secret the mobile SDK
 *                                               needs to open the flow.
 *
 *   POST /identity-verification/webhook       → Stripe calls this when the
 *                                               session transitions. Signature
 *                                               is verified and we update the
 *                                               user doc accordingly.
 *
 * The legacy simple-upload endpoints remain (on /sitters and /walkers) so
 * we can switch users over gradually — they're fine as a fallback while the
 * Stripe Identity integration is being rolled out.
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const stripeIdentity = require('../services/stripeIdentityService');
const logger = require('../utils/logger');

const router = express.Router();

// ── POST /identity-verification/session ─────────────────────────────────────
router.post('/session', requireAuth, async (req, res) => {
  try {
    if (!stripeIdentity.isConfigured()) {
      return res.status(503).json({
        error: 'Identity verification service is not configured on the server.',
        code: 'IDENTITY_NOT_CONFIGURED',
      });
    }

    const role = req.user?.role;
    if (!['sitter', 'walker'].includes(role)) {
      return res.status(403).json({ error: 'Only sitters and walkers need identity verification.' });
    }

    const Model = role === 'sitter' ? Sitter : Walker;
    const user = await Model.findById(req.user.id).select('email identityVerification').lean();
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const session = await stripeIdentity.createVerificationSession({
      userId: req.user.id,
      userRole: role,
      email: user.email,
      returnUrl: req.body?.returnUrl,
    });

    // Persist the Stripe session id + status on the user so we can
    // reconcile when the webhook fires.
    await Model.findByIdAndUpdate(req.user.id, {
      $set: {
        'identityVerification.status': 'pending',
        'identityVerification.submittedAt': new Date(),
        'identityVerification.rejectionReason': '',
        'identityVerification.stripeSessionId': session.id,
        'identityVerification.provider': 'stripe_identity',
      },
    });

    res.json({
      sessionId: session.id,
      clientSecret: session.clientSecret,
      url: session.url,
    });
  } catch (e) {
    logger.error('[identity-verification/session]', e);
    if (e.code === 'IDENTITY_NOT_CONFIGURED') {
      return res.status(503).json({ error: e.message, code: e.code });
    }
    res.status(500).json({ error: e.message });
  }
});

// ── POST /identity-verification/webhook ─────────────────────────────────────
// Stripe webhooks — no auth, signature verified below.
//
// Must be mounted BEFORE any JSON body parser (express.raw()) for the
// signature to verify. See app.js for the mount order.
router.post('/webhook', async (req, res) => {
  let event;
  try {
    const signature = req.headers['stripe-signature'];
    event = stripeIdentity.parseWebhookEvent(req.body, signature);
  } catch (e) {
    logger.warn('[identity-webhook] signature check failed', e);
    return res.status(400).send(`Webhook signature error: ${e.message}`);
  }

  try {
    const session = event.data?.object;
    const type = event.type;
    const meta = session?.metadata || {};
    const userId = meta.userId;
    const role = meta.role;
    if (!userId || !role) {
      logger.warn('[identity-webhook] missing metadata', { type });
      return res.json({ received: true, ignored: true });
    }

    const Model = role === 'sitter' ? Sitter : role === 'walker' ? Walker : null;
    if (!Model) return res.json({ received: true, ignored: true });

    // v19.1.3 — harden auto-approval: even when Stripe reports "verified"
    // we require the full verified_outputs (first_name + last_name + dob)
    // to be present. A monkey selfie in test mode doesn't return these
    // fields, so we drop to "pending_review" instead of granting verified.
    let newStatus = null;
    let rejectionReason = '';
    if (type === 'identity.verification_session.verified') {
      const vo = session.verified_outputs || {};
      const hasNames = !!(vo.first_name && vo.last_name);
      const hasDob = !!(vo.dob && (vo.dob.year || vo.dob.month));
      if (hasNames && hasDob) {
        newStatus = 'verified';
      } else {
        // Stripe thinks it's good but our stricter policy requires a fully
        // populated verified_outputs. Route to admin manual review.
        newStatus = 'pending_review';
        rejectionReason = 'Missing full verified_outputs; admin review required.';
        logger.warn('[identity-webhook] verified event without full outputs', {
          userId,
          hasNames,
          hasDob,
        });
      }
    } else if (type === 'identity.verification_session.requires_input') {
      newStatus = 'rejected';
      rejectionReason = session.last_error?.reason || 'Verification failed.';
    } else if (type === 'identity.verification_session.canceled') {
      newStatus = 'rejected';
      rejectionReason = 'Verification canceled.';
    }

    if (newStatus) {
      await Model.findByIdAndUpdate(userId, {
        $set: {
          'identityVerification.status': newStatus,
          'identityVerification.reviewedAt': new Date(),
          'identityVerification.rejectionReason': rejectionReason,
          // Convenience top-level flag used by many existing queries.
          // Only flip to true when verified AND verified_outputs passed
          // our stricter policy (see hardening block above).
          verified: newStatus === 'verified',
        },
      });
      logger.info(`[identity-webhook] ${role} ${userId} → ${newStatus}`);
    }
    res.json({ received: true });
  } catch (e) {
    logger.error('[identity-webhook] handler error', e);
    res.status(500).json({ received: true, error: e.message });
  }
});

module.exports = router;
