/**
 * siteEventRoutes — v576
 *
 * Mesure d'audience maison, première partie, SANS cookie ni donnée
 * personnelle (voir models/SiteEvent.js pour le détail RGPD).
 *
 *   POST /api/v1/site-events                 (public, répond toujours 204)
 *   GET  /api/v1/admin/site-analytics?days=7 (admin — router `adminRouter`)
 *
 * Le POST est appelé par navigator.sendBeacon depuis www.hopetsit.com : le
 * corps arrive en Content-Type `text/plain` (requête « simple » → aucun
 * preflight CORS) ou `application/json`. Il répond TOUJOURS 204 sans corps,
 * même en cas de rejet : une mesure d'audience ne doit jamais casser une page
 * ni renseigner un robot sur ses filtres.
 */
const express = require('express');
const SiteEvent = require('../models/SiteEvent');
const { requireAuth, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();
const adminRouter = express.Router();
const requireAdmin = [requireAuth, requireRole('admin')];

// ── LIMITATION DE DÉBIT EN MÉMOIRE ───────────────────────────────────────────
// 60 événements par minute et par empreinte. Volontairement en mémoire : pas
// de dépendance, pas d'écriture, et une instance Render qui redémarre remet
// simplement les compteurs à zéro.
const RATE_WINDOW_MS = 60 * 1000;
const RATE_MAX = 60;
const RATE_MAX_KEYS = 20000; // garde-fou mémoire
const _hits = new Map();

function rateLimitAllow(key, now = Date.now()) {
  if (!key) return false;
  const entry = _hits.get(key);
  if (!entry || now - entry.start >= RATE_WINDOW_MS) {
    if (_hits.size >= RATE_MAX_KEYS) _hits.clear();
    _hits.set(key, { start: now, n: 1 });
    return true;
  }
  entry.n += 1;
  return entry.n <= RATE_MAX;
}
function rateLimitReset() { _hits.clear(); }

// ── POST /site-events ────────────────────────────────────────────────────────

const parseBeaconBody = express.text({
  type: () => true, // body-parser saute tout seul si express.json a déjà parsé
  limit: '4kb',
});

function payloadOf(req) {
  if (typeof req.body === 'string') {
    try { return JSON.parse(req.body); } catch (_) { return null; }
  }
  return req.body && typeof req.body === 'object' ? req.body : null;
}

router.post('/', parseBeaconBody, async (req, res) => {
  // Réponse immédiate : le site n'attend rien et ne doit rien apprendre.
  res.status(204).end();
  try {
    const userAgent = req.headers['user-agent'] || '';
    if (SiteEvent.isBotUserAgent(userAgent)) return;

    const payload = payloadOf(req);
    if (!payload) return;

    const doc = SiteEvent.buildEvent(payload, {
      ip: req.ip || '',
      userAgent,
      now: new Date(),
    });
    if (!doc) return;

    if (!rateLimitAllow(doc.visitor)) return;

    await SiteEvent.create(doc);
  } catch (e) {
    // Jamais d'erreur visible : la mesure est secondaire par rapport au site.
    logger.warn({ err: e && e.message }, '[site-events] écriture ignorée');
  }
});

// ── AGRÉGATION (fonction pure, testable sans base) ───────────────────────────

const pct = (n, d) => (d > 0 ? Math.round((n / d) * 1000) / 10 : 0);
const evolution = (now, before) => {
  if (!before) return now > 0 ? 100 : 0;
  return Math.round(((now - before) / before) * 1000) / 10;
};

function emptyBucket(key, value) {
  return {
    [key]: value,
    pageviews: 0,
    storeClicks: 0,
    ctaClicks: 0,
    _visitors: new Set(),
  };
}

function feed(bucket, ev) {
  if (ev.visitor) bucket._visitors.add(ev.visitor);
  if (ev.type === 'pageview') bucket.pageviews += 1;
  else if (ev.type === 'store_click') bucket.storeClicks += 1;
  else if (ev.type === 'cta_click') bucket.ctaClicks += 1;
}

function finish(bucket) {
  const visitors = bucket._visitors.size;
  const out = { ...bucket, visitors, storeClickRate: pct(bucket.storeClicks, visitors) };
  delete out._visitors;
  return out;
}

function totalsOf(events) {
  const t = { pageviews: 0, storeClicks: 0, ctaClicks: 0, _visitors: new Set() };
  for (const ev of events) feed(t, ev);
  return finish(t);
}

/**
 * Construit tous les agrégats affichés dans l'admin à partir des événements
 * bruts des 2 × `days` derniers jours (la 2ᵉ moitié sert à la comparaison).
 */
function buildAnalytics(events, { days = 7, now = new Date() } = {}) {
  const nbDays = Math.max(1, Math.min(90, Number(days) || 7));
  const today = SiteEvent.dayKey(now);
  const from = SiteEvent.shiftDay(today, -(nbDays - 1));
  const prevFrom = SiteEvent.shiftDay(today, -(2 * nbDays - 1));
  const prevTo = SiteEvent.shiftDay(from, -1);

  const all = Array.isArray(events) ? events : [];
  const current = all.filter((e) => e && e.day >= from && e.day <= today);
  const previous = all.filter((e) => e && e.day >= prevFrom && e.day <= prevTo);

  const totals = totalsOf(current);
  const prevTotals = totalsOf(previous);

  // Par jour (tous les jours de la période, même vides).
  const dayMap = new Map();
  for (let i = 0; i < nbDays; i += 1) {
    const d = SiteEvent.shiftDay(from, i);
    dayMap.set(d, emptyBucket('day', d));
  }
  const group = (list, key, keyName) => {
    const map = new Map();
    for (const ev of list) {
      const k = key(ev);
      if (k === null || k === undefined) continue;
      if (!map.has(k)) map.set(k, emptyBucket(keyName, k));
      feed(map.get(k), ev);
    }
    return map;
  };

  for (const ev of current) {
    const b = dayMap.get(ev.day);
    if (b) feed(b, ev);
  }

  const bySource = [...group(current, (e) => e.source || 'direct', 'source').values()]
    .map(finish)
    .sort((a, b) => b.visitors - a.visitors || b.pageviews - a.pageviews);

  const topPages = [...group(
    current.filter((e) => e.path),
    (e) => e.path,
    'path',
  ).values()]
    .map(finish)
    .sort((a, b) => b.pageviews - a.pageviews || b.visitors - a.visitors)
    .slice(0, 15);

  const byCampaign = [...group(
    current.filter((e) => e.utmCampaign),
    (e) => e.utmCampaign,
    'campaign',
  ).values()]
    .map(finish)
    .sort((a, b) => b.visitors - a.visitors || b.pageviews - a.pageviews)
    .slice(0, 20);

  const byDevice = [...group(current, (e) => e.device || 'desktop', 'device').values()]
    .map(finish)
    .sort((a, b) => b.visitors - a.visitors);

  const byLang = [...group(current, (e) => e.lang || '—', 'lang').values()]
    .map(finish)
    .sort((a, b) => b.visitors - a.visitors);

  return {
    days: nbDays,
    from,
    to: today,
    previousFrom: prevFrom,
    previousTo: prevTo,
    totals,
    previous: prevTotals,
    change: {
      pageviews: evolution(totals.pageviews, prevTotals.pageviews),
      visitors: evolution(totals.visitors, prevTotals.visitors),
      storeClicks: evolution(totals.storeClicks, prevTotals.storeClicks),
    },
    byDay: [...dayMap.values()].map(finish),
    bySource,
    topPages,
    byCampaign,
    byDevice,
    byLang,
  };
}

// ── GET /admin/site-analytics ────────────────────────────────────────────────

adminRouter.get('/', requireAdmin, async (req, res) => {
  try {
    const days = Math.max(1, Math.min(90, parseInt(req.query.days, 10) || 7));
    const now = new Date();
    const since = SiteEvent.shiftDay(SiteEvent.dayKey(now), -(2 * days - 1));
    const events = await SiteEvent.find({ day: { $gte: since } })
      .select('type path lang device source utmCampaign day visitor -_id')
      .limit(400000)
      .lean();
    res.json(buildAnalytics(events, { days, now }));
  } catch (e) {
    logger.error('[admin/site-analytics]', e);
    res.status(500).json({ error: 'Unable to load site analytics.' });
  }
});

module.exports = router;
module.exports.adminRouter = adminRouter;
module.exports.buildAnalytics = buildAnalytics;
module.exports.rateLimitAllow = rateLimitAllow;
module.exports.rateLimitReset = rateLimitReset;
module.exports.RATE_MAX = RATE_MAX;
module.exports.RATE_WINDOW_MS = RATE_WINDOW_MS;
