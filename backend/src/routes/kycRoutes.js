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
} = require('../controllers/kycController');

const router = express.Router();

// Sitter/walker only — owners n'ont pas besoin de KYC pour l'instant.
router.post('/initiate-payment', requireAuth, requireRole('sitter', 'walker'), initiatePayment);
router.post('/start', requireAuth, requireRole('sitter', 'walker'), startVerification);
router.get('/status', requireAuth, requireRole('sitter', 'walker'), getStatus);

module.exports = router;
