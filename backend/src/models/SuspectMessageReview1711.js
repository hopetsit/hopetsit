'use strict';
// 17/11/2026 (BOB) — « classé sans suite » d'une alerte de message suspect (admin).
// Une ligne par (conversation, expéditeur). L'alerte revient si un NOUVEAU message suspect
// arrive après `reviewedAt`.
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true }, // conversationId:senderRole:senderId
    reviewedAt: { type: Date, required: true },
    reviewedBy: { type: String, default: '' },
    note: { type: String, default: '', maxlength: 300 },
  },
  { timestamps: true },
);

module.exports = mongoose.models.SuspectMessageReview1711
  || mongoose.model('SuspectMessageReview1711', schema);
