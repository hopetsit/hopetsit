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

  // v23.1.175 — Daniel : "fais le suivi famille". Le bypass famille
  // (PawFollow Famille €9.99) n'était pas câblé ici → un membre famille
  // qui n'avait pas activé son share-flag ne recevait jamais les positions
  // des autres membres. On charge isInSameFamily UNE fois par appel et
  // on l'utilise dans la boucle.
  // v23.1 part 226 — Daniel : "debloque le partage de position a mes
  // amis et famille si jai un abonnement paw follow". Si JE possede un
  // PawFollow ACTIF (n'importe quel tier), je broadcast ma position a
  // TOUS mes amis acceptes sans avoir besoin de toggler chaque switch.
  // C'est l'un des perks payants du plan : "je m'abonne pour partager".
  const { isInSameFamily, hasActivePawFollow } = require('../models/UserSubscription');
  let iHavePawFollow = false;
  try {
    iHavePawFollow = await hasActivePawFollow(userId);
  } catch (_) {/* defensive */}

  const listeners = [];
  for (const f of friendships) {
    const isRequester =
      String(f.requesterId) === String(userId) && f.requesterModel === model;

    const otherId = isRequester ? f.addresseeId : f.requesterId;
    const otherRole = (isRequester ? f.addresseeModel : f.requesterModel)
      .toLowerCase();

    // v23.1.175 — Bypass famille : si on est dans la même famille active,
    // on broadcast sans tenir compte des share-flags.
    let familyBypass = false;
    try {
      familyBypass = await isInSameFamily(userId, otherId);
    } catch (_) {/* defensive */}

    // v23.1 part 226 — Bypass PawFollow : si je suis abonne, je
    // broadcast a tous mes amis acceptes (Daniel : "debloque le
    // partage si j'ai un abonnement").
    if (iHavePawFollow) familyBypass = true;

    // v23.1 part 243 — Daniel : "le bouton afficher position on off
    // marche pas y reste bloquer sur auto". Le bypass PawFollow/famille
    // forcait le broadcast meme quand l'user avait explicitement
    // toggle OFF sa switch (requesterSharesPosition=false). Le toggle
    // visuel revenait sur ON apres refresh (cf. fix friendRoutes ligne
    // 139) ET la position continuait a partir cote socket. Maintenant
    // un opt-out explicite (myShare === false) tue le broadcast meme
    // avec PawFollow ou famille active.
    const myShare = isRequester
      ? f.requesterSharesPosition
      : f.addresseeSharesPosition;
    if (myShare === false) continue;

    if (!familyBypass) {
      // Default true mais l'user a coupe la switch — securite belt+suspenders.
      if (!myShare) continue;

      // The other side's receive flag — they can mute me — we reuse the same
      // flag on their side (it means "I accept receiving positions"). We read
      // it as "if the friend muted their own share, they probably don't want
      // to see ours either" to keep the UX symmetric.
      const theirShare = isRequester
        ? f.addresseeSharesPosition
        : f.requesterSharesPosition;
      if (!theirShare) continue;
    }

    listeners.push({
      userId: otherId,
      role: otherRole,
    });
  }

  // v23.1.297 — Daniel : "jai 5 amis/famille en direct et le cercle compte 2 ;
  // il faut compter famille ET amis". Les co-membres famille qui ne sont PAS
  // aussi des amis acceptés n'apparaissaient jamais ici → leur position
  // n'arrivait jamais (et inversement), donc le badge "Mon cercle" les
  // ignorait. On fusionne les membres famille actifs (perk payé = partage
  // auto, sans toggle par membre), en dédupliquant avec les amis déjà ajoutés.
  try {
    const { listFamilyMembers } = require('../models/UserSubscription');
    const fam = await listFamilyMembers(userId);
    if (fam.length) {
      const seen = new Set(listeners.map((l) => String(l.userId)));
      for (const m of fam) {
        if (!seen.has(String(m.userId))) {
          seen.add(String(m.userId));
          listeners.push({ userId: m.userId, role: m.role });
        }
      }
    }
  } catch (e) {
    logger.warn(`[mapSocket:listPositionListeners] family merge failed : ${e.message}`);
  }

  return listeners;
}

// v416 — Daniel : "le direct doit rester allumé même app fermée de force".
// Relais HTTP réutilisable (même logique que le handler socket map:position-update)
// pour que le SERVICE DE FOND Android (isolate séparé, survit au swipe-kill via
// foreground service) puisse pousser la position SANS socket — il POST sur
// /friends/live-position et on diffuse ici aux amis/famille comme d'habitude.
async function relayLivePosition({ userId, role, lat, lng, city, offline }) {
  const r = String(role || '').toLowerCase();
  let Model = null;
  if (r === 'walker') Model = require('../models/Walker');
  else if (r === 'sitter') Model = require('../models/Sitter');
  else Model = require('../models/Owner');

  if (offline) {
    try {
      await Model.updateOne(
        { _id: userId },
        { $unset: { 'location.coordinates': '' } },
      );
    } catch (e) {
      logger.warn(`[relayLivePosition] offline unset failed : ${e.message}`);
    }
    const listeners = await listPositionListeners(userId, r);
    for (const l of listeners) {
      emitToUser(l.role, l.userId, 'map:friend-offline', {
        userId, role: r, at: new Date().toISOString(),
      });
    }
    return 0;
  }

  try {
    await Model.updateOne(
      { _id: userId },
      {
        $set: {
          location: {
            type: 'Point',
            coordinates: [lng, lat],
            ...(city ? { city: String(city) } : {}),
          },
        },
      },
    );
  } catch (e) {
    logger.warn(`[relayLivePosition] persist failed : ${e.message}`);
  }

  const listeners = await listPositionListeners(userId, r);
  const event = {
    userId, role: r, lat, lng, at: new Date().toISOString(), city: city || '',
  };
  for (const l of listeners) {
    emitToUser(l.role, l.userId, 'map:friend-position', event);
  }
  return listeners.length;
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

      // v23.1 part 77 — Daniel : "jai mis suivre et activer la
      // geolocalisation du walker et ya ce message geoloc pas activer".
      // Root cause : this handler used to broadcast lat/lng via socket
      // ONLY, never persist it on the User document. So when the owner
      // hit GET /bookings/:id/provider-location later, Walker.location
      // .coordinates was empty → 204 NO_LOCATION_YET.
      //
      // Fix : also UPDATE the User's GeoJSON `location.coordinates` so
      // PawFollow live-tracking has a stable read source. Throttled to
      // one DB write every ~10s to avoid hammering Mongo on a fast
      // GPS stream. Only updates on roles that have a `location` field
      // (walker / sitter / owner all do per their respective schemas).
      try {
        const lastDbWrite = socket.data.lastLocationDbWrite || 0;
        if (now - lastDbWrite >= 10000) {
          socket.data.lastLocationDbWrite = now;
          let Model = null;
          if (identity.role === 'walker') Model = require('../models/Walker');
          else if (identity.role === 'sitter') Model = require('../models/Sitter');
          else if (identity.role === 'owner') Model = require('../models/Owner');
          if (Model) {
            await Model.updateOne(
              { _id: identity.userId },
              {
                $set: {
                  location: {
                    type: 'Point',
                    coordinates: [lng, lat], // GeoJSON = [lng, lat]
                    ...(payload.city ? { city: String(payload.city) } : {}),
                  },
                },
              },
            );
          }
        }
      } catch (e) {
        // Best-effort persist — never block the real-time fanout.
        logger.warn(`[mapSocket:position-update] DB persist failed : ${e.message}`);
      }

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
      // v23.1 part 243 — Daniel : "le bouton suivre si il est etain on
      // peux plus nous voir sa desactive la position". Avant : on
      // emettait map:friend-offline aux listeners → leur halo Rx
      // disparaissait COTE socket en temps reel. MAIS la User.location
      // persistee en DB par map:position-update (cf. ci-dessus) restait
      // intacte → /friends/:id/last-position retournait quand meme la
      // derniere position broadcastee. Daniel pouvait donc encore etre
      // localise via PeopleLiveScreen apres avoir eteint le toggle.
      // Fix : on UNSET location.coordinates en DB quand l'user va
      // offline → le fallback DB retourne null lat/lng, l'ami ne voit
      // plus aucun point.
      try {
        let Model = null;
        if (identity.role === 'walker') Model = require('../models/Walker');
        else if (identity.role === 'sitter') Model = require('../models/Sitter');
        else if (identity.role === 'owner') Model = require('../models/Owner');
        if (Model) {
          await Model.updateOne(
            { _id: identity.userId },
            { $unset: { 'location.coordinates': '' } },
          );
        }
      } catch (e) {
        logger.warn(`[mapSocket:go-offline] DB unset failed : ${e.message}`);
      }
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
module.exports.relayLivePosition = relayLivePosition;
module.exports.listPositionListeners = listPositionListeners;
