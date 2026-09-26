const mongoose = require('mongoose');

// v590 — Daniel : « un onglet Dernière connexion, date, heure, lieu, qu'on voie
// l'activité ». Une ligne = un DÉBUT DE SESSION (première requête connectée
// après 30 min sans activité). Lieu = ville du profil / dernière position
// connue, jamais l'adresse IP. Conservé 90 jours.
const activityEventSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    role: { type: String, default: '' },
    at: { type: Date, default: Date.now },
    platform: { type: String, default: '' }, // ios | android | web
    appVersion: { type: String, default: '' },
    city: { type: String, default: '' },
    country: { type: String, default: '' },
  },
  { versionKey: false },
);

activityEventSchema.index({ at: -1 });
activityEventSchema.index({ userId: 1, at: -1 });
activityEventSchema.index({ at: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 90 });

module.exports = mongoose.model('ActivityEvent', activityEventSchema);
