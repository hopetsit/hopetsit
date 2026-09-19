/**
 * airwallexCustomer.js — v568
 *
 * Point UNIQUE pour « le client Airwallex d'un humain » et ses cartes
 * enregistrées. Avant ce fichier, chaque flux (réservation, abonnement,
 * boutique, PawSpot, chat, KYC, don) refaisait son propre bloc
 * `findOrCreateCustomer` — copié-collé, avec des différences : le don n'en
 * avait aucun, et tous utilisaient l'`_id` du document de RÔLE comme
 * `merchant_customer_id`.
 *
 * CAUSE RACINE corrigée ici : un compte HoPetSit = 3 documents Mongo
 * (Owner / Sitter / Walker). Avec l'_id du rôle comme clé, la même personne
 * avait jusqu'à 3 clients Airwallex distincts → la carte enregistrée en
 * propriétaire n'existait plus après un passage en gardien. Désormais :
 *   1. on cherche l'id client déjà mémorisé sur N'IMPORTE lequel des 3 profils ;
 *   2. sinon on interroge Airwallex avec CHACUN des 3 ids (les clients créés
 *      par les versions précédentes sont donc récupérés, cartes comprises) ;
 *   3. sinon on crée UN client, avec une clé stable (le plus petit id du
 *      groupe) ;
 *   4. on mémorise l'id client sur les 3 profils → la carte suit la personne.
 *
 * SÉCURITÉ : aucun numéro de carte, aucun CVC ne transite ni n'est stocké
 * ici. On ne manipule que des identifiants Airwallex (customer id, consent
 * id), la marque, les 4 derniers chiffres et l'expiration.
 */

const logger = require('./logger');
const { identityGroup } = require('./identityGroup');

const MODEL_BY_NAME = (name) => {
  if (name === 'Owner') return require('../models/Owner');
  if (name === 'Sitter') return require('../models/Sitter');
  if (name === 'Walker') return require('../models/Walker');
  return null;
};

const MODEL_NAME_BY_ROLE = (role) =>
  role === 'owner' ? 'Owner' : role === 'walker' ? 'Walker' : role === 'sitter' ? 'Sitter' : null;

const CARD_FIELDS = 'email name airwallexCustomerId defaultCardConsentId';

/**
 * Charge les documents de tous les profils de la personne.
 * @returns {Promise<Array<{id, model, doc}>>}
 */
async function loadProfiles(userId) {
  const group = await identityGroup(userId);
  const out = [];
  for (const entry of group.docs) {
    const Model = MODEL_BY_NAME(entry.model);
    if (!Model) continue;
    try {
      const doc = await Model.findById(entry.id).select(CARD_FIELDS).lean();
      if (doc) out.push({ id: String(entry.id), model: entry.model, doc });
    } catch (e) {
      logger.warn(`[airwallexCustomer] lecture ${entry.model} ${entry.id} : ${e.message}`);
    }
  }
  if (!out.length) {
    // identityGroup n'a rien trouvé (doc supprimé / id inattendu) : on tente
    // les 3 collections directement pour ne jamais bloquer un paiement.
    for (const name of ['Owner', 'Sitter', 'Walker']) {
      const Model = MODEL_BY_NAME(name);
      try {
        const doc = await Model.findById(userId).select(CARD_FIELDS).lean();
        if (doc) out.push({ id: String(userId), model: name, doc });
      } catch (_) { /* profil absent : normal */ }
    }
  }
  return out;
}

/** Mémorise un champ carte sur TOUS les profils de la personne. */
async function persistOnAllProfiles(profiles, patch) {
  for (const p of profiles) {
    const Model = MODEL_BY_NAME(p.model);
    if (!Model) continue;
    try {
      await Model.updateOne({ _id: p.id }, { $set: patch });
      Object.assign(p.doc, patch);
    } catch (e) {
      logger.warn(`[airwallexCustomer] écriture ${p.model} ${p.id} : ${e.message}`);
    }
  }
}

/**
 * Renvoie (et crée si besoin) le client Airwallex de la personne.
 *
 * Ne lève JAMAIS : un échec Airwallex renvoie `customerId: null` et le
 * paiement continue sans carte enregistrée (l'utilisateur saisit sa carte).
 *
 * @param {Object} params
 * @param {string} params.userId  — _id du document de rôle courant
 * @param {string} [params.role]  — 'owner' | 'sitter' | 'walker'
 * @param {Object} [params.userDoc] — document déjà chargé (évite une requête)
 * @param {string} [params.logTag]  — préfixe de log ('booking', 'donation', …)
 * @returns {Promise<{customerId: string|null, defaultConsentId: string|null,
 *                    email: string, name: string, profiles: Array}>}
 */
async function ensureAirwallexCustomer({ userId, role = null, userDoc = null, logTag = 'airwallex' }) {
  const empty = { customerId: null, defaultConsentId: null, email: '', name: '', profiles: [] };
  if (!userId) return empty;

  // Chemin rapide : le document déjà chargé par l'appelant porte l'id client.
  // Évite 9 requêtes Mongo à chaque création d'intention de paiement.
  if (userDoc && userDoc.airwallexCustomerId) {
    return {
      customerId: userDoc.airwallexCustomerId,
      defaultConsentId: userDoc.defaultCardConsentId || null,
      email: userDoc.email || '',
      name: userDoc.name || '',
      profiles: [],
    };
  }

  let profiles = [];
  try {
    profiles = await loadProfiles(userId);
  } catch (e) {
    logger.warn(`[${logTag}] profils introuvables pour ${userId} : ${e.message}`);
  }

  // Identité : on préfère le document fourni par l'appelant, sinon le profil
  // du rôle courant, sinon n'importe lequel du groupe.
  const roleModelName = MODEL_NAME_BY_ROLE(role);
  const current =
    (roleModelName && profiles.find((p) => p.model === roleModelName)) || profiles[0];
  const email = (userDoc && userDoc.email) || current?.doc?.email || '';
  const name = (userDoc && userDoc.name) || current?.doc?.name || '';

  const defaultConsentId =
    profiles.map((p) => p.doc?.defaultCardConsentId).find((v) => v) || null;

  // 1. Id client déjà mémorisé sur l'un des profils.
  const known = profiles.map((p) => p.doc?.airwallexCustomerId).find((v) => v);
  if (known) {
    return { customerId: known, defaultConsentId, email, name, profiles };
  }

  const airwallex = require('../services/airwallexService');

  // 2. Client déjà créé par une version précédente sous l'un des 3 ids.
  //    L'ordre est déterministe pour que deux requêtes concurrentes
  //    retombent sur le même client.
  const candidateIds = profiles.length
    ? profiles.map((p) => p.id).sort()
    : [String(userId)];
  for (const candidate of candidateIds) {
    try {
      const found = await airwallex.findCustomerByMerchantId(candidate);
      if (found && found.id) {
        await persistOnAllProfiles(profiles, { airwallexCustomerId: found.id });
        logger.info(`[${logTag}] client Airwallex ${found.id} récupéré (clé ${candidate})`);
        return { customerId: found.id, defaultConsentId, email, name, profiles };
      }
    } catch (e) {
      logger.warn(`[${logTag}] recherche client ${candidate} : ${e.message}`);
    }
  }

  // 3. Création — une seule fois, sur la clé stable du groupe.
  if (!email) {
    logger.warn(`[${logTag}] pas d'email pour ${userId} : client Airwallex non créé`);
    return { ...empty, defaultConsentId, profiles };
  }
  try {
    const customer = await airwallex.findOrCreateCustomer({
      userId: candidateIds[0],
      email,
      firstName: String(name || '').split(' ')[0] || name || 'Customer',
      lastName: String(name || '').split(' ').slice(1).join(' ') || '',
    });
    const customerId = customer?.id || null;
    if (customerId) {
      await persistOnAllProfiles(profiles, { airwallexCustomerId: customerId });
      logger.info(`[${logTag}] client Airwallex ${customerId} créé pour ${userId}`);
    }
    return { customerId, defaultConsentId, email, name, profiles };
  } catch (e) {
    logger.warn(`[${logTag}] création client Airwallex impossible : ${e.message}`);
    return { ...empty, defaultConsentId, profiles };
  }
}

/**
 * Champs à fusionner dans `createPlatformPaymentIntent` pour que la page
 * Airwallex propose les cartes déjà enregistrées.
 *
 * `customer_id` seul = la page liste les cartes du client et permet d'en
 * saisir une nouvelle (flux « registered user checkout » documenté par
 * Airwallex). Le bloc `payment_consent` n'est ajouté QUE quand on veut
 * explicitement enregistrer une NOUVELLE carte (écran « Ajouter une
 * carte ») : ajouté systématiquement, il faisait afficher une page de
 * paiement vide (régression constatée en v23.1 part 60).
 */
function intentCustomerFields({ customerId, saveCard = false, consentId = null }) {
  if (!customerId) return {};
  const fields = { customer_id: customerId };
  if (saveCard && !consentId) {
    fields.payment_consent = {
      type: 'recurring',
      next_triggered_by: 'customer',
      merchant_trigger_reason: 'unscheduled',
    };
  }
  return fields;
}

/** Vrai si la carte est expirée (mois/année Airwallex). */
function isExpiredCard({ expiryMonth, expiryYear }) {
  const m = Number(expiryMonth);
  const y = Number(expiryYear);
  if (!Number.isFinite(m) || !Number.isFinite(y) || m < 1 || m > 12) return false;
  const now = new Date();
  const year = y < 100 ? 2000 + y : y;
  return year < now.getFullYear() || (year === now.getFullYear() && m < now.getMonth() + 1);
}

/** Consentement Airwallex → carte affichable par l'app (jamais de PAN). */
function normalizeConsent(consent, defaultConsentId) {
  const card = consent?.payment_method?.card || {};
  const out = {
    id: consent?.id,
    brand: card.brand || '',
    last4: card.last4 || '',
    expiryMonth: card.expiry_month || null,
    expiryYear: card.expiry_year || null,
    cardholder: card.name || '',
    createdAt: consent?.created_at || null,
  };
  out.isExpired = isExpiredCard(out);
  out.isDefault = !!defaultConsentId && String(consent?.id) === String(defaultConsentId);
  return out;
}

/**
 * Cartes enregistrées de la personne, carte par défaut en tête.
 * @returns {Promise<{cards: Array, defaultId: string|null}>}
 */
async function listSavedCards({ customerId, defaultConsentId = null }) {
  if (!customerId) return { cards: [], defaultId: null };
  const airwallex = require('../services/airwallexService');
  const consents = await airwallex.listPaymentMethods(customerId);
  const items = (consents?.items || []).map((c) => normalizeConsent(c, defaultConsentId));

  // Une carte par défaut supprimée entre-temps ne doit pas laisser la liste
  // sans défaut : on retombe sur la première carte valide.
  let defaultId = items.find((c) => c.isDefault)?.id || null;
  if (!defaultId && items.length) {
    defaultId = (items.find((c) => !c.isExpired) || items[0]).id || null;
    for (const c of items) c.isDefault = String(c.id) === String(defaultId);
  }
  items.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
  return { cards: items, defaultId };
}

/**
 * Choisit la carte par défaut. Écrit sur les 3 profils pour que le choix
 * survive à un changement de rôle.
 * @returns {Promise<boolean>} true si la valeur a été écrite.
 */
async function setDefaultConsentId({ userId, consentId }) {
  try {
    const profiles = await loadProfiles(userId);
    await persistOnAllProfiles(profiles, { defaultCardConsentId: consentId || '' });
    return true;
  } catch (e) {
    logger.warn(`[airwallexCustomer] carte par défaut non enregistrée : ${e.message}`);
    return false;
  }
}

module.exports = {
  ensureAirwallexCustomer,
  intentCustomerFields,
  listSavedCards,
  normalizeConsent,
  isExpiredCard,
  setDefaultConsentId,
  loadProfiles,
};
