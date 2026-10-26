/**
 * 2610 (ZOE, 26/10/2026 — décision de Daniel, proposition A de SAM) — registre de l'e-mail
 * « candidats reçus » au PROPRIÉTAIRE, une ligne par demande :
 *   · `sentIds`   : candidatures déjà annoncées par e-mail ;
 *   · `queuedIds` : candidatures arrivées depuis, en attente du regroupement quotidien ;
 *   · `lastSentAt`: dernier e-mail (1 par jour au plus et par demande, le 1er tout de suite).
 * La ligne est créée par la 1re candidature REÇUE APRÈS le déploiement (aucun rattrapage).
 */
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    postId: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', required: true },
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true },
    sentIds: [{ type: mongoose.Schema.Types.ObjectId }],
    queuedIds: [{ type: mongoose.Schema.Types.ObjectId }],
    lastSentAt: { type: Date, default: null },
    emails: { type: Number, default: 0 },
    lastResult: { type: String, default: '' },
    createdAt: { type: Date, default: Date.now },
  },
  { versionKey: false },
);
schema.index({ postId: 1 }, { unique: true });
schema.index({ lastSentAt: 1 });

module.exports = mongoose.models.ApplicationEmail2610 || mongoose.model('ApplicationEmail2610', schema);
