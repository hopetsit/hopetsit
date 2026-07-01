/**
 * Donation — v500 (Daniel : « les dons n'apparaissent pas dans l'activité
 * boutique de l'admin »).
 *
 * AVANT : un don créait un PaymentIntent Airwallex (metadata type='donation')
 * mais RIEN n'était persisté en Mongo au succès → aucun moyen de lister les
 * dons dans l'admin (visibles uniquement dans le dashboard Airwallex).
 *
 * MAINTENANT : le webhook Airwallex (payment_intent.succeeded, type='donation')
 * upsert un document ici (idempotent sur paymentIntentId). L'admin
 * (/admin/boosts) agrège ensuite ces documents dans l'activité boutique.
 *
 * NB : seuls les dons reçus APRÈS ce déploiement sont enregistrés — les dons
 * antérieurs n'existent que côté Airwallex.
 */
const mongoose = require('mongoose');

const donationSchema = new mongoose.Schema(
  {
    paymentIntentId: { type: String, required: true, unique: true, index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, default: null },
    userModel: {
      type: String,
      enum: ['Owner', 'Sitter', 'Walker', null],
      default: null,
    },
    userRole: { type: String, default: '' }, // owner | sitter | walker
    name: { type: String, default: '' },
    email: { type: String, default: '' },
    // Montant en unités (ex. 5.00 EUR), PAS en centimes.
    amount: { type: Number, required: true },
    currency: { type: String, default: 'EUR' },
    paidAt: { type: Date, default: Date.now },
    // /admin/payouts et /admin/v2/revenue agrègent sur { status: 'succeeded' }
    // (le webhook n'enregistre que les paiements réussis → défaut succeeded).
    status: { type: String, default: 'succeeded' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('Donation', donationSchema);
