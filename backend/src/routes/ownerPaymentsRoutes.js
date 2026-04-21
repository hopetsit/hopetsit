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

router.use(requireAuth, requireRole('owner'));

router.get('/methods', getPaymentMethods);
router.post('/setup-intent', createSetupIntent);
router.delete('/methods/:id', deletePaymentMethod);
router.get('/history', getPaymentHistory);

module.exports = router;
