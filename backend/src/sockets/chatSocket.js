const {
  sendMessage,
  markConversationRead,
  assertAccessAndFetch,
} = require('../services/conversationService');
const { HttpError } = require('../utils/errors');
const {
  emitToConversation, emitChatMessage, userRoom, walkRoom,
  countSocketsForIds, expandIdentityIds, emitPresenceUpdate, invalidatePresenceIndex,
} = require('./emitter');
const WalkSession = require('../models/WalkSession');
const { evaluateChatAccess } = require('../middleware/chatAccess');
const logger = require('../utils/logger');
// v566 — accusés de réception / lecture (✓ ✓✓ ✓✓ bleu).
const receipts = require('../services/messageReceiptService');

// ─── v565 §6 — présence « en ligne » ────────────────────────────────────────
// À la connexion (jeton validé par io.use) et à la déconnexion, on prévient
// les amis et les correspondants de conversation : `presence:update
// { userId, userIds, online, at }`. L'identité complète (owner/sitter/walker)
// est résolue via identityGroup ; on n'émet que sur une VRAIE transition
// (premier socket de la personne / plus aucun socket, après 5 s de grâce
// pour absorber les reconnexions). `lastSeenAt` est écrit sur les 3 docs.
const PRESENCE_GRACE_MS = 5000;

const presenceRecipientsOf = async (ids) => {
  const out = new Set();
  try {
    const Friendship = require('../models/Friendship');
    const Conversation = require('../models/Conversation');
    const idSet = new Set(ids.map(String));
    const [friendships, conversations] = await Promise.all([
      Friendship.find({
        status: 'accepted',
        $or: [{ requesterId: { $in: ids } }, { addresseeId: { $in: ids } }],
      }).select('requesterId addresseeId').lean(),
      Conversation.find({
        $or: [
          { ownerId: { $in: ids } }, { sitterId: { $in: ids } }, { walkerId: { $in: ids } },
          { 'participants.userId': { $in: ids } },
        ],
      }).select('ownerId sitterId walkerId participants').limit(500).lean(),
    ]);
    for (const f of friendships) {
      for (const v of [f.requesterId, f.addresseeId]) {
        const s = v ? String(v) : null;
        if (s && !idSet.has(s)) out.add(s);
      }
    }
    for (const c of conversations) {
      const cand = [c.ownerId, c.sitterId, c.walkerId, ...((c.participants || []).map((p) => p.userId))];
      for (const v of cand) {
        const s = v ? String(v) : null;
        if (s && !idSet.has(s)) out.add(s);
      }
    }
  } catch (e) {
    logger.warn(`[presence] recipients lookup failed : ${e?.message || e}`);
  }
  // Les destinataires peuvent être connectés sous un autre rôle → on étend.
  return expandIdentityIds([...out]);
};

const identityIdsOf = async (userId) => {
  try {
    const { identityGroup } = require('../utils/identityGroup');
    const g = await identityGroup(userId);
    return g.ids;
  } catch (_) {
    return [String(userId)];
  }
};

const handlePresenceConnect = async (socket) => {
  const me = socket.data?.user;
  if (!me?.id) return;
  try {
    invalidatePresenceIndex();
    const ids = await identityIdsOf(me.id);
    socket.data.presenceIds = ids;
    const others = await countSocketsForIds(ids, socket.id);
    if (others > 0) return; // déjà en ligne sous un autre socket/rôle
    const recipients = await presenceRecipientsOf(ids);
    const n = emitPresenceUpdate({
      userId: me.id, userIds: ids, online: true, at: new Date().toISOString(), recipients,
    });
    logger.info(`[presence] ${me.role}:${me.id} ONLINE → ${n} destinataire(s)`);
  } catch (e) {
    logger.warn(`[presence] connect failed : ${e?.message || e}`);
  }
};

const handlePresenceDisconnect = async (socket) => {
  const me = socket.data?.user;
  if (!me?.id) return;
  const ids = socket.data?.presenceIds || (await identityIdsOf(me.id));
  setTimeout(async () => {
    try {
      invalidatePresenceIndex();
      const remaining = await countSocketsForIds(ids, socket.id);
      if (remaining > 0) return; // reconnecté ou autre appareil/rôle
      const at = new Date();
      try {
        const Owner = require('../models/Owner');
        const Sitter = require('../models/Sitter');
        const Walker = require('../models/Walker');
        await Promise.all([Owner, Sitter, Walker].map((M) =>
          M.updateMany({ _id: { $in: ids } }, { $set: { lastSeenAt: at } }),
        ));
      } catch (e) {
        logger.warn(`[presence] lastSeenAt write failed : ${e?.message || e}`);
      }
      const recipients = await presenceRecipientsOf(ids);
      const n = emitPresenceUpdate({
        userId: me.id, userIds: ids, online: false, at: at.toISOString(), recipients,
      });
      logger.info(`[presence] ${me.role}:${me.id} OFFLINE → ${n} destinataire(s)`);
    } catch (e) {
      logger.warn(`[presence] disconnect failed : ${e?.message || e}`);
    }
  }, PRESENCE_GRACE_MS);
};

// v20.0.19 — align with REST chatAccess.js middleware:
//   1) pass walkerId (walker convos were always blocked before)
//   2) bypass gate for isStaff === true
//   3) bypass gate for Premium active OR Chat add-on active
// Before this fix, walker chats failed at socket join with PAYMENT_REQUIRED
// even after a paid booking, because evaluateChatAccess was called with
// sitterId:null/undefined → Booking.findOne returned a stale unrelated doc.
const assertChatPaid = async (conversation, actorRole, actorId) => {
  // Staff / Premium / Chat add-on bypass.
  // v23.1 part 228 — Daniel : "chat revient erreur 403". Memes bypass
  // que requirePaidBooking middleware REST (chatAccess.js v228) :
  //   - isStaff DB flag
  //   - email dans HARDCODED_STAFF_EMAILS / STAFF_EMAILS env
  //   - hasActivePawFollow (sans filtre userModel)
  //   - ANY UserSubscription active (peu importe userModel/plan)
  //   - legacy premiumActive / chatAddonActive
  try {
    if (actorRole && actorId) {
      const Owner = require('../models/Owner');
      const Sitter = require('../models/Sitter');
      const Walker = require('../models/Walker');
      const UserSubscription = require('../models/UserSubscription');
      const { hasActivePawFollow } = require('../models/UserSubscription');
      const Model = actorRole === 'walker' ? Walker : actorRole === 'sitter' ? Sitter : Owner;
      const me = await Model.findById(actorId).select('isStaff email').lean();
      if (me && me.isStaff === true) return;

      // Hardcoded staff email + env var.
      const HARDCODED_STAFF_EMAILS = new Set(['dadaciao84@gmail.com']);
      const envStaffEmails = String(process.env.STAFF_EMAILS || '')
        .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
      if (me && me.email && (
        HARDCODED_STAFF_EMAILS.has(String(me.email).toLowerCase()) ||
        envStaffEmails.includes(String(me.email).toLowerCase())
      )) return;

      // hasActivePawFollow check.
      try {
        if (await hasActivePawFollow(actorId)) return;
      } catch (_) {/* defensive */}

      // ANY active sub fallback.
      try {
        const anyActiveSub = await UserSubscription.findOne({
          userId: actorId,
          status: 'active',
          currentPeriodEnd: { $gt: new Date() },
        }).select('status').lean();
        if (anyActiveSub) return;
      } catch (_) {/* defensive */}

      const userModel =
        actorRole === 'walker' ? 'Walker' : actorRole === 'sitter' ? 'Sitter' : 'Owner';
      const sub = await UserSubscription.findOne({ userId: actorId, userModel })
        .select('status currentPeriodEnd chatAddonActive chatAddonExpiresAt')
        .lean();
      const now = new Date();
      const premiumActive =
        sub && sub.status === 'active' &&
        sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now;
      const chatAddonActive =
        sub && sub.chatAddonActive === true &&
        sub.chatAddonExpiresAt && new Date(sub.chatAddonExpiresAt) > now;
      if (premiumActive || chatAddonActive) return;
    }
  } catch (_) { /* fall through to paid-booking check */ }

  const access = await evaluateChatAccess({
    ownerId: conversation.ownerId,
    sitterId: conversation.sitterId,
    walkerId: conversation.walkerId,
  });
  if (access.blocked) {
    const err = new HttpError(403, 'Payment required');
    err.code = 'PAYMENT_REQUIRED';
    err.bookingId = access.bookingId;
    throw err;
  }
};

const asErrorPayload = (error) => ({
  error: error instanceof Error ? error.message : 'Unknown error',
});

const registerChatHandlers = (io, socket) => {
  // v23.1 part 130 — Phase 6 audit P6-1 : helper qui retourne l'identité
  // authentifiée du socket (depuis le JWT validé par io.use), en fallback
  // sur le payload pour les anciens clients (à virer une fois le rollout
  // v130 terminé). Toute donnée payload est ignorée si elle ne matche
  // pas le JWT.
  const _authedIdentity = (payload = {}) => {
    const trusted = socket.data?.user;
    if (trusted?.id && trusted?.role) {
      return { role: trusted.role, userId: trusted.id };
    }
    // Fallback legacy : si pas d'auth socket (rolling deploy), on
    // tolère le payload — mais le middleware io.use renvoie 'AUTH_REQUIRED'
    // avant d'arriver ici en prod, donc ce chemin ne devrait JAMAIS
    // se déclencher.
    return { role: payload.role, userId: payload.userId };
  };

  // v565 §6 — rejoint sa room de rôle dès le handshake (jeton validé) et
  // annonce la présence ; à la déconnexion, `lastSeenAt` + annonce hors ligne.
  {
    const trusted = socket.data?.user;
    if (trusted?.id && trusted?.role) {
      socket.join(userRoom(trusted.role, trusted.id));
      socket.data.userRoom = { role: trusted.role, userId: trusted.id };
    }
    handlePresenceConnect(socket).catch(() => {});
    socket.on('disconnect', () => { handlePresenceDisconnect(socket).catch(() => {}); });
  }

  // Sprint 4 step 4 — per-user room for targeted notifications.
  socket.on('user:identify', (payload = {}, callback) => {
    // v23.1 part 130 — Phase 6 audit P6-1 : role/userId proviennent
    // toujours du JWT, plus du payload. Sinon n'importe qui pouvait
    // join le user-room d'autrui et recevoir ses notifs.
    const { role, userId } = _authedIdentity(payload);
    if (role && userId) {
      socket.join(userRoom(role, userId));
      socket.data = socket.data || {};
      socket.data.userRoom = { role, userId };
    }
    if (callback) callback({ status: 'ok' });
  });

  socket.on('conversation:join', async (payload = {}, callback) => {
    try {
      // v23.1 part 130 — Phase 6 audit P6-1 : identité depuis JWT.
      const { conversationId } = payload;
      const { role, userId } = _authedIdentity(payload);
      const conversation = await assertAccessAndFetch({ conversationId, role, userId });
      await assertChatPaid(conversation, role, userId);

      socket.join(conversationId);
      // Also ensure we're in the per-user room for targeted notifications.
      if (role && userId) socket.join(userRoom(role, userId));
      socket.data = socket.data || {};
      socket.data.conversationMetadata = socket.data.conversationMetadata || {};
      socket.data.conversationMetadata[conversationId] = { role, userId };

      socket.emit('conversation:joined', { conversationId });
      if (callback) {
        callback({ status: 'ok', conversation });
      }
    } catch (error) {
      if (error instanceof HttpError && callback) {
        return callback({ status: 'error', ...asErrorPayload(error), ...(error.code ? { code: error.code } : {}) });
      }
      if (callback) {
        callback({ status: 'error', ...asErrorPayload(error) });
      }
      socket.emit('conversation:error', asErrorPayload(error));
    }
  });

  // Sprint 6 step 2 — join a walk room to receive live positions.
  socket.on('walk:join', async (payload = {}, callback) => {
    try {
      // v23.1 part 130 — Phase 6 audit P6-1 : identité depuis JWT.
      const { walkId } = payload;
      const { role, userId } = _authedIdentity(payload);
      if (!walkId || !role || !userId) {
        throw new HttpError(400, 'walkId, role, userId required');
      }
      const walk = await WalkSession.findById(walkId).select('ownerId sitterId');
      if (!walk) throw new HttpError(404, 'Walk not found');
      const uid = String(userId);
      const isParticipant =
        (role === 'sitter' && String(walk.sitterId) === uid) ||
        (role === 'owner' && String(walk.ownerId) === uid);
      if (!isParticipant) throw new HttpError(403, 'Not a walk participant');
      socket.join(walkRoom(walkId));
      if (callback) callback({ status: 'ok' });
    } catch (error) {
      if (callback) callback({ status: 'error', ...asErrorPayload(error) });
    }
  });

  socket.on('conversation:leave', (payload = {}, callback) => {
    const { conversationId } = payload;
    if (conversationId) {
      socket.leave(conversationId);
      if (socket.data?.conversationMetadata) {
        delete socket.data.conversationMetadata[conversationId];
      }
    }
    if (callback) {
      callback({ status: 'ok' });
    }
  });

  socket.on('message:send', async (payload = {}, callback) => {
    try {
      // v23.1 part 130 — Phase 6 audit P6-1 : sender depuis JWT pour
      // empêcher l'usurpation. AVANT le client pouvait poser
      // senderRole/senderId arbitraires et envoyer un message au nom
      // d'un autre user.
      const { conversationId, body } = payload;
      const authed = _authedIdentity(payload);
      const senderRole = authed.role;
      const senderId = authed.userId;
      // v565 §5 — réponse à un message précis (payload.replyTo.messageId).
      const { buildReplySnapshot, patchMessageExtras } = require('../controllers/conversationController');
      const replyTo = await buildReplySnapshot(conversationId, payload.replyTo);

      // Gate chat: verify conversation exists, user is participant, and the
      // latest booking between these two parties is paid (or absent).
      const conversation = await assertAccessAndFetch({
        conversationId,
        role: senderRole,
        userId: senderId,
      });
      await assertChatPaid(conversation, senderRole, senderId);

      const result = await sendMessage({
        conversationId,
        senderRole,
        senderId,
        body,
      });
      if (replyTo) await patchMessageExtras(result, { replyTo });

      // v23.1 part 227 — Daniel : "badge 1 dans le menu a coter de l'icone
      // qd message recu". On emit aussi aux user-rooms via emitChatMessage,
      // pas seulement au conversation-room. La conversation est deja
      // chargee par assertAccessAndFetch ci-dessus.
      emitChatMessage(conversation, 'message:new', {
        conversationId,
        triggeredBy: { role: senderRole, userId: senderId },
        ...result,
      });

      if (callback) {
        callback({ status: 'ok', ...result });
      }
    } catch (error) {
      if (callback) {
        callback({ status: 'error', ...asErrorPayload(error) });
      }
      socket.emit('conversation:error', asErrorPayload(error));
    }
  });

  // v566 — accusé de réception : le destinataire signale que `message:new`
  // a atteint son appareil. Charge utile `{ conversationId, messageId }` (ou
  // `messageIds: []`). Identité = JWT du socket. Le serveur pose `deliveredAt`
  // (updateMany groupé) et émet `message:delivered` à l'EXPÉDITEUR seulement :
  // celui-ci ne répond jamais à cet événement → pas de boucle.
  socket.on('message:delivered', async (payload = {}, callback) => {
    try {
      const { conversationId } = payload;
      const { userId } = _authedIdentity(payload);
      const ids = Array.isArray(payload.messageIds) && payload.messageIds.length
        ? payload.messageIds
        : [payload.messageId];
      const result = await receipts.markMessagesDelivered({
        conversationId,
        messageIds: ids,
        recipientId: userId,
      });
      if (callback) callback({ status: 'ok', ...result });
    } catch (error) {
      if (callback) callback({ status: 'error', ...asErrorPayload(error) });
    }
  });

  socket.on('conversation:read', async (payload = {}, callback) => {
    try {
      // v23.1 part 130 — Phase 6 audit P6-1 : identité depuis JWT.
      const { conversationId } = payload;
      const { role, userId } = _authedIdentity(payload);
      const { conversation, updated } = await markConversationRead({
        conversationId,
        role,
        userId,
      });

      // v566 — même effet que POST /conversations/:id/read : readAt groupé +
      // `message:read` à l'expéditeur (idempotent, rien à marquer = rien émis).
      await receipts.safely(
        'markMessagesRead',
        receipts.markMessagesRead({ conversationId, readerId: userId }),
      );

      if (updated) {
        emitToConversation(
          conversationId,
          'conversation:read',
          {
            conversationId,
            conversation,
            triggeredBy: { role, userId },
          },
          {
            exclude: [{ socketId: socket.id }],
          }
        );
      }

      if (callback) {
        if (updated) {
          callback({ status: 'ok', updated: true, conversation });
        } else {
          callback({ status: 'ok', updated: false });
        }
      }
    } catch (error) {
      if (callback) {
        callback({ status: 'error', ...asErrorPayload(error) });
      }
      socket.emit('conversation:error', asErrorPayload(error));
    }
  });
};

module.exports = registerChatHandlers;

