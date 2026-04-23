/**
 * Donations Routes — v18.9.3.
 * Mounted at /donations in app.js.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { createDonationIntent } = require('../controllers/donationController');

const router = express.Router();

router.use(requireAuth, requireRole('owner', 'sitter', 'walker'));
router.post('/create-intent', createDonationIntent);

module.exports = router;
