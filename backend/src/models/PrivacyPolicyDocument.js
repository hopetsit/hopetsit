const mongoose = require('mongoose');

/**
 * PrivacyPolicyDocument — admin-editable Privacy Policy per language.
 *
 * Mirror of TermsDocument: one doc per language ('en', 'fr', 'es', 'it',
 * 'de', 'pt'). GET /privacy-policy/:lang returns the latest version. The
 * mobile app falls back to the static bundled file when no doc exists for
 * the current locale.
 */
const privacyPolicyDocumentSchema = new mongoose.Schema(
  {
    language: {
      type: String,
      required: true,
      unique: true,
      index: true,
      lowercase: true,
      trim: true,
      enum: ['en', 'fr', 'es', 'it', 'de', 'pt'],
    },
    content: {
      type: String,
      required: true,
      default: '',
    },
    version: {
      type: String,
      default: '1.0',
    },
    updatedBy: {
      type: String,
      default: '',
    },
  },
  { timestamps: true },
);

module.exports = mongoose.model(
  'PrivacyPolicyDocument',
  privacyPolicyDocumentSchema,
);
