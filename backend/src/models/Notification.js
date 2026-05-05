const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    recipientRole: {
      // Session v16.2 - added 'walker' so Mongoose stops silently rejecting
      // notifications destined to pet-walker accounts (root cause of empty
      // in-app notification lists for walkers).
      type: String,
      enum: ['owner', 'sitter', 'walker'],
      required: true,
      index: true,
    },
    recipientId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    actorRole: {
      // v23.1 part 50 — added 'system' for auto-generated notifications
      // (post-payment system messages, scheduled payouts confirmations,
      // etc.) where there is no human actor. The enum was previously
      // dropping these notifications with "actorRole `system` is not a
      // valid enum value" — root cause of "⚠️ Unable to create notification"
      // in Render logs.
      type: String,
      enum: ['owner', 'sitter', 'walker', 'system'],
      default: null,
    },
    actorId: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
    },
    // v23.1 part 50 — type enum dropped. The strict enum was a silent
    // velocity killer : every new template (NEW_MESSAGE, booking_paid_owner,
    // BOOKING_MUTUALLY_ACCEPTED, BOOKING_PAID_CHAT_UNLOCKED, NEW_REVIEW,
    // BOOKING_COMPLETED, payment_success, payment_failed, etc.) had to be
    // added BOTH to locale templates AND here. When the latter was forgotten,
    // Notification.create silently threw a validation error and the user
    // never saw the in-app bell badge — but every other channel (FCM push,
    // email) succeeded so the bug looked like a flaky receiver.
    //
    // The actual validation surface is the template catalog : if a template
    // exists for the type in the user's locale, it can be sent. Anything
    // else returns early in `pickTemplate`. Schema enum here was redundant
    // AND kept silently dropping legitimate types.
    type: {
      type: String,
      required: true,
      index: true,
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

