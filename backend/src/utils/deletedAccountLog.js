/**
 * v530 — Daniel : « je veux voir qui se désinscrit ». Journalise un compte
 * AVANT sa suppression physique (rôle, nom, email en clair, source), pour le
 * bloc « Dernières désinscriptions » de l'onglet Utilisateurs de l'admin.
 * Best-effort : un échec de journalisation ne bloque jamais la suppression.
 */
const logger = require('./logger');

const logDeletedAccount = async ({ role, doc, source }) => {
  try {
    const DeletedAccount = require('../models/DeletedAccount');
    const { decrypt } = require('./encryption');
    let email = '';
    try {
      email = decrypt(doc?.email || '') || '';
    } catch (_) { /* email illisible → champ vide */ }
    await DeletedAccount.create({
      role: role || '',
      name: doc?.name || '',
      email,
      userId: String(doc?._id || ''),
      source: source || 'user',
      deletedAt: new Date(),
    });
  } catch (e) {
    logger.warn(`[deletedAccount] journal failed : ${e?.message || e}`);
  }
};

module.exports = { logDeletedAccount };
