const mongoose = require('mongoose');

const attachmentSchema = new mongoose.Schema(
  {
    url: { type: String, required: true, trim: true },
    publicId: { type: String, required: true, trim: true },
    resourceType: { type: String, default: 'image', trim: true },
    format: { type: String, default: '', trim: true },
    bytes: { type: Number, default: null },
    width: { type: Number, default: null },
    height: { type: Number, default: null },
    duration: { type: Number, default: null },
    thumbnailUrl: { type: String, default: '', trim: true },
    originalFilename: { type: String, default: '', trim: true },
  },
  { _id: false }
);

const messageSchema = new mongoose.Schema(
  {
    conversationId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Conversation',
      required: true,
    },
    senderRole: {
      // v18.6 — walker + system support.
      // 'system' est utilisé pour les messages auto (ex: chat unlock welcome).
      type: String,
      enum: ['owner', 'sitter', 'walker', 'system'],
      required: true,
    },
    senderId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
    },
    body: {
      type: String,
      trim: true,
      default: '',
    },
    attachments: {
      type: [attachmentSchema],
      default: [],
    },
    // Special content types; 'text' is the default, 'phone_share' marks an
    // explicit post-payment phone-number share (see sprint3/step6).
    type: {
      type: String,
      enum: ['text', 'attachment', 'phone_share'],
      default: 'text',
    },
    // v19.1.3 — soft-delete so history stays available for admin moderation
    // even after the sender removes the message on their phone.
    deletedAt: { type: Date, default: null },
    deletedBy: {
      type: String,
      enum: ['sender', 'admin', null],
      default: null,
    },
    // v23.1 part 76 — Daniel : "messages auto envoye en double". The
    // v23.1.65 idempotency guard wrote { metadata: { kind, bookingId,
    // intentId } } on each system message and queried it back to skip
    // duplicates. Problem : Message had no `metadata` field defined,
    // so Mongoose strict-mode dropped it. Every payment-confirmed pair
    // got duplicated on webhook retry. Adding a Mixed metadata field
    // makes the dedup actually persist + match.
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
  },
  { timestamps: true }
);

messageSchema.index({ conversationId: 1, createdAt: 1 });
// v23.1 part 76 — quick dedup lookup by bookingId in metadata.
messageSchema.index({ 'metadata.bookingId': 1, senderRole: 1 });

module.exports = mongoose.model('Message', messageSchema);

