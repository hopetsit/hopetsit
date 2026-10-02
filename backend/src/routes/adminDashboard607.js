'use strict';

/**
 * 607 (ADA, 02/10/2026) — tuiles du TABLEAU DE BORD de l'admin (Daniel : « plus
 * moderne, et afficher les identités vérifiées »). LECTURE SEULE, requireAdmin.
 *
 *   GET /api/v1/admin/dashboard607
 *
 * Pour chaque tuile : valeur, valeur des 7 jours précédents (écart) et série
 * des 14 derniers jours (mini-courbe). Comptes de test et internes (+test,
 * hopetsit@, dadaciao84@, sonde) EXCLUS des chiffres et comptés à part.
 * Les revenus ne sont PAS recalculés ici : l'admin lit /admin/payouts et
 * /admin/shop-revenue, comme « Mes revenus » et la comptabilité (une seule
 * source). Les identités viennent du calcul de FLO (utils/kycPeople607).
 * Aucun e-mail dans la réponse.
 */

const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');
const { isInternalEmail } = require('../utils/userCounts');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin')];
const DAY = 86400000;
const DAYS = 14;

const plainEmail = (stored) => {
  try { return require('../utils/encryption').decrypt(stored); } catch (_) { return stored; }
};
const isInternal = (d) => !!d && isInternalEmail(plainEmail(d.email));
const dayKey = (d) => new Date(d).toISOString().slice(0, 10);
const MODELS = {
  owner: () => require('../models/Owner'),
  sitter: () => require('../models/Sitter'),
  walker: () => require('../models/Walker'),
};
const normRole = (r) => {
  const s = String(r || '').toLowerCase();
  return s === 'sitter' || s === 'walker' ? s : 'owner';
};

/** Série vide des 14 derniers jours (clés AAAA-MM-JJ, du plus ancien au plus récent). */
function emptySeries(now) {
  const out = {};
  for (let i = DAYS - 1; i >= 0; i -= 1) out[dayKey(now - i * DAY)] = 0;
  return out;
}
/** { value7, prev7, series[] } à partir d'une liste de dates (et de poids). */
function tile(items, now, { weight = () => 1 } = {}) {
  const series = emptySeries(now);
  let value7 = 0; let prev7 = 0;
  items.forEach((it) => {
    const t = new Date(it.at).getTime();
    if (!Number.isFinite(t)) return;
    const w = Number(weight(it)) || 0;
    const k = dayKey(t);
    if (k in series) series[k] += w;
    if (t >= now - 7 * DAY) value7 += w;
    else if (t >= now - 14 * DAY) prev7 += w;
  });
  return { value7, prev7, series: Object.values(series) };
}

router.get('/', requireAdmin, async (req, res) => {
  const t0 = Date.now();
  try {
    const now = Date.now();
    const since14 = new Date(now - DAYS * DAY);
    const Owner = MODELS.owner(); const Sitter = MODELS.sitter(); const Walker = MODELS.walker();
    const Post = require('../models/Post');
    const Booking = require('../models/Booking');
    const PawPointsEvent = require('../models/PawPointsEvent');
    let PawPlush = null;
    try { PawPlush = require('../models/PawPlush'); } catch (_) { PawPlush = null; }

    const sel = 'name firstName email verified createdAt city location.city';
    const [owners, sitters, walkers] = await Promise.all([
      Owner.find({}).select(sel).lean(),
      Sitter.find({}).select(sel).lean(),
      Walker.find({}).select(sel).lean(),
    ]);
    const byId = new Map();
    const all = [];
    [['owner', owners], ['sitter', sitters], ['walker', walkers]].forEach(([role, list]) => {
      list.forEach((d) => {
        const row = { role, id: String(d._id), d, internal: isInternal(d) };
        byId.set(`${role}:${row.id}`, row);
        byId.set(row.id, row);
        all.push(row);
      });
    });
    const realOf = (id, role) => {
      const r = byId.get(role ? `${normRole(role)}:${String(id)}` : String(id)) || byId.get(String(id));
      return r ? !r.internal : true;
    };

    // ── Inscriptions ──
    const recentSignups = all.filter((r) => r.d.createdAt && new Date(r.d.createdAt) >= since14);
    const realSignups = recentSignups.filter((r) => !r.internal);
    const signups = tile(realSignups.map((r) => ({ at: r.d.createdAt })), now);
    const byRole = (list, sinceMs) => ['owner', 'sitter', 'walker'].reduce((acc, role) => {
      acc[role] = list.filter((r) => r.role === role && new Date(r.d.createdAt).getTime() >= sinceMs).length;
      return acc;
    }, {});
    signups.last24h = realSignups.filter((r) => new Date(r.d.createdAt).getTime() >= now - DAY).length;
    signups.byRole24h = byRole(realSignups, now - DAY);
    signups.byRole7d = byRole(realSignups, now - 7 * DAY);
    signups.test7d = recentSignups.filter((r) => r.internal && new Date(r.d.createdAt).getTime() >= now - 7 * DAY).length;
    signups.recent = realSignups
      .sort((a, b) => new Date(b.d.createdAt) - new Date(a.d.createdAt))
      .slice(0, 6)
      .map((r) => ({
        id: r.id, role: r.role, name: r.d.name || r.d.firstName || '',
        city: require('../utils/publicCity607').publicCity((r.d.location && r.d.location.city) || r.d.city || ''),
        at: r.d.createdAt, emailVerified: r.d.verified === true,
      }));

    // ── E-mails vérifiés (comptes réels) ──
    const realAll = all.filter((r) => !r.internal);
    const emailVerified = {
      total: realAll.filter((r) => r.d.verified === true).length,
      accounts: realAll.length,
      ...tile(realSignups.filter((r) => r.d.verified === true).map((r) => ({ at: r.d.createdAt })), now),
    };

    // ── Identités (calcul de FLO : utils/kycPeople607) ──
    let identity = { verified: 0, paidUnverified: 0, oldestPaidUnverifiedH: null, testAccounts: 0, series: [], value7: 0, prev7: 0 };
    try {
      const { personRow, summarize } = require('../utils/kycPeople607');
      const f = { $or: [{ kycStatus: 'verified' }, { 'identityVerification.status': 'verified' }, { kycPaidAt: { $ne: null } }] };
      const fields = 'name email city location.city coverageCity kycStatus kycPaidAt kycVerifiedAt kycApplicantId kycPaymentIntentId identityVerification.status identityVerification.reviewedAt';
      const [ks, kw] = await Promise.all([Sitter.find(f).select(fields).lean(), Walker.find(f).select(fields).lean()]);
      const nowD = new Date(now);
      const rows = [...ks.map((d) => personRow(d, 'sitter', { now: nowD, isInternal })), ...kw.map((d) => personRow(d, 'walker', { now: nowD, isInternal }))];
      const sum = summarize(rows, { now: nowD });
      const pu = rows.filter((r) => !r.isTest && r.paid && !r.verified);
      const oldest = pu.reduce((m, r) => Math.min(m, new Date(r.paidAt).getTime()), Infinity);
      identity = {
        verified: sum.verified,
        paidUnverified: sum.paidUnverified,
        oldestPaidUnverifiedH: Number.isFinite(oldest) ? Math.round((now - oldest) / 3600000) : null,
        testAccounts: sum.testAccounts,
        ...tile(rows.filter((r) => !r.isTest && r.verified && r.verifiedAt).map((r) => ({ at: r.verifiedAt })), now),
      };
    } catch (e) { logger.warn(`[admin/dashboard607] identités : ${e.message}`); }

    // ── Demandes publiées ──
    const posts = await Post.find({ postType: 'request', createdAt: { $gte: since14 } }).select('ownerId createdAt').lean();
    const realPosts = posts.filter((p) => realOf(p.ownerId, 'owner'));
    const requests = tile(realPosts.map((p) => ({ at: p.createdAt })), now);
    requests.test7d = posts.length - realPosts.length;

    // ── Réservations payées / terminées ──
    const bks = await Booking.find({
      $or: [{ paidAt: { $gte: since14 } }, { status: 'completed', updatedAt: { $gte: since14 } }],
    }).select('ownerId paidAt paymentStatus status updatedAt').lean();
    const realBks = bks.filter((b) => realOf(b.ownerId, 'owner'));
    const paid = tile(realBks.filter((b) => b.paidAt && b.paymentStatus === 'paid').map((b) => ({ at: b.paidAt })), now);
    const completed = tile(realBks.filter((b) => b.status === 'completed').map((b) => ({ at: b.updatedAt })), now);
    const [paidAllTime, completedAllTime] = await Promise.all([
      Booking.find({ paymentStatus: 'paid' }).select('ownerId').lean(),
      Booking.find({ status: 'completed' }).select('ownerId').lean(),
    ]);
    paid.allTime = paidAllTime.filter((b) => realOf(b.ownerId, 'owner')).length;
    completed.allTime = completedAllTime.filter((b) => realOf(b.ownerId, 'owner')).length;

    // ── Balades terminées (gain walkCompleted) + peluches + PawPoints ──
    const events = await PawPointsEvent.find({ at: { $gte: since14 }, key: { $ne: 'admin_test_adjust' } }).select('userId role key credited at').lean();
    const realEvents = events.filter((e) => realOf(e.userId, e.role));
    const walks = tile(realEvents.filter((e) => e.key === 'walkCompleted').map((e) => ({ at: e.at })), now);
    let plushList = [];
    if (PawPlush) {
      plushList = await PawPlush.find({ caughtByPerson: { $type: 'string' }, 'caughtBy.at': { $gte: since14 } })
        .select('golden testCopy caughtBy').lean();
    }
    const realPlush = plushList.filter((p) => !p.testCopy && p.caughtBy && realOf(p.caughtBy.userId, p.caughtBy.role));
    const plush = tile(realPlush.map((p) => ({ at: p.caughtBy.at })), now);
    const todayKey = dayKey(now);
    walks.today = realEvents.filter((e) => e.key === 'walkCompleted' && dayKey(e.at) === todayKey).length;
    plush.today = realPlush.filter((p) => dayKey(p.caughtBy.at) === todayKey).length;
    plush.test7d = plushList.filter((p) => (p.testCopy || !p.caughtBy || !realOf(p.caughtBy.userId, p.caughtBy.role))
      && new Date(p.caughtBy && p.caughtBy.at).getTime() >= now - 7 * DAY).length;
    const pawpoints = tile([
      ...realEvents.map((e) => ({ at: e.at, w: Number(e.credited || 0) })),
      ...realPlush.map((p) => ({ at: p.caughtBy.at, w: p.golden ? 200 : 20 })),
    ], now, { weight: (it) => it.w });

    return res.json({
      generatedAt: new Date(now).toISOString(),
      days: Object.keys(emptySeries(now)),
      tiles: { signups, emailVerified, identity, requests, paid, completed, walks, plush, pawpoints },
      ms: Date.now() - t0,
    });
  } catch (e) {
    logger.error({ err: e }, '[admin/dashboard607]');
    return res.status(500).json({ error: 'Erreur.' });
  }
});

/**
 * GET /api/v1/admin/dashboard607/email-status — e-mail vérifié (adresse validée par code ou
 * lien) pour CHAQUE profil, calculé par PERSONNE : depuis le 565, /auth/verify pose
 * `verified:true` sur les 3 profils d'un même e-mail (markVerifiedAcrossRoles).
 * Ambiguïté connue (FLO) : sur un gardien / promeneur, l'admin qui valide l'IDENTITÉ pose aussi
 * `verified:true` (et `false` s'il la refuse). Un profil dont le seul « vérifié » vient d'une
 * validation d'identité par l'admin est donc marqué `uncertain`. Lecture seule, sans e-mail.
 */
router.get('/email-status', requireAdmin, async (req, res) => {
  try {
    const sel = 'email verified createdAt kycStatus identityVerification.status identityVerification.reviewedAt';
    const lists = await Promise.all(['owner', 'sitter', 'walker'].map((r) => MODELS[r]().find({}).select(sel).lean()));
    const byEmail = new Map();
    const rows = [];
    ['owner', 'sitter', 'walker'].forEach((role, i) => lists[i].forEach((d) => {
      const email = String(plainEmail(d.email) || '').trim().toLowerCase();
      const iv = d.identityVerification || {};
      const identityVerified = role !== 'owner' && (d.kycStatus === 'verified' || iv.status === 'verified');
      // « vérifié » qui peut venir de la validation d'identité par l'admin (pas de l'e-mail).
      const fromAdminIdentity = role !== 'owner' && iv.status === 'verified' && !!iv.reviewedAt;
      const row = { role, id: String(d._id), email, verified: d.verified === true, fromAdminIdentity, identityVerified, createdAt: d.createdAt || null, internal: isInternal(d) };
      rows.push(row);
      if (email) (byEmail.get(email) || byEmail.set(email, []).get(email)).push(row);
    }));
    const people = {};
    let verified = 0; let uncertain = 0;
    rows.forEach((r) => {
      const group = r.email ? byEmail.get(r.email) : [r];
      const sure = group.some((x) => x.verified && !x.fromAdminIdentity);
      const maybe = !sure && group.some((x) => x.verified);
      const ok = sure || maybe;
      if (ok) verified += 1;
      if (maybe) uncertain += 1;
      people[`${r.role}:${r.id}`] = { emailVerified: ok, uncertain: maybe, identityVerified: r.identityVerified, since: r.createdAt };
    });
    return res.json({ generatedAt: new Date().toISOString(), summary: { verified, total: rows.length, uncertain }, people });
  } catch (e) {
    logger.error({ err: e }, '[admin/dashboard607/email-status]');
    return res.status(500).json({ error: 'Erreur.' });
  }
});

module.exports = router;
