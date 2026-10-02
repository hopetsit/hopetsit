const mongoose = require('mongoose');
const crypto = require('crypto');

/**
 * 607 (ADA, 02/10/2026) — dernier e-mail de VÉRIFICATION D'ADRESSE envoyé à une personne,
 * toutes sources confondues (inscription, « renvoyer le code » de l'app / du site, vigie,
 * admin). Sert la règle « jamais deux envois au même compte en moins de 7 jours » du renvoi
 * groupé de l'admin. La clé est une empreinte de l'e-mail (jamais l'e-mail lui-même).
 */
const schema = new mongoose.Schema(
  {
    emailHash: { type: String, required: true, unique: true },
    lastVerificationEmailAt: { type: Date, required: true },
    lastSource: { type: String, default: '' },
    count: { type: Number, default: 0 },
  },
  { versionKey: false, timestamps: true },
);

const hashEmail = (email) => crypto.createHash('sha256')
  .update(String(email || '').trim().toLowerCase()).digest('hex').slice(0, 40);

const VerificationEmailLog = mongoose.models.VerificationEmailLog
  || mongoose.model('VerificationEmailLog', schema);

/** Note l'envoi (best-effort, jamais bloquant pour l'appelant). */
async function touch(email, source = '', at = new Date()) {
  if (!email) return null;
  return VerificationEmailLog.findOneAndUpdate(
    { emailHash: hashEmail(email) },
    { $set: { lastVerificationEmailAt: at, lastSource: source }, $inc: { count: 1 } },
    { upsert: true, new: true },
  );
}

/** Journal des renvois groupés lancés depuis l'admin (qui, quand, combien, résultat). */
const batchSchema = new mongoose.Schema(
  {
    adminId: { type: String, default: '' },
    dryRun: { type: Boolean, default: false },
    requested: { type: Number, default: 0 },
    sent: { type: Number, default: 0 },
    failed: { type: Number, default: 0 },
    skipped: { type: Object, default: {} },
    results: { type: Array, default: [] }, // { role, id (6 derniers), name, status, reason }
  },
  { versionKey: false, timestamps: true },
);
const VerificationResendBatch = mongoose.models.VerificationResendBatch
  || mongoose.model('VerificationResendBatch', batchSchema);

module.exports = VerificationEmailLog;
module.exports.hashEmail = hashEmail;
module.exports.touch = touch;
module.exports.VerificationResendBatch = VerificationResendBatch;
