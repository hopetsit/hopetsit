const mongoose = require('mongoose');

/**
 * TermsDocument — admin-editable Terms of Service per language.
 *
 * One document per language code ('en', 'fr', 'es', 'it', 'de', 'pt').
 * The latest version is served by GET /terms/:lang and can be edited from
 * the admin dashboard. If a language has no document, the mobile app falls
 * back to the static text bundled in `data/static/terms_of_service.dart`.
 */
const termsDocumentSchema = new mongoose.Schema(
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
      type: String, // admin email or id — free-form for audit.
      default: '',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('TermsDocument', termsDocumentSchema);
