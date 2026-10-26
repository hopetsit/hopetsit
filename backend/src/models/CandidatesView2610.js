const mongoose = require('mongoose');

// 26/10/2026 (ADA, décision de Daniel) — repère « le propriétaire a OUVERT la
// page de ses candidats » (site ou app). Une ligne = une ouverture (doublons
// à moins de 2 min fusionnés). Ni IP, ni User-Agent, ni contenu : demande,
// propriétaire, heure, canal, provenance (e-mail / push / direct).
const schema = new mongoose.Schema(
  {
    postId: { type: String, required: true, index: true },
    ownerId: { type: String, required: true, index: true },
    at: { type: Date, default: Date.now },
    channel: { type: String, default: '' }, // web | app
    source: { type: String, default: '' }, // email | push | notification | direct | link | ''
    origin: { type: String, default: '' }, // app | web | script (cf. utils/ownerReturn2610)
    appVersion: { type: String, default: '' },
  },
  { versionKey: false },
);
schema.index({ ownerId: 1, postId: 1, at: -1 });
schema.index({ at: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 365 });

module.exports = mongoose.models.CandidatesView2610 || mongoose.model('CandidatesView2610', schema);
