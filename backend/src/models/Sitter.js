const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { encrypt, isEncrypted } = require('../utils/encryption');

const sitterSchema = new mongoose.Schema(
  {
    // Stable identifier used across role switches (owner <-> sitter)
    // Defaults to this document's _id for new accounts.
    oldId: {
      type: mongoose.Schema.Types.ObjectId,
      index: true,
      default: function () {
        return this._id;
      },
    },
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    mobile: { type: String, default: '' },
    countryCode: { type: String, default: '' }, // e.g. "+1", "+44"
    country: { type: String, default: '', uppercase: true, trim: true }, // ISO 3166-1 alpha-2, e.g. "FR"
    password: { type: String, required: true, minlength: 8 },
    language: { type: String, default: '' },
    currency: { type: String, enum: ['EUR', 'USD'], default: 'EUR' },
    address: { type: String, default: '' },
    rate: { type: String, default: '' },
    skills: { type: String, default: '' },
    bio: { type: String, default: '' },
    acceptedTerms: { type: Boolean, default: false },
    // Sprint 5 step 4 — traceability of T&C acceptance.
    termsAcceptedAt: { type: Date, default: null },
    termsVersion: { type: String, default: '' },
    service: { type: [String], default: [] },
    verified: { type: Boolean, default: false },
    rating: { type: Number, default: 0 },
    reviewsCount: { type: Number, default: 0 },
    // External authentication information
    firebaseUid: { type: String, default: null, index: true },
    authProvider: { type: String, enum: ['password', 'google', 'apple'], default: 'password' },
    // Firebase Cloud Messaging registration tokens (one per device). Deduplicated via $addToSet.
    fcmTokens: { type: [String], default: [] },
    // Sprint 5 step 2 — where the sitter accepts to work.
    canServiceAtOwner: { type: Boolean, default: true },
    canServiceAtSitter: { type: Boolean, default: true },
    // Sprint 7 step 2 — Top sitter flag (completed>=20 && avgRating>4.5).
    isTopSitter: { type: Boolean, default: false },
    completedServicesCount: { type: Number, default: 0 },
    averageRating: { type: Number, default: 0 },
    // Sprint 7 step 3 — referral program.
    referralCode: { type: String, unique: true, sparse: true, index: true },
    referredBy: { type: String, default: '' },
    // Sprint 5 step 6 — availability calendar. Dates are stored as UTC midnight.
    availableDates: { type: [Date], default: [] },
    unavailableDates: { type: [Date], default: [] },
    // Sprint 5 step 7 — identity verification. documentUrl is stored encrypted
    // (AES-256-GCM via utils/encryption) and is only readable by the sitter
    // themselves and admins. Never exposed via sanitizeUser.
    identityVerification: {
      status: {
        type: String,
        enum: ['none', 'pending', 'verified', 'rejected'],
        default: 'none',
      },
      documentUrl: { type: String, default: '' },
      submittedAt: { type: Date, default: null },
      reviewedAt: { type: Date, default: null },
      rejectionReason: { type: String, default: '' },
    },
    avatar: {
      url: { type: String, default: '' },
      publicId: { type: String, default: '' },
    },
    // PayPal payout destination email for this sitter
    paypalEmail: { type: String, default: '' },
    // IBAN bank transfer payout (like Vinted)
    ibanHolder: { type: String, default: '' },
    ibanNumber: { type: String, default: '' },
    ibanBic: { type: String, default: '' },
    ibanVerified: { type: Boolean, default: false },
    payoutMethod: { type: String, enum: ['stripe', 'paypal', 'iban'], default: 'stripe' },
    feedback: [
      {
        reviewerName: { type: String, default: '' },
        rating: { type: Number, default: 0 },
        comment: { type: String, default: '' },
        createdAt: { type: Date, default: Date.now },
      },
    ],
    hourlyRate: { type: Number, default: 0 },
    dailyRate: { type: Number, default: 0 },
    weeklyRate: { type: Number, default: 0 },
    monthlyRate: { type: Number, default: 0 },
    defaultRateType: {
      type: String,
      enum: ['hour', 'day', 'week', 'month'],
      default: 'hour',
    },
    // Location for geospatial queries (GeoJSON Point format). Optional.
    // Only store when valid [lng, lat] coordinates exist; otherwise field is omitted (2dsphere index).
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number],
        default: undefined,
        validate: {
          validator: function(v) {
            return !v || (Array.isArray(v) && v.length === 2 &&
                   typeof v[0] === 'number' && typeof v[1] === 'number' &&
                   v[0] >= -180 && v[0] <= 180 && v[1] >= -90 && v[1] <= 90);
          },
          message: 'Coordinates must be [longitude, latitude] with valid ranges.',
        },
      },
      city: { type: String, default: '', trim: true },
      locationType: { type: String, enum: ['standard', 'large_city'], default: 'standard' },
    },
    servicePricing: {
      homeVisit: {
        basePrice: { type: Number, default: null },
        currency: { type: String, default: 'EUR' },
      },
      dogWalking30: {
        basePrice: { type: Number, default: null },
        currency: { type: String, default: 'EUR' },
      },
      dogWalking60: {
        basePrice: { type: Number, default: null },
        currency: { type: String, default: 'EUR' },
      },
      overnightStay: {
        basePrice: { type: Number, default: null },
        currency: { type: String, default: 'EUR' },
      },
      longStay: {
        basePrice: { type: Number, default: null },
        currency: { type: String, default: 'EUR' },
      },
    },
    // Stripe Connect account information
    stripeConnectAccountId: {
      type: String,
      default: null,
    },
    stripeConnectAccountStatus: {
      type: String,
      enum: ['not_connected', 'pending', 'restricted', 'active'],
      default: 'not_connected',
    },
    card: {
      holderName: { type: String, default: '' },
      number: { type: String, default: '' },
      maskedNumber: { type: String, default: '' },
      last4: { type: String, default: '' },
      brand: { type: String, default: '' },
      expMonth: { type: Number, default: null },
      expYear: { type: Number, default: null },
      expDate: { type: String, default: '' },
      cvc: { type: String, default: '' },
      updatedAt: { type: Date, default: null },
    },
  },
  { timestamps: true }
);

// Strip invalid location before save so MongoDB 2dsphere index never sees coordinates: null
sitterSchema.pre('save', function stripInvalidLocation(next) {
  if (!this.location) return next();
  const coords = this.location.coordinates;
  const valid =
    Array.isArray(coords) &&
    coords.length === 2 &&
    typeof coords[0] === 'number' &&
    typeof coords[1] === 'number' &&
    coords[0] >= -180 &&
    coords[0] <= 180 &&
    coords[1] >= -90 &&
    coords[1] <= 90;
  if (!valid) {
    this.location = undefined;
  }
  next();
});

sitterSchema.pre('save', async function hashPassword(next) {
  if (!this.isModified('password')) {
    return next();
  }

  try {
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    return next();
  } catch (error) {
    return next(error);
  }
});

sitterSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

// Encrypt sensitive payout fields at rest (AES-256-GCM).
sitterSchema.pre('save', function encryptSensitive(next) {
  if (this.isModified('paypalEmail') && this.paypalEmail && !isEncrypted(this.paypalEmail)) {
    this.paypalEmail = encrypt(this.paypalEmail);
  }
  if (this.isModified('ibanNumber') && this.ibanNumber && !isEncrypted(this.ibanNumber)) {
    this.ibanNumber = encrypt(this.ibanNumber);
  }
  next();
});

// Create geospatial index for location queries (e.g., finding nearby sitters)
sitterSchema.index({ 'location': '2dsphere' });

module.exports = mongoose.model('Sitter', sitterSchema);

