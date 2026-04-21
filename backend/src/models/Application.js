const mongoose = require('mongoose');

const applicationSchema = new mongoose.Schema(
  {
    // Session v16.3b - support both sitter and walker applications.
    // Exactly ONE of sitterId/walkerId must be set (enforced by pre-validate).
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', default: null },
    walkerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Walker', default: null },
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true },
    bookingId: { type: mongoose.Schema.Types.ObjectId, ref: 'Booking', default: null },
    // Session v17.1 — stable reference back to the owner's Post that the
    // sitter/walker applied to. Frontend uses this id (not a fragile
    // multi-field fingerprint) to decide whether to show "Cancel" vs "Send
    // request" on a post card after the sitter logs back in. Indexed so
    // `getMyApplications` can cheaply aggregate per-post state later.
    postId: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', default: null, index: true },
    postBody: { type: String, default: '' },
    petName: { type: String, trim: true, default: '' },
    petIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Pet' }],
    description: { type: String, trim: true, default: '' },
    serviceDate: { type: Date, default: null },
    startDate: { type: Date, default: null },
    endDate: { type: Date, default: null },
    timeSlot: { type: String, trim: true, default: '' },
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
    duration: { type: Number, default: null },
    locationType: {
      type: String,
      enum: ['standard', 'large_city'],
      default: 'standard',
    },
    requestedRateType: {
      type: String,
      enum: ['hour', 'day', 'week', 'month'],
      default: null,
    },
    pricing: {
      basePrice: { type: Number, default: null },
      pricingTier: { type: String, enum: ['hourly', 'daily', 'weekly', 'monthly'], default: 'hourly' },
      appliedRate: { type: Number, default: 0 },
      totalHours: { type: Number, default: 0 },
      totalDays: { type: Number, default: 0 },
      addOns: [
        {
          type: { type: String, default: '' },
          description: { type: String, default: '' },
          amount: { type: Number, default: 0 },
          currency: { type: String, default: 'EUR' },
        },
      ],
      addOnsTotal: { type: Number, default: 0 },
      totalPrice: { type: Number, default: null },
      commission: { type: Number, default: null },
      netPayout: { type: Number, default: null },
      commissionRate: { type: Number, default: 0.2 },
      currency: { type: String, default: 'EUR' },
    },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected'],
      default: 'pending',
    },
  },
  { timestamps: true }
);

applicationSchema.index({ ownerId: 1, sitterId: 1, status: 1, requestFingerprint: 1 });
applicationSchema.index({ ownerId: 1, walkerId: 1, status: 1, requestFingerprint: 1 });

// Session v16.3b - require exactly one of sitterId / walkerId.
applicationSchema.pre('validate', function enforceExactlyOneProvider(next) {
  const hasSitter = !!this.sitterId;
  const hasWalker = !!this.walkerId;
  if (hasSitter === hasWalker) {
    return next(new Error('Application must reference exactly one of sitterId or walkerId.'));
  }
  next();
});

module.exports = mongoose.model('Application', applicationSchema);

