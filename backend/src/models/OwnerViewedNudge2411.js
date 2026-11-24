const mongoose = require('mongoose');

/**
 * 2411 (BOB) — une ligne par CANDIDATURE pour laquelle on a prévenu le prestataire « le propriétaire a regardé ta
 * proposition : écris-lui » (services/ownerViewedNudge2411). Index unique : jamais deux fois pour la même candidature.
 * Aucun texte, aucune adresse. Effacé après 400 jours.
 */
const schema = new mongoose.Schema(
  {
    applicationId: { type: String, required: true },
    postId: { type: String, default: '' },
    providerId: { type: String, default: '' },
    providerRole: { type: String, default: '' },
    status: { type: String, enum: ['claimed', 'sent', 'failed'], default: 'claimed' },
    reason: { type: String, default: '' },
    viewedAt: { type: Date, default: null },
    createdAt: { type: Date, default: Date.now, expires: 400 * 24 * 3600 },
  },
  { versionKey: false },
);
schema.index({ applicationId: 1 }, { unique: true });
schema.index({ providerId: 1, createdAt: -1 });

module.exports = mongoose.models.OwnerViewedNudge2411 || mongoose.model('OwnerViewedNudge2411', schema);
