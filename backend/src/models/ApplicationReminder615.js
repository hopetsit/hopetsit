/**
 * 615 (ZOE, 07/10/2026) — REGISTRE des rappels « tu as N candidats, choisis le tien ».
 *
 * Cas réel : la balade de Nicola (Paris 11e, 05/10) a reçu 2 candidatures, personne
 * n'a été choisi, la demande a expiré → 0 paiement. Un rappel (notification de
 * l'app seulement, jamais d'e-mail) part au plus DEUX fois par demande :
 *   · 'r1' ≈ 2 h après la 1re candidature ;
 *   · 'r2' 2 h avant une balade / une visite, 24 h avant une garde.
 * (postId, slot) UNIQUE : un rappel ne part jamais deux fois, même si deux
 * serveurs balaient en même temps ou si le serveur redémarre.
 */
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    postId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    slot: { type: String, enum: ['r1', 'r2'], required: true },
    ownerId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    candidates: { type: Number, default: 0 },
    applicationId: { type: mongoose.Schema.Types.ObjectId, default: null },
    serviceKind: { type: String, default: '' },
    timeZone: { type: String, default: '' },
    // 'sent' | 'failed' (la place est prise dans les deux cas : jamais de 2e essai)
    status: { type: String, default: 'sent' },
    error: { type: String, default: '' },
  },
  { timestamps: true, collection: 'applicationreminders615' },
);

schema.index({ postId: 1, slot: 1 }, { unique: true });

module.exports = mongoose.models.ApplicationReminder615 || mongoose.model('ApplicationReminder615', schema);
