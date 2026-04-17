const mongoose = require('mongoose');

/**
 * Report — user-submitted abuse reports against a profile, comment,
 * chat message or review. Visible only to admins via /admin/reports.
 *
 * Daniel's spec: "Signaler" buttons on profile / comment / chat, and a
 * single admin view to triage them.
 */
const reportSchema = new mongoose.Schema(
  {
    reporterRole: {
      type: String,
      enum: ['owner', 'sitter'],
      required: true,
      index: true,
    },
    reporterId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    // What is being reported.
    targetType: {
      type: String,
      enum: ['profile', 'comment', 'message', 'review', 'post', 'photo'],
      required: true,
      index: true,
    },
    // The id of the target entity (user id for profile, comment id, etc.).
    targetId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    // Optional cross-reference ids for context (e.g. conversation id for a
    // message report, post id for a comment report).
    contextIds: {
      conversationId: { type: mongoose.Schema.Types.ObjectId, default: null },
      postId: { type: mongoose.Schema.Types.ObjectId, default: null },
      // For photo reports: the full URL of the offending image.
      photoUrl: { type: String, default: '' },
    },
    // Snapshot of the reported content so admins can see what was reported
    // even if the user deletes the message/comment afterwards.
    snapshot: {
      type: String,
      default: '',
      maxlength: 4000,
    },
    reason: {
      type: String,
      enum: [
        'spam',
        'harassment',
        'inappropriate',
        'fraud',
        'safety',
        'other',
      ],
      default: 'other',
      index: true,
    },
    details: {
      type: String,
      default: '',
      maxlength: 2000,
    },
    status: {
      type: String,
      enum: ['open', 'reviewing', 'resolved', 'dismissed'],
      default: 'open',
      index: true,
    },
    resolution: {
      type: String,
      default: '',
    },
    resolvedBy: { type: String, default: '' },
    resolvedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

reportSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model('Report', reportSchema);
