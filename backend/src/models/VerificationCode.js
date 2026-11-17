const mongoose = require('mongoose');

const verificationCodeSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
    },
    code: {
      type: String,
      required: true,
    },
    expiresAt: {
      type: Date,
      required: true,
    },
    purpose: {
      type: String,
      // 1711 (NEO) — 'email_first' : code tapé AVANT la création du compte (routes/emailFirst1711).
      enum: ['email_verification', 'password_reset', 'email_first'],
      default: 'email_verification',
    },
    verified: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

// Compound unique index: one code per email per purpose
verificationCodeSchema.index({ email: 1, purpose: 1 }, { unique: true });
verificationCodeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('VerificationCode', verificationCodeSchema);

