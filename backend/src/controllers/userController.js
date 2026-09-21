const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const Pet = require('../models/Pet');
const Post = require('../models/Post');
const Booking = require('../models/Booking');
const Application = require('../models/Application');
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const Review = require('../models/Review');
const Task = require('../models/Task');
const Block = require('../models/Block');
const { sanitizeUser, sanitizeDoc, sanitizePet, sanitizePost, sanitizeBooking, sanitizeReview } = require('../utils/sanitize');
// v568 — `encrypt` n'est plus importé ici : il ne servait qu'à chiffrer le
// numéro de carte et le CVC de l'ancien formulaire (routes supprimées).
// `decrypt` reste chargé à la demande là où il sert (emails historiques).
const { getOwnerStats } = require('../services/loyaltyService');
const { getMyReferrals } = require('../services/referralService');
const { uploadMedia } = require('../services/cloudinary');
const { normalizeCurrency, DEFAULT_CURRENCY } = require('../utils/currency');
const { processLocationData } = require('../utils/location');
const logger = require('../utils/logger');
const { ensureAvatarFromSiblingRoles } = require('../utils/avatarFallback');
const { identityGroup } = require('../utils/identityGroup');

// ─── v565 point 1 / v575 — propagation aux 3 profils de la personne ────────
// AVANT (v565) : `propagateToSiblings` vivait ici et propageait aussi `bio` et
// `skills` — la présentation d'un GARDIEN se retrouvait sur le profil
// propriétaire — et écrasait les frères par des valeurs VIDES (un écran
// d'édition qui n'affiche pas le champ « pays » envoie `country: ''`).
// v575 : la liste blanche et la règle « jamais d'écrasement par du vide »
// vivent dans `utils/sharedIdentity.js`, partagé par les routes des 3 rôles.
const MODEL_BY_NAME = { Owner, Sitter, Walker };
const {
  propagateSharedIdentity,
  fillMissingIdentityFromSiblings,
  buildIdentityFromSource,
  SHARED_IDENTITY_FIELDS,
  isEmptyValue: isEmptyIdentityValue,
} = require('../utils/sharedIdentity');

// v565 point 12 — indicatif renvoyé/accepté tel quel (« +33 ») ; on ajoute
// juste le « + » manquant quand le client envoie « 33 ».
const normalizeCountryCode = (v) => {
  const raw = String(v ?? '').trim().replace(/\s+/g, '');
  if (!raw) return '';
  if (/^\d{1,4}$/.test(raw)) return `+${raw}`;
  return raw;
};

// ─── v575 — P0-4 : la collection cible vient du RÔLE DU JETON ───────────────
// Plusieurs fonctions de ce fichier devinaient la collection par une cascade
// `Owner.findById(id)` → `Sitter.findById(id)` → `Walker.findById(id)`, en
// ignorant `req.user.role`. Or `switchRole` peut créer le document du rôle
// cible avec `_id = baseOldId` (l'`_id` du premier document de la personne) :
// pour un compte créé d'abord en gardien/promeneur, `Owner._id === Sitter._id`.
// La cascade renvoyait alors TOUJOURS l'Owner — « Supprimer mon compte »
// effaçait le profil PROPRIÉTAIRE d'un prestataire, et « Modifier mon profil »
// écrivait sur le mauvais document.
//
// `ROLE_MODELS[role]` est désormais essayé EN PREMIER ; la cascade historique
// ne sert plus que de repli (jeton sans rôle connu, ou id d'un document frère
// d'une autre collection — cas légitime de `PUT /users/:id/profile`).
const ROLE_MODELS = { owner: Owner, sitter: Sitter, walker: Walker };
const ROLE_MODEL_NAMES = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
const ALL_ROLES = ['owner', 'sitter', 'walker'];

/** Rôles à essayer, celui du jeton d'abord. Ne lève jamais. */
const roleSearchOrder = (req) => {
  const tokenRole = String(req?.user?.role || '').toLowerCase();
  if (!ROLE_MODELS[tokenRole]) return [...ALL_ROLES];
  return [tokenRole, ...ALL_ROLES.filter((r) => r !== tokenRole)];
};

const OWNER_SERVICES = ['Pet Sitting', 'House Sitting', 'Day Care', 'Long Stay'];
const SITTER_SERVICES = [...OWNER_SERVICES, 'Dog Walking'];

// v568 — SÉCURITÉ : `detectCardBrand` / `buildCardPayload` (chiffrement du
// numéro de carte ET du CVC pour stockage en base) ont été SUPPRIMÉS avec
// les routes qui les utilisaient. Les données carte sont collectées par
// Airwallex seul ; nous ne conservons que marque, 4 derniers chiffres et
// expiration, renvoyés par l'API Airwallex.

const buildProfileUpdate = ({ name, mobile, countryCode, language, address, avatar, bio, skills, currency, country, city }, currentDoc = {}) => {
  const update = {};
  // v575 — « prénom » + « nom » : traités par `utils/personName.buildNameUpdate`
  // (appelé par `updateProfile`, qui a accès à `firstName`/`lastName` du corps).
  // Ici on ne garde le chemin historique que pour les appels internes qui ne
  // passent qu'un `name`.
  // v565 point 1 — pays (ISO-2) et ville (champ plat, conservé sans GPS).
  if (country !== undefined) {
    if (country !== null && typeof country !== 'string') throw new Error('Country must be a string.');
    update.country = String(country || '').trim().toUpperCase().slice(0, 2);
  }
  if (city !== undefined) {
    if (city !== null && typeof city !== 'string') throw new Error('City must be a string.');
    update.city = String(city || '').trim();
  }
  if (name !== undefined) {
    if (typeof name !== 'string' || !name.trim()) {
      throw new Error('Name must be a non-empty string.');
    }
    update.name = name.trim();
  }
  if (mobile !== undefined) {
    if (typeof mobile !== 'string') {
      throw new Error('Mobile must be a string.');
    }
    update.mobile = mobile.trim();
  }
  if (countryCode !== undefined) {
    update.countryCode = normalizeCountryCode(countryCode);
  }
  if (language !== undefined) {
    if (typeof language !== 'string') {
      throw new Error('Language must be a string.');
    }
    update.language = language.trim();
  }
  if (address !== undefined) {
    if (typeof address !== 'string') {
      throw new Error('Address must be a string.');
    }
    update.address = address.trim();
  }
  if (bio !== undefined) {
    if (typeof bio !== 'string') {
      throw new Error('Bio must be a string.');
    }
    // v23.1.319 — auto-modération (gros mots/menaces) sur la bio de profil.
    update.bio = require('../services/textModerationService')
      .moderateText(bio.trim()).clean;
  }
  if (skills !== undefined) {
    if (typeof skills !== 'string') {
      throw new Error('Skills must be a string.');
    }
    update.skills = skills.trim();
  }
  if (currency !== undefined) {
    update.currency = normalizeCurrency(currency, { required: true });
  }
  if (avatar !== undefined) {
    if (avatar === null) {
      update.avatar = { url: '', publicId: '' };
    } else if (typeof avatar === 'object' && avatar !== null) {
      const url = typeof avatar.url === 'string' ? avatar.url.trim() : '';
      const publicId = typeof avatar.publicId === 'string' ? avatar.publicId.trim() : '';
      if (!url) {
        throw new Error('Avatar url is required.');
      }
      update.avatar = { url, publicId };
    } else {
      throw new Error('Avatar must be an object or null.');
    }
  }

  return update;
};

const updateService = async (req, res) => {
  try {
    const { id } = req.params;
    const { service } = req.body || {};

    const rawServices = Array.isArray(service) ? service : service != null ? [service] : [];
    const normalizedServices = rawServices
      .map((s) => (typeof s === 'string' ? s.trim() : typeof s === 'number' ? String(s).trim() : ''))
      .filter(Boolean);

    if (normalizedServices.length === 0) {
      return res.status(400).json({ error: 'Service is required (array of service names).' });
    }

    // Session v15 — all roles can pick any of the 5 service types (Pet
    // Sitting, House Sitting, Day Care, Long Stay, Dog Walking). The old
    // split OWNER_SERVICES / SITTER_SERVICES used to reject a legitimate
    // "Dog Walking" selection for an Owner who wants to offer walks too.
    const allowedServices = SITTER_SERVICES;

    // v575 P0-4 — le rôle du jeton d'abord (cf. `roleSearchOrder`). Avant, un
    // gardien dont l'`_id` est partagé avec son document propriétaire voyait
    // ses services écrits sur l'Owner. Le promeneur, lui, n'était même pas
    // cherché (la cascade s'arrêtait à Sitter) → 404.
    let account = null;
    let role = null;
    for (const r of roleSearchOrder(req)) {
      account = await ROLE_MODELS[r].findById(id);
      if (account) { role = r; break; }
    }

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const invalid = normalizedServices.filter((s) => !allowedServices.includes(s));
    if (invalid.length > 0) {
      return res.status(400).json({
        error: `Invalid service(s): ${invalid.join(', ')}. Allowed: ${allowedServices.join(', ')}.`,
      });
    }

    account.service = normalizedServices;
    await account.save();

    res.json({ role, user: sanitizeUser(account, { includeEmail: true }) });
  } catch (error) {
    logger.error('Update service error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    res.status(500).json({ error: 'Unable to update service. Please try again later.' });
  }
};

const updateProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, mobile, countryCode, language, address, avatar, bio, skills, currency, location, servicePreferences, country, city } = req.body || {};

    const update = buildProfileUpdate({ mobile, countryCode, language, address, avatar, bio, skills, currency, country, city });

    // v575 — « dans mon profil j'ai que "nom" et pas "nom et prénom" ».
    // `name` reste la source d'affichage : il est recalculé depuis
    // `firstName` + `lastName` quand l'app les envoie, et re-découpé quand une
    // ancienne app n'envoie que `name`.
    const body = req.body || {};
    const touchesName = ['name', 'firstName', 'lastName']
      .some((k) => Object.prototype.hasOwnProperty.call(body, k));
    if (touchesName) {
      const { buildNameUpdate } = require('../utils/personName');
      // Le champ non fourni garde sa valeur courante : on lit d'abord le
      // document, quel que soit son rôle.
      // v575 P0-4 — rôle du jeton d'abord : quand `Owner._id === Sitter._id`
      // (switchRole), lire l'Owner en premier ramenait le nom du mauvais doc.
      let currentForName = {};
      for (const r of roleSearchOrder(req)) {
        const d = await ROLE_MODELS[r].findById(id).select('name firstName lastName').lean().catch(() => null);
        if (d) { currentForName = d; break; }
      }
      const nameUpdate = buildNameUpdate(body, currentForName);
      if (nameUpdate) Object.assign(update, nameUpdate);
    }

    // Sprint 5 step 2 — accept owner service preferences.
    if (servicePreferences && typeof servicePreferences === 'object') {
      update.servicePreferences = {
        atOwner: servicePreferences.atOwner !== false,
        atSitter: servicePreferences.atSitter === true,
      };
    }

    // v405 refonte — nouveaux champs additifs (profil owner/sitter/walker).
    // Mongoose (strict) ignore à l'écriture les champs absents du schéma du rôle
    // concerné → on peut tous les passer ; seul le rôle qui les possède les garde.
    const _b = req.body || {};
    for (const k of [
      'dateOfBirth', 'experienceTags', 'acceptedPetTypes', 'availableDays',
      'coverageRadiusKm', 'responseTimeMinutes', 'twoFactorEnabled',
      'preferences', 'searchPreferences',
    ]) {
      if (_b[k] !== undefined) update[k] = _b[k];
    }

    // Process location if provided
    let locationUpdate = null;
    let unsetLocation = false;
    if (location !== undefined) {
      if (location === null || (typeof location === 'object' && Object.keys(location || {}).length === 0)) {
        unsetLocation = true;
      } else {
        const locationType = location?.locationType || 'standard';
        const processed = processLocationData(location, { locationType });
        if (processed) {
          locationUpdate = processed;
          if (processed.city && update.city === undefined) update.city = processed.city;
        } else if (typeof location.city === 'string' && location.city.trim() && update.city === undefined) {
          // v565 point 1 — ville sans coordonnées : AVANT elle était perdue
          // (processLocationData → undefined). On la garde dans `city`.
          update.city = location.city.trim();
        }
      }
    }

    if (locationUpdate) {
      update.location = locationUpdate;
    }
    if (Object.keys(update).length === 0 && !unsetLocation) {
      return res.status(400).json({ error: 'No profile fields provided.' });
    }

    const trimmedMobile =
      typeof update.mobile === 'string' && update.mobile.trim().length > 0
        ? update.mobile.trim()
        : null;

    if (trimmedMobile) {
      update.mobile = trimmedMobile;
      // Allow same phone on multiple accounts as long as emails differ.
      // No uniqueness check on mobile — email is the unique identifier.
    }

    const updateOps = {};
    if (Object.keys(update).length > 0) {
      updateOps.$set = update;
    }
    if (unsetLocation) {
      updateOps.$unset = { location: '' };
    }

    // v18.9.8 — support walker (avant, updateProfile ne regardait que Owner
    // et Sitter, un walker obtenait 404 en modifiant son profil).
    // v575 P0-4 — et surtout : le rôle du jeton en premier. Sinon un gardien
    // dont l'`_id` est partagé avec son document propriétaire (switchRole)
    // écrivait sa bio/ses préférences sur le profil PROPRIÉTAIRE.
    let account = null;
    let role = null;
    for (const r of roleSearchOrder(req)) {
      account = await ROLE_MODELS[r].findByIdAndUpdate(id, updateOps, { new: true });
      if (account) { role = r; break; }
    }

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    // v565 point 1 — `location.city` du doc courant quand il a des coordonnées
    // (sinon l'index 2dsphere refuse l'objet) — la ville plate `city` est déjà posée.
    if (update.city && !update.location) {
      try {
        const Model = MODEL_BY_NAME[role === 'owner' ? 'Owner' : role === 'sitter' ? 'Sitter' : 'Walker'];
        await Model.updateOne(
          { _id: account._id, 'location.coordinates.1': { $exists: true } },
          { $set: { 'location.city': update.city } },
        );
        if (account.location && Array.isArray(account.location.coordinates) && account.location.coordinates.length === 2) {
          account.location.city = update.city;
        }
      } catch (_) { /* best-effort */ }
    }

    // v575 — propagation des SEULS champs d'identité de la personne vers ses
    // documents frères (même e-mail / oldId). `bio`, `skills`, les tarifs et
    // tout ce qui est propre à un rôle restent sur le document courant, et une
    // valeur vide ne remplace jamais une valeur existante chez le frère.
    await propagateSharedIdentity(account, role, update);

    const out = sanitizeUser(account, { includeEmail: true });
    out.city = out.city || (out.location && out.location.city) || '';
    res.json({ role, user: out });
  } catch (error) {
    logger.error('Update profile error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    if (error.message && error.message.includes('Avatar url is required')) {
      return res.status(400).json({ error: error.message });
    }
    if (error.message && error.message.includes('must be')) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to update profile. Please try again later.' });
  }
};

// v568 — SÉCURITÉ : ces deux routes acceptaient un numéro de carte et un CVC
// en clair, puis les stockaient (chiffrés) dans Mongo. Rien n'était envoyé à
// Airwallex : l'utilisateur croyait sa carte « enregistrée » alors qu'aucun
// moyen de paiement n'existait côté banque — d'où « elle ne reste pas
// enregistrée quand je veux payer ». Stocker un CVC est par ailleurs
// interdit (PCI-DSS). Les routes sont neutralisées et renvoient le chemin
// correct : POST /owner/payments/methods/verify-card (page Airwallex).
const CARD_FORM_REMOVED = {
  error: 'Card details are collected by Airwallex only.',
  code: 'CARD_FORM_REMOVED',
  use: 'POST /owner/payments/methods/verify-card',
};

const updateCard = async (req, res) => {
  logger.warn('[updateCard] route PAN supprimée (v568) — appel refusé');
  return res.status(410).json(CARD_FORM_REMOVED);
};

// v18.9.3 — role-aware : owner / sitter / walker peuvent tous enregistrer
// leur carte via PUT /users/me/card. Le Sitter.card et Walker.card schemas
// existent déjà (même shape que Owner.card).
const updateOwnerCardFromToken = async (req, res) => {
  // v568 — cf. CARD_FORM_REMOVED : plus aucun numéro de carte ne transite
  // par notre serveur. L'enregistrement passe par la page Airwallex.
  logger.warn('[updateOwnerCardFromToken] route PAN supprimée (v568) — appel refusé');
  return res.status(410).json(CARD_FORM_REMOVED);
};

const deleteAccount = async (req, res) => {
  try {
    const { id } = req.params;

    // Walkers are a distinct collection since session v3.2 — look them up too
    // so "Delete my account" works for the walker role.
    //
    // v575 P0-4 — BUG CRITIQUE : cette cascade commençait par `Owner.findById`
    // et ignorait `req.user.role`. `switchRole` réutilise `baseOldId` comme
    // `_id` du document créé → pour un compte inscrit d'abord en gardien ou
    // promeneur, `Owner._id === Sitter._id`. Un prestataire qui supprimait son
    // compte effaçait donc son profil PROPRIÉTAIRE (et gardait le sien).
    // Le rôle du jeton est maintenant essayé en premier.
    let account = null;
    let role = null;
    for (const r of roleSearchOrder(req)) {
      account = await ROLE_MODELS[r].findById(id);
      if (account) { role = r; break; }
    }

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const roleModel = ROLE_MODEL_NAMES[role];
    const userId = account._id;

    // v567 — Daniel : « demander 3 raisons et que ça me le dise dans l'admin ».
    // Le nombre de réservations est relevé AVANT la cascade (qui les efface),
    // sinon le journal des motifs afficherait toujours 0. Best-effort.
    let deletionStats = { hadPaidBooking: false, bookingsCount: 0 };
    try {
      const bookingFilter =
        role === 'owner'
          ? { ownerId: userId }
          : role === 'sitter'
            ? { sitterId: userId }
            : { walkerId: userId };
      const [bookingsCount, paidCount] = await Promise.all([
        Booking.countDocuments(bookingFilter),
        Booking.countDocuments({
          ...bookingFilter,
          paymentStatus: { $in: ['paid', 'refunded', 'refund'] },
        }),
      ]);
      deletionStats = { hadPaidBooking: paidCount > 0, bookingsCount };
    } catch (e) {
      logger.warn(`[deleteAccount] booking stats failed (continuing): ${e?.message || e}`);
    }

    // Conversation / Booking / Application référencent la personne par
    // `ownerId`, `sitterId` OU `walkerId` (les 3 champs existent dans les 3
    // schémas depuis la v18.6).
    //
    // v575 P1-10 — AVANT, le cas `walker` était sauté : le commentaire
    // annonçait un « job de fond » qui n'a jamais existé, donc les
    // conversations, messages, réservations et candidatures d'un promeneur
    // supprimé restaient en base indéfiniment (RGPD + orphelins affichés en
    // face). Le promeneur suit désormais exactement les mêmes règles que le
    // gardien, avec `walkerId`.
    {
      const idField =
        role === 'owner' ? 'ownerId' : role === 'sitter' ? 'sitterId' : 'walkerId';
      const conversations = await Conversation.find({ [idField]: userId }).select('_id');

      if (conversations.length) {
        const conversationIds = conversations.map((conversation) => conversation._id);
        await Message.deleteMany({ conversationId: { $in: conversationIds } });
        await Conversation.deleteMany({ _id: { $in: conversationIds } });
      }

      await Booking.deleteMany({ [idField]: userId });

      await Application.deleteMany({ [idField]: userId });
    }

    let sitterIdsForRecalc = [];
    if (role === 'owner') {
      const ownerReviews = await Review.find({
        reviewerId: userId,
        reviewerModel: 'Owner',
        revieweeModel: 'Sitter',
      }).select('revieweeId');

      sitterIdsForRecalc = [
        ...new Set(ownerReviews.map((review) => review.revieweeId.toString())),
      ].map((value) => new mongoose.Types.ObjectId(value));
    }

    await Review.deleteMany({
      $or: [
        { reviewerId: userId, reviewerModel: roleModel },
        { revieweeId: userId, revieweeModel: roleModel },
      ],
    });

    if (sitterIdsForRecalc.length) {
      const reviewStats = await Review.aggregate([
        {
          $match: {
            revieweeModel: 'Sitter',
            revieweeId: { $in: sitterIdsForRecalc },
          },
        },
        {
          $group: {
            _id: '$revieweeId',
            averageRating: { $avg: '$rating' },
            total: { $sum: 1 },
          },
        },
      ]);

      const statsMap = new Map(reviewStats.map((stat) => [stat._id.toString(), stat]));

      for (const sitterId of sitterIdsForRecalc) {
        const key = sitterId.toString();
        const stat = statsMap.get(key);
        const totalReviews = stat ? stat.total : 0;
        const averageRating = stat ? Number(stat.averageRating.toFixed(2)) : 0;

        await Sitter.updateOne(
          { _id: sitterId },
          {
            $set: {
              rating: totalReviews === 0 ? 0 : averageRating,
              reviewsCount: totalReviews,
            },
          }
        );
      }
    }

    await Block.deleteMany({
      $or: [
        { blockerId: userId, blockerModel: roleModel },
        { blockedId: userId, blockedModel: roleModel },
      ],
    });

    await Post.updateMany(
      {
        $or: [
          { 'likes.userId': userId },
          { 'comments.userId': userId },
        ],
      },
      {
        $pull: {
          likes: { userId },
          comments: { userId },
        },
      }
    );

    // v23.1 part 133 — Phase 7 audit P7-14 : RGPD article 17 — supprimer
    // aussi les données chez Persona (sous-traitant US, KYC). Si l'user
    // a un kycApplicantId, on appelle DELETE /inquiries/{id} sur Persona.
    // Best-effort, ne bloque pas la suppression du doc principal.
    try {
      const inquiryId = account.kycApplicantId;
      if (inquiryId) {
        const { deleteInquiry } = require('../services/personaService');
        const result = await deleteInquiry(inquiryId);
        logger.info(`[deleteAccount] Persona cascade for ${role} ${userId}: ${JSON.stringify(result)}`);
      }
    } catch (e) {
      logger.warn(`[deleteAccount] Persona cascade failed (continuing): ${e?.message || e}`);
    }

    // v23.1 part 132 — Phase 7 audit P7-1 : cascade RGPD complète sur
    // toutes les collections qui contiennent du PII de l'user.
    // ATTENTION : les invoices sont gardées car obligation légale UE
    // (conservation 10 ans). On les ANONYMISE plutôt que les supprimer.
    try {
      const Invoice = require('../models/Invoice');
      const Notification = require('../models/Notification');
      const WalletTransaction = require('../models/WalletTransaction');
      const UserSubscription = require('../models/UserSubscription');
      const VerificationCode = require('../models/VerificationCode');
      const VisitReport = require('../models/VisitReport');
      const BugReport = require('../models/BugReport');
      const Report = require('../models/Report');
      const Friendship = require('../models/Friendship');
      const OwnerCredit = require('../models/OwnerCredit');
      const MapReport = require('../models/MapReport');

      // Suppressions hard (pas de valeur légale à conserver) :
      await Friendship.deleteMany({
        $or: [{ requesterId: userId }, { addresseeId: userId }],
      });
      // v450 — Daniel : « les utilisateurs supprimés restent en amis et sur la
      // map ». Friendship est bien purgée ci-dessus (donc plus ami), MAIS le
      // compte supprimé restait MEMBRE des familles PawFollow des AUTRES :
      // listFamilyMembers le renvoyait encore → marqueur fallback 🐕 + liste
      // famille. On le retire donc de TOUS les familyMembers (titulaires tiers)
      // — couvre membres acceptés ET invitations en attente.
      await UserSubscription.updateMany(
        { 'familyMembers.userId': userId },
        { $pull: { familyMembers: { userId } } },
      );
      await Notification.deleteMany({
        $or: [
          { recipientId: userId, recipientModel: roleModel },
          { actorId: userId, actorModel: roleModel },
        ],
      });
      await VerificationCode.deleteMany({ email: (account.email || '').toLowerCase() });
      await UserSubscription.deleteMany({ userId, userModel: roleModel });
      await BugReport.deleteMany({ userId });
      await Report.deleteMany({
        $or: [
          { reporterId: userId, reporterModel: roleModel },
          { targetId: userId, targetModel: roleModel },
        ],
      });
      await MapReport.deleteMany({ authorId: userId, authorModel: roleModel });

      // VisitReports : owner uniquement (sitter peut être référencé dans
      // les VR créés AVANT son delete — on les laisse pour l'owner
      // restant).
      if (role === 'owner') {
        await VisitReport.deleteMany({ ownerId: userId });
      }

      // OwnerCredit : owner uniquement, hard-delete (pas de valeur légale).
      if (role === 'owner') {
        await OwnerCredit.deleteMany({ ownerId: userId });
      }

      // WalletTransaction : nous garderons les traces pour traçabilité
      // financière, MAIS on anonymise la référence vers l'user supprimé.
      await WalletTransaction.updateMany(
        { userId, userModel: roleModel },
        { $set: { userId: null, anonymizedAt: new Date(), _deletedUserRole: roleModel } },
      );

      // Invoice : OBLIGATION LÉGALE UE (10 ans) → anonymisation, pas
      // suppression. On efface le nom/email/adresse du buyer/seller
      // qui correspond à cet user.
      const _anonStr = '[DELETED]';
      if (role === 'owner') {
        await Invoice.updateMany(
          { ownerId: userId },
          {
            $set: {
              'buyer.name': _anonStr,
              'buyer.email': _anonStr,
              'buyer.address': _anonStr,
              anonymizedAt: new Date(),
            },
          },
        );
      } else {
        await Invoice.updateMany(
          { $or: [{ sitterId: userId }, { walkerId: userId }] },
          {
            $set: {
              'seller.name': _anonStr,
              'seller.email': _anonStr,
              'seller.address': _anonStr,
              anonymizedAt: new Date(),
            },
          },
        );
      }
    } catch (e) {
      // Cleanup best-effort : on log mais on ne bloque pas la suppression
      // du doc principal. L'admin pourra finir le ménage en backoffice.
      logger.warn(`[deleteAccount] secondary cascade failed (continuing): ${e?.message || e}`);
    }

    // v530 — Daniel : « je veux voir qui se désinscrit ». Journal AVANT la
    // suppression physique (source 'user' = suppression depuis l'app/le site).
    const { logDeletedAccount } = require('../utils/deletedAccountLog');
    await logDeletedAccount({ role, doc: account, source: 'user' });

    // v567 — motifs de départ (feuille « Avant de partir… » de l'app). Les
    // anciennes apps n'envoient rien : on enregistre quand même une ligne avec
    // `reasons: []`. Jamais bloquant pour la suppression.
    try {
      const { recordAccountDeletion } = require('../models/AccountDeletion');
      let plainEmail = '';
      try {
        const { decrypt } = require('../utils/encryption');
        plainEmail = decrypt(account.email || '') || '';
      } catch (_) { plainEmail = ''; }
      await recordAccountDeletion({
        req,
        role,
        doc: account,
        email: plainEmail,
        stats: deletionStats,
      });
    } catch (e) {
      logger.warn(`[deleteAccount] reason journal failed (continuing): ${e?.message || e}`);
    }

    if (role === 'owner') {
      await Pet.deleteMany({ ownerId: userId });
      await Post.deleteMany({ ownerId: userId });
      await Task.deleteMany({ ownerId: userId });
      await Owner.deleteOne({ _id: userId });
    } else if (role === 'sitter') {
      await Sitter.deleteOne({ _id: userId });
    } else {
      await Walker.deleteOne({ _id: userId });
    }

    res.json({ message: 'Account and related data deleted successfully.' });
  } catch (error) {
    logger.error('Delete account error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    res.status(500).json({ error: 'Unable to delete account. Please try again later.' });
  }
};

const deleteAccountFromToken = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;

    if (!userId || !role) {
      return res.status(403).json({ error: 'Authentication context missing.' });
    }

    // Walkers are a distinct collection (added in session v3.2). Without
    // this branch the Model fallback to Owner made walker deletions fail
    // with "User not found".
    const Model = ROLE_MODELS[String(role).toLowerCase()] || Owner;
    const account = await Model.findById(userId);

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    // v575 P0-4 — `deleteAccount` lit `req.user.role` (via `roleSearchOrder`)
    // et cible `ROLE_MODELS[role]` : le rôle du jeton est donc propagé, et un
    // gardien qui se désinscrit ne peut plus effacer son profil propriétaire
    // homonyme (`Owner._id === Sitter._id` après un switchRole).
    req.params.id = userId;
    return deleteAccount(req, res);
  } catch (error) {
    logger.error('Delete account (token) error', error);
    res.status(500).json({ error: 'Unable to delete account. Please try again later.' });
  }
};

const bufferToDataUri = (file) => `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

const updateProfilePicture = async (req, res) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (!userRole || !['owner', 'sitter', 'walker'].includes(userRole)) {
      return res.status(403).json({ error: 'Invalid user role. Only owners, sitters and walkers can update profile picture.' });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'Profile picture file is required.' });
    }

    // Validate file type
    const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedMimeTypes.includes(req.file.mimetype)) {
      return res.status(400).json({ error: 'Invalid file type. Only JPEG, PNG, and WebP images are allowed.' });
    }

    // Convert buffer to data URI
    const dataUri = bufferToDataUri(req.file);

    // Upload to Cloudinary
    const folder = `petsinsta/${userRole}s/${userId}`;
    const uploadResult = await uploadMedia({
      file: dataUri,
      folder: folder,
      resourceType: 'image',
    });

    // Session v3.3 — run Google Vision Safe Search on the uploaded avatar.
    // No-op when CONTENT_MODERATION_ENABLED is not 'true', so this is safe
    // to ship behind a feature flag.
    const { rejectIfUnsafe } = require('../services/contentModerationService');
    try {
      await rejectIfUnsafe(uploadResult);
    } catch (modErr) {
      if (modErr.code === 'CONTENT_REJECTED') {
        return res
          .status(422)
          .json({ error: modErr.message, code: modErr.code, details: modErr.details });
      }
      throw modErr;
    }

    // Update user's avatar in database
    const Model = userRole === 'owner'
      ? Owner
      : (userRole === 'walker' ? Walker : Sitter);
    const user = await Model.findById(userId);

    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    // Delete old avatar from Cloudinary if it exists
    if (user.avatar?.publicId) {
      try {
        const cloudinary = require('cloudinary').v2;
        await cloudinary.uploader.destroy(user.avatar.publicId);
      } catch (deleteError) {
        logger.error('Error deleting old avatar:', deleteError);
        // Continue even if deletion fails
      }
    }

    // Update avatar
    user.avatar = {
      url: uploadResult.url,
      publicId: uploadResult.publicId,
    };

    await user.save();

    // v532 — CAUSE RACINE du bug « ma photo change ou disparaît selon le
    // profil / l'appareil ». `avatar` fait partie de SHARED_FIELDS
    // (utils/userSyncService), et TOUTES les autres écritures de profil
    // appellent syncSharedFields… sauf celle-ci. Résultat : changer sa photo
    // en propriétaire ne la propageait pas aux documents sitter/walker du
    // même email → en changeant de rôle, ou en se connectant depuis un autre
    // appareil sur l'autre rôle, l'ancienne photo (ou aucune) revenait.
    // Le correctif v523 côté app ne faisait que MASQUER ce désalignement.
    // v575 — une seule voie de propagation : utils/sharedIdentity.
    await propagateSharedIdentity(user, userRole, { avatar: user.avatar });

    res.json({
      message: 'Profile picture updated successfully.',
      user: sanitizeUser(user, { includeEmail: true }),
      avatar: {
        url: uploadResult.url,
        publicId: uploadResult.publicId,
      },
    });
  } catch (error) {
    logger.error('Update profile picture error', error);
    if (error.message && error.message.includes('Cloudinary')) {
      return res.status(502).json({ error: 'Media service is unavailable. Please try again later.' });
    }
    res.status(500).json({ error: 'Unable to update profile picture. Please try again later.' });
  }
};

const getOwnerProfile = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const userRole = req.user?.role;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    // v414 — parité site web : les sitters/walkers chargent aussi leur profil
    // via GET /me/profile (le site est role-agnostic). On leur renvoie un profil
    // léger (sanitizeUser, qui inclut bio/preferences/twoFactorEnabled en
    // pass-through) sans les relations owner (pets/bookings/posts). L'app mobile
    // n'utilise pas cette route pour les sitters/walkers → changement additif.
    if (userRole !== 'owner') {
      const Model = userRole === 'walker' ? Walker : Sitter;
      const account = await Model.findById(ownerId);
      if (!account) {
        return res.status(404).json({ error: 'User not found.' });
      }
      // v546 — photo complétée depuis un rôle frère si vide (autre appareil).
      await ensureAvatarFromSiblingRoles(account, userRole);
      // v575 — rattrapage À LA LECTURE : tout champ d'identité vide ici alors
      // qu'un profil frère le possède est complété (réponse + base, pour CE
      // document seulement). Évite toute migration sur la production.
      await fillMissingIdentityFromSiblings(account, userRole);
      const p = sanitizeUser(account, { includeEmail: true });
      // v565 — ville plate (point 1) ; countryCode renvoyé tel quel (point 12).
      p.city = p.city || (p.location && p.location.city) || '';
      p.countryCode = p.countryCode || '';
      return res.json({ profile: p });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }
    // v546 — photo complétée depuis un rôle frère si vide (autre appareil).
    await ensureAvatarFromSiblingRoles(owner, 'owner');
    // v575 — rattrapage à la lecture des champs d'identité vides.
    await fillMissingIdentityFromSiblings(owner, 'owner');

    // Fetch related data
    const pets = await Pet.find({ ownerId: ownerId }).sort({ createdAt: -1 });
    const bookings = await Booking.find({ ownerId: ownerId })
      .populate('sitterId', 'name email avatar')
      .sort({ createdAt: -1 });
    const posts = await Post.find({ ownerId: ownerId }).sort({ createdAt: -1 });
    const tasks = await Task.find({ ownerId: ownerId }).sort({ createdAt: -1 });

    // Get reviews where owner is the reviewer
    const reviewsGiven = await Review.find({
      reviewerId: ownerId,
      reviewerModel: 'Owner',
    })
      .populate('revieweeId', 'name email avatar')
      .sort({ createdAt: -1 });

    // Get reviews where owner is the reviewee (if applicable, though owners typically don't receive reviews)
    const reviewsReceived = await Review.find({
      revieweeId: ownerId,
      revieweeModel: 'Owner',
    })
      .populate('reviewerId', 'name email avatar')
      .sort({ createdAt: -1 });

    const ownerOut = sanitizeUser(owner, { includeEmail: true });
    // v565 — ville plate (point 1) ; countryCode renvoyé tel quel (point 12).
    ownerOut.city = ownerOut.city || (ownerOut.location && ownerOut.location.city) || '';
    ownerOut.countryCode = ownerOut.countryCode || '';
    const profile = {
      ...ownerOut,
      pets: pets.map((pet) => sanitizePet(pet)),
      bookings: bookings.map((booking) => sanitizeBooking(booking)),
      posts: posts.map((post) => sanitizePost(post)),
      tasks: tasks.map((task) => sanitizeDoc(task)),
      reviewsGiven: reviewsGiven.map((review) => sanitizeReview(review)),
      reviewsReceived: reviewsReceived.map((review) => sanitizeReview(review)),
      stats: {
        petsCount: pets.length,
        bookingsCount: bookings.length,
        postsCount: posts.length,
        tasksCount: tasks.length,
        reviewsGivenCount: reviewsGiven.length,
        reviewsReceivedCount: reviewsReceived.length,
      },
    };

    res.json({ profile });
  } catch (error) {
    logger.error('Get owner profile error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner id.' });
    }
    res.status(500).json({ error: 'Unable to fetch owner profile. Please try again later.' });
  }
};

const signAuthToken = (payload, options = {}) => {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is not configured.');
  }
  return jwt.sign(payload, process.env.JWT_SECRET, {
    // v23.1 part 37 — JWT 30j au lieu de 7j (Daniel veut pas d'auto-logout).
    // v23.1.254 — allongé à 365j (switchRole) pour aligner sur authController
    // et éviter le "Session expirée" mensuel.
    expiresIn: '365d',
    ...options,
  });
};

// v575 — `ROLE_MODELS` est désormais déclaré en haut du fichier (il sert aussi
// à `updateService` / `updateProfile` / `deleteAccount`, cf. P0-4).
const VALID_SWITCH_ROLES = Object.keys(ROLE_MODELS);

const switchRole = async (req, res) => {
  try {
    const userId = req.user?.id;
    const currentRole = req.user?.role;

    if (!userId || !currentRole) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    // Determine target role.
    // Backwards compatible: if client sends no `targetRole` and current role is
    // owner/sitter, fall back to the legacy binary toggle. If client sends a
    // specific `targetRole`, use that (enables 3-way switching including walker).
    let targetRole = (req.body?.targetRole || '').toString().toLowerCase().trim();
    if (!targetRole) {
      if (currentRole === 'owner') {
        targetRole = 'sitter';
      } else if (currentRole === 'sitter') {
        targetRole = 'owner';
      } else {
        // walker has no implicit target — client must specify.
        return res.status(400).json({
          error: 'targetRole is required when switching from walker. Expected one of: owner, sitter.',
        });
      }
    }
    if (!VALID_SWITCH_ROLES.includes(targetRole)) {
      return res.status(400).json({
        error: `Invalid targetRole. Expected one of: ${VALID_SWITCH_ROLES.join(', ')}.`,
      });
    }
    if (targetRole === currentRole) {
      return res.status(400).json({ error: 'targetRole must be different from the current role.' });
    }

    // Find current user across 3 possible collections.
    const CurrentModel = ROLE_MODELS[currentRole];
    if (!CurrentModel) {
      return res.status(400).json({ error: 'Unsupported current role.' });
    }
    const currentUser = await CurrentModel.findById(userId);

    if (!currentUser) {
      return res.status(404).json({ error: 'User not found.' });
    }

    // Convert current user data to plain object
    const userData = currentUser.toObject();

    // Determine stable oldId (for existing users use their current _id)
    const baseOldId = userData.oldId || userData._id;

    // Store original password hash (already hashed)
    const originalPasswordHash = userData.password;

    // Prepare data for new role (password will be included temporarily for validation, then restored)
    // v575 — le bloc d'identité (nom, téléphone + indicatif, adresse, ville,
    // pays, langue, locale, devise, date de naissance, photo) vient d'une SEULE
    // source : `utils/sharedIdentity.buildIdentityFromSource`. Le profil créé
    // par « Activer » arrive donc pré-rempli, comme les deux autres.
    // insertOne() ne passe pas par Mongoose : valeurs par défaut et timestamps
    // posés à la main.
    const identityFromSource = buildIdentityFromSource(userData);
    let newUserData = {
      name: userData.name,
      email: userData.email,
      mobile: '',
      countryCode: '',
      password: originalPasswordHash, // Include password for validation, will be restored after create
      language: '',
      city: '',
      country: '',
      appLocale: '',
      dateOfBirth: '',
      address: '',
      currency: DEFAULT_CURRENCY,
      avatar: { url: '', publicId: '' },
      ...identityFromSource,
      createdAt: new Date(),
      updatedAt: new Date(),
      // `bio` / `skills` NE sont PAS des champs partagés (présentation propre
      // au rôle) — on les laisse vides sur le nouveau profil.
      bio: '',
      skills: '',
      acceptedTerms: userData.acceptedTerms || false,
      service: Array.isArray(userData.service) ? userData.service : userData.service ? [userData.service] : [],
      verified: userData.verified || false,
      firebaseUid: userData.firebaseUid || null,
      authProvider: userData.authProvider || 'password',
      // `avatar` est posé par `identityFromSource` ci-dessus (ne pas le
      // redéclarer ici : la dernière clé d'un littéral objet gagne).
      oldId: baseOldId,
      card: userData.card || {
        holderName: '',
        number: '',
        maskedNumber: '',
        last4: '',
        brand: '',
        expMonth: null,
        expYear: null,
        expDate: '',
        cvc: '',
        updatedAt: null,
      },
    };

    // Handle location - only include if coordinates is a valid array
    // MongoDB 2dsphere index cannot index documents with null coordinates
    const originalLocation = userData.location;
    const hasValidCoordinates = originalLocation && 
        Array.isArray(originalLocation.coordinates) && 
        originalLocation.coordinates.length === 2 &&
        typeof originalLocation.coordinates[0] === 'number' &&
        typeof originalLocation.coordinates[1] === 'number';
    
    if (hasValidCoordinates) {
      // Valid coordinates array exists.
      // Sitter and Walker both use a richer location schema with `locationType`.
      if (targetRole === 'sitter' || targetRole === 'walker') {
        newUserData.location = {
          type: 'Point',
          coordinates: originalLocation.coordinates,
          city: originalLocation.city || '',
          locationType: originalLocation.locationType || 'standard',
        };
      } else {
        newUserData.location = {
          type: 'Point',
          coordinates: originalLocation.coordinates,
          city: originalLocation.city || '',
        };
      }
    } else {
      // Explicitly delete location property to prevent Mongoose from applying defaults with null coordinates
      delete newUserData.location;
    }

    // Add role-specific fields
    if (targetRole === 'sitter') {
      newUserData.rate = '';
      newUserData.hourlyRate = 0;
      newUserData.weeklyRate = 0;
      newUserData.monthlyRate = 0;
      newUserData.rating = 0;
      newUserData.reviewsCount = 0;
      newUserData.feedback = [];
      newUserData.servicePricing = {
        homeVisit: { basePrice: null, currency: DEFAULT_CURRENCY },
        dogWalking30: { basePrice: null, currency: DEFAULT_CURRENCY },
        dogWalking60: { basePrice: null, currency: DEFAULT_CURRENCY },
        overnightStay: { basePrice: null, currency: DEFAULT_CURRENCY },
        longStay: { basePrice: null, currency: DEFAULT_CURRENCY },
      };
      newUserData.stripeConnectAccountId = null;
      newUserData.stripeConnectAccountStatus = 'not_connected';
    } else if (targetRole === 'walker') {
      // Walker-specific defaults for a fresh role.
      newUserData.service = Array.isArray(userData.service) && userData.service.length
        ? userData.service
        : ['dog_walking'];
      newUserData.rating = 0;
      newUserData.reviewsCount = 0;
      newUserData.feedback = [];
      newUserData.acceptedPetTypes = ['dog_small', 'dog_medium', 'dog_large'];
      newUserData.maxPetsPerWalk = 1;
      newUserData.hasInsurance = false;
      // `coverageCity` = zone de travail du promeneur (champ PROPRE au rôle) ;
      // on l'initialise seulement, à partir de la ville de la personne.
      newUserData.coverageCity = (originalLocation?.city || newUserData.city || '').toString();
      newUserData.coverageRadiusKm = 3;
      newUserData.walkRates = [];
      newUserData.defaultWalkDurationMinutes = 30;
      newUserData.stripeConnectAccountId = null;
      newUserData.stripeConnectAccountStatus = 'not_connected';
    } else if (targetRole === 'owner') {
      // Session v16.3 - explicit owner defaults. Because we use
      // `collection.insertOne()` at line ~875 (to bypass the location
      // default that breaks the 2dsphere index), Mongoose defaults are
      // NOT applied. Without this block, switching walker -> owner left
      // the Owner document missing required nested structures like
      // `servicePreferences`, which broke downstream reads and is the
      // root cause of the "Impossible de changer de role" error when
      // going directly walker -> owner (the walker -> sitter -> owner
      // path worked because the intermediate Sitter save rebuilt the
      // needed defaults).
      newUserData.servicePreferences = {
        atOwner: true,
        atSitter: false,
      };
      newUserData.isPremium = false;
      newUserData.status = 'active';
      newUserData.boostExpiry = null;
      newUserData.boostTier = null;
      newUserData.boostPurchases = [];
      newUserData.mapBoostExpiry = null;
      newUserData.mapBoostTier = null;
      newUserData.fcmTokens = Array.isArray(userData.fcmTokens)
        ? userData.fcmTokens
        : [];
      newUserData.termsAcceptedAt = userData.termsAcceptedAt || null;
      newUserData.termsVersion = userData.termsVersion || '';
      newUserData.referredBy = userData.referredBy || '';
      // Owner-side `service` list is conceptually "what services the owner
      // NEEDS for their pet" (legacy OWNER_SERVICES), not what they offer.
      // Clear any walker/sitter-provider values like 'dog_walking' that
      // would be meaningless on an Owner document.
      newUserData.service = [];
    }

    // v18.5 — #16 fix défensif : avant de créer le nouveau doc dans la target
    // collection, purger tout doc "zombie" potentiellement leftover (crash passé,
    // migration partielle, test data). Sans ça, un insertOne peut échouer en
    // E11000 (email unique) et l'UI affiche "Impossible de changer de rôle" /
    // "Email already exists", obligeant l'user à passer par le chemin long
    // owner→sitter→walker. Le filtre par email est safe car chaque rôle a son
    // propre espace email-unique.
    // v565 — Daniel : « un compte, trois profils » + « garder mes abonnements
    // déjà payés ». Le changement de profil n'est PLUS destructif : si le profil
    // cible existe déjà, on le RÉUTILISE (jeton + champs partagés + abonnement
    // synchronisés) ; sinon on le crée SANS supprimer le profil courant. Les
    // trois profils coexistent donc (login → availableRoles).
    const capRole = (r) => r.charAt(0).toUpperCase() + r.slice(1);
    const existingTarget = await ROLE_MODELS[targetRole].findOne({
      $or: [{ email: userData.email }, ...(baseOldId ? [{ oldId: baseOldId }] : [])],
    });
    if (existingTarget) {
      try {
        // v575 — le profil cible existe déjà : on ne l'ÉCRASE PAS avec les
        // valeurs du rôle courant (l'utilisateur a pu y saisir autre chose).
        // On ne COMPLÈTE que ses champs d'identité VIDES, depuis le profil
        // source. Le reste du rattrapage (frère le plus récemment modifié)
        // est fait par `fillMissingIdentityFromSiblings` juste après.
        const fromSource = buildIdentityFromSource(userData);
        const shared = {};
        for (const [k, v] of Object.entries(fromSource)) {
          if (isEmptyIdentityValue(existingTarget[k])) shared[k] = v;
        }
        if (Array.isArray(userData.fcmTokens) && userData.fcmTokens.length) {
          await ROLE_MODELS[targetRole].updateOne(
            { _id: existingTarget._id },
            {
              ...(Object.keys(shared).length ? { $set: shared } : {}),
              $addToSet: { fcmTokens: { $each: userData.fcmTokens } },
            },
          );
        } else if (Object.keys(shared).length) {
          await ROLE_MODELS[targetRole].updateOne({ _id: existingTarget._id }, { $set: shared });
        }
      } catch (e) {
        logger.warn('[switchRole] synchro des champs partagés échouée (non bloquant)', e);
      }
      try {
        const { syncSubscriptionAcrossRoles } = require('../models/UserSubscription');
        await syncSubscriptionAcrossRoles(userId, capRole(currentRole));
      } catch (e) {
        logger.warn('[switchRole] synchro abonnement échouée (non bloquant)', e);
      }
      const reusedDoc = await ROLE_MODELS[targetRole].findById(existingTarget._id);
      // v575 — dernier filet : ce qui reste vide est complété depuis le frère
      // le plus récemment modifié (réponse ET base, pour ce document seul).
      await fillMissingIdentityFromSiblings(reusedDoc, targetRole);
      const token = signAuthToken({ id: reusedDoc._id.toString(), role: targetRole });
      let availableRoles = [];
      try {
        const { findAvailableRolesForAccount } = require('./authController');
        availableRoles = await findAvailableRolesForAccount(userData.email, baseOldId);
      } catch (_) { /* best-effort */ }
      logger.info(`[switchRole] ${currentRole} -> ${targetRole} : profil existant réutilisé (${reusedDoc._id})`);
      return res.json({
        message: `Switched to existing ${targetRole} profile.`,
        role: targetRole,
        token,
        user: sanitizeUser(reusedDoc, { includeEmail: true }),
        availableRoles,
        reused: true,
      });
    }

    const TargetModelForCleanup = ROLE_MODELS[targetRole];
    if (TargetModelForCleanup) {
      const zombieFilter = {
        $or: [
          { email: userData.email },
          ...(baseOldId ? [{ oldId: baseOldId }] : []),
        ],
      };
      const deletedZombies = await TargetModelForCleanup.deleteMany(zombieFilter);
      if (deletedZombies?.deletedCount) {
        logger.info(
          `[switchRole] Purged ${deletedZombies.deletedCount} zombie ${targetRole} doc(s) for email=${userData.email} before insert.`
        );
      }
    }

    // Create new user in target role using collection.insertOne to bypass Mongoose defaults
    // This prevents Mongoose from applying location defaults with null coordinates
    let insertedResult;
    let newUser;
    if (targetRole === 'owner') {
      // When switching back to owner, reuse the stable oldId as _id
      // so the owner keeps the same identifier across switches.
      const ownerInsertData = {
        ...newUserData,
        _id: baseOldId,
        oldId: baseOldId,
      };
      insertedResult = await Owner.collection.insertOne(ownerInsertData);
      newUser = await Owner.findById(insertedResult.insertedId);
    } else if (targetRole === 'sitter') {
      insertedResult = await Sitter.collection.insertOne(newUserData);
      newUser = await Sitter.findById(insertedResult.insertedId);
    } else {
      // walker — let MongoDB assign a new _id, keep oldId for traceability.
      insertedResult = await Walker.collection.insertOne(newUserData);
      newUser = await Walker.findById(insertedResult.insertedId);
    }
    logger.info(
      `[switchRole] ${currentRole} -> ${targetRole} OK. userId=${userId} -> newId=${insertedResult.insertedId}`
    );

    // Restore the original password hash using updateOne (bypasses pre-save hook)
    // This is necessary because insertOne doesn't trigger pre-save hooks, so password is already correct
    // But we still update it to be safe, and also remove location if it was invalid
    const updateOps = { $set: { password: originalPasswordHash } };
    if (!hasValidCoordinates) {
      updateOps.$unset = { location: '' };
    }

    const TargetModel = ROLE_MODELS[targetRole];
    await TargetModel.updateOne({ _id: newUser._id }, updateOps);
    newUser = await TargetModel.findById(newUser._id);

    // v565 — les trois profils coexistent : amitiés et conversations RESTENT
    // sur le profil d'origine (les lectures passent par identityGroup) ; seul
    // l'abonnement est COPIÉ vers le nouveau profil (« garder mes abonnements »).
    try {
      const { syncSubscriptionAcrossRoles } = require('../models/UserSubscription');
      await syncSubscriptionAcrossRoles(userId, capRole(currentRole));
    } catch (subErr) {
      logger.warn('[switchRole] copie abonnement échouée (non bloquant)', subErr);
    }

    // v565 — l'ancien profil N'EST PLUS supprimé (coexistence des 3 profils).
    let availableRolesAfter = [];
    try {
      const { findAvailableRolesForAccount } = require('./authController');
      availableRolesAfter = await findAvailableRolesForAccount(userData.email, baseOldId);
    } catch (_) { /* best-effort */ }

    // Generate new token with new role and new user ID
    const token = signAuthToken({ id: newUser._id.toString(), role: targetRole });

    res.json({
      message: `Successfully switched from ${currentRole} to ${targetRole}.`,
      role: targetRole,
      token,
      user: sanitizeUser(newUser, { includeEmail: true }),
      availableRoles: availableRolesAfter,
      reused: false,
    });
  } catch (error) {
    logger.error('Switch role error', error);
    if (error.code === 11000) {
      // Duplicate key error (email already exists)
      return res.status(409).json({ error: 'Email already exists. Unable to switch role.' });
    }
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res.status(500).json({ error: 'Authentication service is not configured.' });
    }
    res.status(500).json({ error: 'Unable to switch role. Please try again later.' });
  }
};

const resolveUserModel = (role) => {
  if (role === 'sitter') return Sitter;
  if (role === 'owner') return Owner;
  // v18.5 — #11 fix : walker support pour FCM token registration, accept terms,
  // etc. Avant v18.5, les walkers tombaient en 403 "Unsupported role" car
  // resolveUserModel retournait null → registerFcmToken échouait silencieusement
  // → aucun push FCM ne parvenait au device. Les notifs in-app et email
  // continuaient à marcher via d'autres chemins.
  if (role === 'walker') return Walker;
  return null;
};

const acceptTerms = async (req, res) => {
  try {
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const version = process.env.TERMS_VERSION || 'v1.0';
    const result = await Model.findByIdAndUpdate(
      req.user.id,
      {
        acceptedTerms: true,
        termsAcceptedAt: new Date(),
        termsVersion: version,
      },
      { new: true }
    ).select('acceptedTerms termsAcceptedAt termsVersion');
    if (!result) return res.status(404).json({ error: 'User not found.' });
    return res.json({
      acceptedTerms: result.acceptedTerms,
      termsAcceptedAt: result.termsAcceptedAt,
      termsVersion: result.termsVersion,
    });
  } catch (e) {
    logger.error('acceptTerms error', e);
    return res.status(500).json({ error: 'Unable to record terms acceptance.' });
  }
};

// v23.1.348 — Daniel : "la langue doit suivre le système dès l'installation".
// PATCH /users/me/app-locale { locale: 'fr'|'en'|'es'|'de'|'it'|'pt' }.
// L'app synchronise sa langue UI (choisie ou héritée du téléphone) → le champ
// appLocale pilote la locale des notifications/emails (prioritaire sur le
// champ libre 'language' = langues parlées affichées sur les profils).
const APP_LOCALES = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']; // v546 — polonais
const updateAppLocale = async (req, res) => {
  try {
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const locale = String(req.body?.locale || '').toLowerCase().trim().slice(0, 2);
    if (!APP_LOCALES.includes(locale)) {
      return res.status(400).json({ error: 'Unsupported locale.', supported: APP_LOCALES });
    }
    const result = await Model.findByIdAndUpdate(
      req.user.id,
      { appLocale: locale },
      { new: true },
    ).select('appLocale email oldId');
    if (!result) return res.status(404).json({ error: 'User not found.' });
    // v530 — Daniel : « notifs mal traduites ». La langue UI n'était écrite que
    // sur le doc du rôle COURANT ; les 2 autres profils de la même personne
    // (même email/oldId) gardaient appLocale vide → leurs notifs/push/emails
    // retombaient sur le champ libre `language` (langues parlées). On propage
    // aux 3 collections — même famille que gatherFcmTokens/identityGroup.
    try {
      const or = [{ _id: req.user.id }];
      if (result.email) or.push({ email: result.email });
      if (result.oldId != null) or.push({ oldId: result.oldId });
      await Promise.all([Owner, Sitter, Walker].map((M) =>
        M.updateMany({ $or: or }, { appLocale: locale }),
      ));
    } catch (e) {
      logger.warn(`updateAppLocale cross-role propagation failed: ${e?.message || e}`);
    }
    return res.json({ appLocale: result.appLocale });
  } catch (e) {
    logger.error('updateAppLocale error', e);
    return res.status(500).json({ error: 'Unable to update app locale.' });
  }
};

const registerFcmToken = async (req, res) => {
  try {
    const { token } = req.body || {};
    if (!token || typeof token !== 'string' || !token.trim()) {
      return res.status(400).json({ error: 'token is required.' });
    }
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role for FCM registration.' });
    const platform = String(req.body?.platform || '').toLowerCase().slice(0, 12);
    // v566 — build de l'app (entier après le « + » de X-App-Version, ex. « 23.1.563+566 »)
    // → le serveur n'envoie le badge chiffré iOS qu'aux apps qui savent le remettre à jour.
    const buildMatch = String(req.headers['x-app-version'] || req.body?.appBuild || '').match(/(?:\+|^)(\d{1,6})$/);
    const appBuild = buildMatch ? Number(buildMatch[1]) : 0;
    // v565 — mémorise la plateforme du jeton (ios/android) pour l'admin.
    await Model.findByIdAndUpdate(req.user.id, { $pull: { fcmDevices: { token: token.trim() } } });
    const result = await Model.findByIdAndUpdate(
      req.user.id,
      {
        $addToSet: { fcmTokens: token.trim() },
        $push: { fcmDevices: { token: token.trim(), platform, appBuild, at: new Date() } },
      },
      { new: true }
    ).select('fcmTokens');
    if (!result) return res.status(404).json({ error: 'User not found.' });
    return res.json({ ok: true, count: result.fcmTokens.length });
  } catch (e) {
    logger.error('registerFcmToken error', e);
    return res.status(500).json({ error: 'Unable to register FCM token.' });
  }
};

const unregisterFcmToken = async (req, res) => {
  try {
    const { token } = req.body || {};
    if (!token || typeof token !== 'string' || !token.trim()) {
      return res.status(400).json({ error: 'token is required.' });
    }
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role for FCM unregistration.' });
    const result = await Model.findByIdAndUpdate(
      req.user.id,
      { $pull: { fcmTokens: token.trim(), fcmDevices: { token: token.trim() } } },
      { new: true }
    ).select('fcmTokens');
    if (!result) return res.status(404).json({ error: 'User not found.' });
    return res.json({ ok: true, count: result.fcmTokens.length });
  } catch (e) {
    logger.error('unregisterFcmToken error', e);
    return res.status(500).json({ error: 'Unable to unregister FCM token.' });
  }
};

// ───────────────────────────────────────────────────────────────────────────
// v444 — Favoris prestataires (cœur sur les cartes de recherche owner).
// 100 % ADDITIF. Stockés sur Owner.favoriteProviders ([{providerId, providerRole}]).
// Réservé à l'owner (seul rôle qui cherche/like des prestataires).
// ───────────────────────────────────────────────────────────────────────────

const VALID_PROVIDER_ROLES = ['sitter', 'walker'];

/// POST /users/me/favorites { providerId, providerRole } → ajout idempotent.
const addFavoriteProvider = async (req, res) => {
  try {
    if (req.user?.role !== 'owner') {
      return res.status(403).json({ error: 'Only owners can have favorite providers.' });
    }
    const providerId = String(req.body?.providerId || '').trim();
    const providerRole = String(req.body?.providerRole || '').trim().toLowerCase();
    if (!providerId) {
      return res.status(400).json({ error: 'providerId is required.' });
    }
    if (!VALID_PROVIDER_ROLES.includes(providerRole)) {
      return res.status(400).json({
        error: `providerRole must be one of: ${VALID_PROVIDER_ROLES.join(', ')}.`,
      });
    }

    const owner = await Owner.findById(req.user.id).select('favoriteProviders');
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    const list = Array.isArray(owner.favoriteProviders) ? owner.favoriteProviders : [];
    const exists = list.some(
      (f) => String(f.providerId) === providerId && f.providerRole === providerRole,
    );
    if (!exists) {
      // $addToSet ne dédoublonne pas fiablement sur des sous-documents (addedAt
      // diffère) → on contrôle l'existence à la main et on $push uniquement si neuf.
      await Owner.updateOne(
        { _id: req.user.id },
        { $push: { favoriteProviders: { providerId, providerRole, addedAt: new Date() } } },
      );
    }

    const fresh = await Owner.findById(req.user.id).select('favoriteProviders').lean();
    const favorites = (fresh?.favoriteProviders || []).map((f) => ({
      providerId: String(f.providerId),
      providerRole: f.providerRole,
    }));
    return res.json({ favorites });
  } catch (error) {
    logger.error('addFavoriteProvider error', error);
    return res.status(500).json({ error: 'Unable to add favorite. Please try again later.' });
  }
};

/// DELETE /users/me/favorites/:providerId → suppression (idempotent).
const removeFavoriteProvider = async (req, res) => {
  try {
    if (req.user?.role !== 'owner') {
      return res.status(403).json({ error: 'Only owners can have favorite providers.' });
    }
    const providerId = String(req.params?.providerId || '').trim();
    if (!providerId) {
      return res.status(400).json({ error: 'providerId is required.' });
    }

    const owner = await Owner.findById(req.user.id).select('_id');
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    await Owner.updateOne(
      { _id: req.user.id },
      { $pull: { favoriteProviders: { providerId } } },
    );

    const fresh = await Owner.findById(req.user.id).select('favoriteProviders').lean();
    const favorites = (fresh?.favoriteProviders || []).map((f) => ({
      providerId: String(f.providerId),
      providerRole: f.providerRole,
    }));
    return res.json({ favorites });
  } catch (error) {
    logger.error('removeFavoriteProvider error', error);
    return res.status(500).json({ error: 'Unable to remove favorite. Please try again later.' });
  }
};

/// GET /users/me/favorites → liste de { providerId, providerRole }.
const getFavoriteProviders = async (req, res) => {
  try {
    if (req.user?.role !== 'owner') {
      return res.status(403).json({ error: 'Only owners can have favorite providers.' });
    }
    const owner = await Owner.findById(req.user.id).select('favoriteProviders').lean();
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }
    const favorites = (owner.favoriteProviders || []).map((f) => ({
      providerId: String(f.providerId),
      providerRole: f.providerRole,
    }));
    return res.json({ favorites });
  } catch (error) {
    logger.error('getFavoriteProviders error', error);
    return res.status(500).json({ error: 'Unable to load favorites. Please try again later.' });
  }
};

// ─── v565 §2 — préférences de notification ──────────────────────────────────
const getNotificationPrefs = async (req, res) => {
  try {
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const doc = await Model.findById(req.user.id).select('email oldId notificationPrefs').lean();
    if (!doc) return res.status(404).json({ error: 'User not found.' });
    const { resolveNotificationPrefsAcrossRoles } = require('../services/notificationSender');
    return res.json(await resolveNotificationPrefsAcrossRoles(doc, req.user.id));
  } catch (e) {
    logger.error('getNotificationPrefs error', e);
    return res.status(500).json({ error: 'Unable to load notification preferences.' });
  }
};

const updateNotificationPrefs = async (req, res) => {
  try {
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const {
      NOTIFICATION_SOUNDS, NOTIFICATION_CATEGORIES,
      normalizeNotificationPrefs, resolveNotificationPrefsAcrossRoles,
    } = require('../services/notificationSender');
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    if (body.sound !== undefined && !NOTIFICATION_SOUNDS.includes(String(body.sound).toLowerCase())) {
      return res.status(400).json({ error: `sound must be one of: ${NOTIFICATION_SOUNDS.join(', ')}.` });
    }
    if (body.categories !== undefined && (typeof body.categories !== 'object' || body.categories === null)) {
      return res.status(400).json({ error: 'categories must be an object.' });
    }
    const doc = await Model.findById(req.user.id).select('email oldId notificationPrefs').lean();
    if (!doc) return res.status(404).json({ error: 'User not found.' });
    // Corps partiel : on part de l'état courant (défauts si absent).
    const current = await resolveNotificationPrefsAcrossRoles(doc, req.user.id);
    const merged = normalizeNotificationPrefs({
      sound: body.sound !== undefined ? body.sound : current.sound,
      categories: { ...current.categories, ...(body.categories || {}) },
    });
    for (const k of Object.keys(body.categories || {})) {
      if (!NOTIFICATION_CATEGORIES.includes(k)) {
        return res.status(400).json({ error: `Unknown category "${k}".`, categories: NOTIFICATION_CATEGORIES });
      }
    }
    // Synchro sur les 3 docs de la personne.
    const g = await identityGroup(req.user.id);
    await Promise.all(g.docs.map((d) => {
      const M = MODEL_BY_NAME[d.model];
      return M ? M.updateOne({ _id: d.id }, { $set: { notificationPrefs: merged } }) : null;
    }));
    logger.info(`[notif.prefs] ${req.user.role}:${req.user.id} → sound=${merged.sound} categories=${JSON.stringify(merged.categories)} (${g.docs.length} doc(s))`);
    return res.json(merged);
  } catch (e) {
    logger.error('updateNotificationPrefs error', e);
    return res.status(500).json({ error: 'Unable to update notification preferences.' });
  }
};

// ─── v565 §3 — changement d'e-mail par l'utilisateur ────────────────────────
// Même logique que PATCH /admin/users/:role/:id/email (unicité sur les 3
// collections hors comptes frères, propagation aux 3 docs), en version
// « moi-même » : mot de passe exigé, code de vérification envoyé à la NOUVELLE
// adresse (emailService.sendVerificationEmail, langue du compte), 24 h.
// Les e-mails sont stockés en clair (lowercase) — comme authController.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const EMAIL_CHANGE_TTL_H = 24;
const EMAIL_CHANGE_RESEND_MS = 2 * 60 * 1000;
const LANG_NAMES = {
  'français': 'fr', francais: 'fr', french: 'fr', english: 'en', anglais: 'en',
  'español': 'es', espanol: 'es', spanish: 'es', deutsch: 'de', german: 'de',
  italiano: 'it', italian: 'it', 'português': 'pt', portugues: 'pt', portuguese: 'pt',
  polski: 'pl', polish: 'pl', '한국어': 'ko', korean: 'ko', '日本語': 'ja', japanese: 'ja',
};
const emailLangOf = async (doc, userId) => {
  const { resolveAppLocaleAcrossRoles } = require('../services/notificationSender');
  const appLocale = await resolveAppLocaleAcrossRoles(doc, userId);
  const raw = String(appLocale || doc?.language || '').toLowerCase().trim();
  if (LANG_NAMES[raw]) return LANG_NAMES[raw];
  const short = raw.slice(0, 2);
  return ['fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ko', 'ja'].includes(short) ? short : 'en';
};
const _sendEmailChangeCode = async (Model, doc, userId, newEmail) => {
  const { generateVerificationCode, hashCode } = require('../utils/code');
  const { sendVerificationEmail } = require('../services/emailService');
  const code = generateVerificationCode();
  const pending = {
    pendingEmail: newEmail,
    pendingEmailCodeHash: hashCode(code),
    pendingEmailExpiresAt: new Date(Date.now() + EMAIL_CHANGE_TTL_H * 3600 * 1000),
    pendingEmailSentAt: new Date(),
  };
  // Posé sur les 3 docs : la confirmation peut venir d'un autre rôle.
  const g = await identityGroup(userId);
  await Promise.all(g.docs.map((d) => {
    const M = MODEL_BY_NAME[d.model];
    return M ? M.updateOne({ _id: d.id }, { $set: pending }) : null;
  }));
  const lang = await emailLangOf(doc, userId);
  await sendVerificationEmail(newEmail, code, lang, doc.name);
  logger.info(`[email-change] code sent to new address for ${userId} (lang=${lang})`);
};

const requestEmailChange = async (req, res) => {
  try {
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const newEmail = String((req.body || {}).newEmail || '').trim().toLowerCase();
    const password = String((req.body || {}).password || '');
    if (!EMAIL_RE.test(newEmail)) return res.status(400).json({ error: 'Invalid email address.', code: 'EMAIL_INVALID' });
    if (!password) return res.status(400).json({ error: 'Password is required.', code: 'PASSWORD_REQUIRED' });
    const doc = await Model.findById(req.user.id);
    if (!doc) return res.status(404).json({ error: 'User not found.' });
    const ok = await doc.comparePassword(password).catch(() => false);
    if (!ok) return res.status(401).json({ error: 'Incorrect password.', code: 'PASSWORD_INCORRECT' });
    const currentEmail = String(doc.email || '').toLowerCase();
    if (newEmail === currentEmail) {
      return res.status(400).json({ error: 'This is already your email address.', code: 'EMAIL_SAME' });
    }
    // Unicité sur les 3 collections, hors comptes frères (même personne).
    const g = await identityGroup(req.user.id);
    const taken = (await Promise.all([Owner, Sitter, Walker].map((M) =>
      M.find({ $or: [{ email: newEmail }, { pendingEmail: newEmail }] }).select('_id email').lean(),
    ))).flat().filter((d) => !g.set.has(String(d._id)) && String(d.email).toLowerCase() === newEmail);
    if (taken.length) {
      return res.status(409).json({ error: 'This email address is already in use.', code: 'EMAIL_TAKEN' });
    }
    await _sendEmailChangeCode(Model, doc.toObject(), req.user.id, newEmail);
    return res.json({ ok: true });
  } catch (e) {
    logger.error('requestEmailChange error', e);
    return res.status(500).json({ error: 'Unable to start email change.' });
  }
};

const confirmEmailChange = async (req, res) => {
  try {
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const code = String((req.body || {}).code || '').trim();
    if (!/^\d{6}$/.test(code)) return res.status(400).json({ error: 'Invalid code.', code: 'CODE_INVALID' });
    const doc = await Model.findById(req.user.id)
      .select('email oldId pendingEmail +pendingEmailCodeHash pendingEmailExpiresAt').lean();
    if (!doc) return res.status(404).json({ error: 'User not found.' });
    const newEmail = String(doc.pendingEmail || '').toLowerCase();
    if (!newEmail || !doc.pendingEmailCodeHash) {
      return res.status(400).json({ error: 'No pending email change.', code: 'NO_PENDING_EMAIL' });
    }
    if (!doc.pendingEmailExpiresAt || new Date(doc.pendingEmailExpiresAt) < new Date()) {
      return res.status(400).json({ error: 'Verification code expired. Please request a new code.', code: 'CODE_EXPIRED' });
    }
    const { compareCode } = require('../utils/code');
    if (!compareCode(code, doc.pendingEmailCodeHash)) {
      return res.status(400).json({ error: 'Invalid verification code.', code: 'CODE_INVALID' });
    }
    // Groupe d'identité calculé AVANT de changer l'e-mail (clé de liaison).
    const g = await identityGroup(req.user.id);
    const taken = (await Promise.all([Owner, Sitter, Walker].map((M) =>
      M.find({ email: newEmail }).select('_id').lean(),
    ))).flat().filter((d) => !g.set.has(String(d._id)));
    if (taken.length) {
      return res.status(409).json({ error: 'This email address is already in use.', code: 'EMAIL_TAKEN' });
    }
    const oldEmail = String(doc.email || '').toLowerCase();
    const results = await Promise.all(g.docs.map((d) => {
      const M = MODEL_BY_NAME[d.model];
      return M ? M.updateOne({ _id: d.id }, {
        $set: { email: newEmail, verified: true },
        $unset: { pendingEmail: '', pendingEmailCodeHash: '', pendingEmailExpiresAt: '', pendingEmailSentAt: '' },
      }) : { modifiedCount: 0 };
    }));
    const changed = results.reduce((n, r) => n + (r?.modifiedCount || 0), 0);
    try {
      const VerificationCode = require('../models/VerificationCode');
      await VerificationCode.deleteMany({ email: { $in: [oldEmail, newEmail] }, purpose: 'email_verification' });
    } catch (_) { /* best-effort */ }
    logger.info(`[email-change] ${req.user.role}:${req.user.id} ${oldEmail} -> ${newEmail} (${changed} doc(s))`);
    return res.json({ ok: true, email: newEmail, changed });
  } catch (e) {
    logger.error('confirmEmailChange error', e);
    return res.status(500).json({ error: 'Unable to confirm email change.' });
  }
};

const resendEmailChange = async (req, res) => {
  try {
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const doc = await Model.findById(req.user.id)
      .select('name email oldId language appLocale pendingEmail pendingEmailSentAt pendingEmailExpiresAt').lean();
    if (!doc) return res.status(404).json({ error: 'User not found.' });
    const newEmail = String(doc.pendingEmail || '').toLowerCase();
    if (!newEmail) return res.status(400).json({ error: 'No pending email change.', code: 'NO_PENDING_EMAIL' });
    const last = doc.pendingEmailSentAt ? new Date(doc.pendingEmailSentAt).getTime() : 0;
    const wait = EMAIL_CHANGE_RESEND_MS - (Date.now() - last);
    if (wait > 0) {
      return res.status(429).json({
        error: 'Please wait before requesting a new code.',
        code: 'RESEND_TOO_SOON',
        retryAfterSeconds: Math.ceil(wait / 1000),
      });
    }
    await _sendEmailChangeCode(Model, doc, req.user.id, newEmail);
    return res.json({ ok: true });
  } catch (e) {
    logger.error('resendEmailChange error', e);
    return res.status(500).json({ error: 'Unable to resend the verification code.' });
  }
};

module.exports = {
  // v565
  getNotificationPrefs,
  updateNotificationPrefs,
  requestEmailChange,
  confirmEmailChange,
  resendEmailChange,
  // v575 — `propagateToSiblings` a été remplacé par
  // `utils/sharedIdentity.propagateSharedIdentity` (liste blanche stricte,
  // jamais d'écrasement par du vide). Personne ne l'importait.
  updateService,
  updateProfile,
  updateCard,
  updateOwnerCardFromToken,
  deleteAccountFromToken,
  deleteAccount,
  updateProfilePicture,
  getOwnerProfile,
  switchRole,
  registerFcmToken,
  unregisterFcmToken,
  acceptTerms,
  updateAppLocale,
  getMyLoyalty,
  getMyReferralsRoute,
  addFavoriteProvider,
  removeFavoriteProvider,
  getFavoriteProviders,
};

// Sprint 7 step 3 — referral program.
async function getMyReferralsRoute(req, res) {
  try {
    const role = req.user?.role;
    // Session avril 2026 — walker role supported alongside owner/sitter.
    if (role !== 'owner' && role !== 'sitter' && role !== 'walker') {
      return res.status(403).json({ error: 'Unsupported role.' });
    }
    const data = await getMyReferrals(req.user.id, role);
    res.json(data);
  } catch (e) {
    logger.error('getMyReferrals error', e);
    res.status(500).json({ error: 'Unable to load referrals.' });
  }
}

// Sprint 7 step 1 — loyalty stats for owner self.
async function getMyLoyalty(req, res) {
  try {
    if (req.user?.role !== 'owner') {
      return res.status(403).json({ error: 'Only owners have a loyalty program.' });
    }
    const stats = await getOwnerStats(req.user.id);
    return res.json(stats);
  } catch (e) {
    logger.error('getMyLoyalty error', e);
    return res.status(500).json({ error: 'Unable to load loyalty stats.' });
  }
}

