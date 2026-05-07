/**
 * KYC Routes — v23.1 part 36
 * Mounted at /api/v1/kyc in app.js.
 *
 * Webhook routes are mounted separately at /webhooks/persona via app.js
 * because they need express.raw() instead of express.json() for the
 * signature verification.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const {
  initiatePayment,
  startVerification,
  getStatus,
  confirmPayment, // v23.1 part 75
} = require('../controllers/kycController');

const router = express.Router();

// Sitter/walker only — owners n'ont pas besoin de KYC pour l'instant.
router.post('/initiate-payment', requireAuth, requireRole('sitter', 'walker'), initiatePayment);
router.post('/start', requireAuth, requireRole('sitter', 'walker'), startVerification);
router.get('/status', requireAuth, requireRole('sitter', 'walker'), getStatus);

// v23.1 part 75 — Daniel : "sa as debiter et sa menvoi pas a la
// verification id". Fallback client-driven confirm in case the
// Airwallex webhook hasn't reached us yet (or is misconfigured).
// The frontend calls this right after the payment WebView closes
// with success ; we re-verify the PI status against Airwallex and
// flip kycStatus to pending_verification if SUCCEEDED. Idempotent.
router.post('/confirm-payment', requireAuth, requireRole('sitter', 'walker'), confirmPayment);

module.exports = router;
