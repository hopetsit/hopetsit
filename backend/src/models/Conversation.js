const mongoose = require('mongoose');

const conversationSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true },
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', required: true },
    lastMessage: { type: String, default: '' },
    lastMessageAt: { type: Date, default: Date.now },
    ownerUnreadCount: { type: Number, default: 0 },
    sitterUnreadCount: { type: Number, default: 0 },
    ownerLastReadAt: { type: Date, default: null },
    sitterLastReadAt: { type: Date, default: null },
  },
  { timestamps: true }
);

conversationSchema.index({ ownerId: 1, sitterId: 1 }, { unique: true });

module.exports = mongoose.model('Conversation', conversationSchema);

