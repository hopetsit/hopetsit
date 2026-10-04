// 607 (PAM, 02/10/2026) — copie en BASE des sessions de partage en direct
// (« Balade ») tenues en mémoire par sockets/mapSocket.js. Mesuré par ZOE le
// 02/10 : chaque publication (redémarrage Render) effaçait les Balades en
// cours — direct vu par les amis, peluches, gain « Balade terminée ». La RAM
// reste la source rapide ; cette collection permet de la RECHARGER au
// démarrage. Une ligne par diffuseur, effacée à l'arrêt.
const mongoose = require('mongoose');

const liveSessionSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, unique: true },
    role: { type: String, default: '' },
    lat: Number,
    lng: Number,
    city: { type: String, default: '' },
    at: Number,
    lastSeenAt: { type: Number, required: true },
    startedAt: { type: Number, required: true },
    duration: { type: String, default: 'until_stop' },
    expiresAt: { type: Number, default: null },
    lastStillActiveNoticeAt: Number,
    trail: { type: [[Number]], default: [] },
    // 611 (PAM) — reprise d'appareil (utils/liveTakeover611.js).
    deviceId: { type: String, default: '' },
    displaced: { type: [String], default: [] },
    personIds: { type: [String], default: [] },
    // Purge automatique : 24 h après le dernier signal (= LIVE_RAM_TTL_MS).
    purgeAt: { type: Date, required: true },
  },
  { versionKey: false },
);
liveSessionSchema.index({ purgeAt: 1 }, { expireAfterSeconds: 0 });

// 04/10/2026 (ZOE) — ville enregistrée sous son nom local (« Parigi » → « Paris »).
liveSessionSchema.plugin(require('../utils/cityCanonicalPlugin0410').cityCanonicalPlugin);
module.exports = mongoose.models.LiveSession607
  || mongoose.model('LiveSession607', liveSessionSchema);
