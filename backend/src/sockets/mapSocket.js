/**
 * PawMap live-position socket handlers.
 *
 * Events the client can emit:
 *   map:identify          { userId, role }
 *     Subscribe to own user-room for targeted messages. Must be called once
 *     at connection time (same pattern as chatSocket).
 *
 *   map:position-update   { lat, lng, city? }
 *     Broadcast the sender's current position to all accepted friends who
 *     have NOT disabled incoming-position-share on their side. Rate-limited
 *     per-socket to 1 emit / 3s to prevent flooding.
 *
 *   map:go-offline
 *     Tell friends I've stopped sharing (clears their live marker).
 *
 * Events the client receives:
 *   map:friend-position   { userId, role, lat, lng, at, city }
 *     Another user (a friend of mine) moved.
 *
 *   map:friend-offline    { userId, role, at }
 *     A friend stopped sharing.
 *
 * The server never persists positions to avoid GDPR concerns — we only relay
 * them through RAM-resident socket rooms.
 */

const Friendship = require('../models/Friendship');
const { userRoom, emitToUser } = require('./emitter');
const logger = require('../utils/logger');

const MIN_EMIT_INTERVAL_MS = 3000;
const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

/** List friends who currently receive my position (based on their toggle). */
async function listPositionListeners(userId, role) {
  const model = ROLE_TO_MODEL_NAME[role];
  if (!model) return [];

  const friendships = await Friendship.find({
    status: 'accepted',
    $or: [
      { requesterId: userId, requesterModel: model },
      { addresseeId: userId, addresseeModel: model },
    ],
  }).lean();

  const listeners = [];
  for (const f of friendships) {
    const isRequester =
      String(f.requesterId) === String(userId) && f.requesterModel === model;

    // My own share flag must be on for me to broadcast.
    const myShare = isRequester
      ? f.requesterSharesPosition
      : f.addresseeSharesPosition;
    if (!myShare) continue;

    // The other side's receive flag — they can mute me — we reuse the same
    // flag on their side (it means "I accept receiving positions"). We read
    // it as "if the friend muted their own share, they probably don't want
    // to see ours either" to keep the UX symmetric.
    const theirShare = isRequester
      ? f.addresseeSharesPosition
      : f.requesterSharesPosition;
    if (!theirShare) continue;

    listeners.push({
      userId: isRequester ? f.addresseeId : f.requesterId,
      role: (isRequester ? f.addresseeModel : f.requesterModel).toLowerCase(),
    });
  }
  return listeners;
}

function registerMapHandlers(io, socket) {
  socket.on('map:identify', (payload = {}, callback) => {
    const { userId, role } = payload;
    if (userId && role) {
      socket.join(userRoom(role, userId));
      socket.data = socket.data || {};
      socket.data.mapIdentity = { userId, role };
      socket.data.lastPositionEmit = 0;
    }
    if (callback) callback({ status: 'ok' });
  });

  socket.on('map:position-update', async (payload = {}) => {
    try {
      const identity = socket.data?.mapIdentity;
      if (!identity) return;
      const now = Date.now();
      const last = socket.data.lastPositionEmit || 0;
      if (now - last < MIN_EMIT_INTERVAL_MS) return; // rate-limit
      socket.data.lastPositionEmit = now;

      const lat = Number(payload.lat);
      const lng = Number(payload.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;

      const listeners = await listPositionListeners(identity.userId, identity.role);
      if (listeners.length === 0) return;

      const event = {
        userId: identity.userId,
        role: identity.role,
        lat,
        lng,
        at: new Date().toISOString(),
        city: payload.city || '',
      };

      for (const l of listeners) {
        emitToUser(l.role, l.userId, 'map:friend-position', event);
      }
    } catch (err) {
      logger.error('[mapSocket:position-update] error', err);
    }
  });

  socket.on('map:go-offline', async () => {
    try {
      const identity = socket.data?.mapIdentity;
      if (!identity) return;
      const listeners = await listPositionListeners(identity.userId, identity.role);
      for (const l of listeners) {
        emitToUser(l.role, l.userId, 'map:friend-offline', {
          userId: identity.userId,
          role: identity.role,
          at: new Date().toISOString(),
        });
      }
    } catch (err) {
      logger.error('[mapSocket:go-offline] error', err);
    }
  });

  socket.on('disconnect', async () => {
    try {
      const identity = socket.data?.mapIdentity;
      if (!identity) return;
      const listeners = await listPositionListeners(identity.userId, identity.role);
      for (const l of listeners) {
        emitToUser(l.role, l.userId, 'map:friend-offline', {
          userId: identity.userId,
          role: identity.role,
          at: new Date().toISOString(),
        });
      }
    } catch (_) {
      // best-effort on disconnect
    }
  });
}

module.exports = registerMapHandlers;
