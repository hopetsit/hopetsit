/**
 * 612 (ZOE, 05/10/2026) — REGISTRE des alertes « nouvelle annonce ».
 *
 * Ordre de Daniel : « quand quelqu'un poste une annonce, que tous les gens à un
 * rayon de 100 km reçoivent l'annonce par mail, notification tel, etc. » — et UN
 * SEUL envoi par annonce et par PERSONNE, même si l'annonce est modifiée,
 * relancée ou republiée à l'identique.
 *
 *   · (postId, personKey) UNIQUE : la même annonce n'atteint jamais deux fois la
 *     même personne (ses profils gardien et promeneur = une personne) ;
 *   · alertKey = empreinte « même propriétaire, même service, même ville, mêmes
 *     dates » : une annonce republiée à l'identique dans les 30 jours ne
 *     reprévient pas ceux qui l'ont déjà reçue.
 * `personKey` est une empreinte (jamais l'adresse e-mail en clair).
 * Sert aussi à l'admin : qui a été prévenu, à quelle distance, par quel canal.
 */
const mongoose = require('mongoose');

const requestAlertSchema = new mongoose.Schema(
  {
    postId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    alertKey: { type: String, default: '', index: true },
    personKey: { type: String, required: true },
    recipientId: { type: mongoose.Schema.Types.ObjectId, required: true },
    recipientRole: { type: String, enum: ['sitter', 'walker'], required: true },
    type: { type: String, default: 'new_request_nearby' },
    // Distance réelle en km (null = repli sur le nom de ville, sans coordonnées).
    km: { type: Number, default: null },
    // 'coords' = position du profil ; 'city_center' = centre de sa ville ;
    // 'city_name' = même ville que l'annonce ; 'target' = « Demander à <prénom> ».
    via: { type: String, default: 'coords' },
    channels: {
      bell: { type: Boolean, default: false },
      // 'sent' | 'no_token' | 'prefs_off' | 'failed' | 'pending'
      push: { type: String, default: 'pending' },
      // 'sent' | 'unsubscribed' | 'prefs_off' | 'no_email' | 'no_smtp' | 'failed' | 'pending'
      email: { type: String, default: 'pending' },
    },
    resend: { type: Boolean, default: false },
  },
  { timestamps: true, collection: 'requestalerts612' },
);

requestAlertSchema.index({ postId: 1, personKey: 1 }, { unique: true });
requestAlertSchema.index({ alertKey: 1, personKey: 1, createdAt: -1 });

module.exports = mongoose.models.RequestAlert612 || mongoose.model('RequestAlert612', requestAlertSchema);
