'use strict';
// v599 — FLO (29/09/2026). Filtre de GET /pets.
// Un propriétaire connecté : ses animaux. Un gardien/promeneur : les animaux du
// propriétaire qu'il désigne (?ownerId=, ex. fiche d'une réservation). Sinon rien.
const buildPetListFilter = ({ userId, userRole, ownerIdQuery } = {}) => {
  if (!userId) return null;
  const role = String(userRole || '').toLowerCase();
  if (role === 'owner') return { ownerId: userId };
  if ((role === 'sitter' || role === 'walker') && ownerIdQuery) {
    return { ownerId: String(ownerIdQuery) };
  }
  return null;
};
module.exports = { buildPetListFilter };
