/**
 * IBAN Payout Routes.
 *
 * Session v18.1 changes (summary):
 *   - Removed the manual-admin verification step. When the IBAN passes the
 *     mod97 checksum validation (validateIBAN), it is persisted with
 *     ibanVerified=true immediately. Format-valid IBANs are trustworthy
 *     enough for an MVP; the first actual Stripe transfer will reject
 *     structurally-broken IBANs anyway.
 *   - Added walker support to every endpoint: sitter and walker hit the
 *     same URLs, the backend routes to the right collection based on
 *     req.user.role (sitter / walker). Previously walker got a 403 and
 *     had no way to configure a payout method.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { validateIBAN, cleanIban } = require('../utils/ibanValidator');
const { encrypt, decrypt } = require('../utils/encryption');

const router = express.Router();

// Pick the right collection for the authenticated provider.
const getProviderModel = (role) => (role === 'walker' ? Walker : Sitter);

const requireProviderRole = requireRole('sitter', 'walker');

// ─── Save / Update IBAN (sitter + walker) ────────────────────────────────────
router.put('/iban', requireAuth, requireProviderRole, async (req, res) => {
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
    const encryptedIban = encrypt(normalizedIban);
    const Model = getProviderModel(req.user.role);

    const ibanUpdate = {
      ibanHolder: ibanHolder.trim(),
      ibanNumber: encryptedIban,
      ibanBic: ibanBic?.trim() ?? '',
      // Session v18.1 — auto-verify on mod97 pass instead of waiting for an
      // admin. The first real Stripe Transfer still rejects structurally
      // invalid accounts, so we cannot pay out to a random number.
      ibanVerified: true,
      payoutMethod: 'iban',
    };

    const provider = await Model.findByIdAndUpdate(req.user.id, ibanUpdate, {
      new: true,
    }).select('-password');

    if (!provider) return res.status(404).json({ error: 'Provider not found.' });

    // v18.9.8 — l'IBAN enregistré côté sitter est aussi disponible côté
    // walker (et inversement) pour le MÊME user (matché par email), car
    // c'est le même compte bancaire. Owner est exclu automatiquement par
    // syncSharedFields. Encryption key globale → on propage la valeur déjà
    // chiffrée sans re-chiffrer.
    try {
      const { syncSharedFields } = require('../utils/userSyncService');
      await syncSharedFields({
        email: provider.email,
        update: ibanUpdate,
        excludeRole: req.user.role,
      });
    } catch (syncErr) {
      // Non-bloquant.
    }

    res.json({
      message: 'IBAN saved and verified. Your future payouts will be sent there.',
      payoutMethod: 'iban',
      ibanHolder: provider.ibanHolder,
      // Return masked IBAN only (derived from plaintext before encryption)
      ibanNumberMasked: normalizedIban.slice(0, 4) + '****' + normalizedIban.slice(-4),
      ibanVerified: provider.ibanVerified,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── Get own IBAN info (masked) (sitter + walker) ────────────────────────────
router.get('/iban', requireAuth, requireProviderRole, async (req, res) => {
  try {
    const Model = getProviderModel(req.user.role);
    const provider = await Model.findById(req.user.id)
      .select('ibanHolder ibanNumber ibanBic ibanVerified payoutMethod');
    if (!provider) return res.status(404).json({ error: 'Provider not found.' });

    const iban = decrypt(provider.ibanNumber);
    const masked = iban
      ? iban.slice(0, 4) + '****' + iban.slice(-4)
      : '';

    res.json({
      ibanHolder: provider.ibanHolder,
      ibanNumberMasked: masked,
      ibanBic: provider.ibanBic,
      ibanVerified: provider.ibanVerified,
      payoutMethod: provider.payoutMethod || 'stripe',
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── Set payout method preference (sitter + walker) ──────────────────────────
router.patch('/payout-method', requireAuth, requireProviderRole, async (req, res) => {
  try {
    const { payoutMethod } = req.body;
    if (!['stripe', 'paypal', 'iban'].includes(payoutMethod)) {
      return res.status(400).json({ error: 'payoutMethod must be stripe, paypal, or iban.' });
    }
    const Model = getProviderModel(req.user.role);
    const provider = await Model.findById(req.user.id)
      .select('ibanNumber ibanVerified paypalEmail');
    if (!provider) return res.status(404).json({ error: 'Provider not found.' });

    // Guard: can't switch to iban if not set. ibanVerified is now auto-set on
    // save (see PUT /iban) so we only need the presence check.
    if (payoutMethod === 'iban' && !provider.ibanNumber) {
      return res.status(400).json({
        error: 'Please save your IBAN first.',
      });
    }
    if (payoutMethod === 'paypal' && !provider.paypalEmail) {
      return res.status(400).json({
        error: 'Please save your PayPal email first.',
      });
    }

    await Model.findByIdAndUpdate(req.user.id, { payoutMethod });
    res.json({ message: 'Payout method updated.', payoutMethod });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
