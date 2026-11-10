/**
 * 1011 (FLO, plan « conclure » validé par Daniel le 09/11, point B.4) — registre du message
 * automatique « un gardien est libre et vous attend → payer » (services/sitterFree1011.js).
 *
 * Deux sortes de lignes, une seule clé unique (`key`) réservée AVANT l'envoi → rien ne part
 * deux fois, même après un redémarrage ou deux balayages en même temps :
 *   · `q:<candidature>` — la question « Êtes-vous toujours libre ? » posée au gardien ou au
 *     promeneur (une seule fois par candidature) ; `answer` + `answeredAt` notent sa réponse ;
 *   · `o:<demande>`     — le message « <Prénom> est libre et vous attend » envoyé au
 *     propriétaire (une seule fois par demande : le premier « oui » le déclenche).
 * Une ligne `failed` (e-mail bloqué, préférences coupées) se rejoue, 3 tentatives au plus.
 * `personKey` : la PERSONNE (ses 3 profils confondus, utils/person3110) pour le plafond de
 * questions par jour. Aucune adresse e-mail ni téléphone n'est stocké ici.
 */
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    key: { type: String, required: true },
    kind: { type: String, enum: ['question', 'owner'], required: true },
    postId: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', required: true },
    applicationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Application', default: null },
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', default: null },
    providerRole: { type: String, enum: ['sitter', 'walker', ''], default: '' },
    providerId: { type: mongoose.Schema.Types.ObjectId, default: null },
    personKey: { type: String, default: '' },
    status: { type: String, enum: ['sent', 'failed'], default: 'sent' },
    attempts: { type: Number, default: 1 },
    error: { type: String, default: '' },
    answer: { type: String, enum: ['', 'yes', 'no'], default: '' },
    answeredAt: { type: Date, default: null },
    // 10/11 — date du déblocage UNIQUE d'une ligne restée en échec « e-mail non validé »
    // (accord de Daniel du 10/11) : une ligne ne se débloque qu'une fois.
    unblockedAt: { type: Date, default: null },
    createdAt: { type: Date, default: Date.now },
  },
  { versionKey: false },
);
schema.index({ key: 1 }, { unique: true });
schema.index({ personKey: 1, createdAt: -1 });
schema.index({ postId: 1, kind: 1 });

module.exports = mongoose.models.SitterFree1011 || mongoose.model('SitterFree1011', schema);
