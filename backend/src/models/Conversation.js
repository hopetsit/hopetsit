const mongoose = require('mongoose');

// v18.6 — walker conversation support.
// Avant v18.6 : sitterId required + unique{ownerId, sitterId}, donc les
// walkers ne pouvaient pas discuter avec owner (chat skip au moment de
// l'accept). Maintenant : EXACTEMENT un des deux (sitterId OU walkerId)
// est défini, enforcé par pre('validate'). Compound indexes séparés.
const conversationSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true },
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', default: null },
    walkerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Walker', default: null },
    lastMessage: { type: String, default: '' },
    lastMessageAt: { type: Date, default: Date.now },
    ownerUnreadCount: { type: Number, default: 0 },
    sitterUnreadCount: { type: Number, default: 0 },
    ownerLastReadAt: { type: Date, default: null },
    sitterLastReadAt: { type: Date, default: null },
  },
  { timestamps: true }
);

// Exactly one provider must be set (sitter XOR walker).
conversationSchema.pre('validate', function (next) {
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
