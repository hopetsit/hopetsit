const mongoose = require('mongoose');

const ownerCreditSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true, index: true },
    type: {
      type: String,
      enum: ['loyalty_3rd', 'referral_5eur'],
      required: true,
    },
    amount: { type: Number, required: true },
    currency: { type: String, default: 'EUR' },
    used: { type: Boolean, default: false, index: true },
    usedAt: { type: Date, default: null },
    usedOnBookingId: { type: mongoose.Schema.Types.ObjectId, ref: 'Booking', default: null },
    expiresAt: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model('OwnerCredit', ownerCreditSchema);
