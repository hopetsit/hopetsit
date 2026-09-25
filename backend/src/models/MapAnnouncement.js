const mongoose = require('mongoose');

/**
 * v589 — FENÊTRES D'ANNONCE de la PawMap (Daniel, 26/09 : « balancer des
 * pop-up sur la PawMap qui apparaissent UNE fois pour lancer un message, genre
 * mettre à jour l'app »).
 *
 * Écrites depuis l'admin, lues par l'app à l'ouverture de la PawMap ; chaque
 * appareil n'affiche une annonce qu'une seule fois (mémorisé côté app, par id).
 *
 *   · title / body : un texte par langue ({ fr, en, es, de, it, pt, ko, ja, pl }),
 *     repli : langue demandée → anglais → français ;
 *   · kind : 'info' (bouton Compris), 'update' (bouton Mettre à jour → store),
 *     'link' (bouton Ouvrir → url) ;
 *   · roles / platforms : vide = tout le monde ;
 *   · maxBuild : si renseigné, seulement les apps dont le build est INFÉRIEUR
 *     (« mettez à jour » ne s'affiche plus chez ceux qui ont déjà la version) ;
 *   · startsAt / endsAt : fenêtre de diffusion facultative.
 */
const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const KINDS = ['info', 'update', 'link'];
const ROLES = ['owner', 'sitter', 'walker'];
const PLATFORMS = ['ios', 'android', 'web'];

const MapAnnouncementSchema = new mongoose.Schema(
  {
    title: { type: mongoose.Schema.Types.Mixed, default: {} },
    body: { type: mongoose.Schema.Types.Mixed, default: {} },
    kind: { type: String, enum: KINDS, default: 'info' },
    url: { type: String, default: '', trim: true, maxlength: 500 },
    roles: { type: [String], default: [] },
    platforms: { type: [String], default: [] },
    // v589 — réservé à quelques comptes (e-mails, en minuscules) : tester une
    // annonce sur son propre téléphone avant de la diffuser à tous.
    onlyEmails: { type: [String], default: [] },
    maxBuild: { type: Number, default: null },
    active: { type: Boolean, default: true },
    startsAt: { type: Date, default: null },
    endsAt: { type: Date, default: null },
    createdBy: { type: String, default: '' },
  },
  { timestamps: true },
);

MapAnnouncementSchema.index({ active: 1, createdAt: -1 });

module.exports = mongoose.model('MapAnnouncement', MapAnnouncementSchema);
module.exports.LANGS = LANGS;
module.exports.KINDS = KINDS;
module.exports.ROLES = ROLES;
module.exports.PLATFORMS = PLATFORMS;
