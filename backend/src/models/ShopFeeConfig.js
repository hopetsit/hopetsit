const mongoose = require('mongoose');

/**
 * v566 — taux de commission des stores, réglables depuis l'admin
 * (Mes revenus › Boutique par canal). Singleton (`key: 'singleton'`).
 *
 * Fractions du brut : 0.15 = 15 %. Défauts : Apple 15 % (App Store Small
 * Business Program) et Google Play 15 %. Sert UNIQUEMENT au calcul du « net
 * estimé » de GET /admin/shop-revenue — aucun flux d'argent n'en dépend.
 */
const ShopFeeConfigSchema = new mongoose.Schema(
  {
    key: { type: String, default: 'singleton', unique: true },
    apple: { type: Number, default: 0.15, min: 0, max: 0.5 },
    google_play: { type: Number, default: 0.15, min: 0, max: 0.5 },
  },
  { timestamps: true },
);

module.exports = mongoose.model('ShopFeeConfig', ShopFeeConfigSchema);
