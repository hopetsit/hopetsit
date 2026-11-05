/**
 * 0511 (BOB, ordre de Daniel « fais-le ») — WEBHOOK META « leadgen » : la demande d'un contact de la
 * pub est créée À LA SECONDE où il envoie le formulaire, au lieu d'attendre le relevé du Mac
 * (leads_suivi.py, toutes les 5 min). Résultat : quand il appuie sur « Publier ma demande
 * maintenant » sur la page de remerciement (/posts/merci, SAM), le contact existe déjà → publié
 * tout de suite au lieu de « ta demande arrive ».
 *
 *   GET  /webhooks/meta-leadgen   → vérification Meta (hub.mode=subscribe, hub.verify_token, hub.challenge)
 *   POST /webhooks/meta-leadgen   → { entry: [{ changes: [{ field: 'leadgen', value: { leadgen_id, form_id, page_id } }] }] }
 *        Pour chaque leadgen_id : lecture du contact chez Meta (jeton de page, chiffré en base), mêmes
 *        champs que leads_suivi.py (prénom, e-mail, téléphone*, code postal, service, animal, quand,
 *        dates), position par code postal (Nominatim, repli centre-ville), AdLead créé (metaLeadId
 *        unique = jamais deux fois) puis BROUILLON + e-mail « confirme » (draftLead, règle du 31/10).
 *        Toujours 200 vite (Meta réessaie sinon) ; le travail se fait après la réponse.
 *        * le téléphone n'est PAS stocké ici (le modèle AdLead n'a pas ce champ ; les SMS lisent
 *          leads/leads.json du Mac, inchangé).
 *   Signature : si un secret d'app est configuré, X-Hub-Signature-256 est vérifié sur le corps brut ;
 *   sans secret, un faux appel ne peut au pire que nous faire RELIRE un vrai contact chez Meta
 *   (l'id seul ne crée rien : les données viennent de Meta, authentifié par le jeton de page).
 *   PUT /admin/meta-leadgen/config { pageToken, verifyToken?, appSecret?, forms: { <form_id>: 'paris'|'nyc' } }
 *   GET /admin/meta-leadgen/status → { configured, forms, events (50 derniers), counts }
 * Le relevé du Mac continue de tourner : il retrouve le contact déjà créé (upsert) et complète
 * leads/leads.json (téléphone pour les SMS). Coupe-circuit : META_LEADGEN_0511=off.
 */
const express = require('express');
const crypto = require('crypto');
const mongoose = require('mongoose');
const logger = require('../utils/logger');
const { encrypt, decrypt, isEncrypted } = require('../utils/encryption');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');

const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];
const GRAPH = 'https://graph.facebook.com/v21.0';
const enabled = () => String(process.env.META_LEADGEN_0511 || '').toLowerCase() !== 'off';

const VILLES = {
  paris: { city: 'Paris', lat: 48.8566, lng: 2.3522, country: 'FR', lang: 'fr' },
  nyc: { city: 'New York', lat: 40.7128, lng: -74.006, country: 'US', lang: 'en' },
};

const configSchema = new mongoose.Schema({
  key: { type: String, default: 'main', unique: true },
  pageTokenEnc: { type: String, default: '' },
  appSecretEnc: { type: String, default: '' },
  verifyToken: { type: String, default: '' },
  forms: { type: Map, of: String, default: {} }, // form_id → 'paris' | 'nyc'
  updatedAt: { type: Date, default: Date.now },
}, { collection: 'metaleadgenconfig0511' });
const Config = mongoose.models.MetaLeadgenConfig0511 || mongoose.model('MetaLeadgenConfig0511', configSchema);

const eventSchema = new mongoose.Schema({
  leadgenId: { type: String, index: true },
  formId: String,
  cityKey: String,
  status: { type: String, enum: ['created', 'existing', 'ignored', 'error'] },
  detail: String,
  leadId: String,
  at: { type: Date, default: Date.now, index: true },
}, { collection: 'metaleadgenevents0511' });
const Event = mongoose.models.MetaLeadgenEvent0511 || mongoose.model('MetaLeadgenEvent0511', eventSchema);

const getConfig = async () => Config.findOne({ key: 'main' }).lean();
const dec = (v) => (v ? (isEncrypted(v) ? decrypt(v) : v) : '');

// ── Meta → champs du contact (mêmes règles que leads_suivi.py / enregistrement()) ───────────────
function fieldsOf(lead) {
  const f = {};
  for (const x of (lead && lead.field_data) || []) {
    if (x && x.name) f[x.name] = Array.isArray(x.values) ? String(x.values[0] || '') : '';
  }
  return f;
}
const pick = (v, list, d) => (list.includes(v) ? v : d);

/** Position par code postal (Nominatim, comme le Mac) ; null si inconnu. 8 s max. */
async function geocodePostcode(code, country, fetchImpl) {
  const c = String(code || '').replace(/[^0-9A-Za-z]/g, '').slice(0, 10);
  if (!c) return null;
  const ctl = new AbortController(); const timer = setTimeout(() => ctl.abort(), 8000);
  try {
    const q = new URLSearchParams({ postalcode: c, country: String(country || '').toLowerCase(), format: 'json', limit: '1', addressdetails: '1' });
    const r = await (fetchImpl || fetch)(`https://nominatim.openstreetmap.org/search?${q}`, { headers: { 'User-Agent': 'HoPetSit-leads/1.0 (hopetsit@gmail.com)' }, signal: ctl.signal });
    if (!r.ok) return null;
    const d = await r.json();
    const a = (d || [])[0] || {}; const ad = a.address || {};
    const city = ad.city || ad.town || ad.village || ad.municipality || ad.suburb || '';
    const lat = Number(a.lat); const lng = Number(a.lon);
    return city && Number.isFinite(lat) && Number.isFinite(lng) ? { city, lat, lng } : null;
  } catch (_) { return null; } finally { clearTimeout(timer); }
}

/** Crée (ou retrouve) le contact AdLead à partir du contact Meta, puis brouillon + e-mail. */
async function ingestLead(leadgenId, formId, cfg, deps = {}) {
  const AdLead = require('../models/AdLead2210');
  const { draftLead } = require('./adLeads2210');
  const fetchImpl = deps.fetch || fetch;
  const pageToken = dec(cfg && cfg.pageTokenEnc);
  if (!pageToken) return { status: 'error', detail: 'no_page_token' };
  const forms = cfg && cfg.forms ? (cfg.forms instanceof Map ? Object.fromEntries(cfg.forms) : cfg.forms) : {};
  const cityKey = forms[String(formId)];
  if (!cityKey || !VILLES[cityKey]) return { status: 'ignored', detail: `form_inconnu:${formId}` };
  const r = await fetchImpl(`${GRAPH}/${encodeURIComponent(leadgenId)}?fields=id,created_time,field_data,form_id&access_token=${encodeURIComponent(pageToken)}`);
  if (!r.ok) return { status: 'error', detail: `graph_${r.status}` };
  const lead = await r.json();
  const f = fieldsOf(lead);
  const email = String(f.email || '').trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { status: 'ignored', detail: 'email_invalide' };
  const prenom = String(f.first_name || '').trim().split(' ')[0];
  const firstName = prenom ? prenom.charAt(0).toUpperCase() + prenom.slice(1) : '';
  const v = VILLES[cityKey];
  const pos = await geocodePostcode(f.post_code || f.zip_code, v.country, fetchImpl);
  let adLead = await AdLead.findOne({ metaLeadId: String(leadgenId) });
  let created = false;
  if (!adLead) {
    try {
      adLead = await AdLead.create({
        metaLeadId: String(leadgenId), email, firstName: firstName.slice(0, 60),
        city: (pos && pos.city) || v.city, lat: pos ? pos.lat : v.lat, lng: pos ? pos.lng : v.lng,
        positionSource: pos ? 'postal' : 'city', postalCode: String(f.post_code || f.zip_code || '').slice(0, 12),
        country: v.country, lang: v.lang, campaign: `${cityKey}_leads`,
        service: pick(f.service, AdLead.SERVICES, 'garde'), animal: pick(f.animal, AdLead.ANIMALS, 'autre'),
        quand: pick(f.quand, AdLead.WHENS, 'plus_tard'),
        startText: String(f.date_debut || f.dates || '').slice(0, 60), endText: String(f.date_fin || '').slice(0, 60),
        source: 'meta',
      });
      created = true;
    } catch (e) {
      if (!(e && e.code === 11000)) throw e; // créé entre-temps (relevé du Mac) : on le reprend
      adLead = await AdLead.findOne({ metaLeadId: String(leadgenId) });
    }
  }
  let detail = '';
  if (created || (!adLead.postId && !adLead.confirmEmailAt)) {
    try { await draftLead(adLead, { variant: 'new' }); } catch (e) { detail = `draft_error:${String(e && e.message).slice(0, 160)}`; logger.warn(`[metaLeadgen0511] draft : ${e && e.message}`); }
  }
  return { status: created ? 'created' : 'existing', leadId: String(adLead._id), cityKey, detail };
}

function verifySignature(cfg, req) {
  const secret = dec(cfg && cfg.appSecretEnc);
  if (!secret) return true; // pas de secret configuré : on s'appuie sur la relecture chez Meta
  const sig = String(req.get('x-hub-signature-256') || '');
  if (!sig.startsWith('sha256=') || !req.rawBody) return false;
  const h = 'sha256=' + crypto.createHmac('sha256', secret).update(req.rawBody).digest('hex');
  const a = Buffer.from(h); const b = Buffer.from(sig);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

const router = express.Router();

router.get('/', async (req, res) => {
  const cfg = await getConfig();
  const mode = req.query['hub.mode']; const token = req.query['hub.verify_token']; const challenge = req.query['hub.challenge'];
  if (mode === 'subscribe' && cfg && cfg.verifyToken && token === cfg.verifyToken) return res.status(200).send(String(challenge || ''));
  return res.status(403).send('forbidden');
});

router.post('/', async (req, res) => {
  const body = req.body || {};
  const cfg = await getConfig();
  if (!verifySignature(cfg, req)) return res.status(403).json({ error: 'signature' });
  res.status(200).send('EVENT_RECEIVED'); // Meta attend un 200 rapide
  if (!enabled() || body.object !== 'page') return;
  const changes = [];
  for (const e of body.entry || []) for (const c of e.changes || []) if (c && c.field === 'leadgen' && c.value && c.value.leadgen_id) changes.push(c.value);
  for (const v of changes) {
    try {
      const r = await ingestLead(String(v.leadgen_id), String(v.form_id || ''), cfg, router.deps || {});
      await Event.create({ leadgenId: String(v.leadgen_id), formId: String(v.form_id || ''), cityKey: r.cityKey || '', status: r.status, detail: r.detail || '', leadId: r.leadId || '' });
      logger.info(`[metaLeadgen0511] ${v.leadgen_id} → ${r.status}${r.detail ? ` (${r.detail})` : ''}`);
    } catch (e) {
      logger.error('[metaLeadgen0511] ingest failed', e);
      try { await Event.create({ leadgenId: String(v.leadgen_id), formId: String(v.form_id || ''), status: 'error', detail: String(e && e.message).slice(0, 200) }); } catch (_) { /* rien */ }
    }
  }
});

const adminRouter = express.Router();
adminRouter.put('/config', requireAdmin, async (req, res) => {
  const b = req.body || {};
  const set = { updatedAt: new Date() };
  if (b.pageToken) set.pageTokenEnc = encrypt(String(b.pageToken));
  if (b.appSecret) set.appSecretEnc = encrypt(String(b.appSecret));
  if (b.verifyToken) set.verifyToken = String(b.verifyToken).slice(0, 80);
  if (b.forms && typeof b.forms === 'object') {
    const forms = {};
    for (const [k, v] of Object.entries(b.forms)) if (/^\d+$/.test(k) && VILLES[v]) forms[k] = v;
    set.forms = forms;
  }
  const cfg = await Config.findOneAndUpdate({ key: 'main' }, { $set: set, $setOnInsert: { key: 'main' } }, { upsert: true, new: true }).lean();
  return res.json({ ok: true, configured: !!cfg.pageTokenEnc, hasSecret: !!cfg.appSecretEnc, hasVerifyToken: !!cfg.verifyToken, forms: cfg.forms || {} });
});
adminRouter.get('/status', requireAdmin, async (req, res) => {
  const cfg = await getConfig();
  const events = await Event.find({}).sort({ at: -1 }).limit(50).lean();
  const counts = {}; for (const e of await Event.find({ at: { $gte: new Date(Date.now() - 7 * 86400000) } }).select('status').lean()) counts[e.status] = (counts[e.status] || 0) + 1;
  return res.json({ enabled: enabled(), configured: !!(cfg && cfg.pageTokenEnc), hasSecret: !!(cfg && cfg.appSecretEnc), hasVerifyToken: !!(cfg && cfg.verifyToken), forms: (cfg && cfg.forms) || {}, counts7d: counts, events });
});

module.exports = router;
module.exports.adminRouter = adminRouter;
module.exports.ingestLead = ingestLead;
module.exports.fieldsOf = fieldsOf;
module.exports.Config = Config;
module.exports.Event = Event;
module.exports.VILLES = VILLES;
