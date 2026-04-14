const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true },
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', required: true },
    petIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Pet' }], // Array of pet IDs
    description: { type: String, default: '' },
    date: { type: String, required: true },
    startDate: { type: String, default: null },
    endDate: { type: String, default: null },
    timeSlot: { type: String, required: true },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected', 'agreed', 'paid', 'payment_failed', 'cancelled', 'refunded'],
      default: 'pending',
    },
    // Payment status - tracks payment state separately from booking status
    paymentStatus: {
      type: String,
      enum: ['pending', 'paid', 'failed', 'refunded', 'cancelled', 'refund'],
      default: 'pending',
    },
    // Payout status - tracks payout to sitter separately from payment capture
    payoutStatus: {
      type: String,
      enum: ['pending', 'processing', 'completed', 'failed'],
      default: 'pending',
    },
    // Status change timestamps
    acceptedAt: { type: Date, default: null },
    rejectedAt: { type: Date, default: null },
    agreedAt: { type: Date, default: null },
    paidAt: { type: Date, default: null },
    paymentFailedAt: { type: Date, default: null },
    // Payment provider and gateway-specific identifiers
    paymentProvider: {
      type: String,
      enum: ['stripe', 'paypal'],
      default: null,
    },
    // Stripe payment information
    stripePaymentIntentId: {
      type: String,
      default: null,
    },
    stripeChargeId: {
      type: String,
      default: null,
    },
    petsitterConnectedAccountId: {
      type: String,
      default: null,
    },
    // PayPal payment information
    paypalOrderId: {
      type: String,
      default: null,
    },
    paypalCaptureId: {
      type: String,
      default: null,
    },
    // PayPal payout information (sitter earnings)
    sitterPaypalEmail: {
      type: String,
      default: '',
    },
    payoutId: {
      type: String,
      default: null,
    },
    payoutBatchId: {
      type: String,
      default: null,
    },
    payoutAt: {
      type: Date,
      default: null,
    },
    payoutError: {
      type: String,
      default: null,
    },
    // Cancellation tracking (for mutual agreement requirement)
    cancellation: {
      ownerRequested: { type: Boolean, default: false },
      sitterRequested: { type: Boolean, default: false },
      ownerConfirmed: { type: Boolean, default: false },
      sitterConfirmed: { type: Boolean, default: false },
      requestedAt: { type: Date, default: null },
      confirmedAt: { type: Date, default: null },
      refundId: { type: String, default: null },
    },
    // Service details
    serviceType: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    houseSittingVenue: {
      type: String,
      enum: ['owners_home', 'sitters_home'],
      default: null,
    },
    requestFingerprint: {
      type: String,
      default: null,
      index: true,
    },
    duration: {
      type: Number, // Duration in minutes (30, 45, 60, etc.) or nights for overnight stay
      default: null,
    },
    locationType: {
      type: String,
      enum: ['standard', 'large_city'],
      default: 'standard',
    },
    // Pricing information
    pricing: {
      basePrice: { type: Number, required: true },
      pricingTier: { type: String, enum: ['hourly', 'weekly', 'monthly'], default: 'hourly' },
      appliedRate: { type: Number, default: 0 },
      totalHours: { type: Number, default: 0 },
      totalDays: { type: Number, default: 0 },
      addOns: [
        {
          type: { type: String, default: '' }, // extraAnimals, medicationSpecialCare, additionalDog, lateEveningWalk
          description: { type: String, default: '' },
          amount: { type: Number, default: 0 },
          currency: { type: String, default: 'EUR' },
        },
      ],
      addOnsTotal: { type: Number, default: 0 },
      totalPrice: { type: Number, required: true }, // Total price owner pays
      commission: { type: Number, required: true }, // 20% platform commission
      netPayout: { type: Number, required: true }, // Amount sitter receives (80%)
      commissionRate: { type: Number, default: 0.2 }, // 20%
      currency: { type: String, default: 'EUR' },
    },
    // Recommended price range at time of booking (for reference)
    recommendedPriceRange: {
      min: { type: Number, default: null },
      max: { type: Number, default: null },
      currency: { type: String, default: 'EUR' },
    },
  },
  { timestamps: true }
);

bookingSchema.index({ ownerId: 1, sitterId: 1, status: 1, requestFingerprint: 1 });

module.exports = mongoose.model('Booking', bookingSchema);

