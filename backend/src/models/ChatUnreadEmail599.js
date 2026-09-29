const mongoose = require('mongoose');

/**
 * v599 (ZOE, 29/09/2026) — E-MAIL DIFFÉRÉ « message non lu » (décision Daniel, 29/09 08 h).
 *
 * Une ATTENTE par (conversation, destinataire) : posée au premier message non lu,
 * l'e-mail ne part que si la conversation est TOUJOURS non lue à `unreadEmailDueAt`
 * (= arrivée + 15 min). Lire la conversation (n'importe quel appareil ou le site)
 * supprime l'attente. Une fois envoyé (`sentAt`), le document reste tant que la
 * conversation n'est pas lue : aucun autre e-mail pour ce fil. La lecture l'efface,
 * et le prochain message repose une attente neuve.
 *
 * Index unique (conversationId, recipientId) : jamais deux attentes, donc jamais
 * deux e-mails pour la même attente, même avec deux instances du serveur.
 * Survit au redémarrage de Render : c'est en base, pas dans un setTimeout.
 */
const chatUnreadEmailSchema = new mongoose.Schema(
  {
    conversationId: { type: String, required: true },
    recipientId: { type: String, required: true },
    recipientRole: { type: String, enum: ['owner', 'sitter', 'walker'], required: true },
    // Tous les ids de rôle de la personne destinataire (owner/sitter/walker) :
    // une lecture depuis n'importe lequel de ses profils annule l'attente.
    recipientIds: { type: [String], default: [] },
    unreadEmailDueAt: { type: Date, required: true },
    // Réclamé atomiquement par le balayage avant l'envoi (anti-doublon).
    claimedAt: { type: Date, default: null },
    sentAt: { type: Date, default: null },
    attempts: { type: Number, default: 0 },
    lastError: { type: String, default: '' },
    // Ce qu'il faut pour rendre l'e-mail au moment voulu (même gabarit,
    // 9 langues, lien vers la conversation) : les entrées de sendNotification.
    payload: {
      userId: { type: String, default: '' },
      role: { type: String, default: '' },
      type: { type: String, default: 'NEW_MESSAGE' },
      data: { type: mongoose.Schema.Types.Mixed, default: {} },
      actor: { type: mongoose.Schema.Types.Mixed, default: null },
    },
  },
  { timestamps: true },
);

chatUnreadEmailSchema.index({ conversationId: 1, recipientId: 1 }, { unique: true });
chatUnreadEmailSchema.index({ sentAt: 1, claimedAt: 1, unreadEmailDueAt: 1 });
chatUnreadEmailSchema.index({ conversationId: 1, recipientIds: 1 });

module.exports = mongoose.model('ChatUnreadEmail', chatUnreadEmailSchema);
