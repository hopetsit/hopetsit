/**
 * 610 (ZOE, 04/10/2026) — notifications « par PERSONNE » (Daniel, iPhone 609 :
 * « quand j'ai lu les notifications, elles restent dans la cloche, et sur
 * l'icône de l'app il y a toujours le numéro »).
 *
 * Constat mesuré en prod le 04/10 sur le compte de test (un e-mail, 3 profils) :
 * 13 non lues sur le profil propriétaire + 1 sur le profil gardien. Le badge de
 * l'icône recevait du serveur le compteur du SEUL profil destinataire du push,
 * l'app le remettait au compteur du profil ACTIF : deux nombres différents pour
 * le même téléphone, et une notification d'un autre profil ne pouvait jamais
 * être lue depuis la cloche. Règle désormais :
 *   - une personne = ses 3 profils (même e-mail / oldId, identityGroup) ;
 *   - la cloche de l'app ≥ 610 liste les notifications des 3 profils
 *     (`?scope=person`), son compteur et le badge de l'icône = le TOTAL ;
 *   - lire / supprimer une notification marche quel que soit le profil actif
 *     (toujours borné aux profils de la personne) ;
 *   - chaque appareil connecté reçoit, dans la salle de SON profil, le compteur
 *     de ce profil (`unreadCount`, inchangé pour les apps ≤ 609) ET le total
 *     (`totalUnreadCount`, lu par l'app ≥ 610).
 * Les apps ≤ 609 gardent exactement leur comportement (liste et compteur du
 * profil actif) : rien ne change sans `scope=person`.
 */
const logger = require('./logger');

const ROLE_BY_MODEL = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };
const ROLES = ['owner', 'sitter', 'walker'];
/** Build iOS à partir duquel l'app affiche le TOTAL de la personne sur l'icône. */
const PERSON_BADGE_MIN_BUILD = 610;

const isPersonScope = (req) =>
  String((req && req.query && req.query.scope) || (req && req.body && req.body.scope) || '')
    .toLowerCase() === 'person';

/**
 * Profils de la personne : [{ role, id }]. Contient TOUJOURS le profil passé
 * (repli sûr si la recherche échoue).
 */
async function personProfiles(userId, role) {
  const me = { role: String(role || '').toLowerCase(), id: String(userId) };
  const out = ROLES.includes(me.role) ? [me] : [];
  try {
    const { identityGroup } = require('./identityGroup');
    const g = await identityGroup(userId);
    for (const d of (g && g.docs) || []) {
      const r = ROLE_BY_MODEL[d.model];
      if (!r) continue;
      if (!out.some((p) => p.role === r && p.id === String(d.id))) out.push({ role: r, id: String(d.id) });
    }
  } catch (e) {
    logger.warn(`[notif.person] profils illisibles (${userId}) : ${e && e.message ? e.message : e}`);
  }
  return out;
}

/** Filtre Mongo « destinataire = un des profils ». */
const recipientFilter = (profiles) => ({
  $or: profiles.map((p) => ({ recipientRole: p.role, recipientId: p.id })),
});

/** { total, byProfile: [{ role, id, count }] } — non lues de la personne. */
async function personUnread(profiles) {
  const Notification = require('../models/Notification');
  const byProfile = await Promise.all(profiles.map(async (p) => ({
    ...p,
    count: await Notification.countDocuments({ recipientRole: p.role, recipientId: p.id, readAt: null }),
  })));
  const total = byProfile.reduce((s, p) => s + (p.count || 0), 0);
  return { total, byProfile };
}

/**
 * Prévient chaque appareil connecté de la personne (salle de SON profil) et
 * remet le badge iOS des appareils hors ligne. `allProfiles` : un « tout lu /
 * tout supprimé » qui a porté sur les 3 profils ; sinon `all` ne concerne que
 * le profil qui agit (les autres reçoivent seulement les compteurs).
 * Ne lève jamais.
 */
async function syncPerson(event, { userId, role, ids = null, all = false, allProfiles = false }) {
  try {
    const profiles = await personProfiles(userId, role);
    const { total, byProfile } = await personUnread(profiles);
    const at = new Date().toISOString();
    const { emitToUser } = require('../sockets/emitter');
    let own = null;
    for (const p of byProfile) {
      const affected = allProfiles || (p.role === String(role) && p.id === String(userId));
      const scope = all
        ? (affected ? { all: true } : { ids: [] })
        : { ids: (ids || []).map(String) };
      const payload = { ...scope, unreadCount: p.count, totalUnreadCount: total, recipientRole: p.role, at };
      emitToUser(p.role, p.id, event, payload);
      if (p.role === String(role) && p.id === String(userId)) own = payload;
    }
    try {
      // Profil qui agit, sinon le premier de la personne (appel « par personne »
      // sans rôle, ex. lecture d'une conversation).
      const mine = byProfile.find((p) => p.role === String(role) && p.id === String(userId)) || byProfile[0];
      if (mine) {
        const { sendBadgeSync } = require('../services/notificationSender');
        Promise.resolve(sendBadgeSync({
          role: mine.role, userId: mine.id, unreadCount: mine.count, personUnreadCount: total,
        })).catch(() => {});
      }
    } catch (_) { /* best-effort */ }
    return own || { ...(all ? { all: true } : { ids: (ids || []).map(String) }), unreadCount: 0, totalUnreadCount: total, at };
  } catch (e) {
    logger.warn(`[notif.person] ${event} sync failed : ${e && e.message ? e.message : e}`);
    return null;
  }
}

module.exports = {
  PERSON_BADGE_MIN_BUILD,
  isPersonScope,
  personProfiles,
  recipientFilter,
  personUnread,
  syncPerson,
};
