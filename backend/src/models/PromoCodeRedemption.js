const mongoose = require('mongoose');

// v402 — trace d'utilisation d'un code promo (1 par user max via l'index unique).
const promoCodeRedemptionSchema = new mongoose.Schema(
  {
    promoCodeId: {
      type: mongoose.Schema.Types.ObjectId, ref: 'PromoCode', required: true, index: true,
    },
    code: { type: String, required: true },
    userId: { type: mongoose.Schema.Types.ObjectId, required: true },
    userModel: { type: String, enum: ['Owner', 'Sitter', 'Walker'], required: true },
    role: { type: String, default: '' },
    reward: { type: Object, default: {} },
    // v450 — pour les codes `percent_discount` : horodate le moment où la
    // réduction a été RÉELLEMENT consommée à l'achat d'un abonnement. Tant
    // que c'est null, la réduction est en attente d'application. (free_subscription
    // est appliqué tout de suite à la redemption, donc ce champ reste null.)
    discountConsumedAt: { type: Date, default: null, index: true },
  },
  { timestamps: true },
);

// Empêche un même utilisateur d'utiliser deux fois le même code.
promoCodeRedemptionSchema.index({ promoCodeId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('PromoCodeRedemption', promoCodeRedemptionSchema);
