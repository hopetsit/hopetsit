/**
 * 22/10/2026 (SAM, accord de Daniel « bouton 1 clic ») — contacts de la pub à
 * formulaire Meta → demande publiée en UN clic depuis l'e-mail.
 *
 *   POST /admin/ad-leads            (admin) enregistre un contact, renvoie { id }
 *                                   (même metaLeadId → même id : jamais deux fois)
 *   GET  /ad-leads/:id              (public) résumé sans e-mail pour la page /confirmer
 *   POST /ad-leads/:id/confirm      (public) { lieu? } crée le compte propriétaire si
 *                                   besoin (e-mail prouvé par le clic → vérifié),
 *                                   publie la demande par createPost (mêmes règles,
 *                                   mêmes alertes aux gardiens), renvoie une session.
 *
 *   POST /admin/ad-leads/:id/publish (admin) 23/10 (SAM, consigne de Daniel) : le
 *                                   suivi des contacts publie la demande DÈS que le
 *                                   formulaire est rempli (même chemin que le clic :
 *                                   compte propriétaire vérifié, demande par createPost,
 *                                   gardiens prévenus), sans renvoyer de session.
 *
 * Idempotent : un 2e clic renvoie la même demande, sans en publier une autre.
 * Mot de passe : aléatoire ; le propriétaire en choisit un par « Mot de passe oublié ».
 */
const crypto = require('crypto');
const express = require('express');
const mongoose = require('mongoose');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');
const AdLead = require('../models/AdLead2210');
const Owner = require('../models/Owner');
const { countryToCurrency } = require('../utils/countryCurrency');

const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];
const TERMS_VERSION = process.env.TERMS_VERSION || 'v1.0';

/** Demande telle que le site la publierait (cf. website posts/create). */
function postInputFor(lead, lieu) {
  const fr = lead.lang === 'fr';
  const qui = lead.animal === 'chien' ? (fr ? 'mon chien' : 'my dog')
    : lead.animal === 'chat' ? (fr ? 'mon chat' : 'my cat') : (fr ? 'mon animal' : 'my pet');
  const quoi = lead.service === 'promenade' ? (fr ? 'des promenades pour' : 'dog walks for')
    : lead.service === 'visites' ? (fr ? 'des visites à domicile pour' : 'drop-in visits for')
      : (fr ? 'une garde pour' : 'a pet sitter for');
  const quand = { bientot: fr ? ' dans les 15 jours' : ' within 2 weeks',
    fetes: fr ? " pendant les fêtes de fin d'année" : ' over the holidays' }[lead.quand] || '';
  const input = {
    body: `${fr ? 'Je cherche' : "I'm looking for"} ${quoi} ${qui}${quand}.`,
    language: lead.lang,
    animalCount: 1,
    animalTypes: [{ chien: 'dog', chat: 'cat' }[lead.animal] || 'other'],
    // 23/10 (BOB, demande de Daniel) — les dates : réponses du formulaire, sinon déduites du choix « quand ».
    ...(() => { const d = require('../utils/adLeadDates2310').datesFor(lead); return d ? { startDate: d.startDate.toISOString(), endDate: d.endDate.toISOString() } : {}; })(),
    location: Number.isFinite(lead.lat) && Number.isFinite(lead.lng)
      ? { city: lead.city, lat: lead.lat, lng: lead.lng } : { city: lead.city },
  };
  // 620 (ZOE) — sans dates lisibles, la demande est « dates à prévoir » (tbd) : les
  // gardiens candidatent au tarif unitaire, le propriétaire pose ses dates ensuite.
  if (!input.startDate) input.dateMode = 'tbd';
  if (lead.service === 'promenade') {
    input.serviceTypes = ['dog_walking'];
    input.serviceLocation = 'pickup';
  } else if (lead.service === 'visites') {
    // 620 — visites à domicile : service `home_visit`, 1 ou 2 visites/jour (formulaire, sinon 1).
    input.serviceTypes = ['home_visit'];
    input.serviceLocation = 'at_owner';
    input.visitsPerDay = [1, 2].includes(Number(lead.visitsPerDay)) ? Number(lead.visitsPerDay) : 1;
  } else {
    const chezGardien = lead.service === 'garde' && lieu === 'at_sitter';
    input.serviceTypes = ['house_sitting'];
    input.houseSittingVenue = chezGardien ? 'sitters_home' : 'owners_home';
    input.serviceLocation = chezGardien ? 'at_sitter' : 'at_owner';
  }
  return input;
}

/** Appelle un contrôleur Express et récupère { status, body }. */
function callController(fn, req) {
  return new Promise((resolve, reject) => {
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ status: this.statusCode, body: b }); return this; },
    };
    Promise.resolve(fn(req, res)).catch(reject);
  });
}

// ── admin : enregistrement d'un contact ──────────────────────────────────────
const adminRouter = express.Router();
adminRouter.post('/', requireAdmin, async (req, res) => {
  try {
    const b = req.body || {};
    const email = String(b.email || '').trim().toLowerCase();
    const metaLeadId = String(b.metaLeadId || '').trim();
    const city = String(b.city || '').trim();
    if (!metaLeadId || !city || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      return res.status(400).json({ error: 'metaLeadId, email and city are required.' });
    }
    const pick = (v, list, d) => (list.includes(v) ? v : d);
    const lat = Number(b.lat); const lng = Number(b.lng);
    const lead = await AdLead.findOneAndUpdate(
      { metaLeadId },
      { $setOnInsert: {
        metaLeadId, email, city,
        firstName: String(b.firstName || '').trim().slice(0, 60),
        ...(Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : {}),
        country: String(b.country || '').trim().toUpperCase().slice(0, 2),
        lang: b.lang === 'en' ? 'en' : 'fr',
        service: pick(b.service, AdLead.SERVICES, 'garde'),
        animal: pick(b.animal, AdLead.ANIMALS, 'autre'),
        quand: pick(b.quand, AdLead.WHENS, 'plus_tard'),
        startText: String(b.startText || '').trim().slice(0, 60), // 23/10 (BOB) — réponses « dates » du formulaire
        endText: String(b.endText || '').trim().slice(0, 60),
        ...([1, 2].includes(Number(b.visitsPerDay)) ? { visitsPerDay: Number(b.visitsPerDay) } : {}), // 620
      } },
      { upsert: true, new: true, setDefaultsOnInsert: true },
    );
    return res.status(200).json({ id: lead._id, confirmed: !!lead.confirmedAt });
  } catch (e) {
    logger.error('[adLeads2210] register failed', e);
    return res.status(500).json({ error: 'Unable to register lead.' });
  }
});

// ── admin : chiffres des contacts pub (2410, ZOE — demande de BOB / ADA) ──────
// GET /admin/ad-leads/stats?days=7&tz=Europe/Paris → { today, yesterday, d7, byCity: { paris, nyc, other },
// published, withDates, confirmed, total } pour la ligne « Aujourd'hui » de l'admin. Jours au fuseau
// de Paris (comme le board 613). byCity / published / withDates / confirmed portent sur la fenêtre
// `days` (1 à 90, 7 par défaut). JAMAIS d'e-mail ni de téléphone : uniquement des compteurs.
function dayStartIn2410(tz, now) {
  try {
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' })
      .formatToParts(now).reduce((o, x) => { o[x.type] = x.value; return o; }, {});
    const asUtc = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute, +parts.second);
    return new Date(Date.UTC(+parts.year, +parts.month - 1, +parts.day) - (asUtc - now.getTime()));
  } catch (_) {
    return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  }
}
const PARIS_RE = /\bparis\b/i;
const NYC_RE = /new\s*york|\bnyc\b|brooklyn|queens|bronx|manhattan|staten/i;
adminRouter.get('/stats', requireAdmin, async (req, res) => {
  try {
    const DAY = 86400000;
    const now = new Date();
    const days = Math.min(90, Math.max(1, parseInt(req.query.days, 10) || 7));
    const tz = String(req.query.tz || 'Europe/Paris').slice(0, 40);
    const t0 = dayStartIn2410(tz, now);
    const since = new Date(now.getTime() - days * DAY);
    const from = new Date(Math.min(since.getTime(), t0.getTime() - DAY));
    const rows = await AdLead.find({ createdAt: { $gte: from } }).select('createdAt city country postId startText endText confirmedAt').lean();
    const { datesFor } = require('../utils/adLeadDates2310');
    const out = { days, timeZone: tz, generatedAt: now, today: 0, yesterday: 0, d7: 0, byCity: { paris: 0, nyc: 0, other: 0 }, published: 0, withDates: 0, confirmed: 0, total: 0 };
    for (const l of rows) {
      const t = l.createdAt ? new Date(l.createdAt).getTime() : 0;
      if (t >= t0.getTime()) out.today += 1;
      else if (t >= t0.getTime() - DAY) out.yesterday += 1;
      if (t < since.getTime()) continue;
      out.d7 += 1;
      const city = String(l.city || '');
      if (PARIS_RE.test(city)) out.byCity.paris += 1;
      else if (NYC_RE.test(city)) out.byCity.nyc += 1;
      else out.byCity.other += 1;
      if (l.postId) out.published += 1;
      if (l.confirmedAt) out.confirmed += 1;
      let dd = null;
      try { dd = datesFor(l, now); } catch (_) { dd = null; }
      if (dd && dd.source === 'form') out.withDates += 1;
    }
    out.total = await AdLead.countDocuments({});
    return res.json(out);
  } catch (e) {
    logger.error('[adLeads2210] stats failed', e);
    return res.status(500).json({ error: 'Unable to read stats.' });
  }
});

// ── public : résumé + confirmation ───────────────────────────────────────────
const router = express.Router();
const ID_RE = /^[a-f0-9]{32}$/;

router.get('/:id', async (req, res) => {
  if (!ID_RE.test(req.params.id)) return res.status(404).json({ error: 'not_found' });
  const lead = await AdLead.findById(req.params.id).lean();
  if (!lead) return res.status(404).json({ error: 'not_found' });
  return res.json({
    firstName: lead.firstName, city: lead.city, lang: lead.lang,
    service: lead.service, animal: lead.animal, quand: lead.quand,
    confirmed: !!lead.confirmedAt,
    ...(lead.postId ? { postId: String(lead.postId) } : {}),
  });
});

/**
 * Publie la demande d'un contact (compte propriétaire créé ou repris et vérifié,
 * demande par createPost = mêmes règles et mêmes alertes aux gardiens).
 * Renvoie { owner, postId, notified, status, body } ; status ≠ 200 = createPost a refusé.
 */
async function publishLead(lead, lieu) {
  // 1. Compte propriétaire : existant (rendu vérifié, l'e-mail vient de Meta / du clic) ou créé.
  let owner = await Owner.findOne({ email: lead.email });
  if (!owner) {
    const firstName = lead.firstName || (lead.lang === 'fr' ? 'Propriétaire' : 'Owner');
    owner = await Owner.create({
      name: firstName, firstName, lastName: '',
      email: lead.email,
      password: crypto.randomBytes(18).toString('hex'),
      city: lead.city,
      country: lead.country || '',
      currency: countryToCurrency(lead.country),
      appLocale: lead.lang,
      language: lead.lang,
      acceptedTerms: true, termsAcceptedAt: new Date(), termsVersion: TERMS_VERSION,
      verified: true,
    });
  }
  const { markVerifiedAcrossRoles } = require('../controllers/authController');
  if (owner.verified !== true) await markVerifiedAcrossRoles(lead.email);

  // 2. Demande : une seule par contact (2e appel = la même).
  let postId = lead.postId;
  let notified;
  if (!postId) {
    const { createPost } = require('../controllers/postController');
    const out = await callController(createPost, {
      user: { id: owner._id.toString(), role: 'owner' }, body: postInputFor(lead, lieu),
    });
    if (out.status === 201) {
      postId = out.body.post && (out.body.post.id || out.body.post._id);
      notified = out.body.notified;
    } else if (out.status === 409) {
      postId = out.body.existingPostId || out.body.postId || null;
    } else {
      logger.warn('[adLeads2210] createPost refused', out.status, out.body && out.body.error);
      return { owner, postId: null, status: out.status, body: out.body };
    }
    if (postId && mongoose.isValidObjectId(String(postId))) lead.postId = postId;
    lead.ownerId = owner._id;
    lead.confirmedAt = lead.confirmedAt || new Date();
    await lead.save();
  }
  const dates = require('../utils/adLeadDates2310').datesFor(lead);
  return { owner, postId: postId ? String(postId) : null, notified, status: 200, dates: dates ? dates.source : null };
}

router.post('/:id/confirm', async (req, res) => {
  try {
    if (!ID_RE.test(req.params.id)) return res.status(404).json({ error: 'not_found' });
    const lead = await AdLead.findById(req.params.id);
    if (!lead) return res.status(404).json({ error: 'not_found' });
    const lieu = req.body && req.body.lieu === 'at_sitter' ? 'at_sitter' : 'at_owner';
    const r = await publishLead(lead, lieu);
    if (r.status !== 200) return res.status(r.status).json(r.body);
    const { signAuthToken } = require('../controllers/authController');
    return res.status(200).json({
      token: signAuthToken({ id: r.owner._id.toString(), role: 'owner' }),
      user: { id: r.owner._id.toString(), name: r.owner.name, email: r.owner.email, role: 'owner' },
      postId: r.postId,
      ...(r.notified === undefined || r.notified === null ? {} : { notified: r.notified }),
    });
  } catch (e) {
    logger.error('[adLeads2210] confirm failed', e);
    return res.status(500).json({ error: 'Unable to confirm.' });
  }
});

// 23/10 (SAM, consigne de Daniel « dès qu'un contact remplit le formulaire, le suivi
// publie ») — même chemin que le clic, appelé par leads_suivi.py ; pas de session renvoyée.
adminRouter.post('/:id/publish', requireAdmin, async (req, res) => {
  try {
    if (!ID_RE.test(req.params.id)) return res.status(404).json({ error: 'not_found' });
    const lead = await AdLead.findById(req.params.id);
    if (!lead) return res.status(404).json({ error: 'not_found' });
    const already = !!lead.postId;
    const lieu = req.body && req.body.lieu === 'at_sitter' ? 'at_sitter' : 'at_owner';
    const r = await publishLead(lead, lieu);
    if (r.status !== 200) return res.status(r.status).json(r.body);
    return res.status(200).json({
      postId: r.postId, ownerId: r.owner._id.toString(), alreadyPublished: already, dates: r.dates || null,
      ...(r.notified === undefined || r.notified === null ? {} : { notified: r.notified }),
    });
  } catch (e) {
    logger.error('[adLeads2210] publish failed', e);
    return res.status(500).json({ error: 'Unable to publish.' });
  }
});

module.exports = router;
module.exports.adminRouter = adminRouter;
module.exports.postInputFor = postInputFor;
