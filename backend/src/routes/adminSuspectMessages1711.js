'use strict';

/**
 * 17/11/2026 (BOB, ordre de Daniel) — alerte « messages suspects » de l'admin.
 *
 *   GET  /api/v1/admin/suspect-messages-1711?days=60
 *        → { days, pending, strong, items: [{ key, conversationId, level, reason, count, excerpt,
 *            firstAt, lastAt, sender: { id, role, name, status, kind }, peer: { name, role },
 *            state: 'a_traiter' | 'compte_bloque' | 'classe' }] }
 *        Lecture seule. Les comptes de test et internes sont écartés. Aucune adresse e-mail.
 *        Une alerte n'est plus « à traiter » quand l'expéditeur est suspendu / banni, ou quand
 *        l'admin l'a classée (elle revient si un nouveau message suspect arrive ensuite).
 *   POST /api/v1/admin/suspect-messages-1711/dismiss  { key, note? }  → classer sans suite.
 *
 * La détection est dans utils/suspectMessages1711.js (fonctions pures, testées).
 */

const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');
const { groupSuspects, PREFILTER_SOURCE } = require('../utils/suspectMessages1711');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

const MODEL_OF = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
const INTERNAL_EMAIL_RE = /^(hopetsit@|dadaciao84@|contact@hopetsit\.com)/i;
const KEY_RE = /^[a-f0-9]{24}:(owner|sitter|walker):[a-f0-9]{24}$/i;

function plainEmail(stored) {
  let e = stored;
  try { e = require('../utils/encryption').decrypt(stored); } catch (_) { /* en clair */ }
  return String(e || '').toLowerCase().trim();
}
function kindOf(doc) {
  if (!doc) return 'real';
  const email = plainEmail(doc.email);
  if (/\+test/i.test(email)) return 'test';
  if (doc.isStaff === true || INTERNAL_EMAIL_RE.test(email)) return 'staff';
  return 'real';
}
function shortName(d) {
  const parts = String((d && (d.firstName || d.name)) || '').trim().split(/\s+/);
  const first = parts[0] || '';
  const lastRaw = String((d && d.lastName) || '').trim() || parts.slice(1).join(' ');
  return `${first} ${lastRaw ? `${lastRaw[0].toUpperCase()}.` : ''}`.trim() || '—';
}

async function loadPeople(refs) {
  const byRole = {};
  refs.forEach(([role, id]) => {
    if (!MODEL_OF[role] || !id) return;
    (byRole[role] = byRole[role] || new Set()).add(String(id));
  });
  const out = new Map();
  await Promise.all(Object.entries(byRole).map(async ([role, ids]) => {
    const docs = await require(`../models/${MODEL_OF[role]}`).find({ _id: { $in: [...ids] } })
      .select('name firstName lastName email isStaff status').lean();
    docs.forEach((d) => out.set(`${role}:${String(d._id)}`, d));
  }));
  return out;
}

router.get('/', requireAdmin, async (req, res) => {
  try {
    const Message = require('../models/Message');
    const Conversation = require('../models/Conversation');
    const Review = require('../models/SuspectMessageReview1711');
    const days = Math.min(Math.max(parseInt(req.query.days, 10) || 60, 1), 365);
    const since = new Date(Date.now() - days * 86400000);

    const messages = await Message.find({
      createdAt: { $gte: since },
      senderRole: { $in: ['owner', 'sitter', 'walker'] },
      deletedAt: null,
      body: { $regex: PREFILTER_SOURCE, $options: 'i' },
    }).select('conversationId senderRole senderId body createdAt').sort({ createdAt: -1 }).limit(3000).lean();

    const groups = groupSuspects(messages);
    const convIds = [...new Set(groups.map((g) => g.conversationId))];
    const [convs, reviews] = await Promise.all([
      Conversation.find({ _id: { $in: convIds } }).select('ownerId sitterId walkerId').lean(),
      Review.find({ key: { $in: groups.map((g) => g.key) } }).lean(),
    ]);
    const convById = new Map(convs.map((c) => [String(c._id), c]));
    const reviewByKey = new Map(reviews.map((r) => [r.key, r]));

    const refs = [];
    groups.forEach((g) => {
      refs.push([g.senderRole, g.senderId]);
      const c = convById.get(g.conversationId);
      if (c) {
        refs.push(['owner', c.ownerId]);
        if (c.sitterId) refs.push(['sitter', c.sitterId]);
        if (c.walkerId) refs.push(['walker', c.walkerId]);
      }
    });
    const people = await loadPeople(refs);

    const items = [];
    for (const g of groups) {
      const sender = people.get(`${g.senderRole}:${g.senderId}`) || null;
      const kind = kindOf(sender);
      if (kind !== 'real') continue;
      const c = convById.get(g.conversationId) || {};
      let peer = null; let peerRole = '';
      if (g.senderRole === 'owner') {
        peerRole = c.sitterId ? 'sitter' : (c.walkerId ? 'walker' : '');
        peer = peerRole ? people.get(`${peerRole}:${String(c.sitterId || c.walkerId)}`) : null;
      } else {
        peerRole = 'owner';
        peer = c.ownerId ? people.get(`owner:${String(c.ownerId)}`) : null;
      }
      if (peer && kindOf(peer) !== 'real') continue; // échange avec un compte de test
      const status = (sender && sender.status) || 'active';
      const review = reviewByKey.get(g.key);
      let state = 'a_traiter';
      if (status === 'suspended' || status === 'banned') state = 'compte_bloque';
      else if (review && new Date(review.reviewedAt).getTime() >= new Date(g.lastAt).getTime()) state = 'classe';
      items.push({
        key: g.key,
        conversationId: g.conversationId,
        level: g.level,
        reason: g.reason,
        apps: g.apps,
        payments: g.payments,
        count: g.count,
        excerpt: g.excerpt,
        firstAt: g.firstAt,
        lastAt: g.lastAt,
        sender: { id: g.senderId, role: g.senderRole, name: shortName(sender), status, kind },
        peer: { name: peer ? shortName(peer) : '—', role: peerRole },
        state,
      });
    }
    const pendingItems = items.filter((i) => i.state === 'a_traiter');
    return res.json({
      days,
      pending: pendingItems.length,
      strong: pendingItems.filter((i) => i.level === 'fort').length,
      total: items.length,
      items,
    });
  } catch (e) {
    logger.error('[admin/suspect-messages-1711]', e);
    return res.status(500).json({ error: e.message });
  }
});

router.post('/dismiss', requireAdmin, async (req, res) => {
  try {
    const key = String((req.body && req.body.key) || '');
    if (!KEY_RE.test(key)) return res.status(400).json({ error: 'key invalide.' });
    const Review = require('../models/SuspectMessageReview1711');
    const doc = await Review.findOneAndUpdate(
      { key },
      { $set: { reviewedAt: new Date(), reviewedBy: String(req.user?.id || ''), note: String((req.body && req.body.note) || '').slice(0, 300) } },
      { upsert: true, new: true },
    ).lean();
    logger.info(`[admin] message suspect classé sans suite ${key} par ${req.user?.id}`);
    return res.json({ ok: true, key: doc.key, reviewedAt: doc.reviewedAt });
  } catch (e) {
    logger.error('[admin/suspect-messages-1711/dismiss]', e);
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
