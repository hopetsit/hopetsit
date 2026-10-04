/**
 * v589 — « QUI SUIT MON DIRECT ? » (Daniel, 26/09 : « quand on me suit, comment
 * je sais que c'est activé ? »). Le téléphone qui SUIT un direct le signale
 * (POST /friends/follow-presence) et le rafraîchit tant qu'il suit ; la
 * personne suivie reçoit le NOMBRE de personnes qui la suivent
 * (`map:followers`). 610 : et QUI (prénom, photo), voir followersList610.js. Mémoire vive seulement : une présence
 * non rafraîchie depuis 3 min disparaît d'elle-même (téléphone éteint, app
 * tuée), rien n'est écrit en base.
 */
const TTL_MS = 3 * 60 * 1000;

/** personKey suivie → Map(followerKey → { at: dernier signe de vie, since:
 *  début du suivi, id: profil qui suit (610 : pour dire QUI suit) }) */
const followers = new Map();

function _prune(key, now) {
  const m = followers.get(key);
  if (!m) return 0;
  for (const [f, e] of m) if (now - e.at > TTL_MS) m.delete(f);
  if (!m.size) followers.delete(key);
  return m.size;
}

/** Marque (on) ou retire (off) un suiveur. Renvoie le nombre de suiveurs.
 *  610 — [followerId] = le profil qui suit (nom et photo), facultatif. */
function touch(targetKey, followerKey, on, now = Date.now(), followerId = '') {
  if (!targetKey || !followerKey || targetKey === followerKey) return count(targetKey, now);
  if (on) {
    if (!followers.has(targetKey)) followers.set(targetKey, new Map());
    const m = followers.get(targetKey);
    const prev = m.get(followerKey);
    m.set(followerKey, {
      at: now,
      since: prev && now - prev.at <= TTL_MS ? prev.since : now,
      id: String(followerId || (prev && prev.id) || followerKey),
    });
  } else if (followers.has(targetKey)) {
    followers.get(targetKey).delete(followerKey);
  }
  return _prune(targetKey, now);
}

/** 610 — qui me suit EN CE MOMENT : [{ key, id, since }] (une personne = une
 *  entrée : la clé est celle de la personne, ses 3 profils comptent pour un). */
function list(targetKey, now = Date.now()) {
  if (!targetKey) return [];
  _prune(targetKey, now);
  const m = followers.get(targetKey);
  if (!m) return [];
  return [...m.entries()]
    .map(([key, e]) => ({ key, id: e.id, since: e.since }))
    .sort((a, b) => a.since - b.since);
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

module.exports = { touch, count, list, personKey, TTL_MS, _resetForTests };
