const mongoose = require('mongoose');

// 607 (ZOE, 02/10/2026) — JOURNAL des gains PawPoints « d'activité »
// (Balade terminée, premier avis reçu, profil complet, Pionnier, série de 7
// jours, peluche). Une ligne = un gain. `dedupeKey` UNIQUE : c'est lui qui
// garantit « une fois » / « une fois par jour » même si deux requêtes
// arrivent en même temps. `personKey` = empreinte de l'e-mail (les 3 profils
// d'une personne partagent la même), jamais l'e-mail lui-même.
const pawPointsEventSchema = new mongoose.Schema(
  {
    personKey: { type: String, required: true, index: true },
    userId: { type: String, required: true },
    role: { type: String, default: '' },
    key: { type: String, required: true, index: true },
    points: { type: Number, default: 0 },      // barème
    credited: { type: Number, default: 0 },    // réellement crédité (×2 Premium, bonus niveau)
    refId: { type: String, default: '' },
    dedupeKey: { type: String, required: true, unique: true },
    at: { type: Date, default: Date.now },
  },
  { versionKey: false },
);
pawPointsEventSchema.index({ at: -1 });

// 607 — série de jours d'activité (une ligne par personne).
const pawPointsStreakSchema = new mongoose.Schema(
  {
    personKey: { type: String, required: true, unique: true },
    lastDay: { type: String, default: '' }, // AAAA-MM-JJ (UTC)
    count: { type: Number, default: 0 },
    best: { type: Number, default: 0 },
  },
  { versionKey: false, timestamps: true },
);

const PawPointsEvent = mongoose.models.PawPointsEvent
  || mongoose.model('PawPointsEvent', pawPointsEventSchema);
const PawPointsStreak = mongoose.models.PawPointsStreak
  || mongoose.model('PawPointsStreak', pawPointsStreakSchema);

module.exports = PawPointsEvent;
module.exports.PawPointsStreak = PawPointsStreak;
