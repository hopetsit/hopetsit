/**
 * 617 (ADA, 16/10/2026) — REGISTRE des demandes d'avis (§B.3 du PROCHAIN_BUILD_617).
 * Quand une réservation passe en `completed`, le PROPRIÉTAIRE reçoit UNE fois
 * (push + cloche, jamais d'e-mail) : « Comment s'est passée la garde avec
 * <Prénom> ? Laisse-lui un avis… ». (bookingId, ownerId) UNIQUE : la place est
 * prise avant l'envoi.
 */
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    bookingId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    ownerId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    revieweeRole: { type: String, enum: ['sitter', 'walker'], required: true },
    revieweeId: { type: mongoose.Schema.Types.ObjectId, required: true },
    status: { type: String, default: 'sent' }, // 'sent' | 'failed'
    error: { type: String, default: '' },
  },
  { timestamps: true, collection: 'reviewrequests617' },
);

schema.index({ bookingId: 1, ownerId: 1 }, { unique: true });

module.exports = mongoose.models.ReviewRequest617 || mongoose.model('ReviewRequest617', schema);
