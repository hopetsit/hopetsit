/**
 * WalletTransaction — journal des mouvements du wallet sitter/walker (v19.0).
 *
 * Chaque opération sur le wallet est stockée ici : crédit de booking payée,
 * débit pour retrait SEPA/PayPal, débit pour achat shop, ajustement admin,
 * remboursement. Permet un audit trail complet et la reconstitution du solde
 * en cas de litige ou réconciliation compta.
 *
 * Le solde en cache est stocké sur Sitter.walletBalance / Walker.walletBalance
 * pour lookup instantané ; ce log sert uniquement de source de vérité et
 * d'historique affiché à l'utilisateur.
 */

const mongoose = require('mongoose');

const walletTransactionSchema = new mongoose.Schema(
  {
    // ── Qui ─────────────────────────────────────────────────────────────
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    userRole: {
      type: String,
      enum: ['sitter', 'walker'],
      required: true,
      index: true,
    },

    // ── Nature de l'opération ───────────────────────────────────────────
    type: {
      type: String,
      required: true,
      enum: [
        'credit_booking',       // Owner a payé une booking → credit provider
        'debit_withdrawal',     // Provider demande un virement IBAN/PayPal
        'debit_shop',           // Provider achète un boost/premium avec solde
        // v23.1 part 252 — 'debit_purchase' etait le default de payFromWallet
        // (walletService l.401) mais absent de l'enum → payFromWallet jetait
        // une ValidationError. Alias de debit_shop pour les achats boutique.
        'debit_purchase',       // Achat boutique via solde wallet (alias shop)
        'refund',               // Booking annulée → remboursement au provider (rare)
        'admin_adjustment',     // Correction manuelle admin (litige)
      ],
      index: true,
    },

    // Positif pour un crédit, négatif pour un débit. Toujours en valeur absolue
    // dans l'UI, le signe est déduit de `type`.
    amount: { type: Number, required: true },
    currency: { type: String, default: 'EUR' },

    // ── Contexte optionnel ──────────────────────────────────────────────
    bookingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      default: null,
    },
    // Pour type=debit_shop : 'boost_bronze' | 'premium_monthly' | 'map_boost_gold' …
    productType: { type: String, default: '' },
    // Pour debit_withdrawal : 'iban' | 'paypal' + détails en meta.
    withdrawalMethod: {
      type: String,
      enum: ['iban', 'paypal', ''],
      default: '',
    },
    // Référence externe : Stripe PaymentIntent id, numéro SEPA, email PayPal…
    referenceId: { type: String, default: '' },

    // ── État ────────────────────────────────────────────────────────────
    status: {
      type: String,
      // v23.1 part 252 — BUG CRITIQUE : 'processing' etait utilise par
      // walletService.processPendingWithdrawals (claim avant l'appel
      // Airwallex) mais ABSENT de l'enum. claimed.save() validait l'enum
      // → ValidationError → rollback en 'pending' alors que le payout
      // Airwallex etait DEJA parti → risque de DOUBLE-PAYOUT au tick
      // suivant (la tx redevient pending et est reclaim). On ajoute
      // 'processing' a l'enum pour que le claim persiste correctement.
      enum: ['pending', 'processing', 'completed', 'failed', 'cancelled'],
      default: 'completed',
      index: true,
    },
    // Snapshot du solde après application de cette transaction (audit).
    balanceAfter: { type: Number, required: true },

    // ── Horodatage ──────────────────────────────────────────────────────
    completedAt: { type: Date, default: null },
    failureReason: { type: String, default: '' },

    // Méta libre (IBAN holder, dernière partie, admin notes).
    meta: {
      type: mongoose.Schema.Types.Mixed,
      default: () => ({}),
    },
  },
  { timestamps: true },
);

// Index composite pour l'écran historique : récentes transactions du user.
walletTransactionSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('WalletTransaction', walletTransactionSchema);
