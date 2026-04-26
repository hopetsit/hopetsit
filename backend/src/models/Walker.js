const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { encrypt, isEncrypted } = require('../utils/encryption');

/**
 * Walker model — third user role alongside Owner and Sitter.
 *
 * A Walker is a professional dog walker whose service model is per-walk
 * (duration-based pricing), distinct from a Sitter whose model is per-stay
 * (hourly/daily/weekly/monthly). Walkers share the same auth, moderation,
 * identity verification, boost, referral and Stripe Connect infrastructure
 * as Sitters to keep the platform coherent.
 *
 * Pricing: `walkRates` is an array of { durationMinutes, basePrice, currency, enabled }.
 * `durationMinutes` must be a multiple of 15, between 15 and 300 (5 hours).
 * This lets each walker configure exactly the durations they offer.
 */
const walkRateEntrySchema = new mongoose.Schema(
  {
    durationMinutes: {
      type: Number,
      required: true,
      min: 15,
      max: 300,
      validate: {
        validator: (v) => Number.isInteger(v) && v % 15 === 0,
        message: 'durationMinutes must be an integer multiple of 15, between 15 and 300.',
      },
    },
    basePrice: { type: Number, required: true, min: 0 },
    currency: { type: String, enum: ['EUR', 'USD'], default: 'EUR' },
    enabled: { type: Boolean, default: true },
  },
  { _id: false }
);

const walkerSchema = new mongoose.Schema(
  {
    // Stable identifier used across role switches (owner <-> sitter <-> walker).
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
    countryCode: { type: String, default: '' },
    country: { type: String, default: '', uppercase: true, trim: true },
    password: { type: String, required: true, minlength: 8 },
    language: { type: String, default: '' },
    currency: { type: String, enum: ['EUR', 'USD'], default: 'EUR' },
    address: { type: String, default: '' },
    bio: { type: String, default: '' },

    // Walker-specific skills (free text), e.g. "Large dogs, reactive dogs, puppies".
    skills: { type: String, default: '' },

    // Terms & conditions
    acceptedTerms: { type: Boolean, default: false },
    termsAcceptedAt: { type: Date, default: null },
    termsVersion: { type: String, default: '' },

    // Service list — by convention walkers always include 'dog_walking' and may
    // add specializations like 'group_walk', 'solo_walk', 'puppy_walk', etc.
    service: { type: [String], default: ['dog_walking'] },

    verified: { type: Boolean, default: false },
    isStaff: { type: Boolean, default: false, index: true },
    rating: { type: Number, default: 0 },
    reviewsCount: { type: Number, default: 0 },

    // External authentication information
    firebaseUid: { type: String, default: null, index: true },
    authProvider: { type: String, enum: ['password', 'google', 'apple'], default: 'password' },
    // Firebase Cloud Messaging registration tokens (one per device).
    fcmTokens: { type: [String], default: [] },

    // Walker-specific: accepted pet sizes/types.
    acceptedPetTypes: {
      type: [String],
      enum: ['dog_small', 'dog_medium', 'dog_large', 'cat', 'other'],
      default: ['dog_small', 'dog_medium', 'dog_large'],
    },
    // Maximum number of pets per walk (group walks).
    maxPetsPerWalk: { type: Number, default: 1, min: 1, max: 10 },

    // Insurance (liability insurance is typically required for professional walkers).
    hasInsurance: { type: Boolean, default: false },
    // Stored encrypted (AES-256-GCM) like identity documents. Never exposed raw.
    insuranceCertUrl: { type: String, default: '' },
    insuranceExpiresAt: { type: Date, default: null },

    // Coverage — city + radius in km around walker's location.
    coverageCity: { type: String, default: '' },
    coverageRadiusKm: { type: Number, default: 3, min: 1, max: 50 },

    // Pricing — per-walk duration.
    walkRates: { type: [walkRateEntrySchema], default: [] },

    // Session v16.2 — pickup preferences. Walkers work at the owner's side by
    // default; this toggle lets a walker declare whether they pick up the dog
    // at the owner's home. Exposed in the edit-profile screen.
    pickupPreferences: {
      atOwner: { type: Boolean, default: true },
    },

    // Optional default walk duration in minutes (for UI prefill).
    defaultWalkDurationMinutes: {
      type: Number,
      default: 30,
      validate: {
        validator: (v) => !v || (Number.isInteger(v) && v >= 15 && v <= 300 && v % 15 === 0),
        message: 'defaultWalkDurationMinutes must be a multiple of 15 between 15 and 300.',
      },
    },

    // Availability calendar. Dates are stored as UTC midnight (same convention as Sitter).
    availableDates: { type: [Date], default: [] },
    unavailableDates: { type: [Date], default: [] },
    // Recurring weekly time-slots during which the walker is available.
    availableTimeSlots: [
      {
        day: {
          type: String,
          enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
          required: true,
        },
        startHour: { type: Number, min: 0, max: 23, required: true },
        endHour: { type: Number, min: 1, max: 24, required: true },
        _id: false,
      },
    ],

    // Identity verification — same structure as Sitter for parity.
    // v21.1.1 — Stripe Identity removed. Identity verification now uses manual upload.
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
      provider: { type: String, default: '' },
    },

    // Top-Walker program (analog to Sitter's Top-Sitter flag).
    isTopWalker: { type: Boolean, default: false },
    completedWalksCount: { type: Number, default: 0 },
    averageRating: { type: Number, default: 0 },

    // Coin Boost — profile boosting system (shared across roles).
    boostExpiry: { type: Date, default: null },
    boostTier: {
      type: String,
      enum: [null, 'bronze', 'silver', 'gold', 'platinum'],
      default: null,
    },
    boostPurchases: [
      {
        tier: { type: String },
        amount: { type: Number },
        currency: { type: String, default: 'EUR' },
        days: { type: Number },
        purchasedAt: { type: Date, default: Date.now },
        paymentProvider: { type: String },
        paymentId: { type: String },
        kind: { type: String, default: 'profile' }, // 'profile' | 'map'
      },
    ],
    // Phase 5 — PawMap boost: pin highlighted on the map.
    mapBoostExpiry: { type: Date, default: null },
    mapBoostTier: {
      type: String,
      enum: [null, 'bronze', 'silver', 'gold', 'platinum'],
      default: null,
    },

    // Referral program
    referralCode: { type: String, unique: true, sparse: true, index: true },
    referredBy: { type: String, default: '' },

    // Admin moderation
    status: {
      type: String,
      enum: ['active', 'suspended', 'banned'],
      default: 'active',
      index: true,
    },
    banReason: { type: String, default: '' },
    bannedAt: { type: Date, default: null },

    // Reviews feedback (inline simple feedback list)
    feedback: [
      {
        reviewerName: { type: String, default: '' },
        rating: { type: Number, default: 0 },
        comment: { type: String, default: '' },
        createdAt: { type: Date, default: Date.now },
      },
    ],

    // Avatar
    avatar: {
      url: { type: String, default: '' },
      publicId: { type: String, default: '' },
    },

    // Payout destinations (same options as Sitter).
    paypalEmail: { type: String, default: '' },
    ibanHolder: { type: String, default: '' },
    ibanNumber: { type: String, default: '' },
    ibanBic: { type: String, default: '' },
    ibanVerified: { type: Boolean, default: false },
    // v21 — Airwallex Beneficiary tied to this IBAN. Created on first IBAN
    // save when PAYMENT_PROVIDER=airwallex ; reused for every payout.
    airwallexBeneficiaryId: { type: String, default: '' },
    payoutMethod: {
      type: String,
      enum: ['stripe', 'paypal', 'iban'],
      default: 'stripe',
    },
    // v19.0 — Wallet Vinted-style (voir Sitter.js pour le détail).
    walletBalance: { type: Number, default: 0, min: 0 },
    walletCurrency: { type: String, default: 'EUR' },

    // v21.1.1 — Stripe Connect fields removed.

    // Saved card (optional, same structure as Sitter)
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

    // Location for geospatial queries (GeoJSON Point format). Optional.
    // Only store when valid [lng, lat] coordinates exist; field is omitted otherwise
    // so the 2dsphere index never sees coordinates: null.
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
          validator: function (v) {
            return (
              !v ||
              (Array.isArray(v) &&
                v.length === 2 &&
                typeof v[0] === 'number' &&
                typeof v[1] === 'number' &&
                v[0] >= -180 &&
                v[0] <= 180 &&
                v[1] >= -90 &&
                v[1] <= 90)
            );
          },
          message: 'Coordinates must be [longitude, latitude] with valid ranges.',
        },
      },
      city: { type: String, default: '', trim: true },
      locationType: {
        type: String,
        enum: ['standard', 'large_city'],
        default: 'standard',
      },
    },
  },
  { timestamps: true }
);

// Strip invalid location before save so MongoDB 2dsphere index never sees coordinates: null.
walkerSchema.pre('save', function stripInvalidLocation(next) {
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

// Hash password on create/update.
walkerSchema.pre('save', async function hashPassword(next) {
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

walkerSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

// Encrypt sensitive payout and insurance fields at rest (AES-256-GCM).
walkerSchema.pre('save', function encryptSensitive(next) {
  if (this.isModified('paypalEmail') && this.paypalEmail && !isEncrypted(this.paypalEmail)) {
    this.paypalEmail = encrypt(this.paypalEmail);
  }
  if (this.isModified('ibanNumber') && this.ibanNumber && !isEncrypted(this.ibanNumber)) {
    this.ibanNumber = encrypt(this.ibanNumber);
  }
  if (
    this.isModified('insuranceCertUrl') &&
    this.insuranceCertUrl &&
    !isEncrypted(this.insuranceCertUrl)
  ) {
    this.insuranceCertUrl = encrypt(this.insuranceCertUrl);
  }
  next();
});

// Geospatial index for "walkers nearby" queries.
walkerSchema.index({ location: '2dsphere' });

// Compound index to quickly find boosted walkers on the PawMap.
walkerSchema.index({ mapBoostExpiry: 1, boostExpiry: 1 });

module.exports = mongoose.model('Walker', walkerSchema);
