/**
 * walletService — v19.0.
 *
 * API unique pour crediter/debiter le wallet d'un provider (sitter ou walker)
 * de manière atomique et auditée.
 *
 *   creditWallet()  → crédite le wallet + insère une WalletTransaction.
 *   debitWallet()   → débite le wallet + insère une WalletTransaction
 *                     (échoue si solde insuffisant).
 *   getBalance()    → lecture directe du cache.
 *
 * Toutes les écritures passent par `findOneAndUpdate` avec `$inc` pour
 * garantir l'atomicité sous concurrence (ex: 2 webhooks Stripe simultanés).
 */

const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const WalletTransaction = require('../models/WalletTransaction');
const logger = require('../utils/logger');

const _roleModel = (role) =>
  role === 'walker' ? Walker : role === 'sitter' ? Sitter : null;

/**
 * Crédite le wallet du provider et insère une WalletTransaction correspondante.
 * Atomique grâce à `findOneAndUpdate` + $inc.
 *
 * @param {object} opts
 * @param {string} opts.userId
 * @param {'sitter'|'walker'} opts.userRole
 * @param {number} opts.amount - Toujours positif. Ex: 10.00 pour créditer 10 €.
 * @param {string} [opts.currency='EUR']
 * @param {string} opts.type - 'credit_booking' | 'refund' | 'admin_adjustment'
 * @param {string} [opts.bookingId]
 * @param {string} [opts.referenceId]
 * @param {object} [opts.meta]
 * @returns {Promise<{success:boolean, balance:number, transactionId:string}>}
 */
async function creditWallet({
  userId,
  userRole,
  amount,
  currency = 'EUR',
  type = 'credit_booking',
  bookingId = null,
  referenceId = '',
  meta = {},
}) {
  if (!userId || !userRole || !amount || amount <= 0) {
    throw new Error('walletService.creditWallet: invalid args');
  }
  const Model = _roleModel(userRole);
  if (!Model) {
    throw new Error(`walletService: unknown userRole "${userRole}"`);
  }

  const rounded = Math.round(amount * 100) / 100;

  // Atomique : $inc + returnDocument=after pour lire le nouveau solde.
  const updated = await Model.findByIdAndUpdate(
    userId,
    { $inc: { walletBalance: rounded }, $set: { walletCurrency: currency } },
    { new: true },
  ).select('walletBalance walletCurrency email');

  if (!updated) {
    throw new Error(`walletService.creditWallet: user not found (${userRole}:${userId})`);
  }

  const tx = await WalletTransaction.create({
    userId,
    userRole,
    type,
    amount: rounded,
    currency,
    bookingId: bookingId || null,
    referenceId,
    status: 'completed',
    balanceAfter: updated.walletBalance,
    completedAt: new Date(),
    meta,
  });

  logger.info(
    `💰 Wallet +${rounded} ${currency} → ${userRole}:${userId} (new balance: ${updated.walletBalance}) type=${type}`,
  );

  return {
    success: true,
    balance: updated.walletBalance,
    currency: updated.walletCurrency,
    transactionId: tx._id.toString(),
  };
}

/**
 * Débite le wallet (pour retrait ou paiement shop). Échoue si solde < amount.
 * `status` démarre à 'pending' pour un retrait (admin doit exécuter le SEPA),
 * directement 'completed' pour un paiement shop (instantané).
 *
 * @param {object} opts
 * @param {string} opts.userId
 * @param {'sitter'|'walker'} opts.userRole
 * @param {number} opts.amount - Positif. Ex: 4.99.
 * @param {string} [opts.currency='EUR']
 * @param {string} opts.type - 'debit_withdrawal' | 'debit_shop'
 * @param {'iban'|'paypal'} [opts.withdrawalMethod]
 * @param {string} [opts.productType]
 * @param {string} [opts.bookingId]
 * @param {'pending'|'completed'} [opts.initialStatus='completed']
 * @param {object} [opts.meta]
 * @returns {Promise<{success:boolean, balance:number, transactionId:string}>}
 */
async function debitWallet({
  userId,
  userRole,
  amount,
  currency = 'EUR',
  type,
  withdrawalMethod = '',
  productType = '',
  bookingId = null,
  initialStatus = 'completed',
  meta = {},
}) {
  if (!userId || !userRole || !amount || amount <= 0 || !type) {
    throw new Error('walletService.debitWallet: invalid args');
  }
  const Model = _roleModel(userRole);
  if (!Model) {
    throw new Error(`walletService: unknown userRole "${userRole}"`);
  }

  const rounded = Math.round(amount * 100) / 100;

  // Atomique avec garde "solde suffisant" via $expr.
  //   1) Vérifie que walletBalance >= amount.
  //   2) Si OK, décrémente.
  //   Si KO, findOneAndUpdate renvoie null → on lève insufficient_balance.
  const updated = await Model.findOneAndUpdate(
    {
      _id: userId,
      $expr: { $gte: ['$walletBalance', rounded] },
    },
    { $inc: { walletBalance: -rounded } },
    { new: true },
  ).select('walletBalance walletCurrency email');

  if (!updated) {
    const err = new Error('Insufficient wallet balance');
    err.code = 'INSUFFICIENT_BALANCE';
    throw err;
  }

  const tx = await WalletTransaction.create({
    userId,
    userRole,
    type,
    amount: rounded,
    currency,
    bookingId: bookingId || null,
    productType,
    withdrawalMethod,
    status: initialStatus,
    balanceAfter: updated.walletBalance,
    completedAt: initialStatus === 'completed' ? new Date() : null,
    meta,
  });

  logger.info(
    `💸 Wallet -${rounded} ${currency} ← ${userRole}:${userId} (new balance: ${updated.walletBalance}) type=${type} status=${initialStatus}`,
  );

  return {
    success: true,
    balance: updated.walletBalance,
    currency: updated.walletCurrency,
    transactionId: tx._id.toString(),
  };
}

async function getBalance({ userId, userRole }) {
  const Model = _roleModel(userRole);
  if (!Model) return { balance: 0, currency: 'EUR' };
  const doc = await Model.findById(userId).select('walletBalance walletCurrency');
  if (!doc) return { balance: 0, currency: 'EUR' };
  return {
    balance: doc.walletBalance || 0,
    currency: doc.walletCurrency || 'EUR',
  };
}

module.exports = {
  creditWallet,
  debitWallet,
  getBalance,
};
