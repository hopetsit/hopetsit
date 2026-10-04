/**
 * 610 (PAM, 04/10/2026) — Daniel : « quand je clique sur "1 te suit", il ne
 * me dit pas QUI me suit ». Liste des personnes qui suivent MON direct en ce
 * moment : [{ id, name, avatar, role, since }].
 *   · une personne = une entrée (ses 3 profils comptent pour un) ;
 *   · prénom si c'est un ami, sinon « Prénom I. » (règle publique du 28/09) ;
 *   · jamais d'e-mail ;
 *   · un compte +test n'est montré qu'à ses amis (il compte quand même dans
 *     le nombre, inchangé pour les apps ≤ 609).
 */
const logger = require('./logger');
const f = require('./followers589');

const ROLE_BY_MODEL = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };

function firstName(doc) {
  const fn = String(doc.firstName || '').trim();
  if (fn) return fn;
  return String(doc.name || '').trim().split(/\s+/)[0] || '';
}

function avatarOf(doc) {
  const a = doc.avatar || doc.profilePicture;
  return (a && (typeof a === 'object' ? a.url : a)) || '';
}

/**
 * @param {string[]} myIds tous mes ids de profil
 * @param {{ friendIds?: Set<string>, now?: number, load?: Function }} opts
 *   `load(ids)` → [{ d, role }] (injectable en test)
 */
async function followersOf(myIds, { friendIds, now = Date.now(), load } = {}) {
  const entries = f.list(f.personKey(myIds), now);
  if (!entries.length) return [];
  const ids = entries.map((e) => e.id);
  let docs = [];
  try {
    docs = await (load || _load)(ids);
  } catch (e) {
    logger.warn(`[followersList610] lecture impossible : ${e?.message || e}`);
    return [];
  }
  const byId = new Map(docs.map((x) => [String(x.d._id), x]));
  const friends = friendIds || new Set();
  const { isTestAccountDoc } = require('./testAccountMap604');
  const { publicNameFields } = require('./publicName2809');
  const out = [];
  for (const e of entries) {
    const x = byId.get(String(e.id));
    if (!x) continue;
    const isFriend = friends.has(String(e.id)) || friends.has(String(e.key));
    if (isTestAccountDoc(x.d) && !isFriend) continue;
    out.push({
      id: String(x.d._id),
      name: isFriend ? firstName(x.d) : publicNameFields(x.d).name,
      avatar: avatarOf(x.d),
      role: x.role,
      since: new Date(e.since).toISOString(),
      isFriend,
    });
  }
  return out;
}

async function _load(ids) {
  const models = {
    Owner: require('../models/Owner'),
    Sitter: require('../models/Sitter'),
    Walker: require('../models/Walker'),
  };
  const rows = await Promise.all(Object.entries(models).map(([name, M]) => M
    .find({ _id: { $in: ids } })
    .select('name firstName lastName avatar profilePicture email')
    .lean()
    .then((r) => (r || []).map((d) => ({ d, role: ROLE_BY_MODEL[name] })))
    .catch(() => [])));
  return rows.flat();
}

module.exports = { followersOf };
