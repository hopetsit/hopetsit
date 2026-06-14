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
  },
  { timestamps: true },
);

// Empêche un même utilisateur d'utiliser deux fois le même code.
promoCodeRedemptionSchema.index({ promoCodeId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('PromoCodeRedemption', promoCodeRedemptionSchema);
