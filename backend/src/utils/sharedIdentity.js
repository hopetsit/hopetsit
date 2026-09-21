/**
 * sharedIdentity.js — v575
 *
 * « Avec le même compte j'ai un profil propriétaire, pet-sitter et promeneur,
 *   mais les infos (nom, e-mail, téléphone, adresse) ne sont pas pré-enregistrées
 *   dans les autres profils » (Daniel, 21/09/2026).
 *
 * UNE PERSONNE = jusqu'à trois documents Mongo (Owner / Sitter / Walker) reliés
 * seulement par l'e-mail (et `oldId` pour les vieux comptes). Ce module est la
 * SEULE source de vérité de « ce qui décrit l'humain » et doit être appelé par
 * toutes les routes qui modifient un profil.
 *
 * Pourquoi un nouveau module alors que `utils/userSyncService.js` existe ?
 *   1. `syncSharedFields` propage `bio` et `skills` — la présentation d'un
 *      GARDIEN n'a rien à faire sur le profil propriétaire de la même personne ;
 *   2. il écrase par du VIDE : un écran d'édition qui n'affiche pas le champ
 *      « pays » envoie `country: ''` et effaçait le pays des deux autres profils ;
 *   3. il matche uniquement sur l'e-mail (pas `oldId`) et ne propage jamais la
 *      ville plate `city` posée hors du payload (chemins « ville sans GPS ») ;
 *   4. il écrase `location` en entier, donc l'état du partage en direct
 *      (`liveShareActive`, `location.updatedAt`) du profil frère.
 * `userSyncService` reste en service pour les champs de PAIEMENT (IBAN, PayPal,
 * client Airwallex) — ce ne sont pas des champs d'identité.
 *
 * CHIFFREMENT : aucun des champs listés ici n'est chiffré en base (seuls
 * `paypalEmail`, `ibanNumber`, `insuranceCertUrl`, `identityVerification.documentUrl`
 * et les anciens `card.number`/`card.cvc` le sont — cf. `utils/encryption.js` et
 * les hooks `pre('save')` de Sitter/Walker). On recopie donc la valeur STOCKÉE
 * telle quelle ; si une valeur porte malgré tout le préfixe `gcm:`, elle est
 * copiée verbatim (même clé globale) et JAMAIS déchiffrée. Aucune donnée
 * personnelle n'est écrite dans les logs.
 */

const logger = require('./logger');
const { isEncrypted } = require('./encryption');

// ─── Liste blanche : ce qui décrit la PERSONNE ──────────────────────────────
// Chacun de ces champs existe sous le MÊME nom dans Owner.js, Sitter.js et
// Walker.js (vérifié le 21/09/2026). Il n'y a donc aucune table de
// correspondance à maintenir : `name` (il n'existe ni `firstName` ni
// `lastName` dans ce projet), `mobile` + `countryCode`, `address`, `city`,
// `country`, `language`, `appLocale`, `currency`, `dateOfBirth`, `avatar`.
const SHARED_IDENTITY_FIELDS = [
  'name',
  // v575 — « nom et prénom » : `name` reste la source d'affichage partout,
  // `firstName`/`lastName` l'alimentent (cf. utils/personName.js).
  'firstName',
  'lastName',
  'mobile',
  'countryCode',
  'address',
  'city',
  'country',
  'language',
  'appLocale',
  'currency',
  'dateOfBirth',
  'avatar',
];

// `location` est partagé lui aussi (c'est le domicile de la personne) mais il
// ne se recopie PAS en bloc : le sous-document porte aussi l'état du partage en
// direct (`liveShareActive`, `updatedAt`) qui appartient au rôle. On écrit donc
// des chemins pointés, et jamais l'objet entier.
const LOCATION_FIELD = 'location';

// ─── Ce qui NE DOIT JAMAIS être propagé (documenté pour les relectures) ─────
// bio, skills, rate/hourlyRate/dailyRate/weeklyRate/monthlyRate/walkRates,
// extraPetRate, servicePricing, service, servicePreferences, canServiceAt*,
// availableDates/unavailableDates/availableTimeSlots/availableDays,
// coverageCity, coverageRadiusKm, acceptedPetTypes, maxPetsPerWalk,
// hasInsurance, experienceTags, responseTimeMinutes, ibanNumber/ibanHolder/
// ibanBic/payoutMethod/paypalEmail, card/airwallexCustomerId/
// defaultCardConsentId, kyc*, identityVerification, isPremium/boost*/mapBoost*,
// pawPoints*, rating/reviewsCount/averageRating/feedback, preferences,
// searchPreferences, notificationPrefs (déjà synchronisées par leur propre
// route), password, fcmTokens/fcmDevices, status/banReason, verified,
// referralCode, billingInfo (déjà synchronisée par utils/billingInfo.js).
const ROLE_ONLY_FIELDS_DOC = Object.freeze([
  'bio', 'skills', 'rate', 'hourlyRate', 'dailyRate', 'weeklyRate', 'monthlyRate',
  'walkRates', 'servicePricing', 'service', 'servicePreferences', 'availableDates',
  'unavailableDates', 'availableTimeSlots', 'availableDays', 'coverageCity',
  'coverageRadiusKm', 'acceptedPetTypes', 'maxPetsPerWalk', 'hasInsurance',
  'experienceTags', 'responseTimeMinutes', 'ibanNumber', 'ibanHolder', 'ibanBic',
  'payoutMethod', 'paypalEmail', 'card', 'airwallexCustomerId', 'defaultCardConsentId',
  'kycStatus', 'identityVerification', 'isPremium', 'boostExpiry', 'mapBoostExpiry',
  'pawPoints', 'rating', 'reviewsCount', 'feedback', 'preferences', 'searchPreferences',
  'notificationPrefs', 'password', 'fcmTokens', 'status', 'verified', 'referralCode',
  'billingInfo',
]);

const MODEL_BY_NAME = () => ({
  Owner: require('../models/Owner'),
  Sitter: require('../models/Sitter'),
  Walker: require('../models/Walker'),
});
const MODEL_BY_ROLE = () => ({
  owner: require('../models/Owner'),
  sitter: require('../models/Sitter'),
  walker: require('../models/Walker'),
});

/** Une valeur « vide » ne remplace jamais une valeur existante chez le frère. */
const isEmptyValue = (v) => {
  if (v === undefined || v === null) return true;
  if (typeof v === 'string') return v.trim() === '';
  if (typeof v === 'number') return false;
  if (typeof v === 'boolean') return false;
  if (v instanceof Date) return false;
  if (Array.isArray(v)) return v.length === 0;
  if (typeof v === 'object') {
    // avatar { url, publicId }
    if (Object.prototype.hasOwnProperty.call(v, 'url')) {
      return !String(v.url || '').trim();
    }
    // location { type, coordinates, city, … }
    if (Object.prototype.hasOwnProperty.call(v, 'coordinates')) {
      return !hasValidCoordinates(v);
    }
    return Object.keys(v).length === 0;
  }
  return false;
};

const hasValidCoordinates = (loc) =>
  !!loc &&
  Array.isArray(loc.coordinates) &&
  loc.coordinates.length === 2 &&
  typeof loc.coordinates[0] === 'number' &&
  typeof loc.coordinates[1] === 'number';

/** Normalisation minimale, identique à celle des contrôleurs. */
const normalizeValue = (field, value) => {
  if (value == null) return value;
  if (typeof value === 'string' && isEncrypted(value)) return value; // verbatim
  switch (field) {
    case 'name':
    case 'firstName':
    case 'lastName':
    case 'mobile':
    case 'address':
    case 'city':
    case 'language':
    case 'appLocale':
    case 'dateOfBirth':
      return typeof value === 'string' ? value.trim() : value;
    case 'country':
      return typeof value === 'string' ? value.trim().toUpperCase().slice(0, 2) : value;
    case 'countryCode': {
      if (typeof value !== 'string') return value;
      const raw = value.trim().replace(/\s+/g, '');
      if (!raw) return '';
      return /^\d{1,4}$/.test(raw) ? `+${raw}` : raw;
    }
    case 'avatar':
      if (typeof value !== 'object') return value;
      return {
        url: String(value.url || '').trim(),
        publicId: String(value.publicId || '').trim(),
      };
    default:
      return value;
  }
};

/**
 * Extrait de `changedFields` les seuls champs partagés effectivement présents.
 * Rien de propre au rôle ne peut passer : la liste blanche fait foi.
 */
const pickSharedIdentity = (changedFields) => {
  const out = {};
  if (!changedFields || typeof changedFields !== 'object') return out;
  for (const field of SHARED_IDENTITY_FIELDS) {
    if (!Object.prototype.hasOwnProperty.call(changedFields, field)) continue;
    const v = changedFields[field];
    if (v === undefined) continue;
    out[field] = normalizeValue(field, v);
  }
  if (Object.prototype.hasOwnProperty.call(changedFields, LOCATION_FIELD)) {
    const loc = changedFields[LOCATION_FIELD];
    if (loc && typeof loc === 'object' && hasValidCoordinates(loc)) {
      out[LOCATION_FIELD] = loc;
    }
  }
  // v575 — `name`, `firstName` et `lastName` forment un TRIO indissociable :
  // propager « Daniel » sans vider le `lastName` du frère laisserait
  // « Daniel » + « Dupont » incohérents. Une ancienne app qui n'envoie que
  // `name` voit donc ses deux parties re-dérivées ici.
  if (out.name !== undefined) {
    const { splitFullName } = require('./personName');
    const parts = splitFullName(out.name);
    if (out.firstName === undefined) out.firstName = parts.firstName;
    if (out.lastName === undefined) out.lastName = parts.lastName;
  }
  return out;
};

/**
 * Traduit le payload partagé en `$set` à chemins pointés pour un frère donné.
 * `sibling` sert à décider si une valeur vide a le droit d'écraser (non) et si
 * `location.city` peut être posé (uniquement quand le frère a des coordonnées).
 */
const buildSiblingSet = (payload, sibling, { allowEmpty = [] } = {}) => {
  const $set = {};
  // Le trio nom : si `name` change, ses deux parties changent avec lui, même
  // quand l'une est vide (« Madonna » = prénom seul).
  if (payload.name !== undefined && !isEmptyValue(payload.name)) {
    allowEmpty = [...allowEmpty, 'firstName', 'lastName'];
  }
  for (const [field, value] of Object.entries(payload)) {
    if (field === LOCATION_FIELD) continue;
    const empty = isEmptyValue(value);
    if (empty && !allowEmpty.includes(field)) continue; // jamais d'écrasement par du vide
    const currentEmpty = isEmptyValue(sibling ? sibling[field] : undefined);
    if (empty && !currentEmpty && !allowEmpty.includes(field)) continue;
    $set[field] = value;
  }

  const loc = payload[LOCATION_FIELD];
  if (loc && hasValidCoordinates(loc)) {
    $set['location.type'] = 'Point';
    $set['location.coordinates'] = loc.coordinates;
    if (!isEmptyValue(loc.city)) $set['location.city'] = String(loc.city).trim();
    if (loc.locationType) $set['location.locationType'] = loc.locationType;
  } else if (
    $set.city &&
    hasValidCoordinates(sibling && sibling.location)
  ) {
    // Ville plate mise à jour sans GPS : on aligne aussi `location.city`, mais
    // seulement si le frère a déjà des coordonnées (sinon l'index 2dsphere
    // refuse un Point sans coordonnées).
    $set['location.city'] = $set.city;
  }

  return $set;
};

const SIBLING_SELECT = [...SHARED_IDENTITY_FIELDS, 'location', 'updatedAt', 'email', 'oldId'].join(' ');

/**
 * Recopie vers les documents frères (même e-mail / même oldId) UNIQUEMENT les
 * champs d'identité partagés effectivement modifiés.
 *
 * - `updateOne` ⇒ ni validateurs ni hooks `pre('save')` (rien à casser) ;
 * - une valeur vide ne remplace jamais une valeur existante chez le frère,
 *   sauf si le champ est listé dans `opts.allowEmpty` (l'utilisateur a
 *   explicitement vidé le champ dans sa requête) ;
 * - non bloquant : toute erreur est journalisée sans donnée personnelle.
 *
 * @param {object} sourceDoc  document mis à jour (mongoose doc ou objet simple)
 * @param {'owner'|'sitter'|'walker'} sourceRole
 * @param {object} changedFields  le `$set` réellement appliqué à la source
 * @param {{allowEmpty?: string[]}} [opts]
 * @returns {Promise<{fields: string[], targets: number, modified: number}>}
 */
async function propagateSharedIdentity(sourceDoc, sourceRole, changedFields, opts = {}) {
  const result = { fields: [], targets: 0, modified: 0 };
  try {
    if (!sourceDoc) return result;
    const src = typeof sourceDoc.toObject === 'function' ? sourceDoc.toObject() : sourceDoc;
    const sourceId = src._id ? String(src._id) : null;
    if (!sourceId) return result;

    const payload = pickSharedIdentity(changedFields);
    if (!Object.keys(payload).length) return result;
    result.fields = Object.keys(payload);

    const { identityGroup } = require('./identityGroup');
    const group = await identityGroup(sourceId);
    const models = MODEL_BY_NAME();

    for (const d of group.docs) {
      if (String(d.id) === sourceId) continue;
      const Model = models[d.model];
      if (!Model) continue;
      result.targets += 1;
      try {
        const sibling = await Model.findById(d.id).select(SIBLING_SELECT).lean();
        if (!sibling) continue;
        const $set = buildSiblingSet(payload, sibling, opts);
        if (!Object.keys($set).length) continue;
        const r = await Model.updateOne({ _id: d.id }, { $set });
        if (r && r.modifiedCount) result.modified += 1;
      } catch (e) {
        logger.warn(`[sharedIdentity] ${d.model} update failed: ${e && e.message ? e.message : e}`);
      }
    }

    logger.info(
      `[sharedIdentity] ${sourceRole}:${sourceId} → ${result.modified}/${result.targets} profil(s) frère(s) : ${result.fields.join(', ')}`,
    );
  } catch (e) {
    logger.warn(`[sharedIdentity] propagation failed: ${e && e.message ? e.message : e}`);
  }
  return result;
}

/**
 * Rattrapage À LA LECTURE (aucune migration sur les données de production).
 *
 * Quand un profil est lu et qu'un champ d'identité partagé y est VIDE alors
 * qu'un frère le possède, on le complète — en mémoire (donc dans la réponse)
 * ET en base POUR CE DOCUMENT SEULEMENT. Même principe que
 * `ensureAvatarFromSiblingRoles`, étendu à toute l'identité.
 *
 * En cas de désaccord entre deux frères, c'est le plus RÉCEMMENT MODIFIÉ qui
 * gagne (`updatedAt`).
 *
 * @param {object} account  document courant (mongoose doc ou objet lean)
 * @param {'owner'|'sitter'|'walker'} role
 * @returns {Promise<object>} le même `account`, complété
 */
async function fillMissingIdentityFromSiblings(account, role) {
  try {
    if (!account || !account._id) return account;

    // `firstName` / `lastName` ne se complètent PAS depuis un frère : ils se
    // dérivent du `name` du document lui-même (sinon un frère renommé
    // laisserait « Daniel » + « Dupont » incohérents). Traités à la fin.
    const NAME_PARTS = ['firstName', 'lastName'];
    const missing = SHARED_IDENTITY_FIELDS
      .filter((f) => !NAME_PARTS.includes(f))
      .filter((f) => isEmptyValue(account[f]));
    const needsLocation = !hasValidCoordinates(account.location);
    if (!missing.length && !needsLocation) return account;

    const { identityGroup } = require('./identityGroup');
    const group = await identityGroup(String(account._id));
    const models = MODEL_BY_NAME();

    const siblings = [];
    for (const d of group.docs) {
      if (String(d.id) === String(account._id)) continue;
      const Model = models[d.model];
      if (!Model) continue;
      const doc = await Model.findById(d.id).select(SIBLING_SELECT).lean();
      if (doc) siblings.push(doc);
    }
    if (!siblings.length) return account;

    // Le frère le plus récemment modifié fait foi.
    siblings.sort((a, b) => new Date(b.updatedAt || 0) - new Date(a.updatedAt || 0));

    const $set = {};
    for (const field of missing) {
      for (const sib of siblings) {
        const v = sib[field];
        if (isEmptyValue(v)) continue;
        const normalized = normalizeValue(field, v);
        $set[field] = normalized;
        account[field] = normalized;
        break;
      }
    }
    if (needsLocation) {
      for (const sib of siblings) {
        if (!hasValidCoordinates(sib.location)) continue;
        $set['location.type'] = 'Point';
        $set['location.coordinates'] = sib.location.coordinates;
        if (!isEmptyValue(sib.location.city)) $set['location.city'] = sib.location.city;
        if (sib.location.locationType) $set['location.locationType'] = sib.location.locationType;
        account.location = {
          ...(account.location && typeof account.location === 'object' ? account.location : {}),
          type: 'Point',
          coordinates: sib.location.coordinates,
          city: sib.location.city || (account.location && account.location.city) || '',
          ...(sib.location.locationType ? { locationType: sib.location.locationType } : {}),
        };
        break;
      }
    }

    if (Object.keys($set).length) {
      const Model = MODEL_BY_ROLE()[role];
      if (Model) {
        await Model.updateOne({ _id: account._id }, { $set });
        logger.info(
          `[sharedIdentity] rattrapage lecture ${role}:${account._id} : ${Object.keys($set).join(', ')}`,
        );
      }
    }
  } catch (e) {
    logger.warn(`[sharedIdentity] rattrapage lecture échoué: ${e && e.message ? e.message : e}`);
  }
  return account;
}

/**
 * Bloc d'identité à recopier dans un document de rôle qui vient d'être CRÉÉ
 * (`switchRole`). Uniquement des champs partagés, valeurs vides exclues.
 */
function buildIdentityFromSource(sourceDoc) {
  const out = {};
  if (!sourceDoc) return out;
  const src = typeof sourceDoc.toObject === 'function' ? sourceDoc.toObject() : sourceDoc;
  for (const field of SHARED_IDENTITY_FIELDS) {
    const v = src[field];
    if (isEmptyValue(v)) continue;
    out[field] = normalizeValue(field, v);
  }
  if (isEmptyValue(out.city) && src.location && !isEmptyValue(src.location.city)) {
    out.city = String(src.location.city).trim();
  }
  // Compte historique sans `firstName`/`lastName` : on les dérive de `name`
  // pour que le nouveau profil naisse déjà en « prénom + nom ».
  if (out.name && (isEmptyValue(out.firstName) || out.firstName === undefined)) {
    const { splitFullName } = require('./personName');
    const parts = splitFullName(out.name);
    out.firstName = parts.firstName;
    out.lastName = parts.lastName;
  }
  return out;
}

module.exports = {
  SHARED_IDENTITY_FIELDS,
  ROLE_ONLY_FIELDS_DOC,
  propagateSharedIdentity,
  fillMissingIdentityFromSiblings,
  buildIdentityFromSource,
  pickSharedIdentity,
  isEmptyValue,
};
