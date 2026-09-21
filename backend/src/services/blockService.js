const Block = require('../models/Block');
// v576 — un blocage vaut pour la PERSONNE, pas pour un profil. Avant, bloquer
// quelqu'un depuis son profil propriétaire n'empêchait rien dès que l'un des
// deux passait sur un autre de ses profils : le blocage se contournait tout
// seul en changeant de rôle. On compare donc les groupes d'identité.
const { personIds } = require('../utils/personScope');

const isOwnerSitterInteractionBlocked = async (ownerId, sitterId) => {
  if (!ownerId || !sitterId) {
    return false;
  }
  const [ownerIds, sitterIds] = await Promise.all([
    personIds(ownerId),
    personIds(sitterId),
  ]);
  return Block.exists({
    $or: [
      { blockerId: { $in: ownerIds }, blockedId: { $in: sitterIds } },
      { blockerId: { $in: sitterIds }, blockedId: { $in: ownerIds } },
    ],
  });
};

module.exports = {
  isOwnerSitterInteractionBlocked,
};
