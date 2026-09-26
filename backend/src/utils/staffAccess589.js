/**
 * v589 — « les gens que je mets staff dans l'admin peuvent cliquer sur les
 * abonnements sans payer, PawBoost gratuit par exemple, juste le staff »
 * (Daniel, 26/09). Le badge staff est posé dans l'admin sur UN profil ; il
 * vaut pour la PERSONNE (ses 3 profils). Avant, les achats ne regardaient que
 * le profil actif : un staff passé sur un autre profil payait.
 */
async function isStaffPerson(userId) {
  const id = String(userId || '');
  if (!id) return false;
  const { identityGroup } = require('./identityGroup');
  const MODELS = {
    Owner: require('../models/Owner'),
    Sitter: require('../models/Sitter'),
    Walker: require('../models/Walker'),
  };
  const g = await identityGroup(id);
  const docs = g.docs.length ? g.docs : [{ id, model: 'Owner' }, { id, model: 'Sitter' }, { id, model: 'Walker' }];
  for (const d of docs) {
    try {
      const M = MODELS[d.model];
      if (!M) continue;
      const doc = await M.findById(d.id).select('isStaff').lean();
      if (doc && doc.isStaff === true) return true;
    } catch (_) {/* profil illisible : on continue */}
  }
  return false;
}

module.exports = { isStaffPerson };
