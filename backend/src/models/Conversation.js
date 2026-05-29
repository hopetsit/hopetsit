const mongoose = require('mongoose');

// v18.6 — walker conversation support.
// Avant v18.6 : sitterId required + unique{ownerId, sitterId}, donc les
// walkers ne pouvaient pas discuter avec owner (chat skip au moment de
// l'accept). Maintenant : EXACTEMENT un des deux (sitterId OU walkerId)
// est défini, enforcé par pre('validate'). Compound indexes séparés.
// v23.1.200 — Daniel : "bouton 💬 sur friend + family member" pour ouvrir
// un chat 1-to-1 (any-role ↔ any-role, owner↔owner inclus). On etend le
// modele Conversation existant avec :
//   - friendChat (Boolean) : flag qui differencie un chat booking
//     (owner ↔ sitter/walker) d'un chat ami/famille (any ↔ any)
//   - participants[] : tableau des 2 users (ou plus si futur extension)
//     avec leur unreadCount + lastReadAt independants
// Backward compatible : les conversations booking existantes ont
// friendChat = false, le pipeline owner-sitter classique reste actif.
const conversationSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', default: null },
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', default: null },
    walkerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Walker', default: null },
    // v23.1.200 — friend/family chat support
    friendChat: { type: Boolean, default: false, index: true },
    participants: [{
      userId: { type: mongoose.Schema.Types.ObjectId, required: true },
      userModel: {
        type: String,
        enum: ['Owner', 'Sitter', 'Walker'],
        required: true,
      },
      unreadCount: { type: Number, default: 0 },
      lastReadAt: { type: Date, default: null },
    }],
    lastMessage: { type: String, default: '' },
    lastMessageAt: { type: Date, default: Date.now },
    // v23.1.255 — Daniel : "si j'efface une conversation et la personne me
    // réécrit, ça doit rouvrir une conversation". Soft-delete PAR USER : la
    // suppression masque la conversation pour CET user (l'autre la garde) en
    // l'ajoutant ici. La liste exclut les conv où je suis dans clearedFor.
    // Un nouveau message vide ce tableau → la conversation réapparaît pour
    // tout le monde (comportement type WhatsApp).
    clearedFor: {
      type: [{ type: mongoose.Schema.Types.ObjectId }],
      default: [],
    },
    ownerUnreadCount: { type: Number, default: 0 },
    sitterUnreadCount: { type: Number, default: 0 },
    ownerLastReadAt: { type: Date, default: null },
    sitterLastReadAt: { type: Date, default: null },
  },
  { timestamps: true }
);

// v23.1.200 — Conversations booking : exactement un des deux providers
// (sitter XOR walker) est defini, et ownerId est require.
// Conversations friendChat : participants[] obligatoire (au moins 2),
// les ownerId/sitterId/walkerId ne sont pas utilises.
conversationSchema.pre('validate', function (next) {
  // Branch friendChat (v23.1.200).
  if (this.friendChat === true) {
    if (!Array.isArray(this.participants) || this.participants.length < 2) {
      return next(
        new Error('Friend conversation must have at least 2 participants.'),
      );
    }
    return next();
  }
  // Branch booking classique (legacy v18.6).
  if (!this.ownerId) {
    return next(new Error('Booking conversation requires an ownerId.'));
  }
  const hasSitter = !!this.sitterId;
  const hasWalker = !!this.walkerId;
  if (hasSitter && hasWalker) {
    return next(
      new Error('Conversation cannot target both a sitter and a walker.'),
    );
  }
  if (!hasSitter && !hasWalker) {
    return next(
      new Error('Conversation must target either a sitter or a walker.'),
    );
  }
  next();
});

// Unique per (owner, sitter) when sitterId is set — partial index.
conversationSchema.index(
  { ownerId: 1, sitterId: 1 },
  { unique: true, partialFilterExpression: { sitterId: { $type: 'objectId' } } }
);
// Unique per (owner, walker) when walkerId is set — partial index.
conversationSchema.index(
  { ownerId: 1, walkerId: 1 },
  { unique: true, partialFilterExpression: { walkerId: { $type: 'objectId' } } }
);

module.exports = mongoose.model('Conversation', conversationSchema);
