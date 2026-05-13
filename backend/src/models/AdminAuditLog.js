// v23.1 part 133 — Phase 7 audit P7-24 (RGPD article 30 + ISO 27001).
// Journal d'audit des actions administratives. Toute action admin
// (ban, unban, refund, delete, KYC approve/reject, payout retry, etc.)
// laisse une trace immutable avec : adminId, action, target, ip, ua,
// timestamp, before/after snapshot quand pertinent.
const mongoose = require('mongoose');

const adminAuditLogSchema = new mongoose.Schema(
  {
    adminId: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin', required: true, index: true },
    adminEmail: { type: String, default: '', trim: true },
    action: { type: String, required: true, index: true }, // ex: 'ban_user', 'kyc_approve', 'refund'
    targetType: { type: String, default: '' }, // ex: 'Sitter', 'Booking', 'Post'
    targetId: { type: mongoose.Schema.Types.ObjectId, default: null, index: true },
    method: { type: String, default: '' },
    path: { type: String, default: '' },
    ip: { type: String, default: '' },
    userAgent: { type: String, default: '' },
    statusCode: { type: Number, default: 0 },
    // Snapshot succinct des params (pas le body complet — perf + RGPD).
    params: { type: mongoose.Schema.Types.Mixed, default: {} },
    notes: { type: String, default: '', maxlength: 2000 },
    createdAt: { type: Date, default: Date.now, index: true },
  },
  // pas de timestamps auto, on contrôle createdAt explicitement
  { timestamps: false, versionKey: false },
);

// Index TTL : on garde l'audit 5 ans (suffit pour RGPD + ISO).
adminAuditLogSchema.index({ createdAt: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 365 * 5 });

module.exports = mongoose.model('AdminAuditLog', adminAuditLogSchema);
