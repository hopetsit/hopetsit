/**
 * 04/10/2026 (ZOE, mission BOB) — PREMIÈRE VRAIE DEMANDE : savoir QUI a été
 * prévenu, relancer sans jamais envoyer deux fois, et lister les villes
 * écrites dans une langue étrangère.
 *
 * Aucune de ces informations n'était lisible depuis l'admin : les
 * notifications ne s'affichent que dans le téléphone du destinataire.
 *
 *   GET  /admin/requests0410/:postId/notified
 *        → destinataires déjà prévenus pour cette annonce (type, rôle, date,
 *          lue ou non), candidatures reçues. Lecture seule.
 *   POST /admin/requests0410/:postId/renotify   { dryRun = true }
 *        → recalcule les prestataires proches (même code que la publication),
 *          RETIRE ceux qui ont déjà reçu une notification pour CETTE annonce,
 *          et n'envoie rien tant que dryRun n'est pas explicitement false.
 *          Même mécanisme que la publication (in-app + push, aucun e-mail en
 *          plus). Journalisé (auditAdmin).
 *   GET  /admin/requests0410/cities/non-canonical
 *        → valeurs de ville déjà en base qui ne sont pas au nom local
 *          (« Parigi », « París »…), par collection et par champ. LECTURE
 *          SEULE : rien n'est modifié.
 * Aucune adresse e-mail renvoyée.
 */
const express = require('express');
const mongoose = require('mongoose');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');
const { canonicalCityName, coordsOfLocation } = require('../utils/canonicalCity0410');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

const NOTIF_TYPES = ['new_request_nearby', 'new_request_for_you'];
const isId = (s) => mongoose.Types.ObjectId.isValid(s) && /^[a-f0-9]{24}$/i.test(String(s));

async function notifiedFor(postId) {
  const Notification = require('../models/Notification');
  const rows = await Notification.find({ 'data.postId': String(postId), type: { $in: NOTIF_TYPES } })
    .select('type recipientRole recipientId createdAt readAt')
    .sort({ createdAt: 1 })
    .lean();
  return rows;
}

async function namesOf(rows) {
  const out = new Map();
  const byRole = { sitter: [], walker: [], owner: [] };
  for (const r of rows) if (byRole[r.recipientRole]) byRole[r.recipientRole].push(r.recipientId);
  const M = { sitter: require('../models/Sitter'), walker: require('../models/Walker'), owner: require('../models/Owner') };
  for (const [role, ids] of Object.entries(byRole)) {
    if (!ids.length) continue;
    const docs = await M[role].find({ _id: { $in: ids } }).select('name city location.city').lean();
    for (const d of docs) out.set(String(d._id), { name: d.name || '', city: (d.location && d.location.city) || d.city || '' });
  }
  return out;
}

router.get('/:postId/notified', requireAdmin, async (req, res) => {
  try {
    const { postId } = req.params;
    if (!isId(postId)) return res.status(400).json({ error: 'postId invalide.' });
    const Post = require('../models/Post');
    const Application = require('../models/Application');
    const post = await Post.findById(postId).select('ownerId location serviceTypes createdAt postType').lean();
    if (!post) return res.status(404).json({ error: 'Annonce introuvable.' });
    const rows = await notifiedFor(postId);
    const names = await namesOf(rows);
    const applications = await Application.countDocuments({ postId: post._id });
    res.json({
      postId,
      city: (post.location && post.location.city) || '',
      lat: post.location && post.location.lat,
      lng: post.location && post.location.lng,
      serviceTypes: post.serviceTypes || [],
      createdAt: post.createdAt,
      notifiedCount: rows.length,
      readCount: rows.filter((r) => r.readAt).length,
      notified: rows.map((r) => ({
        type: r.type,
        role: r.recipientRole,
        id: String(r.recipientId),
        name: (names.get(String(r.recipientId)) || {}).name || '',
        city: (names.get(String(r.recipientId)) || {}).city || '',
        at: r.createdAt,
        read: !!r.readAt,
      })),
      applications,
    });
  } catch (e) {
    logger.error('[admin/requests0410/notified]', e);
    res.status(500).json({ error: e.message });
  }
});

router.post('/:postId/renotify', requireAdmin, async (req, res) => {
  try {
    const { postId } = req.params;
    if (!isId(postId)) return res.status(400).json({ error: 'postId invalide.' });
    const dryRun = !(req.body && req.body.dryRun === false);
    const Post = require('../models/Post');
    const Owner = require('../models/Owner');
    const post = await Post.findById(postId).lean();
    if (!post) return res.status(404).json({ error: 'Annonce introuvable.' });
    if (post.postType && post.postType !== 'request') return res.status(400).json({ error: 'Pas une demande.' });
    if (post.hidden === true) return res.status(400).json({ error: 'Annonce masquée : pas de relance.' });
    const owner = await Owner.findById(post.ownerId).select('name email oldId').lean();
    if (!owner) return res.status(404).json({ error: 'Propriétaire introuvable.' });

    const already = await notifiedFor(postId);
    const skipIds = new Set(already.map((r) => String(r.recipientId)));
    // Autres annonces du même propriétaire (ex. ses 2 demandes identiques) :
    // un prestataire déjà prévenu pour l'une ne l'est pas une 2e fois.
    const others = Array.isArray(req.body && req.body.alsoSkipPostIds) ? req.body.alsoSkipPostIds.filter(isId).slice(0, 10) : [];
    for (const oid of others) {
      for (const r of await notifiedFor(oid)) skipIds.add(String(r.recipientId));
    }
    const { notifyNearbyProviders } = require('../controllers/postController');
    const bilan = await new Promise((resolve) => {
      const timer = setTimeout(() => resolve({ error: 'délai dépassé (60 s)' }), 60000);
      notifyNearbyProviders({
        newPost: post,
        postPayload: { location: post.location || null, targetProvider: post.targetProvider || null },
        normalizedServices: Array.isArray(post.serviceTypes) ? post.serviceTypes : [],
        owner,
        ownerId: String(post.ownerId),
        opts: { skipIds, dryRun, onDone: (b) => { clearTimeout(timer); resolve(b); } },
      });
    });
    logger.info(`[admin/requests0410/renotify] post=${postId} dryRun=${dryRun} candidats=${(bilan.candidates || []).length} envoyés=${(bilan.sent || []).length} déjà=${(bilan.skippedAlready || []).length}`);
    res.json({
      postId,
      dryRun,
      alreadyNotifiedBefore: skipIds.size,
      recipientRole: bilan.recipientRole || '',
      cityKey: bilan.cityKey || '',
      candidates: (bilan.candidates || []).length,
      sent: (bilan.sent || []).length,
      skippedAlready: (bilan.skippedAlready || []).length,
      candidateIds: bilan.candidates || [],
      testAccount: !!bilan.testAccount,
      error: bilan.error || null,
    });
  } catch (e) {
    logger.error('[admin/requests0410/renotify]', e);
    res.status(500).json({ error: e.message });
  }
});

router.get('/cities/non-canonical', requireAdmin, async (req, res) => {
  try {
    const SOURCES = [
      ['owners', require('../models/Owner')],
      ['sitters', require('../models/Sitter')],
      ['walkers', require('../models/Walker')],
      ['posts', require('../models/Post')],
      ['pawspots', require('../models/PawSpot')],
      ['mapreports', require('../models/MapReport')],
      ['mappois', require('../models/MapPOI')],
    ];
    const out = [];
    for (const [name, M] of SOURCES) {
      const docs = await M.find({}).select('city coverageCity location address').lean().maxTimeMS(20000);
      for (const d of docs) {
        const coords = coordsOfLocation(d.location);
        const check = (field, v, c) => {
          if (typeof v !== 'string' || !v.trim()) return;
          const canon = canonicalCityName(v, c);
          if (canon !== v) out.push({ collection: name, id: String(d._id), field, value: v, canonical: canon });
        };
        check('city', d.city, coords);
        check('coverageCity', d.coverageCity, coords);
        check('location.city', d.location && d.location.city, coords);
        check('address.city', d.address && d.address.city, coordsOfLocation(d.address) || coords);
      }
    }
    // Peluches : la clé de ville est un nom normalisé (« parigi » ≠ « paris »).
    const plush = [];
    try {
      const PawPlush = require('../models/PawPlush');
      const keys = await PawPlush.aggregate([{ $group: { _id: '$cityKey', label: { $first: '$cityLabel' }, n: { $sum: 1 } } }]);
      for (const k of keys) {
        const key = String(k._id || '');
        const raw = key.replace(/^(test|shared):/, '').split(':')[0];
        const canon = canonicalCityName(raw);
        if (canon !== raw) plush.push({ cityKey: key, label: k.label || '', count: k.n, canonical: canon });
      }
    } catch (_) { /* collection absente */ }
    // Centres-villes mémorisés sous un nom étranger (souvent faux : « parigi » → Indonésie).
    const anchors = [];
    try {
      const CityAnchor = require('../models/CityAnchor');
      const rows = await CityAnchor.find({}).select('key lat lng').lean();
      for (const r of rows) {
        const canon = canonicalCityName(String(r.key || ''));
        if (canon.toLowerCase() !== String(r.key || '').toLowerCase()) anchors.push({ key: r.key, lat: r.lat, lng: r.lng, canonical: canon });
      }
    } catch (_) { /* collection absente */ }
    const byValue = {};
    for (const r of out) byValue[`${r.value} → ${r.canonical}`] = (byValue[`${r.value} → ${r.canonical}`] || 0) + 1;
    res.json({ total: out.length, byValue, rows: out, plush, anchors, readOnly: true });
  } catch (e) {
    logger.error('[admin/requests0410/cities]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
