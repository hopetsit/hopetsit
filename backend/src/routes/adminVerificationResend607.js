'use strict';

/**
 * 607 (ADA, 02/10/2026) — Daniel : « sélectionner les comptes à l'e-mail non vérifié et cliquer
 * “Renvoyer la vérification” ». Envoi DÉCLENCHÉ À LA MAIN par l'admin, avec garde-fous
 * (règle du 28/09 « pas de spam ») :
 *   1. même flux que l'app : on appelle le contrôleur existant de POST /auth/resend-code
 *      (code 24 h, e-mail dans la langue du compte, bouton « Activer mon compte ») ;
 *   2. jamais deux e-mails de vérification à la même personne en moins de 7 jours, toutes
 *      sources confondues (VerificationEmailLog + dernier code émis) ;
 *   3. écartés d'office : e-mail déjà vérifié, comptes de test / internes, bloqués ou bannis,
 *      adresses invalides ; une personne (un e-mail) = un seul envoi même avec 3 profils ;
 *   4. 50 envois au plus par clic, étalés (une seconde entre deux envois) ;
 *   5. `dryRun: true` = simulation : renvoie ce qui partirait, n'envoie RIEN ;
 *   6. journal : chaque appel (simulation comprise) est enregistré (qui, quand, combien).
 *
 *   POST /api/v1/admin/users/resend-verification   { ids:[{role,id}], dryRun? }
 *   GET  /api/v1/admin/users/resend-verification/last     → dernier rappel par profil
 *   GET  /api/v1/admin/users/resend-verification/journal  → 30 derniers renvois groupés
 */

const express = require('express');
const mongoose = require('mongoose');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');
const { isInternalEmail } = require('../utils/userCounts');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

const CAP = 50;
const MIN_GAP_MS = 7 * 86400000;
const DELAY_MS = () => Number(process.env.VERIF_RESEND_DELAY_MS ?? 1000);
const MODELS = { owner: () => require('../models/Owner'), sitter: () => require('../models/Sitter'), walker: () => require('../models/Walker') };
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[a-z]{2,}$/i;
const BAD_TLD = /\.(con|cmo|comm|cm|co\.fr|fr\.com|gmial|gmai)$/i;

const plainEmail = (stored) => {
  try { return require('../utils/encryption').decrypt(stored); } catch (_) { return stored; }
};
const lower = (e) => String(plainEmail(e) || '').trim().toLowerCase();
const short = (id) => String(id || '').slice(-6);
const sleep = (ms) => new Promise((ok) => setTimeout(ok, ms));

/** Date du dernier e-mail de vérification connu pour chaque e-mail (toutes sources). */
async function lastSentMap(emails) {
  const Log = require('../models/VerificationEmailLog');
  const VerificationCode = require('../models/VerificationCode');
  const list = [...new Set(emails.filter(Boolean))];
  const out = new Map();
  if (!list.length) return out;
  const hashes = new Map(list.map((e) => [Log.hashEmail(e), e]));
  const [logs, codes] = await Promise.all([
    Log.find({ emailHash: { $in: [...hashes.keys()] } }).lean(),
    VerificationCode.find({ email: { $in: list }, purpose: 'email_verification' }).select('email updatedAt createdAt').lean(),
  ]);
  const put = (e, d) => { if (!d) return; const t = new Date(d); if (!out.has(e) || out.get(e) < t) out.set(e, t); };
  logs.forEach((l) => put(hashes.get(l.emailHash), l.lastVerificationEmailAt));
  codes.forEach((c) => put(String(c.email).toLowerCase(), c.updatedAt || c.createdAt));
  return out;
}

/** Profils demandés + tous les profils des mêmes e-mails (règle « une personne »). */
async function loadPeople(ids) {
  const byRole = { owner: [], sitter: [], walker: [] };
  (ids || []).forEach((x) => {
    const r = String((x && x.role) || '').toLowerCase();
    if (byRole[r] && mongoose.isValidObjectId(x.id)) byRole[r].push(String(x.id));
  });
  const sel = 'name firstName email verified status bannedAt';
  const asked = [];
  await Promise.all(Object.entries(byRole).map(async ([role, list]) => {
    if (!list.length) return;
    const docs = await MODELS[role]().find({ _id: { $in: list } }).select(sel).lean();
    docs.forEach((d) => asked.push({ role, d }));
  }));
  const emails = [...new Set(asked.map((a) => lower(a.d.email)).filter(Boolean))];
  const siblings = new Map();
  if (emails.length) {
    await Promise.all(Object.keys(MODELS).map(async (role) => {
      const docs = await MODELS[role]().find({ email: { $in: emails } }).select('email verified').lean();
      docs.forEach((d) => {
        const e = lower(d.email);
        if (!siblings.has(e)) siblings.set(e, []);
        siblings.get(e).push(d);
      });
    }));
  }
  return { asked, siblings };
}

/** Décide pour chaque profil demandé : 'send' ou un motif d'exclusion. */
async function plan(ids, now = Date.now()) {
  const { asked, siblings } = await loadPeople(ids);
  const last = await lastSentMap(asked.map((a) => lower(a.d.email)));
  const seen = new Set();
  const rows = [];
  let toSend = 0;
  asked.sort((a, b) => String(a.d._id).localeCompare(String(b.d._id)));
  for (const { role, d } of asked) {
    const email = lower(d.email);
    const row = { role, id: String(d._id), short: short(d._id), name: d.name || d.firstName || '', email, status: 'skipped', reason: '' };
    const sib = siblings.get(email) || [d];
    const prev = last.get(email) || null;
    row.lastVerificationEmailAt = prev;
    if (!email || !EMAIL_RE.test(email) || BAD_TLD.test(email)) row.reason = 'invalid_email';
    else if (isInternalEmail(email)) row.reason = 'test_account';
    else if (d.status === 'banned' || d.status === 'suspended' || d.bannedAt) row.reason = 'blocked';
    else if (d.verified === true || sib.some((x) => x.verified === true)) row.reason = 'already_verified';
    else if (seen.has(email)) row.reason = 'same_person';
    else if (prev && now - new Date(prev).getTime() < MIN_GAP_MS) row.reason = 'sent_less_than_7_days';
    else if (toSend >= CAP) row.reason = 'cap_50';
    else { row.status = 'send'; toSend += 1; }
    if (email) seen.add(email);
    rows.push(row);
  }
  return rows;
}

/** Le flux EXISTANT de POST /auth/resend-code, appelé tel quel. */
function resendViaAuthFlow(email) {
  const { resendVerificationCode } = require('../controllers/authController');
  return new Promise((resolve) => {
    let code = 200;
    const res = {
      status(c) { code = c; return this; },
      json(body) { resolve({ code, body }); return this; },
    };
    Promise.resolve(resendVerificationCode({ query: { email } }, res)).catch((e) => resolve({ code: 500, body: { error: e.message } }));
  });
}

const publicRow = (r) => ({ role: r.role, id: r.id, short: r.short, name: r.name, status: r.status, reason: r.reason, lastVerificationEmailAt: r.lastVerificationEmailAt || null });
const countReasons = (rows) => rows.reduce((acc, r) => {
  if (r.status === 'skipped') acc[r.reason] = (acc[r.reason] || 0) + 1;
  return acc;
}, {});

router.post('/', requireAdmin, async (req, res) => {
  try {
    const ids = Array.isArray(req.body && req.body.ids) ? req.body.ids.slice(0, 1000) : [];
    if (!ids.length) return res.status(400).json({ error: 'Aucun compte sélectionné.' });
    const dryRun = req.body.dryRun === true;
    const rows = await plan(ids);
    if (!dryRun) {
      let first = true;
      for (const r of rows) {
        if (r.status !== 'send') continue;
        if (!first) await sleep(DELAY_MS());
        first = false;
        const out = await resendViaAuthFlow(r.email);
        if (out.code === 200) {
          r.status = 'sent';
          try { await require('../models/VerificationEmailLog').touch(r.email, 'admin'); } catch (_) { /* best-effort */ }
        } else {
          r.status = 'failed';
          r.reason = (out.body && (out.body.code || out.body.error)) || `HTTP ${out.code}`;
        }
      }
    }
    const summary = {
      dryRun,
      requested: rows.length,
      toSend: rows.filter((r) => r.status === 'send').length,
      sent: rows.filter((r) => r.status === 'sent').length,
      failed: rows.filter((r) => r.status === 'failed').length,
      skipped: countReasons(rows),
    };
    const { VerificationResendBatch } = require('../models/VerificationEmailLog');
    await VerificationResendBatch.create({
      adminId: String((req.user && req.user.id) || ''), dryRun,
      requested: summary.requested, sent: summary.sent, failed: summary.failed, skipped: summary.skipped,
      results: rows.map((r) => ({ role: r.role, id: r.short, name: r.name, status: r.status, reason: r.reason })),
    }).catch((e) => logger.warn(`[admin/resend-verification] journal : ${e.message}`));
    logger.info(`[admin/resend-verification] ${dryRun ? 'SIMULATION' : 'ENVOI'} admin=${req.user && req.user.id} demandés=${summary.requested} envoyés=${summary.sent} échecs=${summary.failed}`);
    return res.json({ ...summary, results: rows.map(publicRow) });
  } catch (e) {
    logger.error({ err: e }, '[admin/resend-verification]');
    return res.status(500).json({ error: 'Erreur.' });
  }
});

// Dernier rappel connu par profil (colonne « Dernier rappel » des tableaux).
router.get('/last', requireAdmin, async (req, res) => {
  try {
    const sel = 'email';
    const lists = await Promise.all(Object.keys(MODELS).map((r) => MODELS[r]().find({}).select(sel).lean()));
    const all = [];
    Object.keys(MODELS).forEach((role, i) => lists[i].forEach((d) => all.push({ role, id: String(d._id), email: lower(d.email) })));
    const last = await lastSentMap(all.map((x) => x.email));
    const out = {};
    all.forEach((x) => { const t = last.get(x.email); if (t) out[`${x.role}:${x.id}`] = t; });
    return res.json({ last: out });
  } catch (e) {
    logger.error({ err: e }, '[admin/resend-verification/last]');
    return res.status(500).json({ error: 'Erreur.' });
  }
});

router.get('/journal', requireAdmin, async (req, res) => {
  try {
    const { VerificationResendBatch } = require('../models/VerificationEmailLog');
    const items = await VerificationResendBatch.find({}).sort({ createdAt: -1 }).limit(30).lean();
    return res.json({ items });
  } catch (e) {
    logger.error({ err: e }, '[admin/resend-verification/journal]');
    return res.status(500).json({ error: 'Erreur.' });
  }
});

module.exports = router;
module.exports.plan = plan;
module.exports.CAP = CAP;
