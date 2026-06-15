const mongoose = require('mongoose');

// v414 — PawPoints : récompenses ÉDITABLES depuis l'admin (Daniel : "je peux
// aussi gérer les offres et récompenses directement de l'admin sans rebuild").
// 100% ADDITIF : nouvelle collection. L'app et le site LISENT cette liste via
// GET /pawpoints/catalog → on peut ajouter/modifier/retirer une récompense sans
// rebuild de l'app (elle affiche ce que le backend renvoie).
//
// kind :
//   'discount'      → bon de réduction (valueLabel ex. "-5 €", "-10 %")
//   'subscription'  → jours d'abonnement offerts (plan + intervalDays)
//   'boost'         → un PawBoost offert (boostTier)
//   'badge'         → badge cosmétique / titre
//   'goodie'        → goodie physique / autre (géré manuellement par l'admin)
const pawRewardSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true },
    description: { type: String, default: '', trim: true },
    // Emoji ou court symbole affiché dans la liste (🎁, 🦴, 🏅…).
    icon: { type: String, default: '🎁', trim: true },
    // Coût en PawPoints pour échanger cette récompense.
    cost: { type: Number, required: true, min: 0, default: 100 },
    kind: {
      type: String,
      enum: ['discount', 'subscription', 'boost', 'badge', 'goodie'],
      default: 'discount',
    },
    // Libellé de la valeur affichée (ex. "-5 €", "7 jours PawFollow").
    valueLabel: { type: String, default: '', trim: true },
    // subscription : plan canonique + durée (voir PromoCode).
    plan: { type: String, default: '' },
    intervalDays: { type: Number, default: 0 },
    // boost : palier offert.
    boostTier: { type: String, default: '' },
    // discount : montant ou pourcentage (informatif, appliqué plus tard).
    discountPercent: { type: Number, default: 0 },
    discountAmount: { type: Number, default: 0 },
    // Ordre d'affichage (croissant) puis coût.
    sortOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    // Stock limité (0 = illimité). Décrémenté à l'échange.
    stock: { type: Number, default: 0 },
    redeemedCount: { type: Number, default: 0 },
  },
  { timestamps: true },
);

pawRewardSchema.methods.isRedeemable = function isRedeemable() {
  if (!this.isActive) return false;
  if (this.stock && this.stock > 0 && this.redeemedCount >= this.stock) return false;
  return true;
};

module.exports = mongoose.model('PawReward', pawRewardSchema);
