const mongoose = require('mongoose');

/**
 * 607 (PAM, 02/10/2026) — MINI-PELUCHES de la PawMap (idée 2 de Daniel).
 *
 * Objets VIRTUELS posés chaque jour par le serveur dans les parcs à chiens
 * publics (POI OpenStreetMap `leisure=dog_park` déjà en base) des villes
 * actives. Visibles seulement pendant une Balade ; attrapées à moins de 30 m.
 * Récompense : des PawPoints, jamais d'argent ni d'abonnement.
 *
 * Une peluche = une ligne. `caughtByPerson` (clé de la PERSONNE, ses 3 profils
 * confondus) est posé à la capture ; l'index unique partiel
 * { day, caughtByPerson } garantit « une capture par personne et par jour »
 * même si deux requêtes arrivent ensemble.
 */
const PLUSH_TYPES = ['teddy', 'bunny', 'kitty', 'puppy', 'fox'];

const pawPlushSchema = new mongoose.Schema(
  {
    cityKey: { type: String, required: true, index: true }, // ville normalisée
    cityLabel: { type: String, default: '' },
    day: { type: String, required: true }, // AAAA-MM-JJ, jour local de la ville
    slot: { type: Number, required: true, min: 0, max: 4 },
    type: { type: String, enum: PLUSH_TYPES, required: true },
    // Peluche DORÉE (rare) : 1 par ville et par semaine (barème BOB/Daniel 02/10).
    golden: { type: Boolean, default: false },
    poiId: { type: mongoose.Schema.Types.ObjectId, ref: 'MapPOI', default: null },
    location: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], required: true }, // [lng, lat]
    },
    caughtByPerson: { type: String, default: null },
    caughtBy: {
      userId: { type: String, default: null },
      role: { type: String, default: null },
      at: { type: Date, default: null },
    },
    // Peluche jamais attrapée : effacée 3 jours après son tirage. Une peluche
    // attrapée perd ce champ et reste dans la collection de la personne.
    expireAt: { type: Date, default: null },
  },
  { timestamps: true, versionKey: false },
);

pawPlushSchema.index({ cityKey: 1, day: 1, slot: 1 }, { unique: true });
pawPlushSchema.index({ location: '2dsphere' });
pawPlushSchema.index(
  { day: 1, caughtByPerson: 1 },
  { unique: true, partialFilterExpression: { caughtByPerson: { $type: 'string' } } },
);
pawPlushSchema.index({ caughtByPerson: 1, 'caughtBy.at': -1 });
pawPlushSchema.index({ expireAt: 1 }, { expireAfterSeconds: 0 });

/**
 * Bonus déjà accordés à une personne (jamais deux fois le même) :
 *   kind 'collector' (5 types réunis, key 'once'),
 *   kind 'streak7'   (7 jours de suite, key = jour qui complète la série).
 */
const pawPlushBonusSchema = new mongoose.Schema(
  {
    personKey: { type: String, required: true },
    kind: { type: String, enum: ['collector', 'streak7'], required: true },
    key: { type: String, required: true },
    points: { type: Number, default: 0 },
    at: { type: Date, default: Date.now },
  },
  { versionKey: false },
);
pawPlushBonusSchema.index({ personKey: 1, kind: 1, key: 1 }, { unique: true });

module.exports = mongoose.model('PawPlush', pawPlushSchema);
module.exports.PLUSH_TYPES = PLUSH_TYPES;
module.exports.PawPlushBonus = mongoose.model('PawPlushBonus', pawPlushBonusSchema);
