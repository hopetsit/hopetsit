/**
 * 05/11/2026 (SAM, décision de Daniel du 05/11 relayée par BOB — plan PLAN_PUB_0511.md, bloc A2) —
 * PAGE DE REMERCIEMENT META → DEMANDE PUBLIÉE SANS PASSER PAR LA BOÎTE MAIL.
 *
 * Mesure du 05/11 : 24 contacts pub depuis le 02/11 → 24 e-mails « confirme » → 2 demandes publiées ;
 * 22 n'ont jamais ouvert l'e-mail. Décision de Daniel : l'e-mail d'un formulaire Meta est celui du compte
 * Facebook, déjà vérifié par Meta ; POUR CE CAS PRÉCIS, le clic sur le bouton de la page de remerciement
 * (« Publier ma demande maintenant » → /posts/merci) vaut confirmation. La règle « e-mail vérifié »
 * du 31/10 reste entière pour tout le reste (site, compte existant, e-mail, SMS).
 *
 *   POST /ad-leads/thanks/confirm { email, city? }
 *     → contact pub (source ≠ site) à cette adresse (insensible à la casse), créé depuis moins de 24 h :
 *         · pas encore publié → publishLead (compte propriétaire + demande par createPost + gardiens prévenus,
 *           exactement comme le clic de l'e-mail dans adLeads2210 /:id/confirm) + e-mail marqué vérifié
 *           (3 profils) + session ; `page` = '/posts/merci' pour mesurer ce chemin à part ; clickedAt daté.
 *         · déjà publié (2e appui sur le bouton) → la même demande, même session, rien de republié.
 *       → 200 { leadId, postId, token, user, notified? }
 *     → aucun contact encore (le relevé des contacts Meta, ads/leads_suivi.py, tourne toutes les 5 min)
 *       → 202 { pending: true } : la page dit « ta demande arrive, on te l'envoie par e-mail » et réessaie.
 *       Le serveur ne peut PAS interroger le formulaire Meta lui-même (aucun jeton Meta côté serveur).
 *
 * Garde-fous : 5 essais / 10 min par IP (en plus du sensitiveLimiter du montage), jamais pour une adresse
 * de test (TEST_LEAD_RE → 403), origine réelle seulement (navigateur ou app ; scripts → 403, comme
 * classifyOrigin dans ownerReturn2610), jamais un brouillon venu du SITE (source 'site' : la sécurité du
 * 31/10 — un inconnu qui connaît l'adresse — reste valable, ces brouillons ne se publient qu'au clic e-mail).
 *
 * Montage : app.js, AVANT `/ad-leads` (sinon « thanks » serait pris pour un :id par adLeads2210 → 404).
 * Rien de adLeads2210.js n'est modifié : ses exports sont réutilisés.
 */
const express = require('express');
const logger = require('../utils/logger');
const AdLead = require('../models/AdLead2210');
const Owner = require('../models/Owner');
const { publishLead, TEST_LEAD_RE } = require('./adLeads2210');
const { classifyOrigin, isRealOrigin } = require('../utils/ownerReturn2610');

const router = express.Router();
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const WINDOW_LEAD_MS = 24 * 3600 * 1000;
const PAGE_MARK = '/posts/merci';

// 5 essais / 10 min par IP : une page qui réessaie toute seule (0 s, 60 s, 150 s, 300 s) en consomme 4.
const PER_IP_MAX = 5;
const PER_IP_WINDOW_MS = 10 * 60 * 1000;
const hits = new Map(); // ip → [timestamps]
function ipAllowed(ip, now = Date.now()) {
  const key = String(ip || 'unknown');
  const list = (hits.get(key) || []).filter((t) => now - t < PER_IP_WINDOW_MS);
  if (list.length >= PER_IP_MAX) { hits.set(key, list); return false; }
  list.push(now);
  hits.set(key, list);
  if (hits.size > 5000) for (const k of hits.keys()) { if (hits.size <= 4000) break; hits.delete(k); }
  return true;
}

/** Contact pub le plus récent (< 24 h) pour cette boîte, hors brouillons du site. */
function findRecentMetaLead(email, now = Date.now()) {
  return AdLead.findOne({
    email, // le schéma stocke l'e-mail en minuscules ; la route normalise aussi
    source: { $ne: 'site' },
    createdAt: { $gte: new Date(now - WINDOW_LEAD_MS) },
  }).sort({ createdAt: -1 });
}

function sessionFor(owner) {
  const { signAuthToken } = require('../controllers/authController');
  return {
    token: signAuthToken({ id: owner._id.toString(), role: 'owner' }),
    user: { id: owner._id.toString(), name: owner.name, email: owner.email, role: 'owner' },
  };
}

router.post('/confirm', async (req, res) => {
  try {
    const b = req.body || {};
    const email = String(b.email || '').trim().toLowerCase();
    if (!EMAIL_RE.test(email) || email.length > 120) return res.status(400).json({ error: 'EMAIL_INVALID', code: 'EMAIL_INVALID' });
    if (TEST_LEAD_RE.test(email)) return res.status(403).json({ error: 'TEST_ACCOUNT', code: 'TEST_ACCOUNT' });
    const origin = classifyOrigin(req);
    if (!isRealOrigin(origin)) return res.status(403).json({ error: 'SCRIPT', code: 'SCRIPT' });
    if (!ipAllowed(req.ip)) return res.status(429).json({ error: 'TOO_MANY', code: 'TOO_MANY' });
    const city = String(b.city || '').trim().slice(0, 40); // information seulement (journal), jamais un critère

    const lead = await findRecentMetaLead(email);
    if (!lead) {
      logger.info(`[adLeadsThanks0511] aucun contact pub (< 24 h) pour cette boîte (${city || '?'}) → 202 pending`);
      return res.status(202).json({ pending: true });
    }

    // Déjà publié (2e appui, ou le clic e-mail est passé avant) : la même demande, la même session.
    if (lead.postId && lead.ownerId) {
      const owner = await Owner.findById(lead.ownerId);
      if (owner) {
        return res.status(200).json({ leadId: String(lead._id), postId: String(lead.postId), existing: true, ...sessionFor(owner) });
      }
    }

    const r = await publishLead(lead, 'at_owner');
    if (r.status !== 200) return res.status(r.status).json(r.body);

    // Décision de Daniel (05/11) : pour un contact Meta, l'appui sur ce bouton vaut confirmation de la boîte.
    const { markVerifiedAcrossRoles } = require('../controllers/authController');
    await markVerifiedAcrossRoles(lead.email, `thanks_${origin}`);
    const set = { page: PAGE_MARK };
    if (!lead.clickedAt) set.clickedAt = new Date();
    await AdLead.updateOne({ _id: lead._id }, { $set: set });

    return res.status(200).json({
      leadId: String(lead._id),
      postId: r.postId,
      existing: false,
      ...sessionFor(r.owner),
      ...(r.notified === undefined || r.notified === null ? {} : { notified: r.notified }),
    });
  } catch (e) {
    logger.error('[adLeadsThanks0511] confirm failed', e);
    return res.status(500).json({ error: 'Unable to publish.' });
  }
});

module.exports = router;
module.exports._resetForTest = () => { hits.clear(); };
module.exports.PAGE_MARK = PAGE_MARK;
