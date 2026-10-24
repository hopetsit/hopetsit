/**
 * 620 (ZOE, 24/10/2026) — registre des rappels « pose tes dates pour valider »
 * (services/postDatesReminder620.js) : une place par demande et par créneau
 * (`d1` = J+1, `d3` = J+3), réservée AVANT l'envoi → jamais deux fois.
 */
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    postId: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', required: true },
    slot: { type: String, enum: ['d1', 'd3'], required: true },
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', default: null },
    candidates: { type: Number, default: 0 },
    status: { type: String, enum: ['sent', 'failed'], default: 'sent' },
    error: { type: String, default: '' },
    createdAt: { type: Date, default: Date.now },
  },
  { versionKey: false },
);
schema.index({ postId: 1, slot: 1 }, { unique: true });

module.exports = mongoose.models.PostDatesReminder620 || mongoose.model('PostDatesReminder620', schema);
