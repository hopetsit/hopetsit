const logger = require('../utils/logger');

/**
 * v574 — GET /users/me/roles
 *
 * Daniel : « j'ai activé un rôle sur Android, iOS ne l'affiche pas activé ».
 * `availableRoles` n'était renvoyé qu'à la connexion et au changement de rôle :
 * un appareil déjà connecté ne savait jamais qu'un profil avait été créé
 * ailleurs. Cet endpoint donne, à tout moment, les rôles que possède la
 * personne (1 personne = jusqu'à 3 documents reliés par l'e-mail / oldId).
 */
const getMyRoles = async (req, res) => {
  try {
    const Owner = require('../models/Owner');
    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');
    const MODELS = { owner: Owner, sitter: Sitter, walker: Walker };
    const Model = MODELS[req.user.role] || Owner;
    let me = await Model.findById(req.user.id).select('email oldId').lean();
    if (!me) {
      // Jeton émis pour un autre rôle : on cherche le document où il est.
      for (const M of [Owner, Sitter, Walker]) {
        // eslint-disable-next-line no-await-in-loop
        me = await M.findById(req.user.id).select('email oldId').lean();
        if (me) break;
      }
    }
    if (!me) return res.status(404).json({ error: 'User not found.' });
    const { findAvailableRolesForAccount } = require('./authController');
    const found = await findAvailableRolesForAccount(me.email, me.oldId);
    return res.json({
      activeRole: req.user.role,
      availableRoles: found.map((r) => r.role),
    });
  } catch (error) {
    logger.error('[getMyRoles]', error);
    return res.status(500).json({ error: 'Unable to load roles.' });
  }
};

module.exports = { getMyRoles };
