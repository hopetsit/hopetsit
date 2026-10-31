/**
 * 3110 (ADA) — RÈGLE DE DANIEL du 31/10 : « il faut toujours regarder les 3 profils pour que tout
 * soit compatible ». Une PERSONNE = les profils propriétaire + gardien + promeneur qui portent le
 * même e-mail ; une info vraie sur un profil (app installée, connexion, appareil…) vaut pour la
 * personne. Fonction serveur PARTAGÉE (lecture seule, aucune donnée personnelle renvoyée) :
 *   · personGroups([{ role, id }]) → Map 'role:id' → { key, ids: { owner, sitter, walker }, allIds, device }
 *   · personOf(role, id)          → le groupe d'un seul profil
 * device = { has, platform, appBuild, at } : app installée si un profil a un jeton push (fcmTokens)
 * ou un appareil enregistré (fcmDevices) ; plateforme / build du plus récent appareil connu.
 */
const ROLES = ['owner', 'sitter', 'walker'];
const isId = (s) => /^[a-f0-9]{24}$/i.test(String(s || ''));

function models() {
  return { owner: require('../models/Owner'), sitter: require('../models/Sitter'), walker: require('../models/Walker') };
}

const plainOf = (stored) => {
  try { return String(require('./encryption').decrypt(stored || '') || '').trim().toLowerCase(); } catch (_) { return ''; }
};

function deviceOf(docs) {
  let has = false; let best = null;
  for (const d of docs) {
    if (Array.isArray(d.fcmTokens) && d.fcmTokens.length) has = true;
    for (const dev of (Array.isArray(d.fcmDevices) ? d.fcmDevices : [])) {
      if (!dev || !dev.token) continue;
      has = true;
      if (!best || new Date(dev.at || 0) > new Date(best.at || 0)) best = dev;
    }
  }
  return { has, platform: best ? String(best.platform || '') : '', appBuild: best ? Number(best.appBuild) || 0 : 0, at: best ? best.at || null : null };
}

/**
 * @param {{role:string, id:string}[]} entries
 * @returns {Promise<Map<string, {key:string, ids:{owner:string[],sitter:string[],walker:string[]}, allIds:string[], device:object}>>}
 */
async function personGroups(entries) {
  const out = new Map();
  const M = models();
  const list = (entries || []).filter((e) => e && ROLES.includes(e.role) && isId(e.id));
  if (!list.length) return out;
  // 1) e-mail (stocké + en clair) de chaque profil demandé
  const own = new Map();
  for (const role of ROLES) {
    const ids = [...new Set(list.filter((e) => e.role === role).map((e) => String(e.id)))];
    if (!ids.length) continue;
    // eslint-disable-next-line no-await-in-loop
    const docs = await M[role].find({ _id: { $in: ids } }).select('email fcmTokens fcmDevices').lean();
    for (const d of docs) own.set(`${role}:${d._id}`, d);
  }
  const emails = new Set();
  for (const d of own.values()) {
    const s = String(d.email || '').trim().toLowerCase();
    if (s) emails.add(s);
    const p = plainOf(d.email); if (p) emails.add(p);
  }
  // 2) tous les profils de ces e-mails (les 3 rôles)
  const byEmail = new Map(); // email stocké ou clair → [{role, doc}]
  if (emails.size) {
    const found = await Promise.all(ROLES.map((role) => M[role].find({ email: { $in: [...emails] } }).select('email fcmTokens fcmDevices').lean()
      .then((docs) => docs.map((doc) => ({ role, doc })))));
    for (const x of found.flat()) {
      for (const k of [String(x.doc.email || '').trim().toLowerCase(), plainOf(x.doc.email)].filter(Boolean)) {
        if (!byEmail.has(k)) byEmail.set(k, []);
        byEmail.get(k).push(x);
      }
    }
  }
  for (const e of list) {
    const key = `${e.role}:${e.id}`;
    const self = own.get(key);
    const members = new Map();
    if (self) {
      members.set(key, { role: e.role, doc: self });
      for (const k of [String(self.email || '').trim().toLowerCase(), plainOf(self.email)].filter(Boolean)) {
        for (const x of byEmail.get(k) || []) members.set(`${x.role}:${x.doc._id}`, x);
      }
    }
    const ids = { owner: [], sitter: [], walker: [] };
    for (const x of members.values()) ids[x.role].push(String(x.doc._id));
    if (!members.size) ids[e.role].push(String(e.id));
    const allIds = [...new Set([...ids.owner, ...ids.sitter, ...ids.walker])];
    out.set(key, { key, ids, allIds, device: deviceOf([...members.values()].map((x) => x.doc)) });
  }
  return out;
}

async function personOf(role, id) {
  const m = await personGroups([{ role, id: String(id) }]);
  return m.get(`${role}:${id}`) || { key: `${role}:${id}`, ids: { owner: [], sitter: [], walker: [], [role]: [String(id)] }, allIds: [String(id)], device: { has: false, platform: '', appBuild: 0, at: null } };
}

module.exports = { personGroups, personOf, deviceOf, ROLES };
