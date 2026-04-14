const mongoose = require('mongoose');

const referralSchema = new mongoose.Schema(
  {
    referrerId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    referrerRole: { type: String, enum: ['owner', 'sitter'], required: true },
    referredUserId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    referredRole: { type: String, enum: ['owner', 'sitter'], required: true },
    status: {
      type: String,
      enum: ['pending', 'completed'],
      default: 'pending',
      index: true,
    },
    creditAwarded: { type: Boolean, default: false },
    completedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

referralSchema.index({ referrerId: 1, referredUserId: 1 }, { unique: true });

module.exports = mongoose.model('Referral', referralSchema);
