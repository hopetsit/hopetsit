/**
 * PawSpot — v23.1.353 (refonte Daniel).
 *
 * NOUVEAU PawSpot : fini les halos "map boost" payants — PawSpot devient un
 * système COMMUNAUTAIRE de spots pet-friendly tagués par les utilisateurs
 * sur la PawMap (chemins de promenade, coins détente, aires de jeux,
 * baignade, cafés pet-friendly...). Les contributeurs gagnent des PawPoints
 * (badges 🥉🥈🥇👑), les meilleurs spots reçoivent l'empreinte DORÉE 🐾,
 * et l'abonnement PawSpot (4,99 €/mois · 39,99 €/an · essai 7 j) débloque
 * le tag illimité, les meilleurs spots et les récompenses à points.
 */

const mongoose = require('mongoose');

// Types de spots (menu déroulant du doc de spécs).
const PAWSPOT_TYPES = [
  'path_walk',   // 🚶 Chemin / Promenade
  'chill',       // 🧘 Chill / Détente
  'playground',  // 🛝 Aire de jeux
  'swimming',    // 🏊 Baignade
  'food_cafe',   // ☕ Restauration / Café pet-friendly
  'other',       // 📍 Autre
];

const commentSchema = new mongoose.Schema(
  {
    authorId: { type: mongoose.Schema.Types.ObjectId, required: true },
    authorModel: { type: String, enum: ['Owner', 'Sitter', 'Walker'], required: true },
    authorName: { type: String, default: '' },
    text: { type: String, required: true, maxlength: 300 },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: true },
);

const pawSpotSchema = new mongoose.Schema(
  {
    creatorId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    creatorModel: { type: String, enum: ['Owner', 'Sitter', 'Walker'], required: true },
    creatorName: { type: String, default: '' },

    type: { type: String, enum: PAWSPOT_TYPES, required: true, index: true },
    name: { type: String, required: true, trim: true, maxlength: 80 },
    description: { type: String, default: '', maxlength: 500 },
    photoUrl: { type: String, default: '' },

    location: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], required: true }, // [lng, lat]
      city: { type: String, default: '' },
    },

    // ── Système de confiance ────────────────────────────────────────────
    likedBy: { type: [String], default: [] },        // userIds (string)
    likesCount: { type: Number, default: 0, index: true },
    validatedBy: { type: [String], default: [] },    // userIds qui ont validé
    validationsCount: { type: Number, default: 0 },
    // validé par la communauté = 3 validations → +10 pts créateur (1 fois)
    communityValidated: { type: Boolean, default: false },
    validationAwarded: { type: Boolean, default: false },
    // très populaire = 50 likes → +25 pts créateur (1 fois)
    popularAwarded: { type: Boolean, default: false },
    visitedBy: { type: [String], default: [] },
    visitsCount: { type: Number, default: 0 },
    comments: { type: [commentSchema], default: [] },

    // ── Doré 🐾 ────────────────────────────────────────────────────────
    // Empreinte dorée sur la carte : spot validé par la communauté, OU très
    // populaire (50 likes), OU créateur "Gold Creator" (>= 1000 PawPoints —
    // recopié à la création/maj pour éviter un lookup par lecture).
    creatorIsGold: { type: Boolean, default: false },

    // Récompense premium : mise en avant 7 jours (dépense de points).
    featuredUntil: { type: Date, default: null },

    // Modération.
    hidden: { type: Boolean, default: false, index: true },
    flags: { type: [String], default: [] },
  },
  { timestamps: true },
);

pawSpotSchema.index({ location: '2dsphere' });
pawSpotSchema.index({ createdAt: -1 });

pawSpotSchema.methods.isGolden = function isGolden() {
  return (
    this.communityValidated === true ||
    this.likesCount >= 50 ||
    this.creatorIsGold === true
  );
};

const PawSpot = mongoose.model('PawSpot', pawSpotSchema);
module.exports = PawSpot;
module.exports.PAWSPOT_TYPES = PAWSPOT_TYPES;
