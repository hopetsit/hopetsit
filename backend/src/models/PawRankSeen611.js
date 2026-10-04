const mongoose = require('mongoose');

// 611 (PAM, 04/10/2026) — dernier RANG dont la personne a vu le message
// « Tu passes Jeune chien ». Une ligne par personne (`personKey` = empreinte
// de l'e-mail, partagée par ses 3 profils, jamais l'e-mail lui-même) : le
// message ne sort qu'une fois, même sur deux téléphones ou deux profils.
const pawRankSeenSchema = new mongoose.Schema(
  {
    personKey: { type: String, required: true, unique: true },
    level: { type: Number, default: 1 },
  },
  { versionKey: false, timestamps: true },
);

module.exports = mongoose.models.PawRankSeen611
  || mongoose.model('PawRankSeen611', pawRankSeenSchema);
