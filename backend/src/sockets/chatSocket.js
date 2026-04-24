const {
  sendMessage,
  markConversationRead,
  assertAccessAndFetch,
} = require('../services/conversationService');
const { HttpError } = require('../utils/errors');
const { emitToConversation, userRoom, walkRoom } = require('./emitter');
const WalkSession = require('../models/WalkSession');
const { evaluateChatAccess } = require('../middleware/chatAccess');

// v20.0.19 — align with REST chatAccess.js middleware:
//   1) pass walkerId (walker convos were always blocked before)
//   2) bypass gate for isStaff === true
//   3) bypass gate for Premium active OR Chat add-on active
// Before this fix, walker chats failed at socket join with PAYMENT_REQUIRED
// even after a paid booking, because evaluateChatAccess was called with
// sitterId:null/undefined → Booking.findOne returned a stale unrelated doc.
const assertChatPaid = async (conversation, actorRole, actorId) => {
  // Staff / Premium / Chat add-on bypass.
  try {
    if (actorRole && actorId) {
      const Owner = require('../models/Owner');
      const Sitter = require('../models/Sitter');
      const Walker = require('../models/Walker');
      const UserSubscription = require('../models/UserSubscription');
      const Model = actorRole === 'walker' ? Walker : actorRole === 'sitter' ? Sitter : Owner;
      const me = await Model.findById(actorId).select('isStaff').lean();
      if (me && me.isStaff === true) return;

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
  // Sprint 4 step 4 — per-user room for targeted notifications.
  socket.on('user:identify', (payload = {}, callback) => {
    const { role, userId } = payload;
    if (role && userId) {
      socket.join(userRoom(role, userId));
      socket.data = socket.data || {};
      socket.data.userRoom = { role, userId };
    }
    if (callback) callback({ status: 'ok' });
  });

  socket.on('conversation:join', async (payload = {}, callback) => {
    try {
      const { conversationId, role, userId } = payload;
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
        return callback({ status: 'error', ...asErrorPayload(error) });
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
      const { walkId, role, userId } = payload;
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
      const { conversationId, senderRole, senderId, body } = payload;

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

      emitToConversation(conversationId, 'message:new', {
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

  socket.on('conversation:read', async (payload = {}, callback) => {
    try {
      const { conversationId, role, userId } = payload;
      const { conversation, updated } = await markConversationRead({
        conversationId,
        role,
        userId,
      });

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

