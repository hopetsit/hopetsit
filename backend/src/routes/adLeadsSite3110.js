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
 *            postalCode, city?, country: FR|US|…, lang: fr|en, startDate?, endDate? (AAAA-MM-JJ, sinon
 *            « dates à prévoir »), visitsPerDay?, lieu?: at_owner|at_sitter, campaign?, page?,
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
    const postalCode = String(b.postalCode || '').trim().slice(0, 12);
    const cityIn = String(b.city || '').trim().slice(0, 80);
    if (!postalCode && !cityIn) return res.status(400).json({ error: 'PLACE_REQUIRED', code: 'PLACE_REQUIRED' });
    if (!emailAllowed(canonical)) return res.status(429).json({ error: 'TOO_MANY', code: 'TOO_MANY' });

    const lieu = b.lieu === 'at_sitter' ? 'at_sitter' : 'at_owner';
    const { publishLead } = require('./adLeads2210');
    const Post = require('../models/Post');
    const { signAuthToken } = require('../controllers/authController');
    const session = (owner) => ({
      token: signAuthToken({ id: owner._id.toString(), role: 'owner' }),
      user: { id: owner._id.toString(), name: owner.name, email: owner.email, role: 'owner' },
    });

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
        email, firstName: String(b.firstName || '').trim().slice(0, 60) || String(existingOwner.name || '').split(' ')[0] || '',
        city: place.city, ...(Number.isFinite(place.lat) && Number.isFinite(place.lng) ? { lat: place.lat, lng: place.lng } : {}),
        country, lang, service, animal: AdLead.ANIMALS.includes(b.animal) ? b.animal : 'autre', quand: 'plus_tard',
        startText: textDate(b.startDate, lang), endText: textDate(b.endDate || b.startDate, lang),
        ...([1, 2].includes(Number(b.visitsPerDay)) ? { visitsPerDay: Number(b.visitsPerDay) } : {}),
        ...(() => { const tp = b.targetProvider && typeof b.targetProvider === 'object' ? b.targetProvider : null; const role = tp && String(tp.role || '').toLowerCase(); const id = tp && String(tp.id || ''); return role && ['sitter', 'walker'].includes(role) && /^[a-f0-9]{24}$/i.test(id) ? { targetRole: role, targetId: id } : {}; })(),
      });
      try {
        const { BASE_URL } = require('../utils/emailLinkBuilder');
        const { sendEmail } = require('../services/emailService');
        const link = `${BASE_URL}/posts/confirmer?l=${draft._id}&utm_source=site&utm_medium=email&utm_campaign=${encodeURIComponent(campaign)}`;
        const p = draft.firstName || '';
        const fr = lang === 'fr';
        const subject = fr ? `${p ? `${p}, confirme` : 'Confirme'} ta demande pour la publier` : `${p ? `${p}, confirm` : 'Confirm'} your request to publish it`;
        const text = fr
          ? `${p ? `Bonjour ${p},` : 'Bonjour,'}\n\nQuelqu'un vient de préparer une demande de garde avec ton adresse e-mail sur hopetsit.com. Si c'est toi, clique pour la publier : les gardiens près de chez toi seront prévenus et tu recevras leurs prix par e-mail.\n\nPublier ma demande : ${link}\n\nSi ce n'est pas toi, ignore cet e-mail : rien ne sera publié.\n\nHoPetSit`
          : `${p ? `Hi ${p},` : 'Hi,'}\n\nSomeone just prepared a pet-sitting request with your email address on hopetsit.com. If it was you, click to publish it: sitters near you will be notified and you'll get their prices by email.\n\nPublish my request: ${link}\n\nIf it wasn't you, ignore this email: nothing will be published.\n\nHoPetSit`;
        const esc = (x) => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const parts = text.split('\n\n');
        const html = `<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:560px;margin:0 auto;color:#231715;line-height:1.5"><p>${esc(parts[0])}</p><p>${esc(parts[1])}</p><p style="text-align:center;margin:24px 0"><a href="${link}" style="display:inline-block;background:#C92A12;color:#fff;text-decoration:none;font-weight:800;padding:14px 26px;border-radius:999px">${fr ? 'Publier ma demande' : 'Publish my request'}</a></p><p style="font-size:13px;color:#6E4F48">${esc(parts[3])}</p></div>`;
        await sendEmail(email, subject, text, html);
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
      animal: AdLead.ANIMALS.includes(b.animal) ? b.animal : 'autre',
      quand: 'plus_tard',
      startText: textDate(b.startDate, lang),
      endText: textDate(b.endDate || b.startDate, lang),
      ...([1, 2].includes(Number(b.visitsPerDay)) ? { visitsPerDay: Number(b.visitsPerDay) } : {}),
      // Cible facultative { role, id } (profil public / épingle) : validée plus loin par createPost.
      ...(() => { const tp = b.targetProvider && typeof b.targetProvider === 'object' ? b.targetProvider : null; const role = tp && String(tp.role || '').toLowerCase(); const id = tp && String(tp.id || ''); return role && ['sitter', 'walker'].includes(role) && /^[a-f0-9]{24}$/i.test(id) ? { targetRole: role, targetId: id } : {}; })(),
    });

    // Compte déjà existant pour cet e-mail (inscrit dans l'app, ou contact précédent) → la demande est
    // publiée sur son compte et l'e-mail « en ligne » part, mais la réponse ne porte AUCUN jeton (ZOE 31/10).
    const existedBefore = !!(await Owner.exists({ email }));
    const r = await publishLead(lead, lieu);
    if (r.status !== 200) return res.status(r.status).json(r.body);

    // E-mail « ta demande est en ligne » — UNE fois par contact, lien qui ouvre la session sans mot de passe.
    if (!lead.siteEmailAt) {
      try {
        const { BASE_URL } = require('../utils/emailLinkBuilder');
        const { sendEmail } = require('../services/emailService');
        const link = `${BASE_URL}/posts/confirmer?l=${lead._id}&next=%2Fposts&utm_source=site&utm_medium=email&utm_campaign=${encodeURIComponent(campaign)}`;
        const p = lead.firstName || '';
        const n = Number(r.notified);
        const fr = lang === 'fr';
        const subject = fr ? `${p ? `${p}, ta` : 'Ta'} demande est en ligne — les gardiens sont prévenus` : `${p ? `${p}, your` : 'Your'} request is live — sitters have been notified`;
        const who = fr
          ? (Number.isFinite(n) && n > 0 ? `${n} gardien${n > 1 ? 's' : ''} et promeneur${n > 1 ? 's' : ''} près de chez toi ${n > 1 ? 'sont prévenus' : 'est prévenu'}.` : 'Les gardiens et promeneurs près de chez toi sont prévenus.')
          : (Number.isFinite(n) && n > 0 ? `${n} sitter${n > 1 ? 's' : ''} and walker${n > 1 ? 's' : ''} near you ${n > 1 ? 'have' : 'has'} been notified.` : 'Sitters and walkers near you have been notified.');
        const text = fr
          ? `${p ? `Bonjour ${p},` : 'Bonjour,'}\n\nTa demande est en ligne sur HoPetSit. ${who}\n\nTu recevras chaque candidature, avec son prix, par e-mail. Tu choisis, tu paies par carte : annulation gratuite jusqu'à 72 h avant, l'argent n'est versé au gardien qu'une fois la garde terminée.\n\nVoir ma demande : ${link}\n\nPas de mot de passe à créer : ce lien ouvre ton espace.\n\nHoPetSit`
          : `${p ? `Hi ${p},` : 'Hi,'}\n\nYour request is live on HoPetSit. ${who}\n\nYou'll get every application, with its price, by email. You choose, you pay by card: free cancellation up to 72 h before, the sitter is only paid once the stay is over.\n\nSee my request: ${link}\n\nNo password to create: this link opens your space.\n\nHoPetSit`;
        const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const html = `<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:560px;margin:0 auto;color:#231715;line-height:1.5"><p>${esc(text.split('\n\n')[0])}</p><p>${esc(text.split('\n\n')[1])}</p><p>${esc(text.split('\n\n')[2])}</p><p style="text-align:center;margin:24px 0"><a href="${link}" style="display:inline-block;background:#C92A12;color:#fff;text-decoration:none;font-weight:800;padding:14px 26px;border-radius:999px">${fr ? 'Voir ma demande' : 'See my request'}</a></p><p style="font-size:13px;color:#6E4F48">${esc(text.split('\n\n')[4])}</p></div>`;
        await sendEmail(email, subject, text, html);
        lead.siteEmailAt = new Date();
        await lead.save();
      } catch (e) {
        logger.warn(`[adLeadsSite3110] e-mail « en ligne » non envoyé : ${e && e.message}`);
      }
    }
    return res.status(201).json({ id: lead._id, postId: r.postId, existing: false, ...(r.notified === undefined || r.notified === null ? {} : { notified: r.notified }), ...(existedBefore ? { session: 'email' } : session(r.owner)) });
  } catch (e) {
    logger.error('[adLeadsSite3110] failed', e);
    return res.status(500).json({ error: 'Unable to publish.' });
  }
});

module.exports = router;
module.exports._resetForTest = () => { recent.clear(); geoCache.clear(); };
