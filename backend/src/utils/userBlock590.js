/**
 * v590 — Daniel (26/09) : « rajoute dans Utilisateurs Bloquer et un onglet
 * Profils bloqués sous Promotions, pour éviter les spams si on m'attaque de
 * bots ». Bloquer = `status: 'banned'` sur les 3 profils de la personne
 * (même e-mail) : le middleware d'auth et le login refusent déjà un compte
 * banni (« Account banned. »). Rien n'est supprimé : Débloquer rend l'accès.
 */
const MODELS = () => ({
  owner: require('../models/Owner'),
  sitter: require('../models/Sitter'),
  walker: require('../models/Walker'),
});
const MODEL_ROLE = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };

/** Tous les profils (rôle + id) de la personne qui porte ce profil. */
async function personProfiles(role, id) {
  const { identityGroup } = require('./identityGroup');
  const g = await identityGroup(String(id));
  const list = g.docs.map((d) => ({ role: MODEL_ROLE[d.model], id: d.id })).filter((d) => d.role);
  if (!list.some((d) => d.id === String(id))) list.push({ role, id: String(id) });
  return list;
}

async function setBlocked(role, id, blocked, reason = '') {
  const M = MODELS();
  if (!M[role]) return { ok: false, status: 400, error: 'rôle inconnu' };
  if (!(await M[role].exists({ _id: id }))) return { ok: false, status: 404, error: 'profil introuvable' };
  const profiles = await personProfiles(role, id);
  const update = blocked
    ? { status: 'banned', banReason: String(reason || '').slice(0, 300), bannedAt: new Date() }
    : { status: 'active', banReason: '', bannedAt: null };
  const done = [];
  for (const p of profiles) {
    // eslint-disable-next-line no-await-in-loop
    const r = await M[p.role].updateOne({ _id: p.id }, { $set: update });
    if (r.matchedCount) done.push(p);
  }
  return { ok: true, blocked, profiles: done };
}

/** Profils bloqués (bannis ou suspendus), les plus récents d'abord. */
async function listBlocked({ limit = 500 } = {}) {
  const M = MODELS();
  const sel = 'name email status banReason bannedAt city country createdAt';
  const all = [];
  for (const role of Object.keys(M)) {
    // eslint-disable-next-line no-await-in-loop
    const docs = await M[role].find({ status: { $in: ['banned', 'suspended'] } })
      .select(sel).sort({ bannedAt: -1 }).limit(limit).lean();
    for (const d of docs) all.push({ ...d, role });
  }
  all.sort((a, b) => new Date(b.bannedAt || 0) - new Date(a.bannedAt || 0));
  return all.slice(0, limit);
}

module.exports = { setBlocked, listBlocked, personProfiles };
