/**
 * v599 (ZOE, 29/09/2026) — « Lu » synchronisé partout (Daniel).
 *
 * Quand une PERSONNE lit une conversation sur UN appareil (iPhone, Android ou
 * le site), tous ses autres appareils doivent le savoir tout de suite, quel
 * que soit le profil (owner / sitter / walker) avec lequel ils sont
 * connectés. Le serveur reste la seule source de vérité (compteurs et readAt
 * posés par le service de conversation) ; ce module ne fait que PRÉVENIR :
 *   1. `conversation:read:self { conversationId, at }` → salles des 3 rôles de
 *      chacun de mes ids (badge du menu, liste du chat, site) ;
 *   2. les entrées « Nouveau message » de la cloche pour CE fil passent en lu
 *      → `notification.read { ids, unreadCount }` (l'app retire la
 *      notification téléphone correspondante, iOS remet le badge) ;
 *   3. push « badge seul » iOS (déjà existant : sendBadgeSync) ;
 *   0. (29/09 08 h) l'e-mail différé « message non lu » en attente est annulé.
 * Best-effort : ne lève jamais, ne bloque jamais la réponse.
 */
const logger = require('./logger');

const idOf = (v) => (v ? String(v._id || v.id || v) : '');

const afterConversationRead = async ({ conversationId, readerId, readerIds = null }) => {
  const cid = idOf(conversationId);
  const me = idOf(readerId);
  if (!cid || !me) return { notified: 0, bell: 0 };
  let ids = Array.isArray(readerIds) && readerIds.length ? readerIds.map(String) : null;
  if (!ids) {
    try {
      const { identityGroup } = require('./identityGroup');
      ids = (await identityGroup(me)).ids;
    } catch (_) {
      ids = [me];
    }
  }
  const out = { notified: 0, bell: 0, emailCancelled: 0 };
  // 0) v599 (29/09 08 h, décision Daniel) : lire le fil annule l'e-mail différé
  //    « message non lu » (15 min) en attente pour cette personne.
  try {
    const { cancelUnreadEmail } = require('../services/chatUnreadEmailScheduler599');
    const r = await cancelUnreadEmail({ conversationId: cid, readerIds: ids });
    out.emailCancelled = (r && r.cancelled) || 0;
  } catch (e) {
    logger.warn(`[chat.readSync] cancel deferred email failed : ${e && e.message ? e.message : e}`);
  }
  // 1) mes autres appareils / profils : le fil est lu.
  try {
    const { emitToUsersAllRoles } = require('../sockets/emitter');
    out.notified = emitToUsersAllRoles(ids, 'conversation:read:self', {
      conversationId: cid,
      at: new Date().toISOString(),
    });
  } catch (e) {
    logger.warn(`[chat.readSync] emit failed : ${e && e.message ? e.message : e}`);
  }
  // 2) entrées de la cloche « Nouveau message » de ce fil → lues, et synchro.
  try {
    const Notification = require('../models/Notification');
    const ROLES = ['owner', 'sitter', 'walker'];
    const docs = await Notification.find({
      recipientId: { $in: ids },
      type: { $in: ['NEW_MESSAGE', 'new_message'] },
      'data.conversationId': cid,
      readAt: null,
    }).select('_id recipientId recipientRole').lean();
    if (docs && docs.length) {
      const now = new Date();
      await Notification.updateMany(
        { _id: { $in: docs.map((d) => d._id) } },
        { $set: { readAt: now } },
      );
      out.bell = docs.length;
      // Regroupe par (rôle, id) pour la synchro et le badge iOS.
      const groups = new Map();
      for (const d of docs) {
        const role = String(d.recipientRole || '').toLowerCase();
        if (!ROLES.includes(role)) continue;
        const key = `${role}:${d.recipientId}`;
        const g = groups.get(key) || { role, userId: String(d.recipientId), ids: [] };
        g.ids.push(String(d._id));
        groups.set(key, g);
      }
      const { emitToUser } = require('../sockets/emitter');
      const { getUnreadCount } = require('../services/notificationService');
      for (const [, g] of groups) {
        let unreadCount;
        try {
          // eslint-disable-next-line no-await-in-loop
          unreadCount = await getUnreadCount({ recipientRole: g.role, recipientId: g.userId });
        } catch (_) { unreadCount = undefined; }
        const payload = { ids: g.ids, unreadCount, recipientRole: g.role, at: now.toISOString() };
        // Toutes mes salles (mes appareils peuvent être connectés sous un autre rôle).
        for (const r of ROLES) emitToUser(r, g.userId, 'notification.read', payload);
        try {
          const { sendBadgeSync } = require('../services/notificationSender');
          if (Number.isInteger(unreadCount)) {
            Promise.resolve(sendBadgeSync({ role: g.role, userId: g.userId, unreadCount })).catch(() => {});
          }
        } catch (_) { /* best-effort */ }
      }
    }
  } catch (e) {
    logger.warn(`[chat.readSync] bell sync failed : ${e && e.message ? e.message : e}`);
  }
  return out;
};

module.exports = { afterConversationRead };
