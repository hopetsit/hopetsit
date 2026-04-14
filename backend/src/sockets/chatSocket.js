const {
  sendMessage,
  markConversationRead,
  assertAccessAndFetch,
} = require('../services/conversationService');
const { HttpError } = require('../utils/errors');
const { emitToConversation } = require('./emitter');
const { evaluateChatAccess } = require('../middleware/chatAccess');

const assertChatPaid = async (conversation) => {
  const access = await evaluateChatAccess({
    ownerId: conversation.ownerId,
    sitterId: conversation.sitterId,
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
  socket.on('conversation:join', async (payload = {}, callback) => {
    try {
      const { conversationId, role, userId } = payload;
      const conversation = await assertAccessAndFetch({ conversationId, role, userId });
      await assertChatPaid(conversation);

      socket.join(conversationId);
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
      await assertChatPaid(conversation);

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

