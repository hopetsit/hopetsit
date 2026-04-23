/**
 * Wallet routes — v19.0.
 *
 * Monté sous /wallet. Tous les endpoints requièrent un user authentifié
 * avec role sitter ou walker (owner n'a pas de wallet : il paye les
 * bookings, il ne les reçoit pas).
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const {
  getWallet,
  getTransactions,
  requestWithdrawal,
  payShop,
} = require('../controllers/walletController');

const router = express.Router();

router.use(requireAuth, requireRole('sitter', 'walker'));

router.get('/', getWallet);
router.get('/transactions', getTransactions);
router.post('/withdraw', requestWithdrawal);
router.post('/pay-shop', payShop);

module.exports = router;
