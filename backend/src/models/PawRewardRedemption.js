const mongoose = require('mongoose');

// v414 — trace d'échange d'une récompense PawPoints. L'admin peut voir qui a
// échangé quoi (et marquer comme traité pour les goodies physiques). 100%
// ADDITIF.
const pawRewardRedemptionSchema = new mongoose.Schema(
  {
    // v414 : récompense admin custom (ObjectId). v416 : pour les récompenses
    // "abonnement" code-définies (sub_*), rewardId est absent et rewardKey
    // porte la clé (sub_disc_10, sub_free_pp_3m…) → contrôle 1 fois/user +
    // consommation de la réduction au prochain achat.
    rewardId: {
      type: mongoose.Schema.Types.ObjectId, ref: 'PawReward', index: true,
    },
    rewardKey: { type: String, default: '', index: true },
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
