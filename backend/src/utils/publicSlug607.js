'use strict';

/**
 * 607 (NEO, 02/10/2026) — LIEN PERSONNEL « hopetsit.com/s/<slug> ».
 *
 * Décision de Daniel (02/10) : un gardien ou un promeneur seul dans sa ville
 * s'inscrit puis repart faute de clients. Réponse : « ramène tes propres
 * clients » — chaque prestataire a un lien à son nom à envoyer à ses voisins.
 *
 * Règles du slug :
 *   · forme « prenom-initiale-ville » (« sasha-b-lyon »), minuscules ASCII,
 *     accents retirés ; jamais le nom de famille complet (même règle que la
 *     fiche publique : prénom + initiale) ;
 *   · UNIQUE sur les gardiens ET les promeneurs (l'URL ne porte pas le rôle) :
 *     suffixe « -2 », « -3 »… en cas de collision ;
 *   · STABLE : créé une fois, au premier appel, puis jamais modifié (même si
 *     la personne change de ville) — un lien imprimé sur une affiche doit
 *     marcher pour toujours ;
 *   · un prénom sans lettre latine (japonais, coréen…) donne « gardien-… » /
 *     « promeneur-… » plutôt qu'un slug vide.
 */

const MAX_BASE = 48;
const RESERVED = new Set(['me', 'api', 'admin', 'new', 'edit', 'poster', 'www', 'sitemap', 'badge']);

function asciiWords(s) {
  return String(s || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/ł/g, 'l').replace(/Ł/g, 'L').replace(/ß/g, 'ss')
    .replace(/æ/gi, 'ae').replace(/œ/gi, 'oe').replace(/ø/gi, 'o')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
}

/** Prénom + initiale + ville → base du slug (sans suffixe). */
function slugBase({ firstName, lastName, name, city } = {}, role = 'sitter') {
  let first = String(firstName || '').trim();
  let last = String(lastName || '').trim();
  if (!first) {
    const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
    first = parts[0] || '';
    if (!last) last = parts.slice(1).join(' ');
  }
  const f = asciiWords(first)[0] || (role === 'walker' ? 'promeneur' : 'gardien');
  const i = (asciiWords(last)[0] || '').charAt(0);
  // « Paris 11e » → « paris » : l'arrondissement ne fait pas partie du lien.
  const cityCore = require('./publicCity607').publicCity(city).split(/[(,/]/)[0];
  const c = asciiWords(cityCore).filter((w) => !/^\d/.test(w)).join('-');
  let base = [f, i, c].filter(Boolean).join('-').replace(/-+/g, '-');
  if (base.length > MAX_BASE) base = base.slice(0, MAX_BASE).replace(/-+$/, '');
  if (RESERVED.has(base)) base = `${base}-hps`;
  return base;
}

/**
 * 02/10 (NEO) — un slug fabriqué AVANT la règle publicCity607 peut contenir
 * une « ville » qui était un e-mail (…-dadaniecka-gmail-com). Il est alors
 * « vicié » : on le remplace (l'ancien répond 404, jamais de redirection qui
 * garderait l'e-mail dans une URL).
 */
function rawCityOf(d) {
  return (d && ((d.homeLocation && d.homeLocation.city) || d.city || (d.location && d.location.city))) || '';
}
function isTaintedSlug(slug, d) {
  if (!slug) return false;
  if (/(^|-)(gmail|hotmail|yahoo|outlook|icloud|live|orange|free|wanadoo|laposte|proton|gmx|aol)(-|$)/.test(slug)
    && /-(com|fr|net|org|es|de|it|pl|pt|co|uk|me)$/.test(slug)) return true;
  const { isUnsafeCity } = require('./publicCity607');
  const raw = rawCityOf(d);
  if (!isUnsafeCity(raw)) return false;
  const words = asciiWords(raw).filter((w) => w.length >= 3);
  return words.some((w) => slug.split('-').includes(w));
}

/** Le slug est-il déjà pris (gardien OU promeneur, autre que `selfId`) ? */
async function slugTaken(slug, selfId) {
  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');
  const q = { publicSlug: slug };
  if (selfId) q._id = { $ne: selfId };
  const [s, w] = await Promise.all([
    Sitter.exists(q),
    Walker.exists(q),
  ]);
  return !!(s || w);
}

/**
 * Rend le slug du document (le crée et l'enregistre s'il n'existe pas).
 * @param {object} doc  document Sitter ou Walker (mongoose ou lean, avec _id)
 * @param {'sitter'|'walker'} role
 * @returns {Promise<string>}
 */
async function ensurePublicSlug(doc, role) {
  if (!doc || !doc._id) throw new Error('ensurePublicSlug: document manquant');
  if (doc.publicSlug && !isTaintedSlug(doc.publicSlug, doc)) return doc.publicSlug;
  const Model = role === 'walker' ? require('../models/Walker') : require('../models/Sitter');

  // Relu en base : un autre appel a pu le créer entre-temps.
  const fresh = await Model.findById(doc._id).select('publicSlug firstName lastName name city location homeLocation').lean();
  if (!fresh) throw new Error('ensurePublicSlug: profil introuvable');
  if (fresh.publicSlug && !isTaintedSlug(fresh.publicSlug, fresh)) return fresh.publicSlug;
  if (fresh.publicSlug) {
    // Slug vicié : retiré, puis recréé sans la « ville » non publiable.
    await Model.updateOne({ _id: fresh._id, publicSlug: fresh.publicSlug }, { $unset: { publicSlug: '' } });
    fresh.publicSlug = undefined;
  }

  const city = (fresh.homeLocation && fresh.homeLocation.city)
    || fresh.city || (fresh.location && fresh.location.city) || '';
  const base = slugBase({ ...fresh, city }, role);

  for (let n = 1; n <= 60; n += 1) {
    const candidate = n === 1 ? base : `${base}-${n}`;
    // eslint-disable-next-line no-await-in-loop
    if (await slugTaken(candidate, fresh._id)) continue;
    try {
      // N'écrit QUE si le champ est encore vide : jamais d'écrasement.
      // eslint-disable-next-line no-await-in-loop
      const r = await Model.updateOne(
        { _id: fresh._id, $or: [{ publicSlug: { $exists: false } }, { publicSlug: null }, { publicSlug: '' }] },
        { $set: { publicSlug: candidate } },
      );
      if (r.modifiedCount === 1) {
        doc.publicSlug = candidate;
        return candidate;
      }
      // Écrit entre-temps par un autre appel : on rend celui-là.
      // eslint-disable-next-line no-await-in-loop
      const again = await Model.findById(fresh._id).select('publicSlug').lean();
      if (again && again.publicSlug) {
        doc.publicSlug = again.publicSlug;
        return again.publicSlug;
      }
    } catch (e) {
      // Course sur l'index unique (E11000) : candidat suivant.
      if (!(e && e.code === 11000)) throw e;
    }
  }
  throw new Error('ensurePublicSlug: aucun slug libre');
}

/** Un slug reçu dans une URL a-t-il une forme acceptable ? */
function isValidSlug(s) {
  return typeof s === 'string' && /^[a-z0-9](?:[a-z0-9-]{0,70}[a-z0-9])?$/.test(s);
}

module.exports = { slugBase, ensurePublicSlug, slugTaken, isValidSlug, asciiWords, isTaintedSlug };
