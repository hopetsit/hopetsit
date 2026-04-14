let ioInstance = null;

const setSocketServer = (io) => {
  ioInstance = io;
};

const getSocketServer = () => ioInstance;

const shouldExcludeSocket = (socket, conversationId, exclude) => {
  if (!exclude?.length) {
    return false;
  }

  const socketId = socket.id;
  const conversationMetadata = socket.data?.conversationMetadata || {};
  const metadata = conversationMetadata[conversationId] || {};
  const { role: socketRole, userId: socketUserId } = metadata;

  return exclude.some((item) => {
    if (item.socketId && item.socketId === socketId) {
      return true;
    }
    if (item.userId && item.userId !== socketUserId) {
      return false;
    }
    if (item.role && item.role !== socketRole) {
      return false;
    }
    if (!item.userId && !item.role && !item.socketId) {
      return false;
    }
    if (item.userId && item.userId === socketUserId && !item.role) {
      return true;
    }
    if (item.role && item.role === socketRole && !item.userId) {
      return true;
    }
    return item.userId === socketUserId && item.role === socketRole;
  });
};

const emitToConversation = (conversationId, event, payload, options = {}) => {
  if (!ioInstance) return;
  const { exclude = [] } = options;

  if (!exclude.length) {
    ioInstance.to(conversationId).emit(event, payload);
    return;
  }

  const room = ioInstance.sockets.adapter.rooms.get(conversationId);
  if (!room) return;

  room.forEach((socketId) => {
    const socket = ioInstance.sockets.sockets.get(socketId);
    if (!socket) return;

    if (shouldExcludeSocket(socket, conversationId, exclude)) {
      return;
    }

    socket.emit(event, payload);
  });
};

const userRoom = (role, userId) => `user:${role}:${userId}`;

const emitToUser = (role, userId, event, payload) => {
  if (!ioInstance || !role || !userId) return;
  ioInstance.to(userRoom(role, userId)).emit(event, payload);
};

const walkRoom = (walkId) => `walk:${walkId}`;

const emitToWalk = (walkId, event, payload) => {
  if (!ioInstance || !walkId) return;
  ioInstance.to(walkRoom(walkId)).emit(event, payload);
};

module.exports = {
  setSocketServer,
  getSocketServer,
  emitToConversation,
  emitToUser,
  emitToWalk,
  userRoom,
  walkRoom,
};

