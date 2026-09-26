/**
 * v590 — Daniel (26/09) : « quand je mets Make Staff, que ça le mette sur les
 * 3 rôles automatiquement, même si la personne n'a qu'un rôle ». Le bouton de
 * l'admin propageait déjà le badge aux profils EXISTANTS ; un rôle créé plus
 * tard (switchRole) naissait sans badge. Le staff est une qualité de la
 * PERSONNE : dès qu'un de ses profils l'a, tous l'ont. N'enlève jamais le
 * badge (le retrait passe par l'admin, qui l'enlève partout).
 */
const logger = require('./logger');

const MODELS = () => ({
  Owner: require('../models/Owner'),
  Sitter: require('../models/Sitter'),
  Walker: require('../models/Walker'),
});

async function propagateStaffForPerson(userId) {
  try {
    const { identityGroup } = require('./identityGroup');
    const g = await identityGroup(String(userId));
    const M = MODELS();
    let staff = false;
    for (const d of g.docs) {
      // eslint-disable-next-line no-await-in-loop
      const doc = await M[d.model].findById(d.id).select('isStaff').lean();
      if (doc && doc.isStaff === true) { staff = true; break; }
    }
    if (!staff) return 0;
    let n = 0;
    for (const d of g.docs) {
      // eslint-disable-next-line no-await-in-loop
      const r = await M[d.model].updateOne({ _id: d.id, isStaff: { $ne: true } }, { $set: { isStaff: true } });
      n += r.modifiedCount || 0;
    }
    return n;
  } catch (e) {
    logger.warn(`[staffSync] ${e?.message || e}`);
    return 0;
  }
}

/** Rattrapage : tous les profils de toutes les personnes staff. */
async function propagateAllStaff() {
  const M = MODELS();
  let fixed = 0;
  for (const name of Object.keys(M)) {
    // eslint-disable-next-line no-await-in-loop
    const staff = await M[name].find({ isStaff: true }).select('_id').lean();
    for (const s of staff) {
      // eslint-disable-next-line no-await-in-loop
      fixed += await propagateStaffForPerson(s._id);
    }
  }
  return fixed;
}

module.exports = { propagateStaffForPerson, propagateAllStaff };
