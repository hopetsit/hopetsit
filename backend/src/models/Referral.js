const mongoose = require('mongoose');

const referralSchema = new mongoose.Schema(
  {
    referrerId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    // v23.1.332 — Daniel : parrainage pour les 3 profils. 'walker' manquait dans
    // l'enum → Referral.create échouait silencieusement pour les walkers.
    referrerRole: { type: String, enum: ['owner', 'sitter', 'walker'], required: true },
    referredUserId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    referredRole: { type: String, enum: ['owner', 'sitter', 'walker'], required: true },
    status: {
      type: String,
      enum: ['pending', 'completed'],
      default: 'pending',
      index: true,
    },
    creditAwarded: { type: Boolean, default: false },
    completedAt: { type: Date, default: null },
    // v23.1.332 — récompense = -10% sur PawFollow/PawFamily, consommée au
    // prochain achat d'abonnement (cf subscriptionRoutes /subscribe).
    rewardConsumed: { type: Boolean, default: false },
    rewardConsumedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

referralSchema.index({ referrerId: 1, referredUserId: 1 }, { unique: true });

module.exports = mongoose.model('Referral', referralSchema);
