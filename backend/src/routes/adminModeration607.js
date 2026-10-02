'use strict';

/**
 * 607 (ADA, 02/10/2026) — « À traiter » de l'admin : une épingle PawMap signalée doit pouvoir
 * être VÉRIFIÉE et TRAITÉE depuis la carte (Daniel : « je n'ai rien pour la vérifier »).
 *
 *   GET  /api/v1/admin/moderation607/flagged-map-reports  → toutes les épingles signalées
 *        (au moins un signalement), avec le détail complet : type, texte, photo, dates,
 *        position, auteur « Prénom I. », signalements (motif, date, qui « Prénom I. »).
 *   POST /api/v1/admin/moderation607/map-reports/:id/hide → masque l'épingle (les
 *        signalements sont gardés pour l'historique). Seule action qui manquait :
 *        « Garder / classer sans suite » = POST /admin/map-reports/:id/restore (existante),
 *        « Supprimer » = DELETE /admin/map-reports/:id (existante).
 *
 * requireAdmin + journal AdminAuditLog (auditAdmin) + journal serveur. Aucune adresse e-mail.
 */

const express = require('express');
const mongoose = require('mongoose');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

const MODEL = { Owner: 'Owner', Sitter: 'Sitter', Walker: 'Walker' };
const ROLE = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };

/** « Prénom I. » à partir du nom du profil (jamais le nom complet). */
function shortName(d) {
  const first = String((d && (d.firstName || d.name)) || '').trim().split(/\s+/)[0] || '';
  const lastRaw = String((d && d.lastName) || '').trim()
    || String((d && d.name) || '').trim().split(/\s+/).slice(1).join(' ');
  const initial = lastRaw ? `${lastRaw[0].toUpperCase()}.` : '';
  return `${first} ${initial}`.trim() || '—';
}

async function peopleOf(refs) {
  const byModel = {};
  refs.forEach((r) => {
    if (!r || !r.userId || !MODEL[r.userModel]) return;
    (byModel[r.userModel] = byModel[r.userModel] || new Set()).add(String(r.userId));
  });
  const out = new Map();
  await Promise.all(Object.entries(byModel).map(async ([m, ids]) => {
    const docs = await require(`../models/${m}`).find({ _id: { $in: [...ids] } })
      .select('name firstName lastName').lean();
    docs.forEach((d) => out.set(`${m}:${String(d._id)}`, shortName(d)));
  }));
  return out;
}

router.get('/flagged-map-reports', requireAdmin, async (req, res) => {
  try {
    const MapReport = require('../models/MapReport');
    const items = await MapReport.find({ 'flags.0': { $exists: true } })
      .sort({ createdAt: -1 }).limit(500).lean();
    const refs = [];
    items.forEach((r) => {
      refs.push({ userId: r.reporterId, userModel: r.reporterModel });
      (r.flags || []).forEach((f) => refs.push(f));
    });
    const names = await peopleOf(refs);
    const nameOf = (id, m) => names.get(`${m}:${String(id)}`) || '—';
    return res.json({
      items: items.map((r) => {
        const c = (r.location && r.location.coordinates) || [];
        const flags = (r.flags || []).map((f) => ({
          reason: f.reason || '', at: f.at || null,
          by: { name: nameOf(f.userId, f.userModel), role: ROLE[f.userModel] || '', id: String(f.userId || '').slice(-6) },
        }));
        return {
          id: String(r._id),
          type: r.type || '',
          note: r.note || '',
          photoUrl: r.photoUrl || '',
          isSos: !!r.isSos,
          hidden: !!r.hidden,
          createdAt: r.createdAt || null,
          expiresAt: r.expiresAt || null,
          expired: !!(r.expiresAt && new Date(r.expiresAt).getTime() < Date.now()),
          lat: Number.isFinite(c[1]) ? c[1] : null,
          lng: Number.isFinite(c[0]) ? c[0] : null,
          city: (r.location && r.location.city) || '',
          confirmations: (r.confirmations || []).length,
          author: { name: nameOf(r.reporterId, r.reporterModel), role: ROLE[r.reporterModel] || '', id: String(r.reporterId || '').slice(-6) },
          flags,
          firstFlagAt: flags.reduce((m, f) => (!m || (f.at && new Date(f.at) < new Date(m)) ? f.at : m), null),
        };
      }),
    });
  } catch (e) {
    logger.error({ err: e }, '[admin/moderation607/flagged-map-reports]');
    return res.status(500).json({ error: 'Erreur.' });
  }
});

router.post('/map-reports/:id/hide', requireAdmin, async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Identifiant invalide.' });
    const MapReport = require('../models/MapReport');
    const r = await MapReport.findByIdAndUpdate(req.params.id, { $set: { hidden: true } }, { new: true });
    if (!r) return res.status(404).json({ error: 'Épingle introuvable.' });
    logger.info(`[admin/moderation607] épingle ${String(r._id)} masquée par l'admin ${req.user && req.user.id}`);
    return res.json({ ok: true, hidden: true });
  } catch (e) {
    logger.error({ err: e }, '[admin/moderation607/hide]');
    return res.status(500).json({ error: 'Erreur.' });
  }
});

module.exports = router;
module.exports.shortName = shortName;
