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
  // 31/10 (LEO) — contact du site « Réserver <prénom> » : prestataire ciblé, validé par createPost.
  if (lead.targetRole && /^[a-f0-9]{24}$/i.test(String(lead.targetId || ''))) input.targetProvider = { role: lead.targetRole, id: String(lead.targetId) };
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
// GET /admin/ad-leads/stats?days=7&tz=Europe/Paris → { today, yesterday, d7, byCity: { paris, nyc, other } (agglomérations),
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
// « Paris » = la commune ET l'agglomération (règle de l'équipe) : un contact à Clamart, Saint-Denis ou
// Levallois compte pour Paris → position du contact (lat/lng) à ≤ 40 km du centre (48.8566, 2.3522) ;
// New York : ≤ 50 km de (40.7128, −74.006) (Yonkers compris). Sans position : le nom de la ville.
const kmBetween = (a, b) => {
  const R = 6371; const r = Math.PI / 180;
  const dLat = (b.lat - a.lat) * r; const dLng = (b.lng - a.lng) * r;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
};
const HUBS = [['paris', { lat: 48.8566, lng: 2.3522 }, 40, PARIS_RE], ['nyc', { lat: 40.7128, lng: -74.006 }, 50, NYC_RE]];
const cityBucket = (l) => {
  const pos = Number.isFinite(l.lat) && Number.isFinite(l.lng) && !(l.lat === 0 && l.lng === 0) ? { lat: l.lat, lng: l.lng } : null;
  for (const [key, center, km, re] of HUBS) {
    if (re.test(String(l.city || ''))) return key;
    if (pos && kmBetween(pos, center) <= km) return key;
  }
  return 'other';
};
adminRouter.get('/stats', requireAdmin, async (req, res) => {
  try {
    const DAY = 86400000;
    const now = new Date();
    const days = Math.min(90, Math.max(1, parseInt(req.query.days, 10) || 7));
    const tz = String(req.query.tz || 'Europe/Paris').slice(0, 40);
    const t0 = dayStartIn2410(tz, now);
    const since = new Date(now.getTime() - days * DAY);
    const from = new Date(Math.min(since.getTime(), t0.getTime() - DAY));
    // 31/10 (LEO) — les contacts venus du site (source 'site') ne comptent pas dans la pub : comptés à part.
    const rows = await AdLead.find({ createdAt: { $gte: from }, source: { $ne: 'site' } }).select('createdAt city country lat lng postId startText endText confirmedAt pendingConfirm clickedAt confirmEmailAt confirmReminderAt').lean();
    const { datesFor } = require('../utils/adLeadDates2310');
    // 3110 (ADA, ordre de Daniel) — awaitingConfirm = brouillons (e-mail « confirme » parti, pas encore cliqué) ;
    // confirmedClick = contacts qui ont VRAIMENT cliqué (clickedAt) ; reminded = rappels (+3 h depuis le 03/11, +24 h avant) envoyés.
    const out = { days, timeZone: tz, generatedAt: now, today: 0, yesterday: 0, d7: 0, byCity: { paris: 0, nyc: 0, other: 0 }, published: 0, withDates: 0, confirmed: 0, awaitingConfirm: 0, confirmedClick: 0, reminded: 0, total: 0 };
    for (const l of rows) {
      const t = l.createdAt ? new Date(l.createdAt).getTime() : 0;
      if (t >= t0.getTime()) out.today += 1;
      else if (t >= t0.getTime() - DAY) out.yesterday += 1;
      if (t < since.getTime()) continue;
      out.d7 += 1;
      out.byCity[cityBucket(l)] += 1;
      if (l.postId) out.published += 1;
      if (l.confirmedAt) out.confirmed += 1;
      if (l.pendingConfirm && !l.postId) out.awaitingConfirm += 1;
      if (l.clickedAt) out.confirmedClick += 1;
      if (l.confirmReminderAt) out.reminded += 1;
      let dd = null;
      try { dd = datesFor(l, now); } catch (_) { dd = null; }
      if (dd && dd.source === 'form') out.withDates += 1;
    }
    out.total = await AdLead.countDocuments({ source: { $ne: 'site' } });
    out.awaitingConfirmTotal = await AdLead.countDocuments({ source: { $ne: 'site' }, pendingConfirm: true, postId: null });
    out.site = await AdLead.countDocuments({ source: 'site', createdAt: { $gte: since } });
    return res.json(out);
  } catch (e) {
    logger.error('[adLeads2210] stats failed', e);
    return res.status(500).json({ error: 'Unable to read stats.' });
  }
});

// ── public : résumé + confirmation ───────────────────────────────────────────
const router = express.Router();
const ID_RE = /^[a-f0-9]{32}$/;
// 31/10 (LEO, feu vert BOB) — POST /ad-leads/site : demande publiée en 1 étape depuis la page d'arrivée.
router.use(require('./adLeadsSite3110'));

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
/** 3110 — compte propriétaire du contact : existant (marqué pub) ou créé NON vérifié. Aucune demande. */
async function ensureLeadOwner(lead) {
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
      // 27/10/2026 (SAM, décision de Daniel) — NON vérifié tant que la personne n'a pas
      // cliqué un lien de nos e-mails (ou validé un code) : l'adresse tapée dans le formulaire
      // Meta n'est prouvée par rien (ex. « hhhh@frrr.fr »). Voir /:id/confirm et adLeadAt.
      verified: false,
      adLeadAt: new Date(),
    });
  } else if (!owner.adLeadAt) {
    // Compte déjà existant : on ne touche PAS à son état de vérification, on le marque seulement.
    await Owner.updateOne({ _id: owner._id }, { $set: { adLeadAt: new Date() } });
  }
  return owner;
}

const TEST_LEAD_RE = /\+test|^hopetsit@|^dadaciao84@|^probe-|@invalid\.example$|staff@hopetsit/i;
const escHtml = (x) => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/**
 * 0511 (BOB) — HTML de l'e-mail « confirme » à partir de son texte brut : chaque paragraphe est rendu
 * (plus seulement les 2 premiers), le paragraphe qui porte le lien devient le gros bouton, une suite de
 * lignes « 1. … » devient une liste numérotée. Valeurs échappées.
 */
function confirmEmailHtml({ text, link, cta }) {
  const blocks = String(text || '').split('\n\n').map((b) => b.trim()).filter(Boolean);
  const body = blocks.map((b, i) => {
    if (b.includes(link)) {
      return `<p style="text-align:center;margin:24px 0"><a href="${link}" style="display:inline-block;background:#C92A12;color:#fff;text-decoration:none;font-weight:800;font-size:17px;padding:16px 30px;border-radius:999px">${escHtml(cta)}</a></p>`;
    }
    const lines = b.split('\n');
    const items = lines.filter((l) => /^\d+\.\s/.test(l));
    if (items.length >= 2) {
      const head = lines.filter((l) => !/^\d+\.\s/.test(l)).join(' ');
      return `${head ? `<p style="margin:16px 0 6px;font-weight:700">${escHtml(head)}</p>` : ''}<ol style="margin:0 0 16px;padding-left:22px">${items.map((l) => `<li style="margin:4px 0">${escHtml(l.replace(/^\d+\.\s/, ''))}</li>`).join('')}</ol>`;
    }
    const last = i === blocks.length - 1;
    return `<p style="margin:0 0 14px${last ? ';color:#6E4F48' : ''}">${escHtml(b)}</p>`;
  }).join('');
  return `<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:560px;margin:0 auto;color:#231715;font-size:16px;line-height:1.55">${body}</div>`;
}

/**
 * 3110 (ADA, ordre de Daniel 31/10) — e-mail « confirme ta demande pour la publier » (lien /posts/confirmer?l=…,
 * dont le clic vérifie l'e-mail ET publie). variant : 'new' (contact neuf : pub Meta ou site), 'existing'
 * (compte déjà inscrit, texte de LEO), 'reminder' (UN rappel à +3 h depuis le 03/11). Jamais aux adresses de test.
 * Retourne true si l'e-mail est parti.
 */
async function sendConfirmEmail(lead, variant = 'new') {
  if (TEST_LEAD_RE.test(String(lead.email || ''))) return false;
  const { BASE_URL } = require('../utils/emailLinkBuilder');
  const { sendEmail } = require('../services/emailService');
  const src = lead.source === 'site' ? 'site' : 'meta';
  const campaign = lead.campaign || (lead.country === 'US' ? 'nyc_leads' : 'paris_leads');
  const content = variant === 'reminder' ? 'rappel' : 'confirme';
  const link = `${BASE_URL}/posts/confirmer?l=${lead._id}&utm_source=${src}&utm_medium=${src === 'meta' ? 'paid' : 'email'}&utm_campaign=${encodeURIComponent(campaign)}&utm_content=${content}`;
  const p = lead.firstName || '';
  const fr = lead.lang !== 'en';
  // 0511 (BOB, ordre de Daniel « fais tout ce qui est possible ») — textes réécrits en langage simple
  // après le cas de Jeanne V. (05/11 : « je ne comprends pas, je ne sais pas faire ») : un seul geste,
  // rien à payer / rien à installer, les 4 étapes de ce qui se passe après, « réponds-moi si tu bloques ».
  // Objets inchangés (tests). Le texte = paragraphes séparés par une ligne vide ; une ligne « 1. … »
  // devient une liste numérotée ; la ligne qui porte le lien devient le bouton.
  const hello = fr ? (p ? `Bonjour ${p},` : 'Bonjour,') : (p ? `Hi ${p},` : 'Hi,');
  const steps = fr
    ? `Ensuite, tout se fait tout seul :\n1. Ta demande est publiée.\n2. Les gardiens proches de chez toi sont prévenus.\n3. Ceux qui sont intéressés te proposent leur prix, et tu les reçois par e-mail.\n4. Tu choisis celui ou celle qui te plaît. Rien n'est payé avant que tu aies choisi.`
    : `Then everything happens by itself:\n1. Your request is published.\n2. Sitters near you are notified.\n3. The ones who are interested send you their price, and you get them by email.\n4. You pick the one you like. Nothing is paid before you choose.`;
  const free = fr ? 'Rien à installer, rien à payer pour publier ta demande.' : 'Nothing to install, nothing to pay to publish your request.';
  const help = fr
    ? 'Si le bouton ne fait rien ou si quelque chose te bloque, réponds simplement à cet e-mail en me disant ce que tu vois à l\'écran : je t\'aide pas à pas.'
    : 'If the button does nothing or something blocks you, just reply to this email and tell me what you see on your screen: I\'ll help you step by step.';
  const sign = fr ? 'L\'équipe HoPetSit' : 'The HoPetSit team';
  let subject; let text; let cta;
  if (variant === 'existing') {
    subject = fr ? `${p ? `${p}, confirme` : 'Confirme'} ta demande pour la publier` : `${p ? `${p}, confirm` : 'Confirm'} your request to publish it`;
    cta = fr ? 'Publier ma demande' : 'Publish my request';
    text = fr
      ? `${hello}\n\nQuelqu'un vient de préparer une demande de garde avec ton adresse e-mail sur hopetsit.com. Si c'est toi, il n'y a qu'un seul geste à faire : appuyer sur le bouton ci-dessous.\n\n${cta} : ${link}\n\n${steps}\n\n${free}\n\nSi ce n'est pas toi, ignore cet e-mail : rien ne sera publié.\n\n${sign}`
      : `${hello}\n\nSomeone just prepared a pet-sitting request with your email address on hopetsit.com. If it was you, there is only one thing to do: press the button below.\n\n${cta}: ${link}\n\n${steps}\n\n${free}\n\nIf it wasn't you, ignore this email: nothing will be published.\n\n${sign}`;
  } else if (variant === 'reminder') {
    subject = fr ? `${p ? `${p}, ta` : 'Ta'} demande attend ta confirmation` : `${p ? `${p}, your` : 'Your'} request is waiting for your confirmation`;
    cta = fr ? 'Confirmer et publier' : 'Confirm and publish';
    text = fr
      ? `${hello}\n\nTa demande de garde est bien enregistrée, mais les gardiens ne la voient pas encore. Pour qu'ils la voient, il nous faut juste une chose : que tu nous confirmes que cette adresse e-mail est bien la tienne.\n\nPour ça, il n'y a qu'un seul geste à faire : appuyer sur le bouton ci-dessous.\n\n${cta} : ${link}\n\n${steps}\n\n${free}\n\n${help}\n\nSi tu n'as plus besoin de garde, ignore simplement cet e-mail : c'est le dernier rappel.\n\n${sign}`
      : `${hello}\n\nYour pet-sitting request is saved, but sitters can't see it yet. For them to see it, we just need one thing: that you confirm this email address is yours.\n\nFor that, there is only one thing to do: press the button below.\n\n${cta}: ${link}\n\n${steps}\n\n${free}\n\n${help}\n\nIf you no longer need a sitter, just ignore this email: this is the last reminder.\n\n${sign}`;
  } else {
    subject = fr ? `${p ? `${p}, un` : 'Un'} clic pour publier ta demande` : `${p ? `${p}, one` : 'One'} click to publish your request`;
    cta = fr ? 'Confirmer et publier' : 'Confirm and publish';
    text = fr
      ? `${hello}\n\nMerci pour ta demande sur HoPetSit ! Elle est bien enregistrée. Pour que les gardiens la voient, il nous faut juste une chose : que tu nous confirmes que cette adresse e-mail est bien la tienne.\n\nPour ça, il n'y a qu'un seul geste à faire : appuyer sur le bouton ci-dessous.\n\n${cta} : ${link}\n\n${steps}\n\n${free} Et si tu réserves : tu paies par carte sur une page simple, l'argent est gardé par HoPetSit et n'est versé au gardien qu'après la garde, annulation gratuite jusqu'à 72 h avant.\n\n${help}\n\n${sign}`
      : `${hello}\n\nThanks for your request on HoPetSit! It is saved. For sitters to see it, we just need one thing: that you confirm this email address is yours.\n\nFor that, there is only one thing to do: press the button below.\n\n${cta}: ${link}\n\n${steps}\n\n${free} And if you book: you pay by card on one simple page, HoPetSit holds the money and only pays the sitter after the stay, free cancellation up to 72 h before.\n\n${help}\n\n${sign}`;
  }
  const html = confirmEmailHtml({ text, link, cta });
  await sendEmail(lead.email, subject, text, html);
  if (variant === 'reminder') lead.confirmReminderAt = new Date();
  else lead.confirmEmailAt = new Date();
  await lead.save();
  return true;
}

/**
 * 3110 (ADA, ordre de Daniel 31/10 : « qu'il y ait au moins l'e-mail vérifié ») — BROUILLON : compte propriétaire
 * NON vérifié (créé si besoin), contact `pendingConfirm`, AUCUNE demande, AUCUN gardien prévenu, e-mail « confirme »
 * UNE fois. La publication n'a lieu qu'au clic (/:id/confirm). Idempotent.
 */
async function draftLead(lead, { variant = 'new' } = {}) {
  if (lead.postId) return { alreadyPublished: true, postId: String(lead.postId), ownerId: lead.ownerId ? String(lead.ownerId) : null, pending: false, emailSent: false };
  const owner = await ensureLeadOwner(lead);
  lead.ownerId = owner._id;
  lead.pendingConfirm = true;
  await lead.save();
  let emailSent = false;
  if (!lead.confirmEmailAt) {
    try { emailSent = await sendConfirmEmail(lead, variant); } catch (e) { logger.warn(`[adLeads2210] e-mail « confirme » non envoyé : ${e && e.message}`); }
  }
  return { alreadyPublished: false, postId: null, ownerId: String(owner._id), pending: true, emailSent, verified: owner.verified === true };
}

/**
 * Publie la demande d'un contact (compte propriétaire créé ou repris, demande par createPost = mêmes règles
 * et mêmes alertes aux gardiens). Renvoie { owner, postId, notified, status, body } ; status ≠ 200 = createPost a refusé.
 */
async function publishLead(lead, lieu) {
  // 1. Compte propriétaire : existant (marqué pub) ou créé NON vérifié (3110 : ensureLeadOwner).
  const owner = await ensureLeadOwner(lead);

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
    lead.pendingConfirm = false; // 3110 — le brouillon est publié
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
    const hadPost0611 = !!lead.postId;
    const r = await publishLead(lead, lieu);
    if (r.status !== 200) return res.status(r.status).json(r.body);
    // 0611 (SAM) — Meta Conversions API : « Lead » quand la demande vient d'être publiée (jamais au 2e clic). Jamais bloquant.
    if (!hadPost0611 && r.postId) { try { void require('../services/metaCapi0611').leadPublished(lead, req); } catch (_) { /* jamais bloquant */ } }
    // 27/10 (SAM, décision de Daniel) — le lien n'existe QUE dans nos e-mails : un clic venu d'un
    // vrai navigateur ou de l'app PROUVE la boîte → compte vérifié (3 profils) + emailProvenAt.
    // Nos scripts (X-HPS-Script, Python, navigateur sans tête) ne prouvent rien.
    const { classifyOrigin, isRealOrigin } = require('../utils/ownerReturn2610');
    const origin = classifyOrigin(req);
    if (isRealOrigin(origin)) {
      const { markVerifiedAcrossRoles } = require('../controllers/authController');
      await markVerifiedAcrossRoles(lead.email, `lead_${origin}`);
      if (!lead.clickedAt) await AdLead.updateOne({ _id: lead._id, clickedAt: null }, { $set: { clickedAt: new Date() } });
    }
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

// ── admin : preuve de l'e-mail des comptes pub (27/10, SAM — décision de Daniel) ──────────
// Une ligne par contact, SANS e-mail ni téléphone : état du compte, vrai clic, vraies sessions,
// candidats vus, e-mails « candidats reçus » partis (registre 2610), demande « dates à prévoir ».
// `decision` = ce que POST /unverify2710 ferait : 'keep_proven' (preuve réelle), 'keep_preexisting'
// (compte qui existait avant la pub : on n'y touche pas), 'unverify' (aucune preuve).
async function proofRows() {
  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');
  const ActivityEvent = require('../models/ActivityEvent');
  const CandidatesView = require('../models/CandidatesView2610');
  const Registry = require('../models/ApplicationEmail2610');
  const Application = require('../models/Application');
  const Post = require('../models/Post');
  const { REAL_SESSION_FILTER } = require('../utils/ownerReturn2610');
  const leads = await AdLead.find({ ownerId: { $ne: null } }).select('_id email city lat lng ownerId postId createdAt confirmedAt clickedAt').lean();
  const rows = [];
  for (const l of leads) {
    // eslint-disable-next-line no-await-in-loop
    const owner = await Owner.findById(l.ownerId).select('verified emailProvenAt emailProofSource adLeadAt createdAt email isStaff').lean();
    if (!owner) { rows.push({ key: String(l._id).slice(0, 6), bucket: cityBucket(l), owner: false, decision: 'no_owner' }); continue; }
    const em = String(owner.email || l.email || '').toLowerCase();
    // eslint-disable-next-line no-await-in-loop
    const [sibS, sibW] = await Promise.all([Sitter, Walker].map((M) => M.find({ email: em }).select('_id verified').lean()));
    const groupIds = [String(owner._id), ...sibS.map((d) => String(d._id)), ...sibW.map((d) => String(d._id))];
    // eslint-disable-next-line no-await-in-loop
    const [firstReal, views, reg, apps, post] = await Promise.all([
      ActivityEvent.findOne({ userId: { $in: groupIds }, ...REAL_SESSION_FILTER }).sort({ at: 1 }).select('at origin appVersion').lean(),
      CandidatesView.countDocuments({ ownerId: owner._id, origin: { $in: ['app', 'web'] } }),
      l.postId ? Registry.findOne({ postId: l.postId }).select('emails lastResult sentIds queuedIds').lean() : null,
      l.postId ? Application.countDocuments({ postId: l.postId }) : 0,
      l.postId ? Post.findById(l.postId).select('dateMode status hidden').lean() : null,
    ]);
    const preexisting = owner.createdAt && l.createdAt && new Date(owner.createdAt).getTime() < new Date(l.createdAt).getTime() - 5 * 60000;
    const siblingVerified = [...sibS, ...sibW].some((d) => d.verified === true);
    const proven = !!owner.emailProvenAt || !!l.clickedAt || !!firstReal || views > 0;
    let decision = 'unverify';
    if (owner.isStaff || /\+test|hopetsit@|dadaciao84@/i.test(em)) decision = 'skip_internal';
    else if (preexisting) decision = 'keep_preexisting';
    else if (proven || siblingVerified) decision = 'keep_proven';
    rows.push({
      key: String(l._id).slice(0, 6),
      ownerId: String(owner._id),
      bucket: cityBucket(l),
      leadAt: l.createdAt,
      verified: owner.verified === true,
      emailProvenAt: owner.emailProvenAt || null,
      proofSource: owner.emailProofSource || '',
      clickedAt: l.clickedAt || null,
      firstRealSession: firstReal ? { at: firstReal.at, origin: firstReal.origin || (firstReal.appVersion === 'web' ? 'web' : 'app') } : null,
      candidatesViews: views,
      siblingVerified,
      preexisting: !!preexisting,
      applications: apps,
      dateMode: post ? (post.dateMode || 'exact') : null,
      postStatus: post ? post.status : null,
      candidateEmails: reg ? { emails: reg.emails || 0, lastResult: reg.lastResult || '', announced: (reg.sentIds || []).length, queued: (reg.queuedIds || []).length } : null,
      decision,
    });
  }
  return rows;
}

adminRouter.get('/proof2710', requireAdmin, async (req, res) => {
  try {
    const rows = await proofRows();
    const count = (f) => rows.filter(f).length;
    const results = {};
    rows.forEach((r) => { const k = r.candidateEmails ? (r.candidateEmails.lastResult || 'none') : 'no_registry'; results[k] = (results[k] || 0) + 1; });
    return res.json({
      generatedAt: new Date(),
      summary: {
        leadsWithOwner: rows.length,
        verified: count((r) => r.verified),
        emailProven: count((r) => !!r.emailProvenAt),
        realClick: count((r) => !!r.clickedAt),
        realSession: count((r) => !!r.firstRealSession),
        viewedCandidates: count((r) => r.candidatesViews > 0),
        preexisting: count((r) => r.preexisting),
        withApplications: count((r) => r.applications > 0),
        tbd: count((r) => r.dateMode === 'tbd'),
        candidateEmailResults: results,
        decisions: rows.reduce((o, r) => { o[r.decision] = (o[r.decision] || 0) + 1; return o; }, {}),
      },
      rows,
    });
  } catch (e) {
    logger.error('[adLeads2210] proof2710 failed', e);
    return res.status(500).json({ error: 'Unable to read.' });
  }
});

// POST /admin/ad-leads/unverify2710 { dryRun: true|false } — repasse en NON vérifié les comptes
// propriétaires CRÉÉS par la pub qui n'ont jamais apporté de preuve réelle ; date la preuve
// (emailProvenAt = 1re vraie session) de ceux qui en ont une ; marque adLeadAt partout.
// Ne touche JAMAIS à un compte qui existait avant la pub, ni aux profils gardien / promeneur.
adminRouter.post('/unverify2710', requireAdmin, async (req, res) => {
  try {
    const dryRun = !(req.body && req.body.dryRun === false);
    const rows = await proofRows();
    const out = { dryRun, unverified: 0, provenDated: 0, marked: 0, kept: 0 };
    for (const r of rows) {
      if (!r.ownerId) continue;
      if (dryRun) { if (r.decision === 'unverify') out.unverified += 1; else out.kept += 1; continue; }
      // eslint-disable-next-line no-await-in-loop
      const m = await Owner.updateOne({ _id: r.ownerId, adLeadAt: null }, { $set: { adLeadAt: r.leadAt || new Date() } });
      out.marked += m.modifiedCount || 0;
      if (r.decision === 'unverify') {
        // eslint-disable-next-line no-await-in-loop
        const u = await Owner.updateOne({ _id: r.ownerId, emailProvenAt: null }, { $set: { verified: false } });
        out.unverified += u.modifiedCount || 0;
      } else {
        out.kept += 1;
        if (r.decision === 'keep_proven' && !r.emailProvenAt) {
          const at = r.clickedAt || (r.firstRealSession && r.firstRealSession.at) || null;
          const src = r.clickedAt ? 'lead_click' : r.firstRealSession ? `session_${r.firstRealSession.origin}` : r.candidatesViews ? 'candidates_view' : 'sibling';
          // eslint-disable-next-line no-await-in-loop
          const d = await Owner.updateOne({ _id: r.ownerId, emailProvenAt: null }, { $set: { emailProvenAt: at || new Date(), emailProofSource: src } });
          out.provenDated += d.modifiedCount || 0;
        }
      }
    }
    logger.info(`[adLeads2210] unverify2710 ${JSON.stringify(out)}`);
    return res.json({ ...out, decisions: rows.reduce((o, r) => { o[r.decision] = (o[r.decision] || 0) + 1; return o; }, {}) });
  } catch (e) {
    logger.error('[adLeads2210] unverify2710 failed', e);
    return res.status(500).json({ error: 'Unable to run.' });
  }
});

// 27/10 (SAM) — nettoyage après un essai : supprime UNIQUEMENT un contact de TEST (+test).
adminRouter.delete('/:id', requireAdmin, async (req, res) => {
  try {
    if (!ID_RE.test(req.params.id)) return res.status(404).json({ error: 'not_found' });
    const lead = await AdLead.findById(req.params.id).select('email').lean();
    if (!lead) return res.status(404).json({ error: 'not_found' });
    if (!/\+test/i.test(String(lead.email || ''))) return res.status(403).json({ error: 'test_leads_only' });
    await AdLead.deleteOne({ _id: req.params.id });
    return res.json({ deleted: true });
  } catch (e) {
    logger.error('[adLeads2210] delete failed', e);
    return res.status(500).json({ error: 'Unable to delete.' });
  }
});

// 3110 (ADA, ORDRE DE DANIEL 31/10 : « que dans la pub les demandes ne soient plus orphelines : au moins
// l'e-mail vérifié ») — POST /admin/ad-leads/:id/draft : appelé par leads_suivi.py à la place de /publish.
// Compte NON vérifié + brouillon + e-mail « confirme » ; rien publié, 0 gardien prévenu ; +test refusé (403).
adminRouter.post('/:id/draft', requireAdmin, async (req, res) => {
  try {
    if (!ID_RE.test(req.params.id)) return res.status(404).json({ error: 'not_found' });
    const lead = await AdLead.findById(req.params.id);
    if (!lead) return res.status(404).json({ error: 'not_found' });
    if (TEST_LEAD_RE.test(String(lead.email || ''))) return res.status(403).json({ error: 'TEST_ACCOUNT', code: 'TEST_ACCOUNT' });
    const r = await draftLead(lead, { variant: 'new' });
    return res.status(200).json({ id: lead._id, ...r });
  } catch (e) {
    logger.error('[adLeads2210] draft failed', e);
    return res.status(500).json({ error: 'Unable to draft.' });
  }
});

// 23/10 (SAM, consigne de Daniel « dès qu'un contact remplit le formulaire, le suivi
// publie ») — même chemin que le clic, appelé par leads_suivi.py ; pas de session renvoyée.
// ⚠️ 3110 : le suivi appelle désormais /draft (ordre de Daniel) ; /publish reste pour l'admin.
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
module.exports.publishLead = publishLead; // 31/10 (LEO) — réutilisé par adLeadsSite3110
module.exports.draftLead = draftLead; // 3110 (ADA) — brouillon + e-mail « confirme » (site, suivi, rappel)
module.exports.sendConfirmEmail = sendConfirmEmail;
module.exports.ensureLeadOwner = ensureLeadOwner;
module.exports.TEST_LEAD_RE = TEST_LEAD_RE;
