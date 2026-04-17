const mongoose = require('mongoose');

/**
 * MapReport — Ephemeral user-submitted signals on the PawMap.
 *
 * TTL: 48 hours from creation (MongoDB auto-deletes via TTL index on expiresAt).
 * Visibility: Free users can SEE vets/parks/water POIs (Couche 1) but
 *             cannot see nor create reports — reports are a Premium feature (Couche 2).
 * Moderation: any user can flag a report; >= 3 flags hides it pending admin review.
 */
const REPORT_TYPES = [
  'poop',           // caca à ramasser
  'pee',            // pipi / marquage intense
  'water_active',   // point d'eau fonctionnel (fontaine ouverte)
  'water_broken',   // point d'eau cassé
  'hazard',         // danger (verre, piège, produit)
  'aggressive_dog', // chien agressif non tenu
  'lost_pet',       // animal perdu repéré ici
  'found_pet',      // animal trouvé
  'other',
];

const REPORT_TTL_MS = 48 * 60 * 60 * 1000; // 48h

const mapReportSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: REPORT_TYPES,
      required: true,
      index: true,
    },
    note: { type: String, default: '', maxlength: 500 },
    photoUrl: { type: String, default: '' },

    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number],
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
      city: { type: String, default: '' },
    },

    // Reporter
    reporterId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'reporterModel',
      index: true,
    },
    reporterModel: {
      type: String,
      enum: ['Owner', 'Sitter', 'Walker'],
      required: true,
    },

    // TTL — MongoDB auto-deletes documents whose expiresAt < now
    expiresAt: {
      type: Date,
      required: true,
      default: () => new Date(Date.now() + REPORT_TTL_MS),
    },

    // Community verification (Premium users can confirm a report is still valid
    // which extends its expiresAt by 12h, up to a max of 96h total)
    confirmations: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, required: true },
        userModel: { type: String, enum: ['Owner', 'Sitter', 'Walker'], required: true },
        at: { type: Date, default: Date.now },
      },
    ],

    // Moderation
    flags: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, required: true },
        userModel: { type: String, enum: ['Owner', 'Sitter', 'Walker'], required: true },
        reason: { type: String, default: '' },
        at: { type: Date, default: Date.now },
      },
    ],
    hidden: { type: Boolean, default: false, index: true }, // set true when flags.length >= 3
  },
  { timestamps: true }
);

// TTL index — MongoDB deletes docs when expiresAt < now.
// Note: TTL has ~60s granularity; a secondary cron sweeps for near-expired docs
// to keep the UI clean (see services/mapReportTtlScheduler.js).
mapReportSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
mapReportSchema.index({ location: '2dsphere' });
mapReportSchema.index({ type: 1, hidden: 1, createdAt: -1 });

module.exports = mongoose.model('MapReport', mapReportSchema);
module.exports.REPORT_TYPES = REPORT_TYPES;
module.exports.REPORT_TTL_MS = REPORT_TTL_MS;
