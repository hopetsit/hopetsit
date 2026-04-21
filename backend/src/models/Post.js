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
        userRole: { type: String, required: true, enum: ['Owner', 'Sitter', 'Walker'] },
        createdAt: { type: Date, default: Date.now },
      },
    ],
    comments: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, required: true },
        userRole: { type: String, required: true, enum: ['Owner', 'Sitter', 'Walker'] },
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

    // Session v17.1 — reservation marker. Set when the owner accepts an
    // Application for this post (respondToApplication) and a Booking is
    // created. Cleared when the resulting booking is cancelled. Frontend
    // PetPostCard renders a "Réservé" / "Reserved" badge when non-null.
    //
    // Kept as a single object (not an array) because a post can only host
    // one concurrent confirmed reservation at a time — any subsequent
    // applications stay pending and the owner sees them queued behind the
    // reservation. If the booking is cancelled the field is unset and the
    // post becomes available again.
    reservedBy: {
      bookingId: { type: mongoose.Schema.Types.ObjectId, ref: 'Booking', default: null },
      providerRole: { type: String, enum: ['sitter', 'walker', null], default: null },
      providerId: { type: mongoose.Schema.Types.ObjectId, default: null },
      providerName: { type: String, default: '' },
      reservedAt: { type: Date, default: null },
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Post', postSchema);

