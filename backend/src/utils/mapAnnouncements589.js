/**
 * v589 — fenêtres d'annonce de la PawMap : règles pures (testées) + accès base.
 * Voir models/MapAnnouncement.js.
 */
const { LANGS, KINDS, ROLES, PLATFORMS } = require('../models/MapAnnouncement');

const MAX_TITLE = 80;
const MAX_BODY = 400;

/** « 23.1.578+589 » → 589 ; « web » ou vide → null. */
function buildFromHeader(v) {
  const m = String(v || '').trim().match(/\+(\d{1,6})$/);
  return m ? Number(m[1]) : null;
}

function pickLang(map, lang) {
  if (!map || typeof map !== 'object') return '';
  const l = String(lang || '').slice(0, 2).toLowerCase();
  return String(map[l] || map.en || map.fr || '').trim();
}

/** L'annonce s'adresse-t-elle à cet appareil, maintenant ? */
function isVisibleTo(a, { role, platform, build, email, now = new Date() } = {}) {
  if (!a || a.active === false) return false;
  const only = Array.isArray(a.onlyEmails) ? a.onlyEmails : [];
  if (only.length && !only.includes(String(email || '').toLowerCase().trim())) return false;
  if (a.startsAt && new Date(a.startsAt) > now) return false;
  if (a.endsAt && new Date(a.endsAt) <= now) return false;
  const roles = Array.isArray(a.roles) ? a.roles : [];
  if (roles.length && !roles.includes(String(role || '').toLowerCase())) return false;
  const plats = Array.isArray(a.platforms) ? a.platforms : [];
  if (plats.length && !plats.includes(String(platform || '').toLowerCase())) return false;
  if (a.maxBuild != null && Number.isFinite(Number(a.maxBuild))) {
    // Build inconnu (site, vieille app sans en-tête) : on montre — c'est
    // justement le cas d'un téléphone à mettre à jour.
    if (build != null && build >= Number(a.maxBuild)) return false;
  }
  return true;
}

/** Forme envoyée à l'app : textes dans SA langue. */
function toPublic(a, lang) {
  return {
    id: String(a._id),
    title: pickLang(a.title, lang),
    body: pickLang(a.body, lang),
    kind: a.kind || 'info',
    url: a.url || '',
    updatedAt: a.updatedAt ? new Date(a.updatedAt).toISOString() : null,
  };
}

function cleanTexts(input, max) {
  const out = {};
  if (input && typeof input === 'object') {
    for (const l of LANGS) {
      const v = input[l];
      if (typeof v === 'string' && v.trim()) out[l] = v.trim().slice(0, max);
    }
  }
  return out;
}

/**
 * Valide le corps envoyé par l'admin. Renvoie { value } ou { error }.
 * [partial] = PATCH : seuls les champs présents sont contrôlés.
 */
function validate(body, { partial = false } = {}) {
  const b = body && typeof body === 'object' ? body : {};
  const v = {};
  if (!partial || 'title' in b) v.title = cleanTexts(b.title, MAX_TITLE);
  if (!partial || 'body' in b) v.body = cleanTexts(b.body, MAX_BODY);
  if (!partial && !(v.title.fr || v.title.en) && !(v.body.fr || v.body.en)) {
    return { error: 'Écris au moins un titre ou un message en français ou en anglais.' };
  }
  if ('kind' in b) {
    if (!KINDS.includes(b.kind)) return { error: `kind ∈ ${KINDS.join(', ')}` };
    v.kind = b.kind;
  }
  if ('url' in b) {
    const url = String(b.url || '').trim();
    if (url && !/^https:\/\//i.test(url)) return { error: 'Le lien doit commencer par https://' };
    v.url = url.slice(0, 500);
  }
  const kind = v.kind || b.kind || 'info';
  if (!partial && kind === 'link' && !v.url) return { error: 'Un lien est requis pour ce type.' };
  if ('roles' in b) v.roles = (Array.isArray(b.roles) ? b.roles : []).map(String).filter((r) => ROLES.includes(r));
  if ('onlyEmails' in b) {
    const list = Array.isArray(b.onlyEmails) ? b.onlyEmails : String(b.onlyEmails || '').split(/[\s,;]+/);
    v.onlyEmails = list.map((e) => String(e).toLowerCase().trim()).filter((e) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)).slice(0, 20);
  }
  if ('platforms' in b) v.platforms = (Array.isArray(b.platforms) ? b.platforms : []).map(String).filter((p) => PLATFORMS.includes(p));
  if ('maxBuild' in b) {
    const n = b.maxBuild === null || b.maxBuild === '' ? null : Number(b.maxBuild);
    if (n !== null && (!Number.isInteger(n) || n < 1)) return { error: 'maxBuild doit être un numéro de build.' };
    v.maxBuild = n;
  }
  if ('active' in b) v.active = b.active === true || b.active === 'true';
  for (const k of ['startsAt', 'endsAt']) {
    if (k in b) {
      if (b[k] === null || b[k] === '') v[k] = null;
      else {
        const d = new Date(b[k]);
        if (Number.isNaN(d.getTime())) return { error: `${k} : date invalide.` };
        v[k] = d;
      }
    }
  }
  return { value: v };
}

module.exports = { buildFromHeader, pickLang, isVisibleTo, toPublic, validate, MAX_TITLE, MAX_BODY };
