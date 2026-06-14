const mongoose = require('mongoose');

// v402 — Codes promo (Chantier 2). 100% ADDITIF : nouvelle collection, aucune
// route existante touchée → aucun impact app. Génération + envoi par l'admin ;
// la redemption côté app arrivera plus tard (l'endpoint /promo/redeem existe
// déjà mais l'app ne l'appelle pas encore).
//
// rewardType :
//   'free_subscription' → offre un abo gratuit pour `intervalDays` jours.
//   'percent_discount'  → % de réduction (appliqué au checkout, plus tard).
//
// plan (free_subscription) — clés canoniques :
//   'monthly' | 'yearly'                 → PawFollow individuel
//   'family'  | 'family_yearly'          → PawFamily
//   'premium_monthly' | 'premium_yearly' → Paw Premium (bundle)
//   'pawspot'                            → PawSpot communautaire
//   'pawboost'                           → PawBoost (palier dans boostTier)
const promoCodeSchema = new mongoose.Schema(
  {
    code: {
      type: String, required: true, unique: true, uppercase: true, trim: true, index: true,
    },
    campaign: { type: String, default: '', trim: true },
    rewardType: {
      type: String,
      enum: ['free_subscription', 'percent_discount'],
      default: 'free_subscription',
    },
    plan: { type: String, default: '' },
    intervalDays: { type: Number, default: 30 },
    // PawBoost uniquement : palier offert (bronze/silver/gold/platinum).
    boostTier: { type: String, default: '' },
    // percent_discount uniquement : pourcentage de réduction.
    discountPercent: { type: Number, default: 0 },
    // Combien de fois CE code peut être utilisé au total (ex. 200 Premium = 1
    // code, maxUses 200). 0 = illimité.
    maxUses: { type: Number, default: 1 },
    usedCount: { type: Number, default: 0 },
    expiresAt: { type: Date, default: null },
    isActive: { type: Boolean, default: true },
    createdBy: { type: String, default: '' },
  },
  { timestamps: true },
);

// Un code est valide si actif, non expiré, et sous le quota d'usages.
promoCodeSchema.methods.isRedeemable = function isRedeemable() {
  if (!this.isActive) return false;
  if (this.expiresAt && new Date(this.expiresAt) < new Date()) return false;
  if (this.maxUses && this.maxUses > 0 && this.usedCount >= this.maxUses) return false;
  return true;
};

module.exports = mongoose.model('PromoCode', promoCodeSchema);
