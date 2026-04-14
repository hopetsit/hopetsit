const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const ownerSchema = new mongoose.Schema(
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
    bio: { type: String, default: '' },
    skills: { type: String, default: '' },
    acceptedTerms: { type: Boolean, default: false },
    // Sprint 5 step 4 — traceability of T&C acceptance.
    termsAcceptedAt: { type: Date, default: null },
    termsVersion: { type: String, default: '' },
    service: { type: [String], default: [] },
    verified: { type: Boolean, default: false },
    // External authentication information
    firebaseUid: { type: String, default: null, index: true },
    authProvider: { type: String, enum: ['password', 'google', 'apple'], default: 'password' },
    // Firebase Cloud Messaging registration tokens (one per device). Deduplicated via $addToSet.
    fcmTokens: { type: [String], default: [] },
    // Sprint 5 step 2 — where the owner is willing to have the service happen.
    servicePreferences: {
      atOwner: { type: Boolean, default: true },  // service happens at the owner's home
      atSitter: { type: Boolean, default: false }, // service happens at the sitter's home
    },
    avatar: {
      url: { type: String, default: '' },
      publicId: { type: String, default: '' },
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
    },
  },
  { timestamps: true }
);

// Create geospatial index for location queries (e.g., finding nearby sitters)
ownerSchema.index({ 'location': '2dsphere' });

// Strip invalid location before save so MongoDB 2dsphere index never sees coordinates: null
ownerSchema.pre('save', function stripInvalidLocation(next) {
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

ownerSchema.pre('save', async function hashPassword(next) {
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

ownerSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

module.exports = mongoose.model('Owner', ownerSchema);

