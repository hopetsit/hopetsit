'use strict';
// v599 — FLO (29/09/2026). Filtre de GET /bookings (listBookings).
//
// Bug corrigé : la liste ne connaissait que les rôles « owner » et « sitter ».
// Un PROMENEUR connecté n'ajoutait donc AUCUNE contrainte d'utilisateur, et
// recevait TOUTES les réservations de la plateforme (nom, position exacte et
// e-mail des propriétaires, identifiants de paiement, code de remise…).
// Vérifié en production le 29/09 avec le compte de test promeneur : 6
// réservations d'autres prestataires renvoyées, dont la seule vraie payée.
//
// Règle : un utilisateur connecté ne voit QUE ses réservations. Si le rôle est
// inconnu, on ne renvoie rien (filtre impossible → null).
const ROLE_FIELD = { owner: 'ownerId', sitter: 'sitterId', walker: 'walkerId' };

/**
 * @param {{ userId?: string, userRole?: string, status?: string }} opts
 * @returns {object|null} filtre Mongoose, ou null si l'utilisateur ne peut rien lister
 */
const buildBookingListFilter = ({ userId, userRole, status } = {}) => {
  const field = ROLE_FIELD[String(userRole || '').toLowerCase()];
  if (!userId || !field) return null;
  const filter = { [field]: userId };
  if (status) {
    filter.status = status;
  } else {
    filter.status = { $ne: 'cancelled' };
  }
  return filter;
};

module.exports = { buildBookingListFilter, ROLE_FIELD };
