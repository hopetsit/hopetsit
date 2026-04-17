const { Server } = require('socket.io');
const registerChatHandlers = require('./chatSocket');
const registerMapHandlers = require('./mapSocket');
const { setSocketServer } = require('./emitter');

const createSocketServer = (httpServer) => {
  const io = new Server(httpServer, {
    cors: {
      origin: process.env.SOCKET_IO_ORIGIN || '*',
    },
  });

  setSocketServer(io);

  io.on('connection', (socket) => {
    registerChatHandlers(io, socket);
    registerMapHandlers(io, socket);
  });

  return io;
};

module.exports = createSocketServer;

