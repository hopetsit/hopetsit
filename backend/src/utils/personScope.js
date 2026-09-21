/**
 * v576 — PORTÉE « PERSONNE » (multi-rôles), version EN LOT.
 *
 * Rappel du modèle : une personne = jusqu'à TROIS documents Mongo (Owner /
 * Sitter / Walker) reliés par l'e-mail (et l'`oldId` hérité). Tout ce qui
 * appartient à l'humain — amitiés, demandes, blocages, PawSpots, favoris,
 * PawPoints — doit donc être lu sur l'ENSEMBLE du groupe, et affiché UNE
 * seule fois par humain.
 *
 * `identityGroup(id)` (utils/identityGroup.js) fait déjà ce travail pour UNE
 * personne, en 6 requêtes. Appelé dans une boucle sur 200 amis, cela ferait
 * 1 200 requêtes : c'est exactement ce que faisait `/friends/live-positions`.
 * Ce module résout N personnes en **6 requêtes au total**, quelle que soit la
 * taille de la liste.
 *
 *   personIndex([...ids]) → Map<idDeN'importeQuelRôle, {
 *     key,          // identifiant stable de la PERSONNE ('e:<email>'…)
 *     ids: [String],// tous ses ids de rôle
 *     set: Set,     // les mêmes, pour un test O(1)
 *     docs: [{ id, model, lastSeenAt }],
 *     roles: ['owner'|'sitter'|'walker'],
 *     activeRole,   // rôle vu le plus récemment (affichage)
 *   }>
 *
 * Aucune écriture, aucune migration : ce module ne fait que LIRE.
 */
const logger = require('./logger');
const { identityGroup } = require('./identityGroup');

const MODEL_NAMES = ['Owner', 'Sitter', 'Walker'];
const ROLE_OF_MODEL = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };

function models() {
  return {
    Owner: require('../models/Owner'),
    Sitter: require('../models/Sitter'),
    Walker: require('../models/Walker'),
  };
}

/**
 * v576 — petit cache mémoire (30 s) des groupes d'identité.
 *
 * `isInSameFamily` et `hasActivePawFollow` sont appelés UNE FOIS PAR AMI dans
 * `/friends/live-positions` ; sans cache, chaque appel relancerait les
 * 6 requêtes d'`identityGroup` et la PawMap deviendrait injouable. Le lien
 * entre les 3 documents d'une personne ne change qu'à la création d'un profil
 * ou à un changement d'e-mail : 30 secondes de retard sont sans conséquence,
 * et le processus Render redémarre régulièrement.
 */
const TTL_MS = 30 * 1000;
const MAX_ENTRIES = 5000;
const _cache = new Map(); // id → { at, ids }

function _cacheGet(id) {
  const hit = _cache.get(id);
  if (!hit) return null;
  if (Date.now() - hit.at > TTL_MS) {
    _cache.delete(id);
    return null;
  }
  return hit.ids;
}

function _cacheSet(id, ids) {
  if (_cache.size >= MAX_ENTRIES) {
    // Purge simple : on vide, plutôt que de maintenir un LRU pour un cache
    // de 30 secondes.
    _cache.clear();
  }
  _cache.set(id, { at: Date.now(), ids });
}

/** Vide le cache (tests, ou après un changement d'e-mail). */
function resetPersonCache() {
  _cache.clear();
}

/** Tous les ids de rôle de la personne connectée (au moins l'id passé). */
async function personIds(userId) {
  const id = String(userId || '');
  if (!id) return [];
  const cached = _cacheGet(id);
  if (cached) return cached;
  const g = await identityGroup(id);
  for (const x of g.ids) _cacheSet(String(x), g.ids);
  return g.ids;
}

const SELECT = 'email oldId lastSeenAt';

function keyOfDoc(d) {
  if (d.email) return `e:${String(d.email).toLowerCase().trim()}`;
  if (d.oldId != null) return `o:${String(d.oldId)}`;
  return `i:${String(d._id)}`;
}

function finalize(entry) {
  entry.set = new Set(entry.ids);
  entry.roles = [...new Set(entry.docs.map((d) => ROLE_OF_MODEL[d.model]))];
  let best = null;
  for (const d of entry.docs) {
    const t = d.lastSeenAt ? new Date(d.lastSeenAt).getTime() : 0;
    if (!best || t > best.t) best = { t, model: d.model };
  }
  entry.activeRole = best ? ROLE_OF_MODEL[best.model] : null;
  return entry;
}

/**
 * Résout en lot le groupe d'identité de plusieurs personnes.
 * Ne lève jamais : en cas d'échec, chaque id devient sa propre personne.
 */
async function personIndex(inputIds) {
  const wanted = [...new Set((inputIds || []).filter(Boolean).map(String))];
  const out = new Map();
  if (!wanted.length) return out;
  const M = models();

  const fetch = (filter) =>
    Promise.all(
      MODEL_NAMES.map((n) =>
        M[n]
          .find(filter)
          .select(SELECT)
          .lean()
          .then((rows) => rows.map((d) => ({ d, model: n })))
          .catch(() => []),
      ),
    ).then((r) => r.flat());

  try {
    // 1) Les documents demandés (3 requêtes).
    const first = await fetch({ _id: { $in: wanted } });

    // 2) Leurs frères, par e-mail ou oldId (3 requêtes).
    const emails = [...new Set(first.map((x) => x.d.email).filter(Boolean))];
    const oldIds = [
      ...new Set(
        first.map((x) => x.d.oldId).filter((v) => v != null).map(String),
      ),
    ];
    const or = [];
    if (emails.length) or.push({ email: { $in: emails } });
    if (oldIds.length) or.push({ oldId: { $in: oldIds } });
    const siblings = or.length ? await fetch({ $or: or }) : [];

    // 3) Regroupement par personne.
    const byKey = new Map();
    const seen = new Set();
    for (const { d, model } of [...first, ...siblings]) {
      const id = String(d._id);
      if (seen.has(id)) continue;
      seen.add(id);
      const key = keyOfDoc(d);
      let entry = byKey.get(key);
      if (!entry) {
        entry = { key, ids: [], docs: [] };
        byKey.set(key, entry);
      }
      entry.ids.push(id);
      entry.docs.push({ id, model, lastSeenAt: d.lastSeenAt || null });
    }
    for (const entry of byKey.values()) {
      finalize(entry);
      for (const id of entry.ids) {
        out.set(id, entry);
        _cacheSet(id, entry.ids);
      }
    }
  } catch (e) {
    logger.warn(`[personScope] personIndex failed : ${e?.message || e}`);
  }

  // Repli sûr : un id introuvable (compte supprimé, lookup en échec) reste
  // une personne à lui seul — on ne perd jamais une entrée.
  for (const id of wanted) {
    if (out.has(id)) continue;
    out.set(
      id,
      finalize({ key: `i:${id}`, ids: [id], docs: [] }),
    );
  }
  return out;
}

/** Clé de personne d'un id (repli : l'id lui-même). */
function personKey(index, id) {
  const e = index.get(String(id));
  return e ? e.key : `i:${String(id)}`;
}

/** Les deux ids désignent-ils le même humain ? */
function samePerson(index, a, b) {
  if (!a || !b) return false;
  if (String(a) === String(b)) return true;
  return personKey(index, a) === personKey(index, b);
}

module.exports = {
  personIds,
  personIndex,
  personKey,
  samePerson,
  resetPersonCache,
  ROLE_OF_MODEL,
};
