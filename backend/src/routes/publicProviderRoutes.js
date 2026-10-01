'use strict';

/**
 * 607 (NEO, 02/10/2026) — « RAMÈNE TES PROPRES CLIENTS » (décision de Daniel).
 *
 *   GET /api/v1/public/providers/me/link            (connecté, gardien/promeneur)
 *       → { slug, url, role, city, isPioneer, bookingsCount, posterUrl }
 *         Crée le slug au premier appel. Lu par l'accueil prestataire et le Profil.
 *   GET /api/v1/public/providers/:slug               (public)
 *       → { provider: {...} }  liste BLANCHE (utils/publicProvider607.js)
 *   GET /api/v1/public/providers/:slug/poster.pdf?lang=fr   (public)
 *       → affiche A4 (application/pdf) : nom, photo, QR vers le lien, 3 lignes.
 *
 * Masqués (404) : profils bannis, suspendus, masqués par l'admin ; comptes de
 * test (+test) sauf pour la personne elle-même (règle v604 : jamais en public).
 * Rien n'est envoyé à personne : ces routes ne font que LIRE et rendre.
 * Contrat pour le site (LEO) : ~/hopetsit-social/CONTRAT_607_lien_perso.md.
 */
const express = require('express');
const logger = require('../utils/logger');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const { ensurePublicSlug, isValidSlug } = require('../utils/publicSlug607');
const { toPublicProvider, cityOfDoc, SITE } = require('../utils/publicProvider607');
const { computeIsPioneer } = require('../utils/pioneer607');
const { buildPosterPdf, posterLang } = require('../utils/posterPdf607');

const router = express.Router();

const modelFor = (role) => (role === 'walker' ? require('../models/Walker') : require('../models/Sitter'));

function hiddenProfile(d) {
  return !d || d.hiddenFromPublic === true || !!d.bannedAt
    || d.status === 'banned' || d.status === 'suspended';
}

async function viewerIds(req) {
  try {
    const { selfIdSet } = require('../utils/identityGroup');
    return await selfIdSet(req);
  } catch (_) {
    return new Set();
  }
}

/** Le prestataire derrière un slug, ou null s'il ne doit pas être montré. */
async function findVisible(slug, req) {
  if (!isValidSlug(slug)) return null;
  for (const role of ['sitter', 'walker']) {
    const Model = modelFor(role);
    // eslint-disable-next-line no-await-in-loop
    const d = await Model.findOne({ publicSlug: slug }).select('+homeLocation').lean();
    if (!d) continue;
    if (hiddenProfile(d)) return null;
    const { isTestAccountDoc } = require('../utils/testAccountMap604');
    const isTest = isTestAccountDoc(d);
    if (isTest) {
      // eslint-disable-next-line no-await-in-loop
      const mine = await viewerIds(req);
      if (!mine.has(String(d._id))) return null;
    }
    return { doc: d, role, indexable: !isTest && d.isStaff !== true };
  }
  return null;
}

router.get('/me/link', requireAuth, async (req, res) => {
  try {
    const role = String(req.user.role || '');
    if (role !== 'sitter' && role !== 'walker') {
      return res.status(403).json({ error: 'provider_only' });
    }
    const Model = modelFor(role);
    const doc = await Model.findById(req.user.id).select('+homeLocation').lean();
    if (!doc) return res.status(404).json({ error: 'not_found' });
    const slug = await ensurePublicSlug(doc, role);

    let isPioneer = null;
    try { isPioneer = await computeIsPioneer(doc); } catch (e) {
      logger.warn(`[public/providers/me/link] pionnier : ${e && e.message}`);
    }

    // « 0 réservation » : toutes les réservations acceptées, payées ou
    // terminées de la PERSONNE (ses profils gardien et promeneur).
    let bookingsCount = 0;
    try {
      const { identityGroup } = require('../utils/identityGroup');
      const ids = (await identityGroup(String(doc._id))).ids;
      const Booking = require('../models/Booking');
      bookingsCount = await Booking.countDocuments({
        $or: [{ sitterId: { $in: ids } }, { walkerId: { $in: ids } }],
        status: { $in: ['accepted', 'agreed', 'paid', 'completed'] },
      });
    } catch (e) {
      logger.warn(`[public/providers/me/link] réservations : ${e && e.message}`);
    }

    return res.json({
      slug,
      url: `${SITE}/s/${slug}`,
      role,
      city: cityOfDoc(doc),
      isPioneer,
      bookingsCount,
      posterPath: `/public/providers/${slug}/poster.pdf`,
    });
  } catch (e) {
    logger.error({ err: e }, '[public/providers/me/link]');
    return res.status(500).json({ error: 'unavailable' });
  }
});

/**
 * Badge « Pionnier » sur la fiche de l'APP (/sitters/:id, /walkers/:id ne le
 * portent pas : on n'alourdit pas ces réponses partagées).
 *   GET /api/v1/public/providers/badge/:role/:id → { isPioneer: bool }
 * Profil masqué / inconnu / de test → false (jamais d'erreur visible).
 */
router.get('/badge/:role/:id', async (req, res) => {
  try {
    const role = req.params.role === 'walker' ? 'walker' : (req.params.role === 'sitter' ? 'sitter' : '');
    const id = String(req.params.id || '');
    if (!role || !/^[a-f0-9]{24}$/i.test(id)) return res.json({ isPioneer: false });
    const d = await modelFor(role).findById(id).select('+homeLocation').lean();
    const { isTestAccountDoc } = require('../utils/testAccountMap604');
    if (!d || hiddenProfile(d) || isTestAccountDoc(d)) return res.json({ isPioneer: false });
    const v = (await computeIsPioneer(d)) === true;
    res.set('Cache-Control', 'public, max-age=600');
    return res.json({ isPioneer: v });
  } catch (e) {
    logger.warn(`[public/providers/badge] ${e && e.message}`);
    return res.json({ isPioneer: false });
  }
});

router.get('/:slug', optionalAuth, async (req, res) => {
  try {
    const slug = String(req.params.slug || '').toLowerCase();
    const found = await findVisible(slug, req);
    if (!found) return res.status(404).json({ error: 'not_found' });
    const { doc, role, indexable } = found;
    const Review = require('../models/Review');
    const reviews = await Review.find({
      revieweeId: doc._id,
      revieweeModel: role === 'walker' ? 'Walker' : 'Sitter',
      hidden: { $ne: true },
    })
      .sort({ createdAt: -1 })
      .limit(5)
      .populate('reviewerId', 'name firstName lastName')
      .lean();
    let isPioneer = false;
    try { isPioneer = (await computeIsPioneer(doc)) === true; } catch (_) { isPioneer = false; }
    const provider = toPublicProvider(doc, role, { reviews, isPioneer, indexable });
    res.set('Cache-Control', indexable ? 'public, max-age=300' : 'private, no-store');
    return res.json({ provider });
  } catch (e) {
    logger.error({ err: e }, '[public/providers/:slug]');
    return res.status(500).json({ error: 'unavailable' });
  }
});

// Petit cache des affiches (10 min) : une affiche imprimée ne bouge pas.
const POSTER_TTL_MS = 10 * 60 * 1000;
const _posters = new Map();

async function fetchPhotoJpeg(url) {
  if (!url || !/^https:\/\//.test(url)) return null;
  // Cloudinary : demande directement un JPEG carré centré sur le visage.
  const src = /res\.cloudinary\.com\/.+\/upload\//.test(url)
    ? url.replace('/upload/', '/upload/c_fill,g_face,w_400,h_400,f_jpg,q_80/')
    : url;
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 4000);
  try {
    const r = await fetch(src, { signal: ctrl.signal });
    if (!r.ok) return null;
    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length > 3 * 1024 * 1024) return null;
    return buf[0] === 0xff && buf[1] === 0xd8 ? buf : null;
  } catch (_) {
    return null;
  } finally {
    clearTimeout(t);
  }
}

router.get('/:slug/poster.pdf', optionalAuth, async (req, res) => {
  try {
    const slug = String(req.params.slug || '').toLowerCase();
    const found = await findVisible(slug, req);
    if (!found) return res.status(404).json({ error: 'not_found' });
    const { doc, role } = found;
    const lang = posterLang(req.query.lang);
    const key = `${slug}|${lang}|${doc.updatedAt ? new Date(doc.updatedAt).getTime() : 0}`;
    let pdf = null;
    const hit = _posters.get(key);
    if (hit && Date.now() - hit.at < POSTER_TTL_MS) pdf = hit.pdf;
    if (!pdf) {
      const p = toPublicProvider(doc, role, {});
      const photoJpeg = await fetchPhotoJpeg(p.photo);
      pdf = buildPosterPdf({
        name: p.name, role, city: p.city, url: `${SITE}/s/${slug}`, photoJpeg, lang,
      });
      _posters.set(key, { at: Date.now(), pdf });
      if (_posters.size > 200) _posters.delete(_posters.keys().next().value);
    }
    res.set('Content-Type', 'application/pdf');
    res.set('Content-Disposition', `inline; filename="hopetsit-${slug}.pdf"`);
    res.set('Cache-Control', 'private, max-age=600');
    return res.send(pdf);
  } catch (e) {
    logger.error({ err: e }, '[public/providers/:slug/poster.pdf]');
    return res.status(500).json({ error: 'unavailable' });
  }
});

module.exports = router;
module.exports._fetchPhotoJpeg = fetchPhotoJpeg;
