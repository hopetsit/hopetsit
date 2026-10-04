const mongoose = require('mongoose');

// 611 (PAM, 04/10/2026) — Cam : « j'ai 36 points et je ne sais pas à quoi je
// les ai gagnés ». JOURNAL de TOUTES les attributions (et reprises) de
// PawPoints, écrit au point unique pawPointsService.awardPointsDetailed /
// revokePoints, à partir du 611. Rien n'est reconstitué pour le passé : la
// route d'historique affiche « Points gagnés avant le journal : N ».
// `personKey` = empreinte de l'e-mail (3 profils = une personne), jamais l'e-mail.
const pawPointsLogSchema = new mongoose.Schema(
  {
    personKey: { type: String, required: true },
    userId: { type: String, default: '' },
    role: { type: String, default: '' },
    key: { type: String, default: 'other' }, // clé du barème (plushCaught, spotCreated…)
    points: { type: Number, default: 0 }, // crédité (négatif pour une reprise)
    at: { type: Date, default: Date.now },
  },
  { versionKey: false },
);
pawPointsLogSchema.index({ personKey: 1, at: -1 });

module.exports = mongoose.models.PawPointsLog611
  || mongoose.model('PawPointsLog611', pawPointsLogSchema);
