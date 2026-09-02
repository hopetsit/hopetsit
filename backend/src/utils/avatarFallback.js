const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('./logger');

const MODELS = { owner: Owner, sitter: Sitter, walker: Walker };

/**
 * v546 — Daniel : « quand je me connecte avec le même compte sur un Samsung
 * ou un iPhone, ma photo de profil disparaît ».
 *
 * Un même e-mail peut avoir jusqu'à trois documents (owner / sitter / walker)
 * et la photo n'est enregistrée que sur le rôle où elle a été envoyée. Si
 * l'autre appareil ouvre un autre rôle — ou si une connexion sociale (Apple
 * ne fournit jamais de photo) a laissé l'avatar vide — la réponse revient
 * SANS photo alors qu'elle existe. Le pansement v523 côté app ne protégeait
 * qu'un appareil ayant déjà la photo en cache : un appareil neuf n'a rien à
 * protéger. Ici on complète depuis le rôle frère et on la PERSISTE sur le
 * rôle courant, pour que ce soit définitif.
 *
 * Idempotent, silencieux en cas d'erreur (ne bloque jamais une connexion).
 */
async function ensureAvatarFromSiblingRoles(account, role) {
  try {
    if (!account) return account;
    const current = account.avatar && account.avatar.url
      ? String(account.avatar.url).trim()
      : '';
    if (current) return account;

    const email = (account.email || '').toString().trim().toLowerCase();
    const filters = [];
    if (email) filters.push({ email });
    if (account.oldId) filters.push({ oldId: account.oldId });
    if (!filters.length) return account;

    const withPhoto = {
      $or: filters,
      'avatar.url': { $exists: true, $nin: ['', null] },
    };

    for (const [siblingRole, Model] of Object.entries(MODELS)) {
      if (siblingRole === role) continue;
      const sibling = await Model.findOne(withPhoto).select('avatar').lean();
      const url = sibling && sibling.avatar && sibling.avatar.url
        ? String(sibling.avatar.url).trim()
        : '';
      if (!url) continue;

      const avatar = { url, publicId: (sibling.avatar.publicId || '').toString() };
      const CurrentModel = MODELS[role];
      if (CurrentModel && account._id) {
        await CurrentModel.updateOne({ _id: account._id }, { $set: { avatar } });
      }
      account.avatar = avatar;
      logger.info(
        `[avatar] ${role} ${account._id} : photo complétée depuis le rôle ${siblingRole}`,
      );
      return account;
    }
  } catch (err) {
    logger.warn({ err }, '[ensureAvatarFromSiblingRoles] failed');
  }
  return account;
}

module.exports = { ensureAvatarFromSiblingRoles };
