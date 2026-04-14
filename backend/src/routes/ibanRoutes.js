/**
 * IBAN Payout Routes — Like Vinted
 * Sitters save their IBAN; admin verifies; platform triggers bank transfer on payout
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const Sitter = require('../models/Sitter');
const { validateIBAN, cleanIban } = require('../utils/ibanValidator');

const router = express.Router();

// ─── SITTER: Save / Update IBAN ───────────────────────────────────────────────
router.put('/iban', requireAuth, requireRole('sitter'), async (req, res) => {
  try {
    const { ibanHolder, ibanNumber, ibanBic } = req.body;

    if (!ibanHolder || !ibanHolder.trim()) {
      return res.status(400).json({ error: 'Account holder name is required.' });
    }
    const result = validateIBAN(ibanNumber);
    if (!result.valid) {
      return res.status(400).json({
        error: 'Invalid IBAN.',
        reason: result.reason,
        country: result.country,
      });
    }

    const normalizedIban = cleanIban(ibanNumber);

    const sitter = await Sitter.findByIdAndUpdate(
      req.user.id,
      {
        ibanHolder: ibanHolder.trim(),
        ibanNumber: normalizedIban,
        ibanBic: ibanBic?.trim() ?? '',
        ibanVerified: false, // Reset verification when IBAN changes
        payoutMethod: 'iban',
      },
      { new: true }
    ).select('-password');

    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });

    res.json({
      message: 'IBAN saved successfully. It will be verified before your first payout.',
      payoutMethod: 'iban',
      ibanHolder: sitter.ibanHolder,
      // Return masked IBAN only
      ibanNumberMasked: normalizedIban.slice(0, 4) + '****' + normalizedIban.slice(-4),
      ibanVerified: sitter.ibanVerified,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── SITTER: Get own IBAN info (masked) ───────────────────────────────────────
router.get('/iban', requireAuth, requireRole('sitter'), async (req, res) => {
  try {
    const sitter = await Sitter.findById(req.user.id)
      .select('ibanHolder ibanNumber ibanBic ibanVerified payoutMethod');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });

    const masked = sitter.ibanNumber
      ? sitter.ibanNumber.slice(0, 4) + '****' + sitter.ibanNumber.slice(-4)
      : '';

    res.json({
      ibanHolder: sitter.ibanHolder,
      ibanNumberMasked: masked,
      ibanBic: sitter.ibanBic,
      ibanVerified: sitter.ibanVerified,
      payoutMethod: sitter.payoutMethod || 'stripe',
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── SITTER: Set payout method preference ────────────────────────────────────
router.patch('/payout-method', requireAuth, requireRole('sitter'), async (req, res) => {
  try {
    const { payoutMethod } = req.body;
    if (!['stripe', 'paypal', 'iban'].includes(payoutMethod)) {
      return res.status(400).json({ error: 'payoutMethod must be stripe, paypal, or iban.' });
    }
    const sitter = await Sitter.findById(req.user.id).select('ibanNumber ibanVerified paypalEmail');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });

    // Guard: can't switch to iban if not set/verified
    if (payoutMethod === 'iban' && (!sitter.ibanNumber || !sitter.ibanVerified)) {
      return res.status(400).json({
        error: 'Please save your IBAN first and wait for admin verification.',
      });
    }

    await Sitter.findByIdAndUpdate(req.user.id, { payoutMethod });
    res.json({ message: 'Payout method updated.', payoutMethod });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
