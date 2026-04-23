/**
 * walletController — v19.0.
 *
 * Expose les endpoints du portefeuille sitter/walker :
 *   GET  /wallet              → solde + devise
 *   GET  /wallet/transactions → historique paginé
 *   POST /wallet/withdraw     → demande de retrait IBAN/PayPal (pending admin)
 *   POST /wallet/pay-shop     → paye une option shop avec le solde (instant)
 *
 * Les endpoints shop (boost / premium / map-boost / chat-addon) peuvent
 * appeler `payShop` depuis leur contrôleur respectif pour remplacer le
 * Stripe PaymentIntent par un débit wallet instantané si le solde suffit.
 */

const { creditWallet, debitWallet, getBalance } = require('../services/walletService');
const WalletTransaction = require('../models/WalletTransaction');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');

const MIN_WITHDRAWAL = 5.0; // Vinted-style : évite les frais SEPA bas montant.

const _requireProvider = (req, res) => {
  const role = req.user?.role;
  if (role !== 'sitter' && role !== 'walker') {
    res.status(403).json({
      error: 'Wallet is only available for sitters and walkers.',
    });
    return null;
  }
  return role;
};

// ── GET /wallet ────────────────────────────────────────────────────────────
exports.getWallet = async (req, res) => {
  try {
    const role = _requireProvider(req, res);
    if (!role) return;

    const data = await getBalance({ userId: req.user.id, userRole: role });

    // Pending withdrawals count pour afficher "1 retrait en cours" dans l'UI.
    const pendingWithdrawals = await WalletTransaction.countDocuments({
      userId: req.user.id,
      type: 'debit_withdrawal',
      status: 'pending',
    });

    const pendingAmount = await WalletTransaction.aggregate([
      {
        $match: {
          userId: req.user._id || req.user.id,
          type: 'debit_withdrawal',
          status: 'pending',
        },
      },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]);

    res.json({
      balance: data.balance,
      currency: data.currency,
      pendingWithdrawals,
      pendingAmount: pendingAmount[0]?.total || 0,
      minWithdrawal: MIN_WITHDRAWAL,
    });
  } catch (e) {
    logger.error('[wallet.getWallet]', e);
    res.status(500).json({ error: e.message });
  }
};

// ── GET /wallet/transactions ───────────────────────────────────────────────
exports.getTransactions = async (req, res) => {
  try {
    const role = _requireProvider(req, res);
    if (!role) return;

    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [items, total] = await Promise.all([
      WalletTransaction.find({ userId: req.user.id, userRole: role })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('bookingId', 'serviceType startDate')
        .lean(),
      WalletTransaction.countDocuments({ userId: req.user.id, userRole: role }),
    ]);

    res.json({
      transactions: items.map((t) => ({
        id: t._id,
        type: t.type,
        amount: t.amount,
        currency: t.currency,
        status: t.status,
        balanceAfter: t.balanceAfter,
        bookingId: t.bookingId?._id || null,
        serviceType: t.bookingId?.serviceType || '',
        productType: t.productType || '',
        withdrawalMethod: t.withdrawalMethod || '',
        createdAt: t.createdAt,
        completedAt: t.completedAt,
        meta: t.meta || {},
      })),
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (e) {
    logger.error('[wallet.getTransactions]', e);
    res.status(500).json({ error: e.message });
  }
};

// ── POST /wallet/withdraw ──────────────────────────────────────────────────
// Body: { amount: number, method: 'iban'|'paypal' }
// Crée une transaction pending. L'admin exécute le virement et marque payé
// via /admin/iban-payouts/:id/mark-paid (même flow que bookings manuelles).
exports.requestWithdrawal = async (req, res) => {
  try {
    const role = _requireProvider(req, res);
    if (!role) return;

    const amount = Number(req.body?.amount);
    const method = req.body?.method;

    if (!Number.isFinite(amount) || amount < MIN_WITHDRAWAL) {
      return res.status(400).json({
        error: `Minimum withdrawal is ${MIN_WITHDRAWAL} EUR.`,
      });
    }
    if (!['iban', 'paypal'].includes(method)) {
      return res.status(400).json({ error: 'method must be iban or paypal.' });
    }

    // Vérif que le user a bien configuré sa méthode de retrait.
    const Model = role === 'walker' ? Walker : Sitter;
    const user = await Model.findById(req.user.id).select(
      'ibanHolder ibanVerified paypalEmail walletBalance walletCurrency email',
    );
    if (!user) return res.status(404).json({ error: 'User not found.' });

    if (method === 'iban' && (!user.ibanHolder || !user.ibanVerified)) {
      return res.status(400).json({
        error: 'Configure and verify your IBAN before withdrawing.',
        code: 'IBAN_NOT_CONFIGURED',
      });
    }
    if (method === 'paypal' && !user.paypalEmail) {
      return res.status(400).json({
        error: 'Add your PayPal email before withdrawing.',
        code: 'PAYPAL_NOT_CONFIGURED',
      });
    }

    const result = await debitWallet({
      userId: req.user.id,
      userRole: role,
      amount,
      currency: user.walletCurrency || 'EUR',
      type: 'debit_withdrawal',
      withdrawalMethod: method,
      initialStatus: 'pending',
      meta: {
        ibanHolder: method === 'iban' ? user.ibanHolder : undefined,
        paypalEmail: method === 'paypal' ? user.paypalEmail : undefined,
        userEmail: user.email,
      },
    });

    res.json({
      ok: true,
      transactionId: result.transactionId,
      newBalance: result.balance,
      currency: result.currency,
      method,
      message:
        method === 'iban'
          ? 'Withdrawal queued. Funds will hit your IBAN within 3 business days.'
          : 'Withdrawal queued. Funds will hit your PayPal within 1 business day.',
    });
  } catch (e) {
    if (e.code === 'INSUFFICIENT_BALANCE') {
      return res.status(400).json({
        error: 'Insufficient wallet balance.',
        code: 'INSUFFICIENT_BALANCE',
      });
    }
    logger.error('[wallet.requestWithdrawal]', e);
    res.status(500).json({ error: e.message });
  }
};

// ── POST /wallet/pay-shop ──────────────────────────────────────────────────
// Body: { amount, productType: 'boost_bronze'|'premium_monthly'|..., currency }
// Utilisable par les controllers boost/premium/chat-addon si le user veut
// payer avec son solde au lieu de CB. Retourne 400 INSUFFICIENT_BALANCE si
// le solde est trop bas → le frontend bascule sur le flow CB.
exports.payShop = async (req, res) => {
  try {
    const role = _requireProvider(req, res);
    if (!role) return;

    const amount = Number(req.body?.amount);
    const productType = req.body?.productType || 'shop_purchase';
    const currency = (req.body?.currency || 'EUR').toUpperCase();

    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount.' });
    }

    const result = await debitWallet({
      userId: req.user.id,
      userRole: role,
      amount,
      currency,
      type: 'debit_shop',
      productType,
      initialStatus: 'completed',
    });

    res.json({
      ok: true,
      transactionId: result.transactionId,
      newBalance: result.balance,
      currency: result.currency,
    });
  } catch (e) {
    if (e.code === 'INSUFFICIENT_BALANCE') {
      return res.status(400).json({
        error: 'Insufficient wallet balance.',
        code: 'INSUFFICIENT_BALANCE',
      });
    }
    logger.error('[wallet.payShop]', e);
    res.status(500).json({ error: e.message });
  }
};
