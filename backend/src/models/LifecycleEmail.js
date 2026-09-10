const mongoose = require('mongoose');

/**
 * v560 — e-mails de cycle de vie (moteur de croissance autonome).
 * Une ligne = un e-mail envoyé (utilisateur, rôle, étape, réf. optionnelle) ;
 * l'index unique garantit qu'une étape n'est jamais envoyée deux fois.
 */
const lifecycleEmailSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    role: { type: String, enum: ['owner', 'sitter', 'walker'], required: true },
    step: { type: String, required: true },
    refId: { type: String, default: '' }, // ex. bookingId pour review_after_booking
    locale: { type: String, default: '' },
    sentAt: { type: Date, default: Date.now },
    skipped: { type: Boolean, default: false }, // pas d'e-mail (opt-out, invalide…) mais étape consommée
  },
  { timestamps: true },
);

lifecycleEmailSchema.index({ userId: 1, role: 1, step: 1, refId: 1 }, { unique: true });

module.exports = mongoose.model('LifecycleEmail', lifecycleEmailSchema);
