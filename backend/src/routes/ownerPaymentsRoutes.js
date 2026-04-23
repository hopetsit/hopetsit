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
  getPaymentHistory,
} = require('../controllers/ownerPaymentsController');

const router = express.Router();

// v18.9 — walker + sitter peuvent aussi enregistrer une carte (débit
// rapide via Stripe). Avant v18.9, le router n'autorisait que 'owner'
// → 403 "You do not have permission" en cliquant Ajouter carte côté
// provider. Le controller est agnostique du rôle.
router.use(requireAuth, requireRole('owner', 'sitter', 'walker'));

router.get('/methods', getPaymentMethods);
router.post('/setup-intent', createSetupIntent);
router.delete('/methods/:id', deletePaymentMethod);
router.get('/history', getPaymentHistory);

module.exports = router;
