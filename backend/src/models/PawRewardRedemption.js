const mongoose = require('mongoose');

// v414 — trace d'échange d'une récompense PawPoints. L'admin peut voir qui a
// échangé quoi (et marquer comme traité pour les goodies physiques). 100%
// ADDITIF.
const pawRewardRedemptionSchema = new mongoose.Schema(
  {
    rewardId: {
      type: mongoose.Schema.Types.ObjectId, ref: 'PawReward', required: true, index: true,
    },
    title: { type: String, default: '' },
    cost: { type: Number, default: 0 },
    userId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    userModel: { type: String, enum: ['Owner', 'Sitter', 'Walker'], required: true },
    role: { type: String, default: '' },
    userName: { type: String, default: '' },
    userEmail: { type: String, default: '' },
    // pending → fulfilled (admin a livré le goodie / appliqué l'avantage).
    status: { type: String, enum: ['pending', 'fulfilled', 'cancelled'], default: 'pending' },
    snapshot: { type: Object, default: {} },
  },
  { timestamps: true },
);

module.exports = mongoose.model('PawRewardRedemption', pawRewardRedemptionSchema);
