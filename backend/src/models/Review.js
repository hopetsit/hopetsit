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
    comment: { type: String, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Review', reviewSchema);

