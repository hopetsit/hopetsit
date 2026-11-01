/**
 * 0111 (ADA) — RÈGLE DE DANIEL du 31/10 « toujours les 3 profils » appliquée aux listes de l'admin.
 * Pour chaque profil demandé, les faits de la PERSONNE (profils propriétaire + gardien + promeneur
 * au même e-mail, regroupés par `person3110.personGroups`) :
 *   · roles     : rôles de la personne (ex. ['owner','sitter'])
 *   · devices   : nombre de jetons push DISTINCTS sur tous ses profils (un même téléphone connecté
 *                 en propriétaire puis en gardien ne compte qu'une fois)
 *   · platforms : plateformes connues de ces jetons (ios / android)
 *   · verified  : vrai si l'un de ses profils est vérifié — même règle que la synchro serveur
 *                 `markVerifiedAcrossRoles` (authController), qui pose `verified:true` sur les 3.
 * Lecture seule, aucune donnée personnelle renvoyée.
 */
const { personGroups, ROLES } = require('./person3110');

function models() {
  return { owner: require('../models/Owner'), sitter: require('../models/Sitter'), walker: require('../models/Walker') };
}

/**
 * @param {{role:string, id:string}[]} entries
 * @returns {Promise<Map<string, {roles:string[], devices:number, platforms:string[], verified:boolean, profiles:number}>>}
 */
async function personFacts(entries) {
  const out = new Map();
  const groups = await personGroups(entries);
  if (!groups.size) return out;
  const want = { owner: new Set(), sitter: new Set(), walker: new Set() };
  for (const g of groups.values()) for (const r of ROLES) for (const id of g.ids[r]) want[r].add(id);
  const M = models();
  const docs = new Map();
  await Promise.all(ROLES.map(async (r) => {
    if (!want[r].size) return;
    const list = await M[r].find({ _id: { $in: [...want[r]] } }).select('verified fcmTokens fcmDevices').lean();
    for (const d of list) docs.set(`${r}:${d._id}`, d);
  }));
  for (const [key, g] of groups) {
    const tokens = new Set(); const platforms = new Set(); let verified = false; let profiles = 0;
    const roles = ROLES.filter((r) => g.ids[r].length);
    for (const r of ROLES) {
      for (const id of g.ids[r]) {
        const d = docs.get(`${r}:${id}`);
        if (!d) continue;
        profiles += 1;
        if (d.verified === true) verified = true;
        for (const t of (Array.isArray(d.fcmTokens) ? d.fcmTokens : [])) if (t) tokens.add(String(t));
      }
    }
    for (const r of ROLES) {
      for (const id of g.ids[r]) {
        const d = docs.get(`${r}:${id}`);
        for (const dev of (d && Array.isArray(d.fcmDevices) ? d.fcmDevices : [])) {
          if (dev && dev.token && tokens.has(String(dev.token)) && dev.platform) platforms.add(String(dev.platform));
        }
      }
    }
    out.set(key, { roles, devices: tokens.size, platforms: [...platforms], verified, profiles });
  }
  return out;
}

/**
 * Ajoute `person` ({ roles, devices, platforms, verified, profiles }) à chaque profil d'une liste.
 * Ne change aucun champ existant (le `verified` du profil reste celui du profil).
 */
async function withPerson(rows, roleOf) {
  const list = Array.isArray(rows) ? rows : [];
  const entries = list.map((u) => ({ role: roleOf(u), id: String(u && u._id) }));
  const facts = await personFacts(entries);
  return list.map((u, i) => ({ ...u, person: facts.get(`${entries[i].role}:${entries[i].id}`) || null }));
}

module.exports = { personFacts, withPerson };
