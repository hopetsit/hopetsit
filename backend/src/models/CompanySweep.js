/**
 * Company Sweep model — v23.1 part 86.
 *
 * Tracks every "Retirer mes bénéfices" action triggered from the admin
 * dashboard. One row per Airwallex Payout sent to the company beneficiary.
 *
 * Daniel : "controle des retrait pour ma societer". The admin page lists
 * the most recent sweeps so Daniel can see :
 *   - quand il a retiré
 *   - combien
 *   - vers quel beneficiary
 *   - quel statut côté Airwallex (initiated / completed / failed)
 */
const mongoose = require('mongoose');

const companySweepSchema = new mongoose.Schema(
  {
    triggeredBy: {
      type: String,
      default: 'admin', // 'admin' | 'cron' | 'api'
    },
    beneficiaryId: { type: String, required: true, trim: true },
    currency: { type: String, required: true, uppercase: true, trim: true },
    amount: { type: Number, required: true }, // major units (EUR not cents)
    requestedAmount: { type: Number, default: null }, // null = swept full available
    payoutId: { type: String, default: '', trim: true },
    status: {
      type: String,
      enum: ['initiated', 'completed', 'failed'],
      default: 'initiated',
      index: true,
    },
    failureReason: { type: String, default: '' },
    completedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

companySweepSchema.index({ createdAt: -1 });

module.exports = mongoose.model('CompanySweep', companySweepSchema);
