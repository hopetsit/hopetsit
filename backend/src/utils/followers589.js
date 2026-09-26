/**
 * v589 — « QUI SUIT MON DIRECT ? » (Daniel, 26/09 : « quand on me suit, comment
 * je sais que c'est activé ? »). Le téléphone qui SUIT un direct le signale
 * (POST /friends/follow-presence) et le rafraîchit tant qu'il suit ; la
 * personne suivie reçoit le NOMBRE de personnes qui la suivent
 * (`map:followers`), jamais leurs noms. Mémoire vive seulement : une présence
 * non rafraîchie depuis 3 min disparaît d'elle-même (téléphone éteint, app
 * tuée), rien n'est écrit en base.
 */
const TTL_MS = 3 * 60 * 1000;

/** personKey suivie → Map(followerKey → dernier signe de vie en ms) */
const followers = new Map();

function _prune(key, now) {
  const m = followers.get(key);
  if (!m) return 0;
  for (const [f, at] of m) if (now - at > TTL_MS) m.delete(f);
  if (!m.size) followers.delete(key);
  return m.size;
}

/** Marque (on) ou retire (off) un suiveur. Renvoie le nombre de suiveurs. */
function touch(targetKey, followerKey, on, now = Date.now()) {
  if (!targetKey || !followerKey || targetKey === followerKey) return count(targetKey, now);
  if (on) {
    if (!followers.has(targetKey)) followers.set(targetKey, new Map());
    followers.get(targetKey).set(followerKey, now);
  } else if (followers.has(targetKey)) {
    followers.get(targetKey).delete(followerKey);
  }
  return _prune(targetKey, now);
}

function count(targetKey, now = Date.now()) {
  return targetKey ? _prune(targetKey, now) : 0;
}

/** Clé stable d'une personne à partir de tous ses ids de profil. */
function personKey(ids) {
  const list = (ids || []).map(String).filter(Boolean).sort();
  return list[0] || '';
}

function _resetForTests() {
  followers.clear();
}

module.exports = { touch, count, personKey, TTL_MS, _resetForTests };
