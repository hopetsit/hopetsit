/**
 * 1610 (SAM, 16/10/2026) — REGISTRE « Partagez votre fiche » (ordre de Daniel du 16/10).
 *
 * UNE notification dans l'app (cloche + téléphone, JAMAIS d'e-mail), UNE SEULE
 * FOIS PAR PERSONNE, aux gardiens et promeneurs réels inscrits avec une ville :
 * « Vous n'avez pas encore de client ? Partagez votre fiche HoPetSit… » + lien
 * public de leur fiche (hopetsit.com/p/<rôle>/<id>).
 *
 *   · personKey UNIQUE (empreinte de l'e-mail, jamais l'adresse en clair) : une
 *     personne qui a un profil gardien ET promeneur ne reçoit qu'un envoi ;
 *   · la place est prise AVANT l'envoi (deux serveurs = un seul envoi) ;
 *   · 'sent' | 'failed' : jamais de 2e essai, dans les deux cas.
 */
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    personKey: { type: String, required: true },
    recipientId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    recipientRole: { type: String, enum: ['sitter', 'walker'], required: true },
    city: { type: String, default: '' },
    timeZone: { type: String, default: '' },
    testOnly: { type: Boolean, default: false },
    status: { type: String, default: 'sent' },
    error: { type: String, default: '' },
  },
  { timestamps: true, collection: 'sitterinvites1610' },
);

schema.index({ personKey: 1 }, { unique: true });

module.exports = mongoose.models.SitterInvite1610 || mongoose.model('SitterInvite1610', schema);
