const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const registerChatHandlers = require('./chatSocket');
const registerMapHandlers = require('./mapSocket');
const { setSocketServer } = require('./emitter');
const logger = require('../utils/logger');

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

  // v23.1.322 — Daniel (scale) : adaptateur Redis pour le MULTI-INSTANCE. Quand
  // l'app tourne sur PLUSIEURS instances Render, sans adaptateur un socket émis
  // par l'instance A n'atteint pas un user connecté à l'instance B → chat, carte
  // live et notifs cassés entre instances. Avec REDIS_URL défini, on branche
  // @socket.io/redis-adapter (pub/sub). Sans REDIS_URL → mono-instance (comme
  // aujourd'hui), aucun changement. Tout est en try/catch : si Redis/le package
  // échoue, on dégrade proprement en mono-instance au lieu de crasher le backend.
  const REDIS_URL = process.env.REDIS_URL || process.env.UPSTASH_REDIS_URL || '';
  if (REDIS_URL) {
    (async () => {
      try {
        const { createAdapter } = require('@socket.io/redis-adapter');
        const Redis = require('ioredis');
        const pubClient = new Redis(REDIS_URL, { lazyConnect: false, maxRetriesPerRequest: 3 });
        const subClient = pubClient.duplicate();
        pubClient.on('error', (e) => logger.warn(`[socket.redis] pub error: ${e.message}`));
        subClient.on('error', (e) => logger.warn(`[socket.redis] sub error: ${e.message}`));
        io.adapter(createAdapter(pubClient, subClient));
        logger.info('[socket.redis] adaptateur Redis ACTIVÉ → sockets multi-instance OK');
      } catch (e) {
        logger.warn(`[socket.redis] Redis indisponible (${e.message}) — fallback mono-instance`);
      }
    })();
  } else {
    logger.info('[socket.redis] REDIS_URL absent → mode mono-instance (OK pour 1 instance Render)');
  }

  // v23.1 part 130 — Phase 6 audit P6-1 (BLOCKER) :
  // AVANT : pas d'auth socket → un attaquant pouvait envoyer
  // `user:identify {role:'admin', userId:<anyone>}` puis recevoir tous
  // les évènements de cet user (chat, notif, paiements). De même
  // `conversation:join` acceptait un userId arbitraire du payload.
  // MAINTENANT : middleware io.use qui valide le JWT au handshake
  // exactement comme requireAuth REST. Le token doit arriver via
  //   - socket.handshake.auth.token  (recommandé, socket.io v3+)
  //   - OU socket.handshake.headers.authorization (Bearer …) en
  //     fallback (compat avec setExtraHeaders côté Flutter).
  // Le payload {id, role} décodé est stocké sur socket.data.user et
  // les handlers (chatSocket, mapSocket) doivent désormais utiliser
  // CETTE source de vérité, pas le payload client.
  io.use((socket, next) => {
    try {
      const authToken =
        socket.handshake?.auth?.token ||
        ((socket.handshake?.headers?.authorization || '')
          .replace(/^Bearer\s+/i, '')
          .trim());
      if (!authToken) {
        return next(new Error('AUTH_REQUIRED'));
      }
      if (!process.env.JWT_SECRET) {
        return next(new Error('JWT_SECRET not configured'));
      }
      const payload = jwt.verify(authToken, process.env.JWT_SECRET);
      if (!payload?.id || !payload?.role) {
        return next(new Error('AUTH_INVALID'));
      }
      // ignore: no-param-reassign
      socket.data = socket.data || {};
      socket.data.user = { id: String(payload.id), role: String(payload.role) };
      return next();
    } catch (e) {
      logger.warn(`[socket] auth rejected : ${e?.message || e}`);
      return next(new Error('AUTH_FAILED'));
    }
  });

  io.on('connection', (socket) => {
    registerChatHandlers(io, socket);
    registerMapHandlers(io, socket);
  });

  return io;
};

module.exports = createSocketServer;

