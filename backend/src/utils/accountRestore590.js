/**
 * v590 — Daniel (26/09) : « rajoute dans mon admin désinscription un bouton
 * restaurer le compte, j'ai effacé un compte sans vouloir ».
 *
 * Les suppressions effacent physiquement le doc Owner/Sitter/Walker. Depuis
 * cette version, une suppression faite DEPUIS L'ADMIN garde une copie brute
 * du doc (`snapshot`) dans le journal DeletedAccount pendant RESTORE_DAYS
 * jours : la restauration réinsère ce doc tel quel (même _id → amis,
 * réservations, avis et annonces qui pointent vers lui se raccrochent ; même
 * mot de passe haché, mêmes champs chiffrés).
 *
 * Une suppression demandée par l'utilisateur lui-même (app/site) n'est JAMAIS
 * copiée ni restaurable : c'est son droit à l'effacement.
 *
 * Suppressions admin antérieures (sans copie) : reconstruction PARTIELLE —
 * même _id, nom, e-mail, rôle, et ce qui peut être repris d'un autre profil
 * de la même personne (même e-mail) : téléphone, pays, ville, position,
 * photo, langue, devise, et le mot de passe haché. Sans autre profil, un mot
 * de passe aléatoire est posé : la personne passe par « Mot de passe oublié ».
 */
const crypto = require('crypto');

const RESTORE_DAYS = 30;
const MODEL_BY_ROLE = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

// Champs repris d'un profil frère pour une reconstruction partielle.
const SIBLING_FIELDS = [
  'firstName', 'lastName', 'mobile', 'countryCode', 'country', 'city',
  'address', 'avatar', 'language', 'appLocale', 'currency', 'location',
  'dateOfBirth', 'password', 'authProvider', 'firebaseUid', 'acceptedTerms',
  'termsAcceptedAt', 'termsVersion', 'verified', 'isStaff',
];

/** Copie brute du doc supprimé (valeurs stockées : hachées/chiffrées). */
function snapshotOf(doc) {
  if (!doc) return null;
  const raw = typeof doc.toObject === 'function'
    ? doc.toObject({ getters: false, virtuals: false, depopulate: true })
    : { ...doc };
  return raw;
}

/** Peut-on restaurer cette entrée du journal ? → null si oui, sinon la raison. */
function restoreBlocker(entry, now = new Date()) {
  if (!entry) return 'introuvable';
  if (entry.restoredAt) return 'déjà restauré';
  if (entry.source !== 'admin') return 'supprimé par la personne elle-même';
  if (!MODEL_BY_ROLE[entry.role]) return 'rôle inconnu';
  if (!entry.userId || !/^[a-f0-9]{24}$/i.test(String(entry.userId))) return 'identifiant manquant';
  if (entry.snapshot) {
    const age = now - new Date(entry.deletedAt || 0);
    if (age > RESTORE_DAYS * 86400000) return `copie expirée (plus de ${RESTORE_DAYS} jours)`;
  }
  return null;
}

/** Doc minimal pour une suppression sans copie (pur, testable). */
function buildPartialDoc(entry, sibling, now = new Date(), randomHash = null) {
  const doc = {
    name: entry.name || 'Compte restauré',
    email: String(entry.email || '').toLowerCase().trim(),
    createdAt: now,
    updatedAt: now,
  };
  if (sibling) {
    for (const k of SIBLING_FIELDS) {
      if (sibling[k] !== undefined && sibling[k] !== null) doc[k] = sibling[k];
    }
  }
  if (!doc.password) doc.password = randomHash;
  return doc;
}

async function restoreDeletedAccount(entryId, { adminId = null } = {}) {
  const mongoose = require('mongoose');
  const DeletedAccount = require('../models/DeletedAccount');
  const entry = await DeletedAccount.findById(entryId).select('+snapshot').lean();
  const blocker = restoreBlocker(entry);
  if (blocker) return { ok: false, status: blocker === 'introuvable' ? 404 : 409, error: blocker };

  const Model = require(`../models/${MODEL_BY_ROLE[entry.role]}`);
  const _id = new mongoose.Types.ObjectId(String(entry.userId));
  if (await Model.exists({ _id })) return { ok: false, status: 409, error: 'ce compte existe déjà' };
  const email = String(entry.email || '').toLowerCase().trim();
  if (!email) return { ok: false, status: 409, error: 'e-mail inconnu, restauration impossible' };
  if (await Model.exists({ email })) {
    return { ok: false, status: 409, error: 'un autre compte de ce rôle utilise déjà cet e-mail' };
  }

  let mode;
  let raw;
  if (entry.snapshot) {
    mode = 'complet';
    raw = { ...entry.snapshot, _id };
  } else {
    mode = 'partiel';
    let sibling = null;
    for (const m of ['Owner', 'Sitter', 'Walker']) {
      if (m === MODEL_BY_ROLE[entry.role]) continue;
      // eslint-disable-next-line no-await-in-loop
      sibling = await require(`../models/${m}`).findOne({ email }).lean();
      if (sibling) break;
    }
    const bcrypt = require('bcryptjs');
    const randomHash = await bcrypt.hash(crypto.randomBytes(24).toString('hex'), 12);
    raw = { ...buildPartialDoc(entry, sibling, new Date(), randomHash), _id };
    mode = sibling ? 'partiel (repris du profil frère)' : 'partiel';
  }

  // Un point GeoJSON sans coordonnées fait refuser l'insertion par l'index
  // 2dsphere ; Mongoose ne l'écrit d'ailleurs jamais en base : on le retire.
  for (const k of Object.keys(raw)) {
    const v = raw[k];
    const geo = v && typeof v === 'object' && !Array.isArray(v)
      && (v.type === 'Point' || k === 'location' || k === 'mapBoostLocation');
    if (geo && !(Array.isArray(v.coordinates) && v.coordinates.length === 2)) delete raw[k];
  }
  // Insertion brute : pas de re-hachage du mot de passe ni de double chiffrement.
  await Model.collection.insertOne(raw);
  await DeletedAccount.updateOne(
    { _id: entry._id },
    { $set: { restoredAt: new Date(), restoredMode: mode, restoredBy: adminId ? String(adminId) : '' },
      $unset: { snapshot: 1 } },
  );
  return { ok: true, mode, role: entry.role, userId: String(_id) };
}

/** Efface les copies de plus de RESTORE_DAYS jours (appelé à la lecture du journal). */
async function purgeOldSnapshots(now = new Date()) {
  const DeletedAccount = require('../models/DeletedAccount');
  const limit = new Date(now - RESTORE_DAYS * 86400000);
  await DeletedAccount.updateMany(
    { snapshot: { $exists: true }, deletedAt: { $lt: limit } },
    { $unset: { snapshot: 1 } },
  );
}

module.exports = {
  RESTORE_DAYS, snapshotOf, restoreBlocker, buildPartialDoc, restoreDeletedAccount, purgeOldSnapshots,
};
