/**
 * 31/10/2026 (LEO, feu vert BOB 14 h 20 — territoire BOB délégué) — DEMANDE PUBLIÉE EN 1 ÉTAPE
 * DEPUIS LE SITE, sans compte ni mot de passe : POST /ad-leads/site.
 *
 * Même parcours que la pub à formulaire (adLeads2210 : contact → compte propriétaire NON vérifié
 * → demande publiée par createPost → gardiens prévenus), mais le contact vient de la page d'arrivée
 * (Paris FR / New York EN) : `source: 'site'` + `campaign` pour que le suivi de la pub (leads_suivi.py,
 * stats admin) ne le compte jamais dans la dépense pub.
 *
 * Entrée : { email, firstName, service: garde|promenade|visites, animal: chien|chat|autre,
 *            postalCode, city?, country: FR|US|…, lang: fr|en, startDate, endDate (AAAA-MM-JJ, OBLIGATOIRES
 *            depuis le 06/11 — NEO, ordre de Daniel : 400 DATES_REQUIRED / DATES_INVALID ; coupe-circuit
 *            SITE_DATES_REQUIRED_0611=off → « dates à prévoir » comme avant), visitsPerDay?, lieu?: at_owner|at_sitter, (1011 : service « journee », postalCode OBLIGATOIRE, timeFrom?, timeTo?, noCar?, budget? ; 639 : foodProvided?: true|false, breed?: race libre ≤ 60 car.) campaign?, page?,
 *            website (champ piège : doit rester vide) }
 * Garde-fous : limiteur par IP (sensitiveLimiter, monté sur /ad-leads) + par e-mail (3 / 10 min),
 * champ piège, e-mail valide, jamais +test / staff, dédoublonnage par e-mail (contact déjà publié et
 * demande encore ouverte → même demande, même session, pas de 2e compte), position par code postal
 * (Nominatim, comme leads_suivi.py, règle du 23/10 ; repli : centre de la ville connue), e-mail
 * « ta demande est en ligne » UNE fois, avec le lien d'ouverture de session de la pub
 * (/posts/confirmer?l=…&next=/posts : sans mot de passe ; les e-mails « candidats » qui suivent
 * portent le lien signé &k=).
 * Sortie : { id, postId, notified?, existing, token + user } — jeton SEULEMENT si le compte vient d'être créé par
 * cet appel ; compte déjà existant (ou contact déjà publié) → { session: 'email' } : la session ne s'ouvre que par
 * le lien de l'e-mail ou la connexion normale (ZOE 31/10 : une adresse e-mail seule ne prouve rien).
 */
const crypto = require('crypto');
const express = require('express');
const logger = require('../utils/logger');
const AdLead = require('../models/AdLead2210');
const Owner = require('../models/Owner');

const router = express.Router();
// 0811 (NEO, ordre de Daniel 08/11) — code reçu par e-mail tapé sur la page /demande : POST /ad-leads/code/send|check.
router.use('/code', require('./demandeCode0811'));
// 1011 (BOB) — accord SMS facultatif de la page de demande (jeton obligatoire, coupe-circuit DEMANDE_SMS_1011=off).
router.use('/sms-consent', require('./demandeSms1011'));
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const TEST_RE = /\+test|^hopetsit@|^dadaciao84@|^probe-|@invalid\.example$|staff@hopetsit/i;
const CITY_ANCHORS = {
  FR: { city: 'Paris', lat: 48.8566, lng: 2.3522, lang: 'fr' },
  US: { city: 'New York', lat: 40.7128, lng: -74.006, lang: 'en' },
};
/** a.b+alias@gmail.com → a.b@gmail.com (même boîte) ; sert au limiteur et au dédoublonnage, jamais au compte. */
function canonicalEmail(email) {
  const [local, domain] = String(email || '').toLowerCase().split('@');
  if (!domain) return String(email || '').toLowerCase();
  return `${local.split('+')[0]}@${domain}`;
}
const PER_EMAIL_MAX = 3;
const PER_EMAIL_WINDOW_MS = 10 * 60 * 1000;
const recent = new Map(); // e-mail → [timestamps]

function emailAllowed(email, now = Date.now()) {
  const list = (recent.get(email) || []).filter((t) => now - t < PER_EMAIL_WINDOW_MS);
  if (list.length >= PER_EMAIL_MAX) { recent.set(email, list); return false; }
  list.push(now);
  recent.set(email, list);
  if (recent.size > 5000) for (const k of recent.keys()) { if (recent.size <= 4000) break; recent.delete(k); }
  return true;
}

/** Position au code postal (Nominatim, 2,5 s), cache mémoire ; null si inconnu ou réseau coupé. */
const geoCache = new Map();
async function geocodePostal(code, country) {
  const key = `${country}:${code}`;
  if (geoCache.has(key)) return geoCache.get(key);
  if (String(process.env.POSTAL_GEOCODE || '').toLowerCase() === 'off' || typeof fetch !== 'function') return null;
  try {
    const q = new URLSearchParams({ postalcode: code, country: country.toLowerCase(), format: 'json', limit: '1', addressdetails: '1' });
    const ctl = new AbortController();
    const t = setTimeout(() => ctl.abort(), 2500);
    const r = await fetch(`https://nominatim.openstreetmap.org/search?${q}`, { headers: { 'User-Agent': 'HoPetSit/1.0 (contact@hopetsit.com)' }, signal: ctl.signal });
    clearTimeout(t);
    const arr = r.ok ? await r.json() : [];
    const a = Array.isArray(arr) && arr[0];
    const ad = (a && a.address) || {};
    const city = ad.city || ad.town || ad.village || ad.municipality || ad.county || '';
    const out = a && a.lat && city ? { city, lat: Number(a.lat), lng: Number(a.lon) } : null;
    geoCache.set(key, out);
    return out;
  } catch (_) {
    return null;
  }
}

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;
/** « 2026-11-20 » est-il un vrai jour du calendrier ? */
function isRealDay(d) {
  if (!DAY_RE.test(String(d || ''))) return false;
  const [y, m, dd] = String(d).split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, dd));
  return !Number.isNaN(dt.getTime()) && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === dd;
}
/**
 * 06/11/2026 (NEO, ordre de Daniel « dates obligatoires ») — mesure de FLO (14 j) : 19 demandes sur 45 avec
 * candidats étaient « dates à prévoir » → aucun prix total, jamais de bouton « Payer » (409 DATES_REQUIRED),
 * 0 paiement. Toute NOUVELLE demande du site porte des dates : début et fin (AAAA-MM-JJ, fin = début si absente),
 * jamais avant hier (fuseaux), début ≤ fin. Renvoie null si tout va bien, sinon { status, body } (message traduit).
 * Coupe-circuit : SITE_DATES_REQUIRED_0611=off remet le comportement d'avant (« à prévoir »).
 */
const DATES_MSG = {
  required: { fr: 'Indique les dates de début et de fin : les gardiens en ont besoin pour répondre.', en: 'Enter the start and end dates: sitters need them to reply.' },
  order: { fr: 'La fin doit être après le début.', en: 'The end must be after the start.' },
};
// 1011 (BOB) — message du code postal obligatoire (le site l'affiche tel quel).
const POSTAL_MSG = {
  fr: 'Indique ton code postal : il sert à te proposer les gardiens les plus proches de chez toi.',
  en: 'Enter your ZIP / postal code: we use it to show you the sitters closest to you.',
};
function datesRequired0611(b, lang) {
  if (String(process.env.SITE_DATES_REQUIRED_0611 || '').toLowerCase() === 'off') return null;
  const start = String(b.startDate || '').trim();
  const end = String(b.endDate || start).trim();
  const l = lang === 'en' ? 'en' : 'fr';
  if (!isRealDay(start) || !isRealDay(end)) return { status: 400, body: { error: DATES_MSG.required[l], code: 'DATES_REQUIRED' } };
  const yesterday = new Date(Date.now() - 24 * 3600 * 1000).toISOString().slice(0, 10);
  if (start < yesterday || end < start) return { status: 400, body: { error: DATES_MSG.order[l], code: 'DATES_INVALID' } };
  return null;
}
function textDate(d, lang) {
  // adLeadDates2310 lit startText/endText écrits « à la main » : on lui donne un format sûr (JJ/MM/AAAA ou MM/DD/YYYY).
  if (!DAY_RE.test(String(d || ''))) return '';
  const [y, m, dd] = String(d).split('-');
  return lang === 'en' ? `${m}/${dd}/${y}` : `${dd}/${m}/${y}`;
}

router.post('/site', async (req, res) => {
  try {
    const b = req.body || {};
    // Champ piège : un robot le remplit, une personne ne le voit pas.
    if (String(b.website || '').trim()) return res.status(400).json({ error: 'ROBOT', code: 'ROBOT' });
    const email = String(b.email || '').trim().toLowerCase();
    if (!EMAIL_RE.test(email) || email.length > 120) return res.status(400).json({ error: 'EMAIL_INVALID', code: 'EMAIL_INVALID' });
    if (TEST_RE.test(email)) return res.status(403).json({ error: 'TEST_ACCOUNT', code: 'TEST_ACCOUNT' });
    // 31/10 (BOB, point 1) — e-mail CANONIQUE : alias « +xxx » retiré (a+1@ = a+2@ = a@) pour le limiteur et le
    // dédoublonnage ; le +test reste refusé au-dessus. Le compte, lui, garde l'adresse telle quelle.
    const canonical = canonicalEmail(email);
    const service = AdLead.SERVICES.includes(b.service) ? b.service : '';
    if (!service) return res.status(400).json({ error: 'SERVICE_REQUIRED', code: 'SERVICE_REQUIRED' });
    const country = String(b.country || 'FR').trim().toUpperCase().slice(0, 2);
    const lang = b.lang === 'en' ? 'en' : 'fr';
    // 0811 (NEO, ordre de Daniel 08/11) — page /demande : la preuve de la boîte est un CODE tapé sur la page même
    // (e-mail « ton code » avec, en filet, le même bouton « Confirmer et publier » qu'aujourd'hui).
    const codeFlow = b.codeFlow === true || b.codeFlow === 'true';
    // 0611 (NEO, ordre de Daniel) — DATES OBLIGATOIRES avant tout le reste (rien créé, aucun e-mail).
    const datesErr = datesRequired0611(b, lang);
    if (datesErr) return res.status(datesErr.status).json(datesErr.body);
    const postalCode = String(b.postalCode || '').trim().slice(0, 12);
    const cityIn = String(b.city || '').trim().slice(0, 80);
    if (!postalCode && !cityIn) return res.status(400).json({ error: 'PLACE_REQUIRED', code: 'PLACE_REQUIRED' });
    // 1011 (BOB, accord de Daniel) — CODE POSTAL OBLIGATOIRE : 43 demandes sur 46 n'en avaient pas, et une ville choisie
    // dans la liste place la demande au centre-ville (gardiens proposés à 8-10 km). Coupe-circuit : SITE_POSTAL_REQUIRED_1011=off.
    if (!postalCode && String(process.env.SITE_POSTAL_REQUIRED_1011 || '').toLowerCase() !== 'off') {
      return res.status(400).json({ error: POSTAL_MSG[lang === 'en' ? 'en' : 'fr'], code: 'POSTAL_REQUIRED' });
    }
    if (!emailAllowed(canonical)) return res.status(429).json({ error: 'TOO_MANY', code: 'TOO_MANY' });

    const lieu = b.lieu === 'at_sitter' ? 'at_sitter' : 'at_owner';
    // 1011 — précisions facultatives du formulaire (« ＋ Préciser ») : jamais une erreur, l'illisible est ignoré.
    const { cleanTime, toBool } = require('../utils/postExtras1011');
    const budgetN = Number(String(b.budget == null ? '' : b.budget).replace(/\s/g, '').replace(',', '.'));
    const extras1011 = {
      lieu,
      timeFrom: cleanTime(b.timeFrom) || '',
      timeTo: cleanTime(b.timeTo) || '',
      noCar: toBool(b.noCar) === true,
      // 639 — facultatifs : « Je fournis la nourriture » (true / false, sinon non précisé) et race (nettoyée, ≤ 60 car.).
      ...(toBool(b.foodProvided) === null ? {} : { foodProvided: toBool(b.foodProvided) }),
      ...(() => { const r = require('../utils/postPet612').cleanBreed(b.breed); return r ? { breed: r } : {}; })(),
      ...(Number.isFinite(budgetN) && budgetN > 0 ? { budget: Math.round(Math.min(budgetN, 100000) * 100) / 100 } : {}),
    };
    const Post = require('../models/Post');
    // 3110 — plus aucun jeton de session renvoyé par cette route : la session s'ouvre par le lien de l'e-mail.

    // Dédoublonnage par e-mail CANONIQUE : un contact déjà publié dont la demande est encore ouverte → la même.
    const [cLocal, cDomain] = canonical.split('@');
    const sameBox = { email: new RegExp(`^${cLocal.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\+[^@]*)?@${cDomain.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') };
    const prev = await AdLead.findOne({ ...sameBox, postId: { $ne: null } }).sort({ createdAt: -1 });
    if (prev && prev.ownerId) {
      const post = await Post.findById(prev.postId).select('status').lean();
      const owner = post && post.status !== 'closed' ? await Owner.findById(prev.ownerId) : null;
      // 31/10 16 h 40 (ZOE) — JAMAIS de jeton de session pour un compte qui existe déjà : la seule
      // donnée fournie ici est une adresse e-mail (connue de tous), elle ne prouve rien. La session ne
      // s'ouvre que par le lien reçu dans la boîte (/posts/confirmer?l=…) ou par la connexion normale.
      if (owner) return res.status(200).json({ id: prev._id, postId: String(prev.postId), existing: true, session: 'email' });
    }

    // 3110 (ADA, ordre de Daniel) — un brouillon encore en attente de confirmation pour la même boîte (< 24 h) :
    // même brouillon, pas de 2e compte, pas de 2e e-mail (le rappel +24 h s'en charge).
    const pendingDraft = await AdLead.findOne({ ...sameBox, pendingConfirm: true, postId: null, createdAt: { $gte: new Date(Date.now() - 24 * 3600 * 1000) } }).sort({ createdAt: -1 }).lean();
    if (pendingDraft) return res.status(202).json({ id: pendingDraft._id, pending: true, existing: true, session: 'email' });

    // Position (demande de Daniel, 31/10 : « sélectionnée par carte pour être précis ») :
    //   1. lat/lng choisis sur la carte par le propriétaire, s'ils sont plausibles (plages valides, pas 0/0) ;
    //      une position hors plage est REFUSÉE (400 POSITION_INVALID) plutôt que corrigée en silence ;
    //   2. sinon code postal → ville + lat/lng (Nominatim) ; 3. sinon ville saisie ; 4. sinon centre de la ville du pays.
    // C'est cette position qui décide des gardiens prévenus et de la distance montrée aux candidats.
    const anchor = CITY_ANCHORS[country] || null;
    const hasLat = b.lat !== undefined && b.lat !== null && b.lat !== '';
    const hasLng = b.lng !== undefined && b.lng !== null && b.lng !== '';
    const lat = Number(b.lat); const lng = Number(b.lng);
    let picked = null;
    if (hasLat || hasLng) {
      const ok = Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 && !(Math.abs(lat) < 0.01 && Math.abs(lng) < 0.01);
      if (!ok) return res.status(400).json({ error: 'POSITION_INVALID', code: 'POSITION_INVALID' });
      picked = { lat, lng, source: 'map' };
    }
    const geo = !picked && postalCode ? await geocodePostal(postalCode, country) : null;
    const place = (picked ? { city: cityIn || (geo && geo.city) || (anchor ? anchor.city : ''), lat: picked.lat, lng: picked.lng } : null)
      || geo
      || (cityIn ? { city: cityIn, ...(anchor ? { lat: anchor.lat, lng: anchor.lng } : {}) } : null)
      || (anchor ? { city: anchor.city, lat: anchor.lat, lng: anchor.lng } : null);
    if (!place || !place.city) return res.status(400).json({ error: 'PLACE_REQUIRED', code: 'PLACE_REQUIRED' });

    const campaign = String(b.campaign || '').trim().slice(0, 40) || (country === 'US' ? 'nyc_owners' : 'paris_owners');
    // 31/10 (BOB, point 1 — SÉCURITÉ) — COMPTE DÉJÀ EXISTANT : un inconnu qui connaît l'adresse ne doit pas pouvoir
    // publier une demande au nom de ce compte ni faire prévenir les gardiens. La demande est donc gardée en
    // BROUILLON (contact enregistré, rien publié, aucun gardien prévenu) et un e-mail « confirme ta demande » part
    // vers la boîte : le clic (/posts/confirmer?l=…, route /ad-leads/:id/confirm) publie ET ouvre la session.
    const existingOwner = await Owner.findOne({ email }).select('_id name').lean();
    if (existingOwner) {
      const draft = await AdLead.create({
        metaLeadId: `site:${crypto.randomBytes(12).toString('hex')}`,
        source: 'site', campaign, page: String(b.page || '').trim().slice(0, 120), postalCode,
        positionSource: picked ? 'map' : geo ? 'postal' : cityIn ? 'city' : 'anchor',
        pendingConfirm: true,
        ...extras1011,
        email, firstName: String(b.firstName || '').trim().slice(0, 60) || String(existingOwner.name || '').split(' ')[0] || '',
        city: place.city, ...(Number.isFinite(place.lat) && Number.isFinite(place.lng) ? { lat: place.lat, lng: place.lng } : {}),
        country, lang, service, animal: AdLead.ANIMALS.includes(b.animal) ? b.animal : 'autre', quand: 'plus_tard',
        startText: textDate(b.startDate, lang), endText: textDate(b.endDate || b.startDate, lang),
        ...([1, 2].includes(Number(b.visitsPerDay)) ? { visitsPerDay: Number(b.visitsPerDay) } : {}),
        ...(() => { const tp = b.targetProvider && typeof b.targetProvider === 'object' ? b.targetProvider : null; const role = tp && String(tp.role || '').toLowerCase(); const id = tp && String(tp.id || ''); return role && ['sitter', 'walker'].includes(role) && /^[a-f0-9]{24}$/i.test(id) ? { targetRole: role, targetId: id } : {}; })(),
      });
      if (codeFlow) {
        // 0811 — compte déjà existant : même brouillon, mais l'e-mail porte le code (+ le bouton en filet).
        const { startCodeFlow } = require('./demandeCode0811');
        const c = await startCodeFlow(draft);
        if (c.emailSent) { draft.siteEmailAt = new Date(); await draft.save(); }
        return res.status(202).json({ id: draft._id, pending: true, existing: false, session: 'email', code: c.emailSent });
      }
      // 3110 (ADA) — texte « Quelqu'un vient de préparer… » (LEO) servi par le helper commun de adLeads2210.
      try {
        const { sendConfirmEmail } = require('./adLeads2210');
        await sendConfirmEmail(draft, 'existing');
        draft.siteEmailAt = new Date();
        await draft.save();
      } catch (e) {
        logger.warn(`[adLeadsSite3110] e-mail « confirme » non envoyé : ${e && e.message}`);
      }
      return res.status(202).json({ id: draft._id, pending: true, existing: false, session: 'email' });
    }

    const lead = await AdLead.create({
      metaLeadId: `site:${crypto.randomBytes(12).toString('hex')}`,
      source: 'site',
      campaign,
      page: String(b.page || '').trim().slice(0, 120),
      postalCode,
      positionSource: picked ? 'map' : geo ? 'postal' : cityIn ? 'city' : 'anchor',
      email,
      firstName: String(b.firstName || '').trim().slice(0, 60),
      city: place.city,
      ...(Number.isFinite(place.lat) && Number.isFinite(place.lng) ? { lat: place.lat, lng: place.lng } : {}),
      country,
      lang,
      service,
      ...extras1011,
      animal: AdLead.ANIMALS.includes(b.animal) ? b.animal : 'autre',
      quand: 'plus_tard',
      startText: textDate(b.startDate, lang),
      endText: textDate(b.endDate || b.startDate, lang),
      ...([1, 2].includes(Number(b.visitsPerDay)) ? { visitsPerDay: Number(b.visitsPerDay) } : {}),
      // Cible facultative { role, id } (profil public / épingle) : validée plus loin par createPost.
      ...(() => { const tp = b.targetProvider && typeof b.targetProvider === 'object' ? b.targetProvider : null; const role = tp && String(tp.role || '').toLowerCase(); const id = tp && String(tp.id || ''); return role && ['sitter', 'walker'].includes(role) && /^[a-f0-9]{24}$/i.test(id) ? { targetRole: role, targetId: id } : {}; })(),
    });

    // 3110 (ADA, ORDRE DE DANIEL 31/10 : « au moins l'e-mail vérifié, pour de vraies demandes suivies ») —
    // NOUVEAU compte : plus de publication immédiate. Compte propriétaire NON vérifié + brouillon + e-mail
    // « un clic pour publier ta demande » ; le clic (/ad-leads/:id/confirm) vérifie l'e-mail, publie et
    // prévient les gardiens. Réponse 202 { pending } : le site affiche « vérifie ta boîte mail ».
    if (codeFlow) {
      // 0811 — NOUVEAU compte (NON vérifié) + brouillon + e-mail « ton code » (code + bouton) ; rien publié avant le code.
      const { startCodeFlow } = require('./demandeCode0811');
      const c = await startCodeFlow(lead);
      if (c.emailSent) { lead.siteEmailAt = new Date(); await lead.save(); }
      return res.status(202).json({ id: lead._id, pending: true, existing: false, session: 'email', code: c.emailSent });
    }
    const { draftLead } = require('./adLeads2210');
    const d = await draftLead(lead, { variant: 'new' });
    if (d.emailSent) { lead.siteEmailAt = new Date(); await lead.save(); }
    return res.status(202).json({ id: lead._id, pending: true, existing: false, session: 'email' });
  } catch (e) {
    logger.error('[adLeadsSite3110] failed', e);
    return res.status(500).json({ error: 'Unable to publish.' });
  }
});

module.exports = router;
module.exports._resetForTest = () => { recent.clear(); geoCache.clear(); };
module.exports.datesRequired0611 = datesRequired0611; // 0611 — testable à part
