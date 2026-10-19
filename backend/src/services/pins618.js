/**
 * 618 (ZOE, 19/10/2026) — PINS (décision de Daniel du 19/10 : « podium + 1er
 * Chef de meute »). Contrat : ~/hopetsit-social/PROCHAIN_BUILD_618.md §B.
 *
 *   pins: { podium: 1|2|3|null, firstPackLeader: true|false }
 *
 * · Podium = les 3 premières PERSONNES du classement GÉNÉRAL du moment, avec
 *   exactement la règle de GET /pawspots/leaderboard?scope=europe : documents
 *   à pawPoints > 0, ni staff (isStaff) ni comptes de test (+test), une
 *   personne = une ligne (dédoublonnage par e-mail, meilleure ligne gardée).
 *   Il change de main dès que quelqu'un passe devant.
 * · 1er Chef de meute = pin UNIQUE et DÉFINITIF (modèle PawFirstPackLeader,
 *   index unique) posé au passage des 3 000 points (rang pack_leader) dans
 *   pawPointsService.awardPointsDetailed. Jamais pour un staff ni un test.
 *
 * Le podium est calculé UNE fois puis gardé 60 s en mémoire (instantané
 * partagé par toutes les routes) : jamais une requête par membre.
 */
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const PawFirstPackLeader = require('../models/PawFirstPackLeader');
const logger = require('../utils/logger');

const TTL_MS = 60 * 1000;
const PACK_LEADER_MIN = require('./ranks611').RANKS.find((r) => r.key === 'pack_leader').min; // 3000
const NO_PINS = Object.freeze({ podium: null, firstPackLeader: false });

let _snap = null; // { at, podium: [{userId, role, name, points, ids:Set}], fpl: {..., ids:Set}|null }
let _inflight = null;

async function _personIds(userId) {
  try {
    const ids = await require('../utils/personScope').personIds(userId);
    if (ids && ids.length) return ids.map(String);
  } catch (_) { /* id seul */ }
  return [String(userId)];
}

/** Classement général (règle de /pawspots/leaderboard scope=europe), trié. */
async function globalRows() {
  const { isTestAccountEmail } = require('../utils/testAccount2809');
  const { publicNameFields } = require('../utils/publicName2809');
  const rows = [];
  for (const [Model, role] of [[Owner, 'owner'], [Sitter, 'sitter'], [Walker, 'walker']]) {
    // eslint-disable-next-line no-await-in-loop
    const docs = await Model.find({ pawPoints: { $gt: 0 }, isStaff: { $ne: true } })
      .sort({ pawPoints: -1 })
      .limit(50)
      .select('name firstName lastName avatar email pawPoints')
      .lean();
    for (const d of docs) {
      if (isTestAccountEmail(d.email)) continue;
      rows.push({
        userId: String(d._id),
        role,
        name: publicNameFields(d).name,
        points: d.pawPoints || 0,
        _avatar: d.avatar?.url || '',
        _email: String(d.email || '').toLowerCase().trim(),
      });
    }
  }
  const byPerson = new Map();
  for (const r of rows) {
    const key = r._email || `id:${r.userId}`;
    const prev = byPerson.get(key);
    if (!prev || r.points > prev.points || (r.points === prev.points && r._avatar && !prev._avatar)) {
      byPerson.set(key, r);
    }
  }
  const out = [...byPerson.values()];
  out.sort((a, b) => b.points - a.points);
  return out;
}

/** La personne est-elle staff ou compte de test (un de ses profils suffit) ? */
async function isStaffOrTestPerson(ids) {
  const { isTestAccountEmail } = require('../utils/testAccount2809');
  const docs = (await Promise.all([Owner, Sitter, Walker].map((M) => M.find({ _id: { $in: ids } })
    .select('email isStaff').lean().catch(() => [])))).flat();
  return docs.some((d) => d.isStaff === true || isTestAccountEmail(d.email));
}

async function _publicNameOf(userId, role) {
  try {
    const M = role === 'walker' ? Walker : role === 'sitter' ? Sitter : Owner;
    const d = await M.findById(userId).select('name firstName lastName').lean();
    if (d) return require('../utils/publicName2809').publicNameFields(d).name;
  } catch (_) { /* nom inconnu */ }
  return '';
}

// Base pas (encore) connectée : jamais d'attente (mongoose mettrait chaque
// lecture en file 10 s) — pas de pin plutôt qu'une route ralentie.
const _dbReady = () => require('mongoose').connection.readyState === 1;

async function _build() {
  if (!_dbReady()) return { at: Date.now(), podium: [], fpl: null };
  const top = (await globalRows()).slice(0, 3);
  const podium = [];
  for (const r of top) {
    // eslint-disable-next-line no-await-in-loop
    const ids = await _personIds(r.userId);
    podium.push({ userId: r.userId, role: r.role, name: r.name, points: r.points, ids: new Set([r.userId, ...ids]) });
  }
  let fpl = null;
  const rec = await PawFirstPackLeader.findOne({ key: 'pack_leader' }).lean();
  if (rec) {
    const ids = await _personIds(rec.userId);
    fpl = {
      userId: String(rec.userId),
      role: rec.role || 'owner',
      name: await _publicNameOf(rec.userId, rec.role),
      at: rec.at ? new Date(rec.at).toISOString() : null,
      ids: new Set([String(rec.userId), ...ids]),
    };
  }
  return { at: Date.now(), podium, fpl };
}

/** Instantané partagé (60 s). Une seule reconstruction à la fois. */
async function getSnapshot({ now = Date.now() } = {}) {
  if (_snap && now - _snap.at < TTL_MS) return _snap;
  if (!_inflight) {
    _inflight = _build()
      .then((s) => { _snap = s; return s; })
      .catch((e) => {
        logger.warn(`[pins618] instantané : ${e?.message || e}`);
        return _snap || { at: 0, podium: [], fpl: null };
      })
      .finally(() => { _inflight = null; });
  }
  return _inflight;
}

/** pins d'une personne (n'importe lequel de ses ids de rôle). */
function pinsFromSnapshot(snap, ids) {
  if (!snap) return { ...NO_PINS };
  const list = (ids || []).map(String).filter(Boolean);
  if (!list.length) return { ...NO_PINS };
  let podium = null;
  snap.podium.forEach((p, i) => {
    if (podium === null && list.some((x) => p.ids.has(x))) podium = i + 1;
  });
  const firstPackLeader = !!(snap.fpl && list.some((x) => snap.fpl.ids.has(x)));
  return { podium, firstPackLeader };
}

/** pins de l'utilisateur connecté (ses 3 profils). */
async function pinsForUser(userId) {
  if (!_dbReady()) return { ...NO_PINS };
  const [snap, ids] = await Promise.all([getSnapshot(), _personIds(userId)]);
  return pinsFromSnapshot(snap, [String(userId), ...ids]);
}

/** Ajoute `pins` à chaque membre d'une liste (sans toucher l'objet d'origine). */
async function withMemberPins(members) {
  const snap = await getSnapshot();
  return (members || []).map((m) => ({
    ...m,
    pins: pinsFromSnapshot(snap, [m.id, ...(m.personIds || [])]),
  }));
}

/** Réponse publique de GET /pawpoints/pins. */
async function publicPins() {
  const snap = await getSnapshot();
  return {
    podium: snap.podium.map((p) => ({ userId: p.userId, role: p.role, name: p.name, points: p.points })),
    firstPackLeader: snap.fpl
      ? { userId: snap.fpl.userId, role: snap.fpl.role, name: snap.fpl.name, at: snap.fpl.at }
      : null,
  };
}

/**
 * Appelé par awardPointsDetailed après chaque crédit. Enregistre le 1er Chef de
 * meute au PASSAGE du seuil (avant < 3000 ≤ après), une seule fois dans toute
 * la base, jamais pour un staff ni un compte de test. Ne lève jamais.
 * Retourne true si CETTE personne vient de recevoir le pin.
 */
async function maybeRecordFirstPackLeader({ userId, role, before, after }) {
  try {
    if (!(Number(before) < PACK_LEADER_MIN && Number(after) >= PACK_LEADER_MIN)) return false;
    if (!_dbReady()) return false;
    if (await PawFirstPackLeader.exists({ key: 'pack_leader' })) return false;
    const ids = await _personIds(userId);
    if (await isStaffOrTestPerson([String(userId), ...ids])) return false;
    await PawFirstPackLeader.create({
      key: 'pack_leader',
      userId: String(userId),
      role: String(role || 'owner').toLowerCase(),
      personKey: require('../utils/followers589').personKey(ids),
      points: Number(after) || 0,
      at: new Date(),
    });
    _snap = null; // visible tout de suite
    logger.info(`🏅 [pins618] 1er Chef de meute → ${role}:${userId} (${after} points)`);
    return true;
  } catch (e) {
    if (e && e.code === 11000) return false; // quelqu'un l'a eu à la même seconde
    logger.warn(`[pins618] 1er Chef de meute : ${e?.message || e}`);
    return false;
  }
}

function _resetForTests() { _snap = null; _inflight = null; }

module.exports = {
  NO_PINS,
  PACK_LEADER_MIN,
  TTL_MS,
  globalRows,
  getSnapshot,
  pinsFromSnapshot,
  pinsForUser,
  withMemberPins,
  publicPins,
  maybeRecordFirstPackLeader,
  isStaffOrTestPerson,
  _resetForTests,
};
