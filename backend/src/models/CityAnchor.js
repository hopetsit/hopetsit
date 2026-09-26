const mongoose = require('mongoose');

// v594 — Daniel (27/09) : « ma mère et moi on est au même endroit, et quand je
// reviens sur la carte elle apparaît plus loin ». Le floutage des positions
// (couche monde, amis) se tire vers le CENTRE-VILLE ; ce centre n'était gardé
// qu'en mémoire (perdu à chaque redémarrage du serveur, 24 h max) → la même
// personne changeait de point selon que le centre était connu ou non. Une
// ville ne bouge pas : on la garde en base, sans expiration.
const cityAnchorSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true }, // nom en minuscules
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    at: { type: Date, default: Date.now },
  },
  { versionKey: false },
);

module.exports = mongoose.model('CityAnchor', cityAnchorSchema);
