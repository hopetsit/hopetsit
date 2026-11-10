/**
 * AdLead2210 — 22/10/2026 (SAM, accord de Daniel « bouton 1 clic »).
 *
 * Contact reçu par la pub à formulaire Meta (Paris, New York). La pub promet
 * « laissez votre demande sans créer de compte, les gardiens vous répondent » ;
 * l'e-mail de bienvenue renvoyait pourtant vers un formulaire avec mot de passe
 * et code : 11 contacts en 48 h → 0 compte → 0 demande.
 *
 * Désormais l'e-mail porte un lien /confirmer/<_id> : un clic crée le compte
 * propriétaire (l'e-mail est prouvé par le clic) et publie la demande déjà
 * décrite dans la pub. `_id` est un jeton aléatoire de 128 bits : l'URL ne
 * contient aucune donnée personnelle. Purge automatique au bout de 60 jours.
 */
const crypto = require('crypto');
const mongoose = require('mongoose');

// 1011 (BOB) — « journee » = garde en journée (service day_care, prix à la journée).
const SERVICES = ['garde', 'journee', 'promenade', 'visites'];
const ANIMALS = ['chien', 'chat', 'autre'];
const WHENS = ['bientot', 'fetes', 'plus_tard'];

const adLeadSchema = new mongoose.Schema(
  {
    _id: { type: String, default: () => crypto.randomBytes(16).toString('hex') },
    metaLeadId: { type: String, required: true, unique: true },
    email: { type: String, required: true, lowercase: true, trim: true },
    firstName: { type: String, default: '', trim: true },
    city: { type: String, required: true, trim: true },
    lat: { type: Number },
    lng: { type: Number },
    country: { type: String, default: '' },
    lang: { type: String, enum: ['fr', 'en'], default: 'fr' },
    service: { type: String, enum: SERVICES, default: 'garde' },
    animal: { type: String, enum: ANIMALS, default: 'autre' },
    quand: { type: String, enum: WHENS, default: 'plus_tard' },
    startText: { type: String, default: '', trim: true }, // 23/10 (BOB) — dates écrites dans le formulaire
    endText: { type: String, default: '', trim: true },
    // 620 (ZOE) — service « visites » : visites par jour lues dans le formulaire (1 | 2), sinon 1.
    visitsPerDay: { type: Number, enum: [1, 2, null], default: null },
    // 1011 (BOB, accord de Daniel) — précisions du formulaire : lieu choisi (jusqu'ici calculé puis perdu),
    // horaires « HH:MM », « je n'ai pas de voiture », budget. Tout est facultatif.
    lieu: { type: String, enum: ['at_owner', 'at_sitter'], default: 'at_owner' },
    timeFrom: { type: String, default: '', trim: true, maxlength: 5 },
    timeTo: { type: String, default: '', trim: true, maxlength: 5 },
    noCar: { type: Boolean, default: false },
    // 639 (BOB) — « Je fournis la nourriture » (true / false, null = non précisé) et race FACULTATIVE
    // de l'animal (≤ 60 car., nettoyée) : recopiées sur la demande / la fiche animal créée à la publication.
    foodProvided: { type: Boolean, default: null },
    breed: { type: String, default: '', trim: true, maxlength: 60 },
    budget: { type: Number, default: null },
    confirmedAt: { type: Date }, // demande publiée (par le clic OU par le suivi automatique) — n'est PAS une preuve
    clickedAt: { type: Date }, // 27/10 (SAM) — 1er VRAI clic (navigateur ou app) sur le lien de l'e-mail
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner' },
    postId: { type: mongoose.Schema.Types.ObjectId, ref: 'Post' },
    // 31/10 (LEO, feu vert BOB) — contact venu du SITE (page d'arrivée, POST /ad-leads/site) : jamais
    // compté dans la dépense pub (leads_suivi.py lit Meta ; les stats admin séparent `site`).
    source: { type: String, enum: ['meta', 'site'], default: 'meta', index: true },
    campaign: { type: String, default: '' },
    page: { type: String, default: '' },
    postalCode: { type: String, default: '' },
    positionSource: { type: String, default: '' }, // 31/10 — map | postal | city | anchor
    pendingConfirm: { type: Boolean, default: false }, // 31/10 (BOB) — compte existant : publié seulement au clic de l'e-mail
    siteEmailAt: { type: Date }, // e-mail « ta demande est en ligne » envoyé (une fois)
    // 3110 (ADA, ordre de Daniel 31/10 : « au moins l'e-mail vérifié ») — contact NEUF gardé en BROUILLON :
    // compte non vérifié + e-mail « confirme ta demande » (confirmEmailAt), UN rappel à +24 h (confirmReminderAt),
    // publication seulement au clic (/ad-leads/:id/confirm).
    confirmEmailAt: { type: Date },
    confirmReminderAt: { type: Date },
    // 31/10 (LEO) — « Réserver <prénom> » depuis un profil public / une épingle : le prestataire ciblé est
    // prévenu en premier (createPost → targetProvider, utils/targetProvider2809).
    targetRole: { type: String, enum: ['sitter', 'walker', null], default: null },
    targetId: { type: String, default: '' },
    // 1011 (BOB, accord de Daniel 10/11) — accord SMS FACULTATIF donné sur la page de demande (case non cochée par
    // défaut, routes/demandeSms1011). On n'écrit par SMS qu'à un contact qui a `smsConsentAt` et pas `smsOptOutAt`.
    smsPhone: { type: String, default: '', trim: true, maxlength: 20 },
    smsConsentAt: { type: Date },
    smsConsentText: { type: String, default: '', maxlength: 700 },
    smsConsentIp: { type: String, default: '', maxlength: 64 },
    smsOptOutAt: { type: Date },
    createdAt: { type: Date, default: Date.now, expires: 60 * 24 * 3600 },
  },
  { versionKey: false },
);

adLeadSchema.statics.SERVICES = SERVICES;
adLeadSchema.statics.ANIMALS = ANIMALS;
adLeadSchema.statics.WHENS = WHENS;

module.exports = mongoose.models.AdLead2210 || mongoose.model('AdLead2210', adLeadSchema);
