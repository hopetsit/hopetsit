const mongoose = require('mongoose');

const postSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true },
    postType: {
      type: String,
      enum: ['request', 'media'],
      default: 'request',
      required: true,
    },
    body: {
      type: String,
      default: '',
      trim: true,
    },
    // Optional booking-related dates for this post
    startDate: {
      type: Date,
      default: null,
    },
    endDate: {
      type: Date,
      default: null,
    },
    serviceTypes: [
      {
        type: String,
        trim: true,
      },
    ],
    houseSittingVenue: {
      type: String,
      enum: ['owners_home', 'sitters_home'],
      default: null,
    },
    // Associated pet for this post (optional)
    petId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Pet',
      default: null,
    },
    // Optional location object as provided by frontend (no geo index needed here)
    location: {
      type: Object,
      default: null,
    },
    // Additional notes from owner (optional)
    notes: {
      type: String,
      default: '',
      trim: true,
    },
    images: [
      {
        url: { type: String, default: '' },
        publicId: { type: String, default: '' },
        uploadedAt: { type: Date, default: Date.now },
      },
    ],
    videos: [
      {
        url: { type: String, default: '' },
        publicId: { type: String, default: '' },
        uploadedAt: { type: Date, default: Date.now },
      },
    ],
    likes: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, required: true },
        userRole: { type: String, required: true, enum: ['Owner', 'Sitter'] },
        createdAt: { type: Date, default: Date.now },
      },
    ],
    comments: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, required: true },
        userRole: { type: String, required: true, enum: ['Owner', 'Sitter'] },
        authorName: { type: String, default: '' },
        authorAvatar: {
          url: { type: String, default: '' },
        },
        body: { type: String, required: true, trim: true },
        createdAt: { type: Date, default: Date.now },
      },
    ],
    // Sprint 4 step 6 — automatic translations of the post body.
    translations: {
      fr: { type: String, default: '' },
      en: { type: String, default: '' },
      es: { type: String, default: '' },
      de: { type: String, default: '' },
      it: { type: String, default: '' },
      pt: { type: String, default: '' },
    },
    sourceLanguage: { type: String, default: '' },
    // Sprint 5 step 2 — where the owner wants the service to happen.
    serviceLocation: {
      type: String,
      enum: ['at_owner', 'at_sitter', 'both'],
      default: 'at_owner',
    },

    // Session avril 2026 — moderation fields for the admin Annonces tab.
    // Soft-delete only so the historical dataset is preserved (same policy
    // as MapReport). `bannedReason` is shown to the offending user.
    hidden: {
      type: Boolean,
      default: false,
      index: true,
    },
    bannedAt: { type: Date, default: null },
    bannedBy: { type: String, default: '' }, // admin email / id for audit
    bannedReason: { type: String, default: '' },
    moderationNote: { type: String, default: '' },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Post', postSchema);

