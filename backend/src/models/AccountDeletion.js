'use strict';

/**
 * v567 — Daniel : « si quelqu'un supprime son compte, demander 3 raisons et
 * que ça me le dise dans l'admin ».
 *
 * Journal des MOTIFS de désinscription, distinct de `DeletedAccount` (qui reste
 * la trace nominative « qui s'est désinscrit »). Ici on ne stocke AUCUN e-mail
 * en clair : seulement un sha256 de l'e-mail minuscule, suffisant pour
 * recouper deux suppressions sans conserver de donnée personnelle (RGPD).
 *
 * L'enregistrement est TOUJOURS best-effort : il ne doit jamais empêcher la
 * suppression du compte.
 */
const crypto = require('crypto');
const mongoose = require('mongoose');

const logger = require('../utils/logger');

// Identifiants stables partagés avec l'app (delete567_i18n.dart) et l'admin.
const ACCOUNT_DELETION_REASONS = [
  'no_providers_nearby',
  'no_clients',
  'too_expensive',
  'too_complicated',
  'bugs',
  'notifications_too_many',
  'found_other_app',
  'privacy',
  'no_longer_need',
  'temporary_break',
  'other',
];

const MAX_REASONS = 3;
const MAX_COMMENT = 300;

/** sha256 de l'e-mail en minuscules — jamais l'e-mail lui-même. */
const hashEmail = (email) => {
  const clean = String(email || '').trim().toLowerCase();
  if (!clean) return '';
  return crypto.createHash('sha256').update(clean).digest('hex');
};

/**
 * Normalise les raisons reçues du client : accepte un tableau ou une chaîne
 * « a,b,c » (query string), filtre sur la liste autorisée, déduplique et
 * plafonne à 3. Une ancienne app qui n'envoie rien → [].
 */
const normalizeReasons = (raw) => {
  let list = raw;
  if (typeof list === 'string') list = list.split(',');
  if (!Array.isArray(list)) return [];
  const out = [];
  for (const item of list) {
    const id = String(item == null ? '' : item).trim();
    if (!ACCOUNT_DELETION_REASONS.includes(id)) continue;
    if (out.includes(id)) continue;
    out.push(id);
    if (out.length >= MAX_REASONS) break;
  }
  return out;
};

/** Commentaire libre facultatif : trim + troncature à 300 caractères. */
const normalizeComment = (raw) => {
  if (raw == null) return '';
  return String(raw).trim().slice(0, MAX_COMMENT);
};

const accountDeletionSchema = new mongoose.Schema(
  {
    role: { type: String, default: '' }, // 'owner' | 'sitter' | 'walker'
    userId: { type: String, default: '' },
    emailHash: { type: String, default: '' }, // sha256(email.toLowerCase()) — jamais l'e-mail
    country: { type: String, default: '' },
    city: { type: String, default: '' },
    appLocale: { type: String, default: '' },
    accountCreatedAt: { type: Date, default: null },
    deletedAt: { type: Date, default: Date.now },
    reasons: { type: [String], default: [] },
    comment: { type: String, default: '', trim: true, maxlength: MAX_COMMENT },
    platform: { type: String, default: '' }, // 'ios' | 'android' | 'web' | ''
    appVersion: { type: String, default: '' },
    hadPaidBooking: { type: Boolean, default: false },
    bookingsCount: { type: Number, default: 0 },
  },
  { timestamps: true },
);

accountDeletionSchema.index({ deletedAt: -1 });

const AccountDeletion = mongoose.model('AccountDeletion', accountDeletionSchema);

/**
 * Construit la ligne de journal à partir de la requête et du compte, sans
 * jamais lever : une entrée est toujours produite, même vide de raisons.
 * `stats` = { hadPaidBooking, bookingsCount } relevé AVANT la cascade.
 */
const buildAccountDeletionRecord = ({ req, role, doc, email, stats } = {}) => {
  const body = (req && req.body) || {};
  const query = (req && req.query) || {};
  // Certains clients HTTP n'envoient pas de corps sur DELETE → repli sur ?reasons=
  const rawReasons = body.reasons !== undefined ? body.reasons : query.reasons;
  const rawComment = body.comment !== undefined ? body.comment : query.comment;

  let platform = '';
  let appVersion = '';
  try {
    const { platformFromRequest } = require('../utils/purchasePlatform');
    platform = platformFromRequest(req) || '';
  } catch (_) { /* utilitaire absent → plateforme inconnue */ }
  try {
    appVersion = String((req && req.headers && req.headers['x-app-version']) || '').trim().slice(0, 32);
  } catch (_) { appVersion = ''; }

  const location = (doc && doc.location) || {};
  const s = stats || {};

  return {
    role: role || '',
    userId: String((doc && doc._id) || ''),
    emailHash: hashEmail(email),
    country: String((doc && doc.country) || ''),
    city: String((doc && doc.city) || location.city || ''),
    appLocale: String((doc && doc.appLocale) || ''),
    accountCreatedAt: (doc && doc.createdAt) || null,
    deletedAt: new Date(),
    reasons: normalizeReasons(rawReasons),
    comment: normalizeComment(rawComment),
    platform,
    appVersion,
    hadPaidBooking: Boolean(s.hadPaidBooking),
    bookingsCount: Number(s.bookingsCount) || 0,
  };
};

/**
 * Enregistre le motif de départ. Best-effort absolu : toute erreur est
 * loguée et avalée pour que la suppression du compte continue.
 */
const recordAccountDeletion = async (params) => {
  try {
    await AccountDeletion.create(buildAccountDeletionRecord(params));
  } catch (e) {
    logger.warn(`[accountDeletion] journal des motifs échoué : ${e?.message || e}`);
  }
};

module.exports = {
  AccountDeletion,
  ACCOUNT_DELETION_REASONS,
  MAX_REASONS,
  MAX_COMMENT,
  hashEmail,
  normalizeReasons,
  normalizeComment,
  buildAccountDeletionRecord,
  recordAccountDeletion,
};
