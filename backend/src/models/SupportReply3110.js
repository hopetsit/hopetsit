'use strict';
/**
 * 3110 (ADA, demande de BOB) — journal des réponses support envoyées depuis l'admin
 * (POST /admin/support-reply). Une ligne par e-mail : destinataire, sujet, texte, admin, date,
 * bug signalé lié (facultatif). Lecture par l'admin seulement.
 */
const mongoose = require('mongoose');

const supportReplySchema = new mongoose.Schema(
  {
    to: { type: String, required: true, trim: true, lowercase: true, index: true },
    subject: { type: String, required: true, trim: true, maxlength: 200 },
    text: { type: String, required: true, maxlength: 4200 },
    adminId: { type: String, default: '' },
    bugReportId: { type: mongoose.Schema.Types.ObjectId, ref: 'BugReport', default: null, index: true },
    bugStatusBefore: { type: String, default: '' },
    bugStatusAfter: { type: String, default: '' },
    messageId: { type: String, default: '' },
    sentAt: { type: Date, default: Date.now, index: true },
  },
  { timestamps: true },
);

module.exports = mongoose.model('SupportReply3110', supportReplySchema);
