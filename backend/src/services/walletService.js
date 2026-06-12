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
  // v23.1 part 81 — Daniel : "walker et sitter sont independent avec
  // leur iban comment fait til pour retirer leur argent". When auto-
  // payout to IBAN already succeeded (createPayout returned ok), the
  // money is already moving to the walker's bank. We still want to
  // record a WalletTransaction for the in-app earnings history, but
  // we must NOT increment walletBalance — otherwise the walker could
  // withdraw the same amount a second time = double pay.
  //
  // withdrawable=true (default) : balance += amount, walker can later
  //                                request a withdrawal.
  // withdrawable=false           : transaction logged only, balance
  //                                untouched. Used when an IBAN payout
  //                                already shipped the money.
  withdrawable = true,
}) {
  if (!userId || !userRole || !amount || amount <= 0) {
    throw new Error('walletService.creditWallet: invalid args');
  }
  const Model = _roleModel(userRole);
  if (!Model) {
    throw new Error(`walletService: unknown userRole "${userRole}"`);
  }

  // v23.1 part 47 — idempotency on (bookingId, type) so we can call this
  // function from multiple places (webhook payment_intent.succeeded,
  // confirmBookingPayment sync fallback, processProviderPayoutForBooking
  // success path) without double-crediting. Without this, a single paid
  // booking could end up crediting the provider's wallet twice : once
  // when payment was confirmed, once again when the SEPA payout settled.
  // v23.1.270 — Daniel : "j'ai fini un service et 0€ dans mon wallet". La
  // dedup ignorait le flag `withdrawable` : une ligne d'HISTORIQUE
  // (withdrawable=false, n'incrémente PAS le solde) bloquait ensuite le VRAI
  // crédit (withdrawable=true) → solde figé à 0 alors que l'historique montre
  // le paiement. On ne dédup QUE contre un crédit qui a réellement incrémenté
  // le solde (withdrawable=true), et seulement quand on s'apprête à créditer.
  if (bookingId && type === 'credit_booking' && withdrawable) {
    const existing = await WalletTransaction.findOne({
      userId,
      bookingId,
      type,
      status: { $in: ['completed', 'pending'] },
      'meta.withdrawable': true,
    }).lean();
    if (existing) {
      logger.info(
        `💰 Wallet credit skipped (already credited) booking=${bookingId} ${userRole}:${userId} tx=${existing._id}`,
      );
      return {
        success: true,
        balance: undefined,
        currency,
        transactionId: existing._id.toString(),
        deduplicated: true,
      };
    }
  }

  const rounded = Math.round(amount * 100) / 100;

  // Atomique : $inc + returnDocument=after pour lire le nouveau solde.
  // v23.1 part 81 — when withdrawable=false the IBAN payout already moved
  // the money so we don't increment balance. We still want walletCurrency
  // synced to provide UI defaults.
  const updated = withdrawable
    ? await Model.findByIdAndUpdate(
        userId,
        { $inc: { walletBalance: rounded }, $set: { walletCurrency: currency } },
        { new: true },
      ).select('walletBalance walletCurrency email')
    : await Model.findByIdAndUpdate(
        userId,
        { $set: { walletCurrency: currency } },
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
    meta: { ...meta, withdrawable },
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

/**
 * v23.1 part 78 — Daniel : "jai fais des payout sur walker cest toujour
 * en attente le statut ne bouge pas argent pas recu".
 *
 * Auto-process pending wallet withdrawals via Airwallex Payout API. Run
 * every tick of the existing payoutScheduler. For each pending
 * `debit_withdrawal` transaction :
 *   1. Re-validate that the user still has IBAN configured + Airwallex
 *      beneficiary id
 *   2. Call airwallex.createPayout to actually move the money to the
 *      walker / sitter's bank
 *   3. Flip the transaction to status='processing' with the Airwallex
 *      payout id stored in referenceId
 *   4. Booking webhook (payout.status update) will later flip it to
 *      'completed'.
 *
 * If beneficiaryId is missing → leave as pending so the admin can
 * resolve manually (or the IBAN-save flow auto-creates it later).
 * Errors are non-fatal — kept pending for retry.
 */
// v23.1.384 — état de débogage du traitement des retraits, exposé via
// POST /admin/withdrawals/process-now : Daniel n'a pas accès aux logs
// Render, donc la trace pas-à-pas doit être lisible depuis l'admin.
let _wdDebug = {
  lastRunAt: null,
  lastSchedulerRunAt: null, // null = le scheduler n'a JAMAIS tourné depuis le boot
  source: null,
  found: 0,
  released: 0,
  trace: [],
};

async function processPendingWithdrawals(source = 'scheduler') {
  let released = 0;
  let found = 0;
  const trace = [];
  // v23.1.383 — chaque failureReason est HORODATÉE : impossible jusqu'ici de
  // distinguer une erreur fraîche (le tick vient de réessayer) d'une erreur
  // fossile (écrite avant un correctif) — Daniel voyait "toujours pareil".
  const stamp = () => new Date().toLocaleString('fr-FR', {
    timeZone: 'Europe/Madrid',
    day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
  });
  try {
    const airwallex = require('./airwallexService');
    const items = await WalletTransaction.find({
      type: 'debit_withdrawal',
      status: 'pending',
      withdrawalMethod: 'iban', // PayPal payouts go through a separate flow
    })
      .sort({ createdAt: 1 })
      .limit(50)
      .lean();
    found = items.length;

    for (const tx of items) {
      const txRef = `${String(tx._id).slice(-8)} · ${tx.amount}€ · ${tx.userRole || '?'}`;
      try {
        const Model = _roleModel(tx.userRole);
        if (!Model) {
          trace.push(`${txRef} → rôle inconnu "${tx.userRole}" — ignoré`);
          continue;
        }
        const user = await Model.findById(tx.userId).select(
          'airwallexBeneficiaryId ibanVerified ibanHolder ibanNumber ibanBic name email address location',
        );
        if (!user) {
          logger.warn(`[wallet.processPendingWithdrawals] user not found ${tx.userId}`);
          trace.push(`${txRef} → utilisateur ${tx.userId} introuvable en base — ignoré`);
          continue;
        }
        if (!user.airwallexBeneficiaryId) {
          // v23.1.378 — Daniel : "tous les retraits sont pending depuis
          // 3 jours". CAUSE : le bénéficiaire Airwallex n'est créé QU'À
          // l'enregistrement de l'IBAN ; si cet appel a échoué ce jour-là,
          // AUCUNE relance n'existait → retraits pending éternels.
          // AUTO-RÉPARATION : si l'IBAN est enregistré, on (re)crée le
          // bénéficiaire ICI, puis le retrait part dans le MÊME tick.
          // v23.1.384 — les cas "IBAN absent / titulaire manquant / IBAN
          // indéchiffrable" étaient SILENCIEUX (aucune écriture) : le retrait
          // restait pending en affichant une erreur périmée. Chaque sortie
          // écrit désormais une failureReason horodatée + une ligne de trace.
          if (!user.ibanNumber) {
            await WalletTransaction.updateOne(
              { _id: tx._id },
              { $set: { failureReason: `[${stamp()}] IBAN non configuré par le prestataire — retrait en attente.` } },
            );
            trace.push(`${txRef} → IBAN absent du profil — pending`);
            continue;
          }
          if (!user.ibanHolder) {
            await WalletTransaction.updateOne(
              { _id: tx._id },
              { $set: { failureReason: `[${stamp()}] Titulaire IBAN manquant — le prestataire doit re-sauvegarder son IBAN.` } },
            );
            trace.push(`${txRef} → titulaire IBAN manquant — pending`);
            continue;
          }
          let healed = false;
          try {
            const { decrypt } = require('../utils/encryption');
            const plainIban = decrypt(user.ibanNumber);
            if (!plainIban) {
              await WalletTransaction.updateOne(
                { _id: tx._id },
                { $set: { failureReason: `[${stamp()}] IBAN illisible (déchiffrement) — le prestataire doit re-sauvegarder son IBAN.` } },
              );
              trace.push(`${txRef} → IBAN indéchiffrable — pending`);
              continue;
            }
            const ben = await airwallex.createBeneficiary({
              providerId: String(user._id),
              holderName: user.ibanHolder,
              iban: plainIban,
              bic: user.ibanBic || undefined,
              currency: tx.currency || 'EUR',
              // v23.1.380 — adresse profil (exigée par Airwallex).
              addressLine: user.address || '',
              addressCity: (user.location && user.location.city) || '',
            });
            if (ben && ben.id) {
              user.airwallexBeneficiaryId = ben.id;
              // v23.1.383 — Airwallex vient d'ACCEPTER l'IBAN (validation
              // la plus forte possible) : on lève aussi ibanVerified pour
              // les comptes enregistrés avant l'auto-vérification v18.1,
              // sinon le gate ci-dessous les laissait pending en silence.
              user.ibanVerified = true;
              await Model.updateOne(
                { _id: user._id },
                { $set: { airwallexBeneficiaryId: ben.id, ibanVerified: true } },
              );
              healed = true;
              trace.push(`${txRef} → bénéficiaire ${ben.id} auto-créé ✅`);
              logger.info(
                `✅ [wallet.processPendingWithdrawals] beneficiary ${ben.id} ` +
                `auto-créé pour ${tx.userRole} ${tx.userId} (self-heal).`,
              );
            } else {
              trace.push(`${txRef} → création bénéficiaire : réponse sans id — pending`);
            }
          } catch (healErr) {
            logger.warn(
              `[wallet.processPendingWithdrawals] self-heal beneficiary failed ` +
              `for ${tx.userId}: ${healErr?.message || healErr}`,
            );
            // Trace visible dans l'admin (table Retraits wallet).
            // v23.1.383 — horodaté + tronqué plus large (le message inclut
            // désormais l'adresse envoyée pour diagnostiquer les 400).
            await WalletTransaction.updateOne(
              { _id: tx._id },
              { $set: { failureReason: `[${stamp()}] Création bénéficiaire Airwallex : ${(healErr?.message || String(healErr)).slice(0, 320)}` } },
            );
            trace.push(`${txRef} → création bénéficiaire ÉCHEC : ${(healErr?.message || String(healErr)).slice(0, 220)}`);
          }
          if (!healed) {
            logger.info(
              `[wallet.processPendingWithdrawals] tx ${tx._id} user ${tx.userId} ` +
              `has no Airwallex beneficiary yet — keeping pending for next tick.`,
            );
            continue;
          }
        }
        if (!user.ibanVerified) {
          // v23.1.383 — ce blocage était INVISIBLE dans l'admin : le retrait
          // restait pending en affichant la dernière erreur (périmée).
          await WalletTransaction.updateOne(
            { _id: tx._id },
            { $set: { failureReason: `[${stamp()}] IBAN non vérifié — retrait en attente de vérification.` } },
          );
          logger.info(
            `[wallet.processPendingWithdrawals] tx ${tx._id} user ${tx.userId} ` +
            `IBAN not yet verified — keeping pending.`,
          );
          trace.push(`${txRef} → IBAN non vérifié — pending`);
          continue;
        }

        // Mark as processing BEFORE the API call so concurrent ticks
        // can't double-pay.
        const claimed = await WalletTransaction.findOneAndUpdate(
          { _id: tx._id, status: 'pending' },
          { $set: { status: 'processing', processingStartedAt: new Date() } },
          { new: true },
        );
        if (!claimed) {
          trace.push(`${txRef} → déjà réclamé par un autre tick — ignoré`);
          continue;
        }

        try {
          const amountInCents = Math.round(tx.amount * 100);
          const payout = await airwallex.createPayout({
            beneficiaryId: user.airwallexBeneficiaryId,
            amount: amountInCents,
            currency: tx.currency || 'EUR',
            reference: `Wallet WD ${String(tx._id).slice(-8)}`,
            metadata: {
              type: 'wallet_withdrawal',
              transactionId: String(tx._id),
              userId: String(tx.userId),
              userRole: tx.userRole,
            },
          });
          claimed.referenceId = payout?.id || claimed.referenceId;
          // v23.1.382 — succès : on EFFACE l'ancienne raison d'échec (sinon
          // l'admin continue d'afficher la vieille erreur à côté d'un
          // statut completed — confusion Daniel).
          claimed.failureReason = '';
          // Airwallex returns status PENDING → flip to processing
          // confirmed. Webhook later confirms COMPLETED.
          await claimed.save();
          logger.info(
            `[wallet.processPendingWithdrawals] tx ${tx._id} → Airwallex payout ` +
            `${payout?.id} (${tx.amount} ${tx.currency} to ${tx.userRole} ${tx.userId}).`,
          );
          // v23.1 part 82 — notify the user their withdrawal is being
          // sent to their bank. A 2nd "completed" notif fires from the
          // webhook once the bank confirms.
          try {
            const { sendNotification } = require('./notificationSender');
            await sendNotification({
              userId: String(tx.userId),
              role: tx.userRole,
              type: 'withdrawal_initiated',
              data: {
                transactionId: String(tx._id),
                amount: String(tx.amount),
                currency: (tx.currency || 'EUR').toUpperCase(),
              },
              actor: { role: 'system', id: null },
            });
          } catch (_) { /* non-critical */ }
          released += 1;
          trace.push(`${txRef} → virement Airwallex ${payout?.id || '?'} créé ✅`);
        } catch (apiErr) {
          // Roll back to pending so a later tick can retry.
          claimed.status = 'pending';
          claimed.processingStartedAt = null;
          // v23.1.383 — l'échec du VIREMENT (transfers/create) n'était jamais
          // écrit : l'admin continuait d'afficher l'ancienne erreur de
          // création de bénéficiaire alors que celle-ci était résolue.
          claimed.failureReason =
            `[${stamp()}] Virement Airwallex : ${(apiErr?.message || String(apiErr)).slice(0, 320)}`;
          await claimed.save();
          trace.push(`${txRef} → virement ÉCHEC : ${(apiErr?.message || String(apiErr)).slice(0, 220)}`);
          logger.error(
            `[wallet.processPendingWithdrawals] Airwallex payout failed for tx ` +
            `${tx._id} : ${apiErr.message}`,
          );
        }
      } catch (e) {
        trace.push(`${txRef} → ERREUR inattendue : ${(e?.message || String(e)).slice(0, 220)}`);
        logger.error(
          `[wallet.processPendingWithdrawals] error on tx ${tx._id} : ${e.message}`,
        );
      }
    }
  } catch (e) {
    trace.push(`ERREUR GLOBALE : ${(e?.message || String(e)).slice(0, 220)}`);
    logger.error('[wallet.processPendingWithdrawals] outer error', e);
  }
  if (released > 0) {
    logger.info(`💸 [wallet.processPendingWithdrawals] released ${released} withdrawal(s).`);
  }
  // v23.1.384 — instantané du run pour POST /admin/withdrawals/process-now.
  _wdDebug = {
    lastRunAt: new Date(),
    lastSchedulerRunAt:
      source === 'scheduler' ? new Date() : _wdDebug.lastSchedulerRunAt,
    source,
    found,
    released,
    trace,
  };
  return _wdDebug;
}

/**
 * v23.1 part 84 — pay-from-wallet for boutique purchases.
 *
 * Daniel : "soit il l'utilise pour la boutique soit il le retire". When
 * a walker / sitter wants to buy a Boost / PawSpot / Chat-Addon / KYC
 * with their accumulated earnings instead of a credit card, the boutique
 * route flips a `payWithWallet=true` flag and calls this helper :
 *
 *   1. Atomically debit the wallet by `amount`.
 *   2. Create a WalletTransaction tagged with the purchase metadata.
 *   3. Return { transactionId, balance } for the route to record on the
 *      user's purchase entry (so it can be reconciled with the activation
 *      side-effects).
 *
 * Throws { code: 'INSUFFICIENT_BALANCE' } if balance < amount — the
 * route catches this and falls back to "ouvre la HPP carte" UX.
 *
 * Idempotency : the caller is responsible for not double-charging
 * (e.g. by checking they haven't already activated for this purchaseId).
 * This helper itself doesn't dedup.
 */
async function payFromWallet({
  userId,
  userRole,
  amount,
  currency = 'EUR',
  type = 'debit_purchase',
  reference = '',
  meta = {},
}) {
  if (!userId || !userRole || !Number.isFinite(amount) || amount <= 0) {
    throw new Error('walletService.payFromWallet: invalid args');
  }
  const Model = _roleModel(userRole);
  if (!Model) {
    throw new Error(`walletService: unknown userRole "${userRole}"`);
  }
  const rounded = Math.round(amount * 100) / 100;

  // CAS atomic debit : decrement only if balance >= rounded.
  const updated = await Model.findOneAndUpdate(
    { _id: userId, walletBalance: { $gte: rounded } },
    {
      $inc: { walletBalance: -rounded },
      $set: { walletCurrency: currency },
    },
    { new: true },
  ).select('walletBalance walletCurrency email');

  if (!updated) {
    const err = new Error('Insufficient wallet balance.');
    err.code = 'INSUFFICIENT_BALANCE';
    throw err;
  }

  const tx = await WalletTransaction.create({
    userId,
    userRole,
    type,
    amount: rounded,
    currency,
    referenceId: reference || '',
    status: 'completed',
    balanceAfter: updated.walletBalance,
    completedAt: new Date(),
    meta: { ...meta, source: 'wallet_purchase' },
  });

  logger.info(
    `🛒 Wallet purchase : -${rounded} ${currency} from ${userRole}:${userId} ` +
    `(remaining: ${updated.walletBalance}) ref=${reference || '?'}`,
  );

  return {
    success: true,
    transactionId: tx._id.toString(),
    balance: updated.walletBalance,
    currency: updated.walletCurrency,
  };
}

module.exports = {
  creditWallet,
  debitWallet,
  getBalance,
  processPendingWithdrawals,
  payFromWallet,
};
