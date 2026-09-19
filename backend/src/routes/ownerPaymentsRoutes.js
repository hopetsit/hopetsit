/**
 * Owner Payments Routes — Session v18.2.
 * Mounted at /owner/payments in app.js.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const {
  getPaymentMethods,
  createSetupIntent,
  deletePaymentMethod,
  setDefaultPaymentMethod,
  getPaymentHistory,
  attachPaymentMethod,
  verifyCard,
} = require('../controllers/ownerPaymentsController');

const router = express.Router();

// v18.9 — walker + sitter peuvent aussi enregistrer une carte (débit
// rapide via Stripe). Avant v18.9, le router n'autorisait que 'owner'
// → 403 "You do not have permission" en cliquant Ajouter carte côté
// provider. Le controller est agnostique du rôle.
router.use(requireAuth, requireRole('owner', 'sitter', 'walker'));

router.get('/methods', getPaymentMethods);
router.post('/methods/attach', attachPaymentMethod); // v20.0.3
router.post('/methods/verify-card', verifyCard); // v23.1 — Add card flow without booking
router.post('/setup-intent', createSetupIntent);
// v568 — carte par défaut (présentée en premier au paiement). Déclarée AVANT
// la route DELETE générique pour rester lisible ; Express distingue de toute
// façon les méthodes.
router.post('/methods/:id/default', setDefaultPaymentMethod);
router.delete('/methods/:id', deletePaymentMethod);
router.get('/history', getPaymentHistory);

module.exports = router;
