/**
 * Wallet routes — v19.0.
 *
 * Monté sous /wallet. Tous les endpoints requièrent un user authentifié
 * avec role sitter ou walker (owner n'a pas de wallet : il paye les
 * bookings, il ne les reçoit pas).
 */
const express = require('express');
const { requireAuth, requireRole, requireVerifiedEmail } = require('../middleware/auth');
const {
  getWallet,
  getTransactions,
  requestWithdrawal,
  acceptBillingMandate,
  payShop,
} = require('../controllers/walletController');

const router = express.Router();

router.use(requireAuth, requireRole('sitter', 'walker'));

router.get('/', getWallet);
router.get('/transactions', getTransactions);
router.post('/withdraw', requireVerifiedEmail, requestWithdrawal);
// 616 (FLO) — acceptation explicite du mandat de facturation (idempotente).
router.post('/billing-mandate', acceptBillingMandate);
router.post('/pay-shop', payShop);

module.exports = router;
