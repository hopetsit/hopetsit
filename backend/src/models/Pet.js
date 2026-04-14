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
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Pet', petSchema);

