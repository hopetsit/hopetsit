const mongoose = require('mongoose');

/**
 * 618 (ZOE, 19/10/2026) — pin « 1er Chef de meute » (décision de Daniel du
 * 19/10, PROCHAIN_BUILD_618.md §B).
 *
 * UNE seule ligne dans toute la base : la première personne (hors staff et
 * comptes de test) qui atteint le rang `pack_leader` (3 000 PawPoints gagnés,
 * services/ranks611.js). L'index unique sur `key` garantit qu'elle n'est
 * jamais réattribuée, même si deux personnes passent le seuil à la même
 * seconde sur deux serveurs.
 */
const schema = new mongoose.Schema(
  {
    key: { type: String, required: true, default: 'pack_leader' },
    userId: { type: String, required: true }, // document de rôle crédité au passage du seuil
    role: { type: String, default: 'owner' },
    personKey: { type: String, default: '' },
    points: { type: Number, default: 0 }, // total gagné au moment du passage
    at: { type: Date, default: Date.now },
  },
  { versionKey: false },
);
schema.index({ key: 1 }, { unique: true });

module.exports = mongoose.model('PawFirstPackLeader', schema);
