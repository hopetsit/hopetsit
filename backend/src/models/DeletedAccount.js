const mongoose = require('mongoose');

// v530 — Daniel : « je veux voir qui se désinscrit ». Les suppressions de
// compte effacent physiquement le doc Owner/Sitter/Walker : sans journal il
// est impossible d'afficher les désinscriptions dans l'admin. Trace minimale,
// consultée uniquement par l'admin (email stocké en clair au moment de la
// suppression pour rester lisible après disparition du doc).
const deletedAccountSchema = new mongoose.Schema(
  {
    role: { type: String, default: '' }, // 'owner' | 'sitter' | 'walker'
    name: { type: String, default: '' },
    email: { type: String, default: '' },
    userId: { type: String, default: '' },
    source: { type: String, default: 'user' }, // 'user' (app/site) | 'admin'
    deletedAt: { type: Date, default: Date.now },
  },
  { timestamps: true },
);

deletedAccountSchema.index({ deletedAt: -1 });

module.exports = mongoose.model('DeletedAccount', deletedAccountSchema);
