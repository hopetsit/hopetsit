/**
 * 617 (ADA, 16/10/2026) — REGISTRE des rappels « des deux côtés » (§B.1 du
 * PROCHAIN_BUILD_617, accord de Daniel du 16/10).
 *
 *   · 'p24' au GARDIEN / PROMENEUR : sa candidature attend depuis ≥ 24 h sans
 *     réponse du propriétaire → « envoie-lui un message ». Clé = p24:<applicationId>.
 *   · 'x48' au PROPRIÉTAIRE : sa demande expire dans 48 h et des candidats
 *     attendent → « choisis-en un maintenant ». Clé = x48:<postId>.
 *
 * `key` UNIQUE : la place est prise AVANT l'envoi (comme 615) — un rappel ne
 * part jamais deux fois, même si deux serveurs balaient en même temps.
 */
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true },
    slot: { type: String, enum: ['p24', 'x48'], required: true },
    postId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    applicationId: { type: mongoose.Schema.Types.ObjectId, default: null },
    recipientRole: { type: String, enum: ['owner', 'sitter', 'walker'], required: true },
    recipientId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    candidates: { type: Number, default: 0 },
    timeZone: { type: String, default: '' },
    // 'sent' | 'failed' (la place est prise dans les deux cas : jamais de 2e essai)
    status: { type: String, default: 'sent' },
    error: { type: String, default: '' },
  },
  { timestamps: true, collection: 'applicationreminders617' },
);

module.exports = mongoose.models.ApplicationReminder617 || mongoose.model('ApplicationReminder617', schema);
