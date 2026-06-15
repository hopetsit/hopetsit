const mongoose = require('mongoose');

// v404 — Daniel : "dans admin onglet filtre, je rentre les gros mots pas
// autorisés et ça me les traduit 6 langues". Liste de mots interdits éditable
// par l'admin, chargée par textModerationService → s'applique à l'app ET au
// web (modération de texte côté serveur, sur les annonces + messages).
// `variants` = traductions/variantes du mot (générées via translateToAll).
const bannedWordSchema = new mongoose.Schema(
  {
    word: { type: String, required: true, lowercase: true, trim: true, unique: true },
    variants: [{ type: String, lowercase: true, trim: true }],
    createdBy: { type: String, default: '' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('BannedWord', bannedWordSchema);
