/**
 * v589 — Daniel : « je vois la même personne à deux endroits différents ».
 * Deux amitiés peuvent relier les mêmes personnes sous deux couples de rôles.
 * GET /friends garde la plus récente (dedupeFriendshipsByPerson) ; le direct
 * (socket + GET /friends/live-positions) prenait la PREMIÈRE trouvée : l'id
 * de la position (`viewAsId`) différait de celui de la liste d'amis, et l'app
 * dessinait un second rond. Même ordre partout : la plus récente d'abord.
 */
function friendshipsPreferredFirst(list) {
  const t = (f) => new Date(f.updatedAt || f.createdAt || 0).getTime();
  return [...(list || [])].sort((a, b) => t(b) - t(a));
}

/**
 * v589 — retire d'une liste de points de carte TOUS ceux de la personne qui
 * regarde (id, personIds ou roles[].id dans [mine]).
 */
function withoutViewer(members, mine) {
  const set = mine instanceof Set ? mine : new Set((mine || []).map(String));
  const isMine = (m) => set.has(String(m && m.id))
    || ((m && m.personIds) || []).some((x) => set.has(String(x)))
    || ((m && m.roles) || []).some((r) => r && set.has(String(r.id)));
  return (members || []).filter((m) => !isMine(m));
}

module.exports = { friendshipsPreferredFirst, withoutViewer };
