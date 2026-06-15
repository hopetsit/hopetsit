const mongoose = require('mongoose');

const petSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true },
    petName: {
      type: String,
      required: true,
    },
    breed: {
      type: String,
      default: '',
    },
    dob: {
      type: String,
      default: '',
    },
    weight: {
      type: String,
      default: '',
    },
    height: {
      type: String,
      default: '',
    },
    passportNumber: {
      type: String,
      default: '',
    },
    chipNumber: {
      type: String,
      default: '',
    },
    medicationAllergies: {
      type: String,
      default: '',
    },
    category: {
      type: String,
      default: '',
    },
    vaccination: {
      type: String,
      default: '',
    },
    bio: {
      type: String,
      default: '',
      trim: true,
    },
    colour: {
      type: String,
      default: '',
      trim: true,
    },
    // v22.5 — Bug R2 : sexe de l'animal. Schema enum + null pour
    // 'pas spécifié'. Persiste désormais à la création ET à l'édition.
    gender: {
      type: String,
      enum: ['male', 'female', null],
      default: null,
    },
    profileView: {
      type: String,
      default: '',
    },
    avatar: {
      url: { type: String, default: '' },
      publicId: { type: String, default: '' },
    },
    photos: [
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
    passportImage: {
      url: { type: String, default: '' },
      publicId: { type: String, default: '' },
      uploadedAt: { type: Date, default: Date.now },
    },
    // Sprint 5 step 5 — enriched pet profile.
    age: { type: Number, default: null, min: 0, max: 60 },
    vaccinations: [
      {
        name: { type: String, required: true, trim: true },
        date: { type: Date, default: null },
      },
    ],
    behavior: { type: String, default: '', trim: true, maxlength: 500 },
    regularVet: {
      name: { type: String, default: '', trim: true },
      phone: { type: String, default: '', trim: true },
      address: { type: String, default: '', trim: true },
    },
    emergencyVet: {
      name: { type: String, default: '', trim: true },
      phone: { type: String, default: '', trim: true },
      address: { type: String, default: '', trim: true },
    },
    emergencyInterventionAuthorization: { type: Boolean, default: false },
    emergencyAuthorizationText: { type: String, default: '' },

    // ─── v405 refonte — fiche animal enrichie (onglets À propos / Santé /
    // Habitudes). 100% ADDITIF : tous optionnels, défauts vides → aucune casse.
    // À propos
    characterTraits: [{ type: String, trim: true }], // ex: energetic, smart, protective, playful, social
    compatibilities: {
      // 'compatible' | 'supervised' | 'no' | '' (non renseigné)
      withDogs: { type: String, default: '' },
      withCats: { type: String, default: '' },
      withChildren: { type: String, default: '' },
    },
    history: { type: String, default: '', trim: true, maxlength: 2000 },
    particularities: [{ type: String, trim: true }],
    notes: { type: String, default: '', trim: true, maxlength: 2000 },
    // Santé
    vaccinationStatus: { type: String, default: '' }, // 'up_to_date' | 'late' | 'unknown'
    deworming: {
      lastDate: { type: Date, default: null },
      frequency: { type: String, default: '', trim: true },
    },
    currentTreatments: { type: String, default: '', trim: true },
    bloodGroup: { type: String, default: '', trim: true },
    healthInsurance: {
      name: { type: String, default: '', trim: true },
      number: { type: String, default: '', trim: true },
    },
    // Habitudes
    habits: {
      energyLevel: { type: String, default: '', trim: true },
      preferredActivity: { type: String, default: '', trim: true },
      education: { type: String, default: '', trim: true },
      aloneTolerance: { type: String, default: '', trim: true },
      barking: { type: String, default: '', trim: true },
      likes: { type: String, default: '', trim: true },
      dislikes: { type: String, default: '', trim: true },
      transport: { type: String, default: '', trim: true },
      brushing: { type: String, default: '', trim: true },
      food: { type: String, default: '', trim: true },
      allowedTreats: { type: String, default: '', trim: true },
      favoriteObjects: { type: String, default: '', trim: true },
      favoritePlaces: { type: String, default: '', trim: true },
      remarks: { type: String, default: '', trim: true, maxlength: 2000 },
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Pet', petSchema);
