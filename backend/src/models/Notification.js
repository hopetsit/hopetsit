const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    recipientRole: {
      type: String,
      enum: ['owner', 'sitter'],
      required: true,
      index: true,
    },
    recipientId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    actorRole: {
      type: String,
      enum: ['owner', 'sitter'],
      default: null,
    },
    actorId: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
    },
    type: {
      type: String,
      required: true,
      index: true,
      enum: [
        'post_like',
        'post_comment',
        'message_new',
        'application_new',
        'application_accepted',
        'application_rejected',
        'booking_new',
        'booking_accepted',
        'booking_rejected',
        'booking_paid',
      ],
    },
    title: { type: String, default: '' },
    body: { type: String, default: '' },
    data: { type: Object, default: {} }, // entity references (postId, conversationId, bookingId, applicationId, etc.)
    readAt: { type: Date, default: null, index: true },
  },
  { timestamps: true }
);

notificationSchema.index({ recipientRole: 1, recipientId: 1, createdAt: -1 });
notificationSchema.index({ recipientRole: 1, recipientId: 1, readAt: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);

