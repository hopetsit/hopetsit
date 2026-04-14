const mongoose = require('mongoose');

const reviewSchema = new mongoose.Schema(
  {
    reviewerId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'reviewerModel',
    },
    reviewerModel: {
      type: String,
      required: true,
      enum: ['Owner', 'Sitter'],
    },
    revieweeId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'revieweeModel',
    },
    revieweeModel: {
      type: String,
      required: true,
      enum: ['Owner', 'Sitter'],
    },
    rating: { type: Number, required: true, min: 1, max: 5 },
    comment: { type: String, default: '', maxlength: 500 },
    // Sprint 7 step 4 — mutual reviews tied to a booking + one reply allowed.
    bookingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      default: null,
      index: true,
    },
    reply: {
      body: { type: String, default: '', maxlength: 500 },
      repliedAt: { type: Date, default: null },
    },
    // Sprint 7 step 5 — admin moderation fields.
    hidden: { type: Boolean, default: false, index: true },
    hiddenReason: { type: String, default: '' },
    hiddenAt: { type: Date, default: null },
    reportedCount: { type: Number, default: 0, index: true },
  },
  { timestamps: true }
);

// Sprint 7 step 4 — one review per reviewer per booking.
reviewSchema.index(
  { bookingId: 1, reviewerId: 1 },
  { unique: true, partialFilterExpression: { bookingId: { $type: 'objectId' } } }
);

module.exports = mongoose.model('Review', reviewSchema);

