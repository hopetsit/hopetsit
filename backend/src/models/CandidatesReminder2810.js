/**
 * 2810 (BOB) — registre des e-mails « N gardiens ont répondu — choisissez le vôtre »
 * (services/candidatesReminder2810.js) : une place par demande et par envoi (`e1`, `e2`, `e3`),
 * réservée AVANT l'envoi → jamais deux fois, jamais plus de 3 par demande.
 */
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    postId: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', required: true },
    slot: { type: String, enum: ['e1', 'e2', 'e3'], required: true },
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', default: null },
    candidates: { type: Number, default: 0 },
    status: { type: String, enum: ['sent', 'failed'], default: 'sent' },
    error: { type: String, default: '' },
    createdAt: { type: Date, default: Date.now },
  },
  { versionKey: false },
);
schema.index({ postId: 1, slot: 1 }, { unique: true });

module.exports = mongoose.models.CandidatesReminder2810 || mongoose.model('CandidatesReminder2810', schema);
