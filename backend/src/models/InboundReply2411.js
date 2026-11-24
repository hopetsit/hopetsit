const mongoose = require('mongoose');

/**
 * 2411 (BOB) — une ligne par e-mail de réponse reçu sur une adresse « +r… » (voir utils/replyAddress2411).
 * Index unique sur l'identifiant du message : un même e-mail n'est jamais posté deux fois, même si le serveur
 * redémarre entre la lecture de la boîte et le marquage « lu ». Aucun texte ni adresse stockés : seulement le fil,
 * le rôle, le résultat et sa raison (lecture admin /admin/inbound-replies-2411). Effacé après 400 jours.
 */
const schema = new mongoose.Schema(
  {
    messageId: { type: String, required: true },
    conversationId: { type: String, default: '' },
    role: { type: String, default: '' },
    userId: { type: String, default: '' },
    status: { type: String, enum: ['claimed', 'posted', 'rejected'], default: 'claimed' },
    reason: { type: String, default: '' },
    chars: { type: Number, default: 0 },
    receivedAt: { type: Date, default: null },
    createdAt: { type: Date, default: Date.now, expires: 400 * 24 * 3600 },
  },
  { versionKey: false },
);
schema.index({ messageId: 1 }, { unique: true });
schema.index({ conversationId: 1, createdAt: -1 });

module.exports = mongoose.models.InboundReply2411 || mongoose.model('InboundReply2411', schema);
