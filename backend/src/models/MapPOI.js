const mongoose = require('mongoose');

/**
 * MapPOI — Static points of interest on the PawMap.
 *
 * Sources:
 *   - 'seed'       : imported from OpenStreetMap during cold start
 *   - 'user'       : submitted by end-user, requires admin validation
 *   - 'admin'      : created directly by an admin (trusted)
 *
 * Categories map to the freemium Couche 1 tiles — all categories are visible
 * to free users. Premium users can chat around POIs and leave photos.
 */
const POI_CATEGORIES = [
  'vet',          // clinique vétérinaire
  'shop',         // animalerie / boutique
  'groomer',      // toiletteur
  'park',         // parc à chiens
  'beach',        // plage autorisée aux chiens
  'water',        // point d'eau potable
  'trainer',      // éducateur canin
  'hotel',        // pet-friendly hôtel
  'restaurant',   // pet-friendly restaurant
  'other',
];

const POI_STATUSES = ['pending', 'active', 'rejected', 'inactive'];

const mapPoiSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 120 },
    description: { type: String, default: '', maxlength: 1000 },

    category: {
      type: String,
      enum: POI_CATEGORIES,
      required: true,
      index: true,
    },

    // GeoJSON Point — mandatory for $near queries
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        required: true,
        validate: {
          validator: (v) =>
            Array.isArray(v) &&
            v.length === 2 &&
            typeof v[0] === 'number' &&
            typeof v[1] === 'number' &&
            v[0] >= -180 && v[0] <= 180 &&
            v[1] >= -90 && v[1] <= 90,
          message: 'coordinates must be [lng, lat] within valid ranges',
        },
      },
      city: { type: String, default: '', trim: true },
      country: { type: String, default: '', trim: true },
    },

    address: { type: String, default: '', trim: true },
    phone: { type: String, default: '', trim: true },
    website: { type: String, default: '', trim: true },
    openingHours: { type: String, default: '' }, // freeform ("Lun-Ven 9h-18h")

    // Provenance
    source: {
      type: String,
      enum: ['seed', 'user', 'admin'],
      default: 'user',
      index: true,
    },
    osmId: { type: String, default: null, index: true, sparse: true },

    // Submission metadata
    submittedBy: {
      type: mongoose.Schema.Types.ObjectId,
      refPath: 'submittedByModel',
      default: null,
    },
    submittedByModel: {
      type: String,
      enum: ['Owner', 'Sitter', 'Walker'],
      default: null,
    },

    // Admin moderation
    status: {
      type: String,
      enum: POI_STATUSES,
      default: 'pending',
      index: true,
    },
    validatedBy: { type: String, default: '' }, // admin email/id
    validatedAt: { type: Date, default: null },
    rejectionReason: { type: String, default: '' },

    // Community signals (filled by premium users)
    rating: { type: Number, default: 0, min: 0, max: 5 },
    reviewsCount: { type: Number, default: 0 },
    photosCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

// Indexes
mapPoiSchema.index({ location: '2dsphere' });
mapPoiSchema.index({ category: 1, status: 1 });
mapPoiSchema.index({ source: 1, createdAt: -1 });

// Strip invalid coordinates before save (same pattern as Owner/Walker)
mapPoiSchema.pre('save', function stripInvalidLocation(next) {
  if (!this.location || !this.location.coordinates) return next();
  const [lng, lat] = this.location.coordinates;
  const valid =
    typeof lng === 'number' &&
    typeof lat === 'number' &&
    lng >= -180 && lng <= 180 &&
    lat >= -90 && lat <= 90;
  if (!valid) {
    const err = new Error('Invalid coordinates for MapPOI');
    err.status = 400;
    return next(err);
  }
  return next();
});

module.exports = mongoose.model('MapPOI', mapPoiSchema);
module.exports.POI_CATEGORIES = POI_CATEGORIES;
module.exports.POI_STATUSES = POI_STATUSES;
