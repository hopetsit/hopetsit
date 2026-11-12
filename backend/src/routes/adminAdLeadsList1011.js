/**
 * 10/11/2026 (BOB, ordre de Daniel « améliore le tableau de bord admin et les demandes pub ») — LECTURE SEULE.
 *
 *   GET /admin/ad-leads-1011/list?days=14&limit=200&source=all|meta|site
 *
 * Une ligne par demande venue de la pub (formulaire Meta) ou du formulaire du site, avec OÙ elle en est :
 *   recu → email_envoye → clique → publiee → candidats → candidats_vus → choisi → paye
 * et ce qu'elle a demandé (service, garde en journée, horaires, sans voiture, budget, code postal).
 * `blocked` = l'étape où elle attend, en mots simples, pour que l'admin sache quoi regarder.
 *
 * JAMAIS d'e-mail ni de téléphone dans la réponse : prénom, ville, identifiants (ownerId / postId)
 * pour ouvrir les fiches existantes de l'admin. Comptes de test et internes comptés à part.
 * Réutilise le calcul du tableau « Demandes publiées » (adminRequestJourney613._journeys) : mêmes chiffres.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];
const DAY = 86400000;
const STEPS = ['recu', 'email_envoye', 'clique', 'publiee', 'candidats', 'candidats_vus', 'choisi', 'paye'];
const BLOCKED = {
  recu: 'Formulaire reçu, e-mail pas encore parti',
  email_envoye: 'N\'a pas cliqué le lien de l\'e-mail',
  clique: 'A cliqué, demande pas encore publiée',
  publiee: 'En ligne, aucun gardien n\'a encore répondu',
  candidats: 'Des gardiens ont répondu, le propriétaire ne les a pas regardés',
  candidats_vus: 'A vu les gardiens, n\'a pas choisi',
  choisi: 'A choisi un gardien, n\'a pas payé',
  paye: '',
};
const isTestLead = (l) => /\+test|@example\.|@invalid\.example/i.test(String(l.email || ''))
  || (Number.isFinite(l.lat) && Number.isFinite(l.lng) && Math.abs(l.lat + 35) <= 1 && Math.abs(l.lng + 30) <= 1);

function stepOf(lead, j, views) {
  if (j) {
    const st = j.stages || {};
    if (st.payment && st.payment.state === 'paid') return 'paye';
    if (st.decision && st.decision.state === 'accepted') return 'choisi';
    if (st.applications && st.applications.count > 0) return views > 0 ? 'candidats_vus' : 'candidats';
    return 'publiee';
  }
  if (lead.postId) return 'publiee';
  if (lead.clickedAt) return 'clique';
  if (lead.confirmEmailAt || lead.siteEmailAt) return 'email_envoye';
  return 'recu';
}

router.get('/list', requireAdmin, async (req, res) => {
  try {
    const AdLead = require('../models/AdLead2210');
    const Post = require('../models/Post');
    const now = new Date();
    const days = Math.min(60, Math.max(1, parseInt(req.query.days, 10) || 14));
    const limit = Math.min(500, Math.max(1, parseInt(req.query.limit, 10) || 200));
    const source = ['meta', 'site'].includes(req.query.source) ? req.query.source : 'all';
    const q = { createdAt: { $gte: new Date(now.getTime() - days * DAY) } };
    if (source === 'meta') q.source = { $ne: 'site' };
    if (source === 'site') q.source = 'site';
    const leads = await AdLead.find(q).sort({ createdAt: -1 }).limit(limit).lean();

    const postIds = leads.map((l) => l.postId).filter(Boolean);
    let map = new Map();
    let signals = new Map();
    if (postIds.length) {
      const posts = await Post.find({ _id: { $in: postIds } }).lean();
      try { map = await require('./adminRequestJourney613')._journeys(posts, { now }); } catch (e) { logger.warn(`[adLeadsList1011] journeys ${e?.message || e}`); }
      try { signals = await require('../utils/ownerReturn2610').boardSignals([...map.values()]); } catch (e) { logger.warn(`[adLeadsList1011] signals ${e?.message || e}`); }
    }

    const counters = STEPS.reduce((o, s) => { o[s] = 0; return o; }, {});
    const extras = { journee: 0, horaires: 0, sansVoiture: 0, budget: 0, codePostal: 0 };
    let excludedTest = 0;
    const items = [];
    for (const l of leads) {
      if (isTestLead(l)) { excludedTest += 1; continue; }
      const j = l.postId ? map.get(String(l.postId)) : null;
      if (j && j.owner && j.owner.kind && j.owner.kind !== 'real') { excludedTest += 1; continue; }
      const sig = j ? signals.get(String(l.postId)) : null;
      const views = Number(sig && sig.candidatesView && sig.candidatesView.count) || 0;
      const step = stepOf(l, j, views);
      counters[step] += 1;
      const hasHours = !!(l.timeFrom || l.timeTo);
      const hasBudget = typeof l.budget === 'number' && l.budget > 0;
      if (l.service === 'journee') extras.journee += 1;
      if (hasHours) extras.horaires += 1;
      if (l.noCar) extras.sansVoiture += 1;
      if (hasBudget) extras.budget += 1;
      if (l.postalCode) extras.codePostal += 1;
      const st = (j && j.stages) || {};
      items.push({
        id: l._id,
        createdAt: l.createdAt,
        ageHours: l.createdAt ? Math.round((now.getTime() - new Date(l.createdAt).getTime()) / 3600000) : null,
        source: l.source === 'site' ? 'site' : 'meta',
        campaign: l.campaign || '',
        firstName: l.firstName || '',
        city: l.city || '',
        postalCode: l.postalCode || '',
        service: l.service || '',
        animal: l.animal || '',
        lieu: l.lieu || '',
        startText: l.startText || '',
        endText: l.endText || '',
        timeFrom: l.timeFrom || '',
        timeTo: l.timeTo || '',
        noCar: !!l.noCar,
        foodProvided: typeof l.foodProvided === 'boolean' ? l.foodProvided : null, // 639 — nourriture fournie (null = non précisé)
        breed: typeof l.breed === 'string' ? l.breed : '', // 639 — race facultative
        budget: hasBudget ? l.budget : null,
        ownerId: l.ownerId || null,
        postId: l.postId || null,
        step,
        stepIndex: STEPS.indexOf(step),
        blocked: BLOCKED[step],
        applications: (st.applications && st.applications.count) || 0,
        candidatesViews: views,
        payment: (st.payment && st.payment.state) || 'none',
        amount: (st.payment && st.payment.amount) || null,
        currency: (st.payment && st.payment.currency) || null,
      });
    }
    return res.json({ generatedAt: now, days, source, steps: STEPS, total: items.length, excludedTest, counters, extras, items });
  } catch (e) {
    logger.error('[adLeadsList1011] list failed', e);
    return res.status(500).json({ error: 'Unable to read.' });
  }
});

/**
 * 12/11/2026 (BOB, « Oui, construis-le » de Daniel) — ACCORDS SMS, pour l'envoi « un gardien a répondu ».
 * Le numéro gratuit américain est approuvé par Twilio depuis le 11/11. L'envoi se fait depuis le Mac
 * (~/hopetsit-social/sms/sms_accord_1211.py) : le serveur n'a pas les clés Twilio.
 *
 *   GET  /admin/ad-leads-1011/sms-consents           → contacts qui ont COCHÉ la case (smsConsentAt), qui n'ont
 *        pas dit STOP (smsOptOutAt vide) et dont la demande est publiée. SEULE route admin qui renvoie un
 *        numéro : il faut bien l'avoir pour écrire. Jamais d'e-mail. Comptes de test écartés.
 *   POST /admin/ad-leads-1011/sms-optout { id }      → note le STOP (Twilio refuse alors l'envoi, code 21610).
 * Aucun numéro dans les journaux.
 */
router.get('/sms-consents', requireAdmin, async (req, res) => {
  try {
    const AdLead = require('../models/AdLead2210');
    const leads = await AdLead.find({ smsConsentAt: { $ne: null }, smsPhone: { $regex: /^\+\d{8,15}$/ }, postId: { $ne: null } })
      .sort({ smsConsentAt: -1 }).limit(500).lean();
    const items = leads.filter((l) => !l.smsOptOutAt && !isTestLead(l)).map((l) => ({
      id: l._id,
      phone: l.smsPhone,
      consentAt: l.smsConsentAt,
      lang: l.lang === 'en' ? 'en' : 'fr',
      country: String(l.country || '').toUpperCase(),
      firstName: l.firstName || '',
      animal: l.animal || '',
      postId: l.postId,
    }));
    return res.json({ generatedAt: new Date(), total: items.length, items });
  } catch (e) {
    logger.error('[adLeadsList1011] sms-consents failed', e && e.message);
    return res.status(500).json({ error: 'Unable to read.' });
  }
});

router.post('/sms-optout', requireAdmin, async (req, res) => {
  try {
    const AdLead = require('../models/AdLead2210');
    const id = typeof (req.body || {}).id === 'string' ? req.body.id : '';
    if (!/^[a-f0-9]{32}$/.test(id)) return res.status(404).json({ error: 'not_found' });
    const lead = await AdLead.findById(id);
    if (!lead || !lead.smsConsentAt) return res.status(404).json({ error: 'not_found' });
    if (!lead.smsOptOutAt) { lead.smsOptOutAt = new Date(); await lead.save(); }
    logger.info({ leadId: String(lead._id) }, '[adLeadsList1011] STOP SMS noté');
    return res.json({ ok: true });
  } catch (e) {
    logger.error('[adLeadsList1011] sms-optout failed', e && e.message);
    return res.status(500).json({ error: 'Unable to save.' });
  }
});

module.exports = router;
module.exports._stepOf = stepOf;
module.exports.STEPS = STEPS;
