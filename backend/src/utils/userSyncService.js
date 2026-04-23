/**
 * userSyncService.js  —  v18.9.8
 *
 * Sync des champs partagés entre les 3 collections Owner / Sitter / Walker.
 *
 * Contexte — HoPetSit autorise un même utilisateur (même email) à avoir
 * simultanément un compte Owner, Sitter ET Walker. Les 3 docs Mongo sont
 * indépendants (voir Owner.js / Sitter.js / Walker.js) et ne partagent
 * actuellement aucune information. Résultat : si Daniel met à jour son
 * nom / adresse / carte CB depuis le profil Owner, les profils Sitter et
 * Walker restent figés sur l'ancienne valeur.
 *
 * Cette utility propage automatiquement les champs qui doivent rester
 * cohérents (identité + paiement + adresse + préférences). Les champs
 * spécifiques à un rôle (tarifs, pets, bio service) NE sont PAS syncés.
 *
 * Usage :
 *   const { syncSharedFields } = require('../utils/userSyncService');
 *   await syncSharedFields({ email: user.email, update, excludeRole: 'owner' });
 *
 * Les erreurs de sync ne bloquent JAMAIS l'update principal — on log et
 * on continue. Mieux vaut un sync différé qu'un 500 côté API.
 */

const logger = require('./logger');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');

/**
 * Liste des champs considérés comme partagés entre les 3 rôles.
 *
 * Ne PAS inclure : hourlyRate, dailyRate, weeklyRate, monthlyRate,
 *   walkRates, pets, servicePricing, servicePreferences, isTopSitter,
 *   isTopWalker, identityVerification, coverageCity, coverageRadiusKm,
 *   acceptedPetTypes, maxPetsPerWalk, hasInsurance (propres à chaque rôle).
 */
const SHARED_FIELDS = [
  // Identité
  'name',
  'firstName',
  'lastName',
  'fullName',
  'mobile',
  'phone',
  'phoneNumber',
  'countryCode',
  'avatar',
  'profileImage',
  'dateOfBirth',
  'dob',
  'gender',
  // Adresse / localisation
  'address',
  'city',
  'postalCode',
  'country',
  'location',
  // Préférences app
  'language',
  'currency',
  'bio',
  'skills',
  // Paiement / carte (peut évoluer côté compte)
  'card',
  'stripeCustomerId',
  // IBAN — partagé car c'est le compte bancaire du user, peu importe le
  // rôle qui est payé (walker OU sitter utilisent le même IBAN). On ne
  // sync PAS ces champs vers Owner (qui ne reçoit pas de paiements),
  // voir filtre `excludeRole === 'owner'` plus bas.
  //
  // Noms réels utilisés par ibanRoutes.js (ne pas renommer) :
  'ibanHolder',
  'ibanNumber', // stocké chiffré, on propage la même chaîne chiffrée
  'ibanBic',
  'ibanVerified',
  'payoutMethod',
  // PayPal — pareil, partagé entre sitter/walker.
  'paypalEmail',
  'paypalConnectedAt',
];

/**
 * Propage les champs partagés de `update` vers les autres rôles pour le
 * même user (matché par email).
 *
 * @param {object} opts
 * @param {string} opts.email - email du user (clé de matching inter-rôles)
 * @param {object} opts.update - payload complet passé au $set de l'update
 *                               courant. On extrait uniquement les champs
 *                               partagés de ce payload.
 * @param {'owner'|'sitter'|'walker'} opts.excludeRole - rôle qui vient de
 *                               faire l'update (on ne se re-update pas).
 * @returns {Promise<{synced: string[], targets: string[]}>}
 */
async function syncSharedFields({ email, update, excludeRole }) {
  const safe = { synced: [], targets: [] };

  if (!email || typeof email !== 'string') {
    return safe;
  }
  if (!update || typeof update !== 'object') {
    return safe;
  }

  // Extrait uniquement les clés partagées effectivement présentes dans
  // le payload. Tout le reste (tarifs etc.) est ignoré.
  const payload = {};
  for (const key of SHARED_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(update, key)) {
      payload[key] = update[key];
    }
  }
  if (Object.keys(payload).length === 0) {
    return safe;
  }
  safe.synced = Object.keys(payload);

  const normalizedEmail = email.toLowerCase().trim();
  const filter = { email: normalizedEmail };

  // Map rôle → modèle Mongoose.
  const models = {
    owner: Owner,
    sitter: Sitter,
    walker: Walker,
  };

  const targets = Object.keys(models).filter((r) => r !== excludeRole);
  safe.targets = targets;

  for (const role of targets) {
    try {
      // Filtre spécial pour les champs IBAN/PayPal : on ne les propage
      // PAS vers Owner (qui ne doit pas recevoir de paiements).
      let effectivePayload = payload;
      if (role === 'owner') {
        effectivePayload = { ...payload };
        for (const k of [
          'ibanHolder',
          'ibanNumber',
          'ibanBic',
          'ibanVerified',
          'payoutMethod',
          'paypalEmail',
          'paypalConnectedAt',
        ]) {
          delete effectivePayload[k];
        }
        if (Object.keys(effectivePayload).length === 0) continue;
      }

      const res = await models[role].updateOne(filter, {
        $set: effectivePayload,
      });
      if (res?.matchedCount > 0 && res?.modifiedCount > 0) {
        logger.info(
          `[userSync] ${excludeRole} → ${role} (${normalizedEmail}) : ${Object.keys(effectivePayload).join(', ')}`,
        );
      }
    } catch (err) {
      // Non-bloquant : log et continue sur les autres rôles.
      logger.warn(
        `[userSync] failed to propagate to ${role} (${normalizedEmail})`,
        err?.message || err,
      );
    }
  }

  return safe;
}

module.exports = {
  syncSharedFields,
  SHARED_FIELDS,
};
