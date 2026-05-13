const { Server } = require('socket.io');
const registerChatHandlers = require('./chatSocket');
const registerMapHandlers = require('./mapSocket');
const { setSocketServer } = require('./emitter');

// v23.1 part 128 — Phase 4 audit P4-14 : whitelist explicite des origins
// pour Socket.IO. AVANT : cors.origin='*' par défaut → tout site externe
// pouvait initier une connexion WS et tenter du DoS (la JWT-auth bloque
// les events utiles mais pas le coût de connexion).
const _parseAllowedOrigins = () => {
  const fromEnv = (
    process.env.SOCKET_IO_ORIGIN ||
    process.env.ALLOWED_ORIGINS ||
    ''
  )
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  // Auto-allow le propre URL Render comme pour CORS REST.
  const renderOwnUrl = (process.env.RENDER_EXTERNAL_URL || '').replace(/\/$/, '');
  if (renderOwnUrl && !fromEnv.includes(renderOwnUrl)) {
    fromEnv.push(renderOwnUrl);
  }
  return fromEnv;
};

const createSocketServer = (httpServer) => {
  const allowList = _parseAllowedOrigins();
  const io = new Server(httpServer, {
    cors: {
      origin(origin, callback) {
        // Connexions natives mobiles (Flutter via socket_io_client) ne
        // passent pas d'Origin header → on les autorise systématiquement.
        if (!origin) return callback(null, true);
        if (allowList.includes(origin)) return callback(null, true);
        return callback(new Error(`Socket.IO CORS: origin ${origin} not allowed`));
      },
      credentials: true,
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

