const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true },
    // Session v16-owner-walker — the booking now targets either a Sitter
    // (traditional garde/garderie) OR a Walker (dog_walking). Exactly one
    // of the two must be set, enforced by the pre-save validator below.
    // Legacy bookings keep `sitterId` populated, so no migration needed.
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', default: null },
    walkerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Walker', default: null },
    petIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Pet' }], // Array of pet IDs
    description: { type: String, default: '' },
    date: { type: String, required: true },
    startDate: { type: String, default: null },
    endDate: { type: String, default: null },
    timeSlot: { type: String, required: true },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected', 'agreed', 'paid', 'completed', 'payment_failed', 'cancelled', 'refunded'],
      default: 'pending',
    },
    // Payment status - tracks payment state separately from booking status
    paymentStatus: {
      type: String,
      enum: ['pending', 'paid', 'failed', 'refunded', 'cancelled', 'refund'],
      default: 'pending',
    },
    // Payout status - tracks payout to sitter/walker separately from payment capture.
    // Session v17 — 'scheduled' was already written by schedulePayoutForBooking
    // but silently rejected by the enum validator on save. Added so the
    // scheduler state is actually persisted and findable via
    // { payoutStatus: 'scheduled' } queries.
    payoutStatus: {
      type: String,
      // v18.5 — #3 : 'held' = le owner a payé la totalité MAIS le provider
      // n'avait pas encore configuré IBAN/PayPal au moment de la capture.
      // L'argent dort sur le compte plateforme. Le scheduler check
      // périodiquement si le provider a depuis configuré, et si oui
      // déclenche le transfert en marquant 'scheduled' → 'completed'.
      enum: ['pending', 'scheduled', 'processing', 'completed', 'failed', 'held'],
      default: 'pending',
    },
    // v18.5 — #3 hold admin : montants dormants en attente que le provider
    // configure son IBAN ou PayPal. `heldAmount` = part provider (netPayout,
    // = 80% du total). `heldSince` = quand on a marqué held (pour tracking
    // + reporting). `heldReleasedAt` = quand on a débloqué (pour audit).
    heldAmount: { type: Number, default: null },
    heldSince: { type: Date, default: null, index: true },
    heldReleasedAt: { type: Date, default: null },
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
    // Session v17 — actual datetime at which the scheduler should release
    // the funds. Set by schedulePayoutForBooking from the booking start
    // date (+ time slot in v17c, hour-exact). The scheduler query uses
    // { $lte: now } on this field so precise hour-exact releases work.
    // Indexed because the scheduler polls this column every few minutes.
    scheduledPayoutAt: {
      type: Date,
      default: null,
      index: true,
    },
    payoutError: {
      type: String,
      default: null,
    },
    // Self-cancellation (72h window)
    cancelledAt: { type: Date, default: null },
    cancelledBy: { type: String, enum: ['owner', 'sitter', null], default: null },
    cancellationReason: { type: String, default: null },
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
// Session v16-owner-walker — mirror index for walker lookups.
bookingSchema.index({ ownerId: 1, walkerId: 1, status: 1, requestFingerprint: 1 });

// Session v16-owner-walker — enforce exactly one provider target. Without
// this, a buggy caller could persist a booking with neither field set (the
// booking would end up linked to nobody) or with both set (ambiguous which
// provider gets paid). Validator is pre('validate') so error surfaces on
// save() before any downstream $set does weird stuff.
bookingSchema.pre('validate', function (next) {
  const hasSitter = !!this.sitterId;
  const hasWalker = !!this.walkerId;
  if (hasSitter && hasWalker) {
    return next(
      new Error('Booking cannot target both a sitter and a walker.'),
    );
  }
  if (!hasSitter && !hasWalker) {
    return next(
      new Error('Booking must target either a sitter or a walker.'),
    );
  }
  next();
});

module.exports = mongoose.model('Booking', bookingSchema);

