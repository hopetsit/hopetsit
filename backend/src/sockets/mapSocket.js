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

// ─────────────────────────────────────────────────────────────────────────
// v565 — point 23 (contrat §8) : PARTAGE EN DIRECT ROBUSTE.
//
// Daniel : « le partage s'arrête tout seul en < 2 h, j'ai rien touché ».
// Côté serveur, DEUX causes : (1) à la moindre déconnexion socket (app
// suspendue par l'OS, réseau qui saute) le handler `disconnect` émettait
// `map:friend-offline` à tous les amis → le marqueur disparaissait comme si
// l'utilisateur avait coupé ; (2) rien ne gardait la dernière position en
// mémoire, donc « vu il y a X min » était impossible.
//
// Règle désormais : le serveur NE COUPE JAMAIS un partage de sa propre
// initiative. Il garde la DERNIÈRE position de chaque diffuseur en RAM
// pendant 24 h avec `lastSeenAt` ; les amis voient « signal perdu »
// (`stale` = plus de 3 min sans signal) au lieu d'un marqueur qui disparaît.
// Le partage ne s'arrête QUE : (a) sur `map:go-offline` / `offline:true`
// (action utilisateur), (b) à l'échéance de la durée CHOISIE par
// l'utilisateur ('1h' | '4h' ; 'until_stop' = jamais). Toutes les 4 h de
// partage, notification `live_still_active` au diffuseur.
// ─────────────────────────────────────────────────────────────────────────
const LIVE_RAM_TTL_MS = 24 * 60 * 60 * 1000;   // dernière position gardée 24 h
const LIVE_STALE_MS = 3 * 60 * 1000;            // « signal perdu » après 3 min
const LIVE_STILL_ACTIVE_MS = 4 * 60 * 60 * 1000; // rappel « toujours actif » / 4 h
const LIVE_DURATIONS = { '1h': 60 * 60 * 1000, '4h': 4 * 60 * 60 * 1000, until_stop: null };

/** userId (String) → session { userId, role, lat, lng, city, at, lastSeenAt,
 *  startedAt, duration, expiresAt, lastStillActiveNoticeAt } */
const liveSessions = new Map();

const normalizeDuration = (d) => {
  const key = String(d || '').trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(LIVE_DURATIONS, key) ? key : null;
};

/**
 * Crée/rafraîchit la session de partage d'un diffuseur.
 * - position (lat/lng) → met à jour la position + lastSeenAt ;
 * - heartbeat seul → met à jour lastSeenAt uniquement ;
 * - `duration` n'est appliquée que si fournie ('1h'|'4h'|'until_stop').
 */
function touchLiveSession({ userId, role, lat, lng, city, duration, heartbeat }) {
  const key = String(userId);
  const now = Date.now();
  let s = liveSessions.get(key);
  const hasPos = Number.isFinite(lat) && Number.isFinite(lng);
  if (!s) {
    if (!hasPos) return null; // un battement sans position ni session : rien à garder
    s = {
      userId: key,
      role: String(role || '').toLowerCase(),
      lat, lng, city: city || '',
      at: now,
      lastSeenAt: now,
      startedAt: now,
      duration: 'until_stop',
      expiresAt: null,
      lastStillActiveNoticeAt: now,
    };
    liveSessions.set(key, s);
  }
  if (role) s.role = String(role).toLowerCase();
  if (hasPos) {
    s.lat = lat; s.lng = lng; s.at = now;
    if (city) s.city = String(city);
  }
  s.lastSeenAt = now;
  const d = normalizeDuration(duration);
  if (d) {
    s.duration = d;
    const ms = LIVE_DURATIONS[d];
    // La durée court depuis le DÉBUT du partage (pas depuis ce battement).
    s.expiresAt = ms ? s.startedAt + ms : null;
  }
  void heartbeat;
  return s;
}

function getLiveSession(userId) {
  return liveSessions.get(String(userId)) || null;
}

/** Session la plus fraîche parmi plusieurs ids (les 3 docs de rôle d'une personne). */
function getLiveSessionForIds(ids = []) {
  let best = null;
  for (const id of ids) {
    const s = liveSessions.get(String(id));
    if (s && (!best || s.lastSeenAt > best.lastSeenAt)) best = s;
  }
  return best;
}

function clearLiveSession(userId) {
  return liveSessions.delete(String(userId));
}

const isLiveStale = (lastSeenAt) => (Date.now() - Number(lastSeenAt || 0)) > LIVE_STALE_MS;

/** Sérialisation publique d'une session (pour /friends/live-positions). */
function describeLiveSession(s) {
  if (!s) return null;
  return {
    lat: s.lat,
    lng: s.lng,
    city: s.city || '',
    at: new Date(s.at).toISOString(),
    lastSeenAt: new Date(s.lastSeenAt).toISOString(),
    stale: isLiveStale(s.lastSeenAt),
    duration: s.duration,
    expiresAt: s.expiresAt ? new Date(s.expiresAt).toISOString() : null,
  };
}

/**
 * Termine une session à l'ÉCHÉANCE de la durée choisie : drapeau DB éteint,
 * `map:friend-offline` aux amis, notification `live_session_ended` au
 * diffuseur. Jamais appelée pour une simple perte de signal.
 */
async function endLiveSessionByDuration(s) {
  liveSessions.delete(s.userId);
  const model = ROLE_TO_MODEL_NAME[s.role];
  if (model) {
    try {
      await require(`../models/${model}`).updateOne(
        { _id: s.userId },
        { $set: { 'location.liveShareActive': false } },
      );
    } catch (e) {
      logger.warn(`[live] offline flag (duration end) failed : ${e.message}`);
    }
  }
  try {
    const listeners = await listPositionListeners(s.userId, s.role);
    for (const l of listeners) {
      emitToUser(l.role, l.userId, 'map:friend-offline', {
        userId: l.viewAsId || s.userId,
        role: s.role,
        at: new Date().toISOString(),
        reason: 'duration_ended',
      });
    }
  } catch (e) {
    logger.warn(`[live] friend-offline (duration end) failed : ${e.message}`);
  }
  // Le diffuseur lui-même : son écran repasse sur « arrêté ».
  emitToUser(s.role, s.userId, 'map:live-session-ended', {
    userId: s.userId,
    role: s.role,
    duration: s.duration,
    at: new Date().toISOString(),
  });
  try {
    const { sendNotification } = require('../services/notificationSender');
    const { BASE_URL } = require('../utils/emailLinkBuilder');
    await sendNotification({
      userId: s.userId,
      role: s.role,
      type: 'live_session_ended',
      data: { duration: s.duration, emailLink: `${BASE_URL}/map` },
      actor: { role: 'system', id: null },
    });
  } catch (e) {
    logger.warn(`[live] live_session_ended notif failed : ${e.message}`);
  }
}

/**
 * Tick (60 s, appelé par services/handoverScheduler.js) :
 *   - durée choisie écoulée → fin de session (seule coupure serveur) ;
 *   - toutes les 4 h de partage → `live_still_active` au diffuseur ;
 *   - 24 h sans aucun signal → oubli silencieux de la RAM (les amis ne
 *     voyaient déjà plus qu'un point « signal perdu » ; aucune notification).
 */
async function tickLiveShare() {
  const now = Date.now();
  let ended = 0;
  let noticed = 0;
  for (const s of Array.from(liveSessions.values())) {
    try {
      if (now - s.lastSeenAt > LIVE_RAM_TTL_MS) {
        liveSessions.delete(s.userId);
        continue;
      }
      if (s.expiresAt && now >= s.expiresAt) {
        await endLiveSessionByDuration(s);
        ended += 1;
        continue;
      }
      if (now - s.lastStillActiveNoticeAt >= LIVE_STILL_ACTIVE_MS) {
        s.lastStillActiveNoticeAt = now; // posé AVANT l'envoi : jamais deux fois
        const hours = Math.max(1, Math.round((now - s.startedAt) / (60 * 60 * 1000)));
        try {
          const { sendNotification } = require('../services/notificationSender');
          const { BASE_URL } = require('../utils/emailLinkBuilder');
          await sendNotification({
            userId: s.userId,
            role: s.role,
            type: 'live_still_active',
            data: { hours: String(hours), duration: s.duration, emailLink: `${BASE_URL}/map` },
            actor: { role: 'system', id: null },
          });
          noticed += 1;
        } catch (e) {
          logger.warn(`[live] live_still_active notif failed : ${e.message}`);
        }
      }
    } catch (e) {
      logger.warn(`[live] tick error for ${s.userId} : ${e.message}`);
    }
  }
  if (ended || noticed) {
    logger.info(`[live] tick : ${ended} session(s) terminée(s) (durée), ${noticed} rappel(s) « toujours actif ».`);
  }
  return { ended, noticed, active: liveSessions.size };
}

/** List friends who currently receive my position (based on their toggle). */
async function listPositionListeners(userId, role) {
  const model = ROLE_TO_MODEL_NAME[role];
  if (!model) return [];

  // v526 — Daniel : « mon ami inscrit en sitter passe en owner/walker et je
  // ne peux plus le suivre ». L'amitié référence UN doc de rôle précis ;
  // quand le diffuseur émet depuis un AUTRE de ses rôles, la query stricte
  // (userId, model) ne trouvait AUCUNE amitié → 0 listener → plus personne
  // ne recevait sa position. On matche désormais TOUTES les identités de la
  // personne (docs Owner/Sitter/Walker reliés par email/oldId).
  const { identityGroup } = require('../utils/identityGroup');
  const g = await identityGroup(userId);
  // v586 — « Masqué » sur la carte (preferences.mapVisibility = 'hidden') :
  // ma position n'est relayée à AUCUN ami. Le suivi d'une prestation payée
  // passe par /bookings/:id/provider-location, il n'est pas concerné.
  try {
    const { personMapVisibility } = require('../utils/mapVisibility');
    if ((await personMapVisibility(g.ids)) === 'hidden') return [];
  } catch (_) {/* lecture impossible : comportement d'avant */}
  const friendships = await Friendship.find({
    status: 'accepted',
    $or: [
      { requesterId: { $in: g.ids } },
      { addresseeId: { $in: g.ids } },
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
  // v532 — mémorise les personnes vers qui j'ai EXPLICITEMENT coupé le
  // partage. Sans cette liste, la fusion famille plus bas les réintégrait :
  // le `seen` ne contenait que les destinataires déjà ajoutés, jamais les
  // exclus. Résultat : couper le partage vers un membre de sa famille
  // n'avait aucun effet sur le direct (alors que /friends/live-positions,
  // lui, le respectait) — deux comportements contradictoires.
  const optedOut = new Set();
  for (const f of friendships) {
    // v526 — « moi » = n'importe lequel de mes docs de rôle.
    const isRequester = g.set.has(String(f.requesterId));

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
    if (myShare === false) {
      optedOut.add(String(otherId));
      continue;
    }

    if (!familyBypass && !myShare) {
      // v587 (25/09) — MÊME RÈGLE que GET /friends/live-positions : un ami
      // qui a SON PawFollow actif me suit (sauf opt-out explicite, traité plus
      // haut). Avant, la route HTTP le lui montrait mais la socket ne lui
      // envoyait rien : son écran ne recevait la position que toutes les
      // 2 min, et entre deux relectures l'ami passait « signal perdu ».
      let listenerPawFollow = false;
      try { listenerPawFollow = await hasActivePawFollow(otherId); } catch (_) {/* */}
      if (!listenerPawFollow) continue;
    }
    if (!familyBypass) {
      // Sans abo ni famille : je diffuse à cet ami seulement si J'AI allumé
      // « Partager » pour lui (Mes amis), ou s'il a son PawFollow (ci-dessus).
      // Le drapeau vaut false par défaut dans le schéma → opt-in par ami.
      // v555 — Daniel : « vérifie si le suivi direct marche bien pour tout le
      // monde ». On exigeait AUSSI que l'ami ait allumé SON partage vers moi
      // (« UX symétrique ») : A partage avec B, B n'a rien touché → B ne
      // recevait JAMAIS A. Or /friends/live-positions, lui, montrait A à B.
      // Deux règles contradictoires pour la même amitié ; le schéma dit
      // « chaque côté choisit sans affecter l'autre ». On s'y tient : mon
      // partage suffit. B garde son propre drapeau pour couper le sien.
    }

    listeners.push({
      userId: otherId,
      role: otherRole,
      // v526 — l'app du destinataire connaît le diffuseur par l'id référencé
      // dans LEUR amitié (pas forcément le doc du rôle courant du diffuseur).
      // On émet l'événement avec CET id pour que le marker matche côté app.
      viewAsId: String(isRequester ? f.requesterId : f.addresseeId),
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
        // v532 — un opt-out explicite prime sur l'appartenance à la famille.
        if (optedOut.has(String(m.userId))) continue;
        if (!seen.has(String(m.userId))) {
          seen.add(String(m.userId));
          listeners.push({ userId: m.userId, role: m.role });
        }
      }
    }
  } catch (e) {
    logger.warn(`[mapSocket:listPositionListeners] family merge failed : ${e.message}`);
  }

  return expandListenerRooms(listeners);
}

/**
 * v587 (25/09) — Daniel : « le direct ne marche pas, je vois suspendu ».
 * CAUSE : l'événement partait dans le salon du document de rôle référencé
 * par l'AMITIÉ (`user:owner:<id>`), alors que la socket de l'ami a rejoint le
 * salon de son rôle COURANT (`map:identify` = rôle du jeton). Un ami inscrit
 * en propriétaire qui regarde depuis son profil gardien (ou l'inverse) ne
 * recevait donc AUCUNE position en direct : seule la relecture HTTP toutes
 * les 2 min le rafraîchissait, et entre deux relectures le rond passait
 * « signal perdu » / le suivi s'arrêtait. On émet désormais vers les salons
 * des 3 rôles de la personne (une socket n'est que dans un seul : aucun
 * doublon), en gardant `viewAsId` (l'id que SON app connaît).
 */
async function expandListenerRooms(listeners) {
  if (!listeners.length) return listeners;
  let index = null;
  try {
    const { personIndex } = require('../utils/personScope');
    index = await personIndex(listeners.map((l) => String(l.userId)));
  } catch (e) {
    logger.warn(`[mapSocket:expandListenerRooms] ${e.message}`);
  }
  const out = [];
  const rooms = new Set();
  const push = (l) => {
    const room = userRoom(l.role, l.userId);
    if (rooms.has(room)) return;
    rooms.add(room);
    out.push(l);
  };
  for (const l of listeners) {
    push(l);
    const entry = index && index.get(String(l.userId));
    for (const d of (entry && entry.docs) || []) {
      const role = String(d.model || '').toLowerCase();
      if (!role) continue;
      push({ ...l, userId: String(d.id), role, viewAsId: l.viewAsId });
    }
  }
  return out;
}

// v416 — Daniel : "le direct doit rester allumé même app fermée de force".
// Relais HTTP réutilisable (même logique que le handler socket map:position-update)
// pour que le SERVICE DE FOND Android (isolate séparé, survit au swipe-kill via
// foreground service) puisse pousser la position SANS socket — il POST sur
// /friends/live-position et on diffuse ici aux amis/famille comme d'habitude.
async function relayLivePosition({ userId, role, lat, lng, city, offline, duration, heartbeat }) {
  const r = String(role || '').toLowerCase();
  let Model = null;
  if (r === 'walker') Model = require('../models/Walker');
  else if (r === 'sitter') Model = require('../models/Sitter');
  else Model = require('../models/Owner');

  // v565 (contrat §8) — battement sans position : on prolonge seulement
  // `lastSeenAt` (et on applique une éventuelle nouvelle durée), puis on
  // ré-émet la dernière position connue pour que les amis sortent de
  // « signal perdu ». Sans session en RAM (serveur redémarré), rien à
  // rejouer : l'app renverra une vraie position au prochain tick GPS.
  if (heartbeat && !(Number.isFinite(lat) && Number.isFinite(lng))) {
    const s = touchLiveSession({ userId, role: r, duration, heartbeat: true });
    if (!s) return 0;
    const listeners = await listPositionListeners(userId, r);
    const event = {
      userId, role: r, lat: s.lat, lng: s.lng, city: s.city || '',
      at: new Date(s.at).toISOString(),
      lastSeenAt: new Date(s.lastSeenAt).toISOString(),
      heartbeat: true,
    };
    for (const l of listeners) {
      emitToUser(l.role, l.userId, 'map:friend-position', {
        ...event,
        userId: l.viewAsId || userId,
      });
    }
    return listeners.length;
  }

  if (offline) {
    clearLiveSession(userId); // v565 — arrêt VOULU par l'utilisateur
    try {
      // v532 — on EFFAÇAIT `location.coordinates`. Or la recherche de
      // prestataires filtre sur l'existence de ce champ : couper le partage
      // faisait littéralement DISPARAÎTRE le gardien ou le promeneur des
      // résultats « près de chez moi », jusqu'à ce qu'il ressaisisse son
      // adresse. On garde les coordonnées et on éteint le direct avec le
      // drapeau dédié (les lecteurs du live le respectent).
      await Model.updateOne(
        { _id: userId },
        { $set: { 'location.liveShareActive': false } },
      );
    } catch (e) {
      logger.warn(`[relayLivePosition] offline flag failed : ${e.message}`);
    }
    const listeners = await listPositionListeners(userId, r);
    for (const l of listeners) {
      emitToUser(l.role, l.userId, 'map:friend-offline', {
        // v526 — id traduit par destinataire (cf. listPositionListeners).
        userId: l.viewAsId || userId, role: r, at: new Date().toISOString(),
      });
    }
    return 0;
  }

  try {
    // v532 — on remplaçait TOUT le sous-document `location`. Deux dégâts à
    // chaque position reçue : `locationType` ('large_city') repassait à
    // 'standard' — il pilote la tarification — et `city` était vidée quand le
    // client ne l'envoyait pas. On écrit désormais champ par champ.
    await Model.updateOne(
      { _id: userId },
      {
        $set: {
          'location.type': 'Point',
          'location.coordinates': [lng, lat],
          'location.updatedAt': new Date(),
          'location.liveShareActive': true,
          ...(city ? { 'location.city': String(city) } : {}),
        },
      },
    );
  } catch (e) {
    logger.warn(`[relayLivePosition] persist failed : ${e.message}`);
  }

  // v565 (contrat §8) — dernière position gardée en RAM 24 h + durée choisie.
  const session = touchLiveSession({ userId, role: r, lat, lng, city, duration });

  const listeners = await listPositionListeners(userId, r);
  const event = {
    userId, role: r, lat, lng, at: new Date().toISOString(), city: city || '',
    lastSeenAt: new Date(session ? session.lastSeenAt : Date.now()).toISOString(),
  };
  for (const l of listeners) {
    // v526 — id traduit par destinataire : son app matche le marker de l'ami
    // via l'id référencé dans LEUR amitié.
    emitToUser(l.role, l.userId, 'map:friend-position', {
      ...event,
      userId: l.viewAsId || userId,
    });
  }
  return listeners.length;
}

function registerMapHandlers(io, socket) {
  socket.on('map:identify', (payload = {}, callback) => {
    // v532 — USURPATION D'IDENTITÉ. Ce handler était le DERNIER à faire
    // confiance au payload du client (chatSocket avait été corrigé en part 130,
    // pas celui-ci). Avec un jeton parfaitement valide, il suffisait d'émettre
    // `map:identify {userId: <id de quelqu'un d'autre>, role: 'owner'}` pour :
    //   - rejoindre son salon privé et recevoir SES messages et notifications ;
    //   - recevoir les positions en direct de TOUS ses amis ;
    //   - écrire de fausses positions dans SON profil et les diffuser en son
    //     nom, ou effacer sa position avec `map:go-offline`.
    // L'identité vient désormais du JWT vérifié par le middleware socket.
    const trusted = socket.data?.user;
    const userId = trusted?.id || payload.userId;
    const role = trusted?.role || payload.role;
    if (trusted?.id && payload?.userId && String(payload.userId) !== String(trusted.id)) {
      logger.warn(
        `[mapSocket] map:identify refusé : le client prétend être ${payload.role}:${payload.userId} ` +
        `alors que son jeton dit ${trusted.role}:${trusted.id}.`,
      );
    }
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
                // v532 — écriture champ par champ : remplacer tout le
                // sous-document effaçait `locationType` (qui pilote les
                // tarifs) et `city`. Cf. même correctif dans relayLivePosition.
                $set: {
                  'location.type': 'Point',
                  'location.coordinates': [lng, lat], // GeoJSON = [lng, lat]
                  'location.updatedAt': new Date(),
                  'location.liveShareActive': true,
                  ...(payload.city ? { 'location.city': String(payload.city) } : {}),
                },
              },
            );
          }
        }
      } catch (e) {
        // Best-effort persist — never block the real-time fanout.
        logger.warn(`[mapSocket:position-update] DB persist failed : ${e.message}`);
      }

      // v565 (contrat §8) — dernière position en RAM 24 h + durée choisie
      // (`duration` optionnelle dans le payload : '1h' | '4h' | 'until_stop').
      const session = touchLiveSession({
        userId: identity.userId,
        role: identity.role,
        lat, lng,
        city: payload.city,
        duration: payload.duration,
      });

      const listeners = await listPositionListeners(identity.userId, identity.role);
      if (listeners.length === 0) return;

      const event = {
        userId: identity.userId,
        role: identity.role,
        lat,
        lng,
        at: new Date().toISOString(),
        lastSeenAt: new Date(session ? session.lastSeenAt : now).toISOString(),
        city: payload.city || '',
      };

      for (const l of listeners) {
        // v565 — id traduit par destinataire (comme relayLivePosition) : sans
        // cette traduction, le marqueur ne matchait pas quand le diffuseur
        // émettait depuis un autre de ses rôles.
        emitToUser(l.role, l.userId, 'map:friend-position', {
          ...event,
          userId: l.viewAsId || identity.userId,
        });
      }
    } catch (err) {
      logger.error('[mapSocket:position-update] error', err);
    }
  });

  socket.on('map:go-offline', async () => {
    try {
      const identity = socket.data?.mapIdentity;
      if (!identity) return;
      // v565 (contrat §8, point 11) — SEUL arrêt à l'initiative de
      // l'utilisateur : on oublie la session RAM, on éteint le drapeau DB
      // (ci-dessous) et on prévient les amis (map:friend-offline).
      clearLiveSession(identity.userId);
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
            // v532 — cf. relayLivePosition : on n'efface plus les coordonnées
            // (le prestataire disparaissait des résultats de recherche), on
            // éteint seulement le partage en direct.
            { $set: { 'location.liveShareActive': false } },
          );
        }
      } catch (e) {
        logger.warn(`[mapSocket:go-offline] DB unset failed : ${e.message}`);
      }
      const listeners = await listPositionListeners(identity.userId, identity.role);
      for (const l of listeners) {
        emitToUser(l.role, l.userId, 'map:friend-offline', {
          // v565 — id traduit par destinataire (cf. relayLivePosition).
          userId: l.viewAsId || identity.userId,
          role: identity.role,
          at: new Date().toISOString(),
          reason: 'user_stopped',
        });
      }
    } catch (err) {
      logger.error('[mapSocket:go-offline] error', err);
    }
  });

  socket.on('disconnect', () => {
    // v565 — point 23 (contrat §8) : AVANT, toute déconnexion socket (app
    // suspendue par l'OS, réseau qui saute, changement d'écran) émettait
    // `map:friend-offline` : le marqueur disparaissait chez les amis comme si
    // l'utilisateur avait coupé — c'est le « partage qui s'arrête tout seul ».
    // Le serveur ne coupe plus rien de lui-même : la dernière position reste
    // en RAM avec `lastSeenAt`, les amis voient « signal perdu » (`stale`)
    // après 3 min sans battement, et le partage ne s'arrête que sur
    // `map:go-offline` / `offline:true` ou à l'échéance de la durée choisie.
  });
}

module.exports = registerMapHandlers;
module.exports.relayLivePosition = relayLivePosition;
module.exports.listPositionListeners = listPositionListeners;
// v565 — contrat §8.
module.exports.touchLiveSession = touchLiveSession;
module.exports.getLiveSession = getLiveSession;
module.exports.getLiveSessionForIds = getLiveSessionForIds;
module.exports.clearLiveSession = clearLiveSession;
module.exports.describeLiveSession = describeLiveSession;
module.exports.tickLiveShare = tickLiveShare;
module.exports.isLiveStale = isLiveStale;
module.exports.LIVE_STALE_MS = LIVE_STALE_MS;
