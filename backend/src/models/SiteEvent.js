/**
 * SiteEvent — v576
 *
 * Mesure d'audience maison du site hopetsit.com. Daniel paie de la pub Meta
 * sans savoir combien de personnes arrivent vraiment sur la page ni combien
 * touchent le bouton du store : ce modèle est le strict minimum pour répondre
 * à ces deux questions.
 *
 * PRIVACY BY DESIGN — aucune donnée personnelle n'est stockée :
 *   - pas de cookie, pas de localStorage côté site (rien à consentir) ;
 *   - l'IP et le user-agent servent UNIQUEMENT à calculer `visitor`, une
 *     empreinte sha256 tronquée, et ne sont JAMAIS écrits en base ;
 *   - le sel de cette empreinte est un HMAC(secret serveur, date du jour) :
 *     il change à minuit UTC, donc la même personne a une empreinte
 *     différente demain → impossible de suivre quelqu'un dans le temps ;
 *   - du referrer on ne garde que le nom d'hôte (« google.com »), jamais
 *     l'URL complète ; du chemin visité, jamais la query string ;
 *   - purge automatique (TTL) au bout de 400 jours.
 *
 * Les helpers purs (classement de la source, empreinte, validation) sont
 * exposés en statics : ils sont testables sans base ni réseau.
 */
const crypto = require('crypto');
const mongoose = require('mongoose');

const EVENT_TYPES = ['pageview', 'store_click', 'cta_click'];
const DEVICES = ['mobile', 'tablet', 'desktop'];
const SOURCES = [
  'meta_ads',
  'google_ads',
  'google',
  'facebook',
  'instagram',
  'direct',
  'other',
];
const STORES = ['ios', 'android', 'other'];

// Langues du site (website/src/lib/i18n/translations.ts).
const LANGS = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

// Chemins jamais mesurés (espaces privés / connectés).
const EXCLUDED_PREFIXES = ['/admin', '/dashboard', '/chat'];

const MAX_PATH = 200;
const MAX_UTM = 80;
const MAX_LABEL = 60;
const MAX_HOST = 100;

const siteEventSchema = new mongoose.Schema(
  {
    type: { type: String, enum: EVENT_TYPES, required: true },
    // Chemin seul, sans query string ni identifiant (« /villes/paris »).
    path: { type: String, default: '/', maxLength: MAX_PATH },
    lang: { type: String, default: '' },
    device: { type: String, enum: DEVICES, default: 'desktop' },
    // Catégorie normalisée — c'est la ligne que Daniel lit dans l'admin.
    source: { type: String, enum: SOURCES, default: 'direct' },
    utmSource: { type: String, default: '', maxLength: MAX_UTM },
    utmMedium: { type: String, default: '', maxLength: MAX_UTM },
    utmCampaign: { type: String, default: '', maxLength: MAX_UTM },
    // Nom d'hôte du referrer UNIQUEMENT (« l.facebook.com »).
    refHost: { type: String, default: '', maxLength: MAX_HOST },
    // Renseigné pour les store_click.
    store: { type: String, enum: [...STORES, ''], default: '' },
    // Renseigné pour les cta_click.
    label: { type: String, default: '', maxLength: MAX_LABEL },
    // Jour UTC « AAAA-MM-JJ » : tous les agrégats se font dessus.
    day: { type: String, default: '' },
    // Empreinte NON réversible, valable une seule journée (voir en-tête).
    visitor: { type: String, default: '' },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: false },
);

siteEventSchema.index({ day: 1, type: 1 });
siteEventSchema.index({ day: 1, path: 1 });
// Purge automatique après 400 jours : on garde de quoi comparer une année
// sur l'autre, pas davantage.
siteEventSchema.index({ createdAt: 1 }, { expireAfterSeconds: 400 * 24 * 3600 });

// ── HELPERS PURS (statics) ───────────────────────────────────────────────────

const str = (v) => (typeof v === 'string' ? v : '');
const clip = (v, n) => str(v).slice(0, n);

/** « AAAA-MM-JJ » en UTC. */
function dayKey(date) {
  const d = date instanceof Date ? date : new Date(date || Date.now());
  if (Number.isNaN(d.getTime())) return dayKey(new Date());
  return d.toISOString().slice(0, 10);
}

/** Décale un jour UTC de n jours (n négatif = dans le passé). */
function shiftDay(day, n) {
  const d = new Date(`${day}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return dayKey(d);
}

function analyticsSecret() {
  return (
    process.env.SITE_ANALYTICS_SECRET
    || process.env.JWT_SECRET
    || 'hopetsit-site-analytics-fallback'
  );
}

/**
 * Sel du jour = HMAC(secret serveur, « AAAA-MM-JJ »).
 * Il change à minuit UTC : deux visites du même appareil à 48 h d'écart
 * donnent deux empreintes sans lien possible.
 */
function dailySalt(day) {
  return crypto.createHmac('sha256', analyticsSecret()).update(String(day)).digest('hex');
}

/**
 * Empreinte visiteur : sha256(sel du jour + IP + user-agent), 16 hex.
 * Irréversible (le sel est secret ET change chaque jour). L'IP et l'UA ne
 * sortent jamais de cette fonction.
 */
function visitorFingerprint(ip, userAgent, day) {
  const d = day || dayKey(new Date());
  return crypto
    .createHash('sha256')
    .update(`${dailySalt(d)}|${str(ip)}|${str(userAgent)}`)
    .digest('hex')
    .slice(0, 16);
}

// Robots évidents : ils ne sont pas des visiteurs et fausseraient tout.
const BOT_RE = new RegExp(
  [
    'bot', 'crawl', 'spider', 'slurp', 'preview', 'facebookexternalhit',
    'headless', 'phantom', 'puppeteer', 'playwright', 'lighthouse', 'pingdom',
    'gtmetrix', 'monitor', 'scrap', 'curl', 'wget', 'python-requests',
    'go-http-client', 'java/', 'okhttp', 'axios', 'node-fetch', 'postman',
    'whatsapp', 'telegrambot', 'discordbot', 'slackbot', 'embedly', 'quora link',
    'skypeuripreview', 'bingpreview', 'yandex', 'baidu', 'ahrefs', 'semrush',
    'mj12', 'dotbot', 'petalbot', 'applebot', 'google-inspectiontool',
  ].join('|'),
  'i',
);

/** Vrai pour un robot évident (ou un user-agent absent = script). */
function isBotUserAgent(ua) {
  const s = str(ua).trim();
  if (!s) return true;
  return BOT_RE.test(s);
}

/** mobile / tablet / desktop d'après le user-agent. */
function deviceFromUserAgent(ua) {
  const s = str(ua);
  if (!s) return 'desktop';
  if (/iPad|Tablet|PlayBook|Silk/i.test(s)) return 'tablet';
  if (/Android/i.test(s) && !/Mobi/i.test(s)) return 'tablet';
  if (/Mobi|Android|iPhone|iPod|IEMobile|Opera Mini/i.test(s)) return 'mobile';
  return 'desktop';
}

/** Ne garde que le nom d'hôte, que l'entrée soit une URL ou déjà un hôte. */
function hostOf(value) {
  let s = str(value).trim();
  if (!s) return '';
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(s) || s.startsWith('//')) {
    try {
      s = new URL(s.startsWith('//') ? `https:${s}` : s).hostname;
    } catch (_) {
      return '';
    }
  }
  s = s.split('/')[0].split('?')[0].split('#')[0].split('@').pop();
  s = s.replace(/:\d+$/, '').replace(/^www\./i, '').toLowerCase();
  if (!/^[a-z0-9.-]+\.[a-z]{2,}$/.test(s)) return '';
  return s.slice(0, MAX_HOST);
}

/**
 * Chemin propre : « / » en tête, sans query string, sans fragment, ≤ 200 car.
 * Retourne '' si le chemin n'appartient pas au site (URL absolue, chemin
 * privé, caractères interdits) → l'événement est alors ignoré.
 */
function cleanPath(value) {
  let s = str(value).trim();
  if (!s) return '';
  // URL complète du site : on retombe sur le chemin. Tout autre domaine sort.
  if (/^https?:\/\//i.test(s)) {
    try {
      const u = new URL(s);
      if (!/(^|\.)hopetsit\.com$/i.test(u.hostname)) return '';
      s = u.pathname;
    } catch (_) {
      return '';
    }
  }
  if (s.startsWith('//')) return ''; // protocole-relatif → autre domaine
  if (!s.startsWith('/')) return '';
  s = s.split('?')[0].split('#')[0];
  if (/[\s<>"'\\]/.test(s)) return '';
  if (s.length > 1) s = s.replace(/\/+$/, '') || '/';
  s = s.slice(0, MAX_PATH);
  const lower = s.toLowerCase();
  if (EXCLUDED_PREFIXES.some((p) => lower === p || lower.startsWith(`${p}/`))) return '';
  return s;
}

/** Code langue du site, sinon ''. */
function cleanLang(value) {
  const s = str(value).trim().toLowerCase().slice(0, 5).split('-')[0];
  return LANGS.includes(s) ? s : '';
}

/** Paramètre utm : minuscules, ≤ 80 caractères, caractères inoffensifs. */
function cleanUtm(value) {
  const s = clip(value, MAX_UTM).trim().toLowerCase();
  if (!s) return '';
  return s.replace(/[^\w .+%@:/-]+/g, '').slice(0, MAX_UTM);
}

const PAID_MEDIUMS = ['paid', 'cpc', 'ppc', 'paidsocial', 'paid_social', 'cpm', 'ads'];

const isMetaish = (s) => {
  if (!s) return false;
  if (/meta|facebook|instagram/.test(s)) return true;
  const tokens = s.split(/[^a-z0-9]+/).filter(Boolean);
  return tokens.includes('fb') || tokens.includes('ig');
};
const isGoogleish = (s) => Boolean(s) && /google|adwords|gads/.test(s);
const isPaidMedium = (m) => {
  if (!m) return false;
  const tokens = m.split(/[^a-z0-9]+/).filter(Boolean);
  return PAID_MEDIUMS.includes(m) || tokens.some((tk) => PAID_MEDIUMS.includes(tk));
};

/**
 * Catégorie de source. Une seule règle compte vraiment pour Daniel :
 * tout ce qui vient d'une pub Meta doit atterrir dans « meta_ads ».
 *
 *   fbclid présent (le site envoie us:'fbclid')      → meta_ads
 *   gclid présent  (le site envoie us:'gclid')       → google_ads
 *   utm_source meta/facebook/instagram/fb/ig + utm_medium payant → meta_ads
 *   utm_source google + utm_medium payant            → google_ads
 *   referrer google                                  → google
 *   referrer facebook / instagram sans utm           → facebook / instagram
 *   rien du tout                                     → direct
 */
function classifySource({ utmSource, utmMedium, refHost } = {}) {
  const us = str(utmSource).trim().toLowerCase();
  const um = str(utmMedium).trim().toLowerCase();
  const host = str(refHost).trim().toLowerCase();

  if (us === 'fbclid') return 'meta_ads';
  if (us === 'gclid') return 'google_ads';

  if (us) {
    if (isMetaish(us)) return isPaidMedium(um) ? 'meta_ads' : (/instagram|(^|[^a-z])ig([^a-z]|$)/.test(us) ? 'instagram' : 'facebook');
    if (isGoogleish(us)) return isPaidMedium(um) ? 'google_ads' : 'google';
    return 'other';
  }

  if (host) {
    if (/(^|\.)google\./.test(host) || host === 'google' || /(^|\.)googleadservices\./.test(host)) return 'google';
    if (/(^|\.)(facebook\.com|fb\.com|fb\.me|facebook\.net)$/.test(host)) return 'facebook';
    if (/(^|\.)instagram\.com$/.test(host)) return 'instagram';
    if (/(^|\.)hopetsit\.com$/.test(host)) return 'direct'; // navigation interne
    return 'other';
  }

  return 'direct';
}

/**
 * Valide et normalise le corps minuscule envoyé par le site :
 *   { t, p, l, r, us, um, uc, s, lb }
 * Retourne null si l'événement doit être ignoré (silencieusement, 204).
 */
function buildEvent(body, { ip, userAgent, now } = {}) {
  const b = body && typeof body === 'object' ? body : {};
  // Comparaison stricte, sans nettoyage : le site envoie une des 3 valeurs.
  const type = str(b.t);
  if (!EVENT_TYPES.includes(type)) return null;

  const path = cleanPath(b.p);
  if (!path) return null;

  const utmSource = cleanUtm(b.us);
  const utmMedium = cleanUtm(b.um);
  const utmCampaign = cleanUtm(b.uc);
  const refHost = hostOf(b.r);
  const day = dayKey(now || new Date());

  const store = STORES.includes(str(b.s).trim().toLowerCase())
    ? str(b.s).trim().toLowerCase()
    : '';

  return {
    type,
    path,
    lang: cleanLang(b.l),
    device: deviceFromUserAgent(userAgent),
    source: classifySource({ utmSource, utmMedium, refHost }),
    utmSource,
    utmMedium,
    utmCampaign,
    refHost,
    store: type === 'store_click' ? (store || 'other') : '',
    label: type === 'cta_click' ? clip(b.lb, MAX_LABEL).trim() : '',
    day,
    visitor: visitorFingerprint(ip, userAgent, day),
    createdAt: now instanceof Date ? now : new Date(),
  };
}

siteEventSchema.statics.EVENT_TYPES = EVENT_TYPES;
siteEventSchema.statics.DEVICES = DEVICES;
siteEventSchema.statics.SOURCES = SOURCES;
siteEventSchema.statics.STORES = STORES;
siteEventSchema.statics.LANGS = LANGS;
siteEventSchema.statics.EXCLUDED_PREFIXES = EXCLUDED_PREFIXES;
siteEventSchema.statics.dayKey = dayKey;
siteEventSchema.statics.shiftDay = shiftDay;
siteEventSchema.statics.dailySalt = dailySalt;
siteEventSchema.statics.visitorFingerprint = visitorFingerprint;
siteEventSchema.statics.isBotUserAgent = isBotUserAgent;
siteEventSchema.statics.deviceFromUserAgent = deviceFromUserAgent;
siteEventSchema.statics.hostOf = hostOf;
siteEventSchema.statics.cleanPath = cleanPath;
siteEventSchema.statics.cleanLang = cleanLang;
siteEventSchema.statics.cleanUtm = cleanUtm;
siteEventSchema.statics.classifySource = classifySource;
siteEventSchema.statics.buildEvent = buildEvent;

module.exports = mongoose.model('SiteEvent', siteEventSchema);
