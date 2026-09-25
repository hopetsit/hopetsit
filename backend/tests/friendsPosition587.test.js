// v587 — point 11 (décision écrite de Daniel du 25/09 : « Amis OK, je l'active »).
// VRAIE base Mongo en mémoire, vrais gestionnaires de GET /friends et
// GET /friends/members/world, vraie résolution des personnes (identityGroup,
// personScope). Zone fictive (lat -35 / lng -30), aucun réseau, aucune production.
//
// Vérifié :
//   · /friends renvoie pour chaque ami sa position de PROFIL floutée ~1 km
//     (approxKm, positionSource), sauf « Masqué » (aucune position) ;
//   · les 3 états de visibilité × ami / inconnu ;
//   · le MÊME résultat depuis mes 3 profils (retour de Daniel : « je me suis
//     connecté avec un autre profil et aucun ami n'apparaît ») ;
//   · world : isFriend sur tous les ids de la personne, ami hors cache (au-delà
//     du plafond) réinjecté, compte de test visible de ses amis seulement,
//     « Masqué » absent pour tous.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/services/notificationSender', () => new Proxy({}, {
  get: () => jest.fn(async () => ({})),
}));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)),
  isIdentityOnline: jest.fn(() => false),
  emitToUser: jest.fn(),
  userRoom: (role, id) => `user:${role}:${id}`,
}));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo;
let Owner; let Sitter; let Walker; let Friendship;
let router;

const oid = () => new mongoose.Types.ObjectId();
const LAT = -35.2;
const LNG = -30.4;
const KM = (a, b, c, d) => {
  const R = 6371; const r = (x) => (x * Math.PI) / 180;
  const h = Math.sin(r(c - a) / 2) ** 2 + Math.cos(r(a)) * Math.cos(r(c)) * Math.sin(r(d - b) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
};

// Moi : un compte, trois profils (même e-mail).
const ME = { owner: oid(), sitter: oid(), walker: oid() };
// Amis : un état chacun ; fAll a deux profils (gardien + promeneur).
const F = {
  all: { sitter: oid(), walker: oid(), email: 'fall587@example.test', vis: 'all', at: [LNG + 0.01, LAT] },
  friends: { owner: oid(), email: 'ffriends587@example.test', vis: 'friends', at: [LNG + 0.02, LAT] },
  hidden: { walker: oid(), email: 'fhidden587@example.test', vis: 'hidden', at: [LNG + 0.03, LAT] },
  test: { sitter: oid(), email: 'dadaciao84+test587@example.test', vis: 'all', at: [LNG + 0.04, LAT] },
};
const LATE = { owner: oid(), email: 'flate587@example.test', vis: 'all', at: [LNG + 0.05, LAT] };
const STRANGER = { owner: oid(), email: 'stranger587@example.test' };

function doc(_id, email, name, vis, at) {
  return {
    _id,
    email,
    name,
    firstName: name,
    preferences: vis ? { mapVisibility: vis, hideFromMap: vis !== 'all' } : {},
    // position de PROFIL (formulaire) : pas de location.updatedAt
    location: { type: 'Point', coordinates: at, city: '' },
    homeLocation: { coordinates: at, city: '', at: new Date() },
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

function handler(path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods.get);
  if (!layer) throw new Error(`route ${path} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
function call(path, user) {
  const fn = handler(path);
  return new Promise((resolve, reject) => {
    const req = { user, query: {}, headers: {} };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ status: this.statusCode, body: b }); },
    };
    Promise.resolve(fn(req, res)).catch(reject);
  });
}
const befriend = (otherId, otherModel) => Friendship.collection.insertOne({
  requesterId: ME.owner, requesterModel: 'Owner',
  addresseeId: otherId, addresseeModel: otherModel,
  status: 'accepted', acceptedAt: new Date(), createdAt: new Date(), updatedAt: new Date(),
  requesterSharesPosition: true, addresseeSharesPosition: true,
});

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Friendship = require('../src/models/Friendship');
  router = require('../src/routes/friendRoutes');

  await Owner.collection.insertOne(doc(ME.owner, 'me587@example.test', 'Moi', 'all', [LNG, LAT]));
  await Sitter.collection.insertOne(doc(ME.sitter, 'me587@example.test', 'Moi', 'all', [LNG, LAT]));
  await Walker.collection.insertOne(doc(ME.walker, 'me587@example.test', 'Moi', 'all', [LNG, LAT]));
  await Sitter.collection.insertOne(doc(F.all.sitter, F.all.email, 'Ami tous', 'all', F.all.at));
  await Walker.collection.insertOne(doc(F.all.walker, F.all.email, 'Ami tous', 'all', F.all.at));
  await Owner.collection.insertOne(doc(F.friends.owner, F.friends.email, 'Ami amis', 'friends', F.friends.at));
  await Walker.collection.insertOne(doc(F.hidden.walker, F.hidden.email, 'Ami masque', 'hidden', F.hidden.at));
  await Sitter.collection.insertOne(doc(F.test.sitter, F.test.email, 'Ami test', 'all', F.test.at));
  await Owner.collection.insertOne(doc(STRANGER.owner, STRANGER.email, 'Inconnu', 'all', [LNG - 0.02, LAT]));

  // Amitiés nouées depuis MON profil propriétaire, vers un profil précis de chacun.
  await befriend(F.all.sitter, 'Sitter');
  await befriend(F.friends.owner, 'Owner');
  await befriend(F.hidden.walker, 'Walker');
  await befriend(F.test.sitter, 'Sitter');
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

const ASME = [
  ['propriétaire', { id: String(ME.owner), role: 'owner' }],
  ['gardien', { id: String(ME.sitter), role: 'sitter' }],
  ['promeneur', { id: String(ME.walker), role: 'walker' }],
];
const byName = (list) => Object.fromEntries((list || []).map((f) => [f.other.name, f.other]));

describe('GET /friends — position de profil floutée, depuis chacun de mes 3 profils', () => {
  test.each(ASME)('connecté en %s : les 4 mêmes amis', async (_label, user) => {
    const r = await call('/', user);
    expect(r.status).toBe(200);
    const got = byName(r.body.friends);
    expect(Object.keys(got).sort()).toEqual(['Ami amis', 'Ami masque', 'Ami test', 'Ami tous']);

    // « Visible par tous », « Amis seulement », compte de test : position floutée ~1 km.
    for (const [name, exact] of [['Ami tous', F.all.at], ['Ami amis', F.friends.at], ['Ami test', F.test.at]]) {
      const o = got[name];
      expect([name, !!o.location]).toEqual([name, true]);
      expect(o.approx).toBe(true);
      expect(o.approxKm).toBe(1);
      expect(o.positionSource).toBe('home');
      expect(o.location.coordinates).not.toEqual(exact);
      const [lng, lat] = o.location.coordinates;
      expect(KM(exact[1], exact[0], lat, lng)).toBeLessThan(1);
    }
    // « Masqué » : ami listé, mais AUCUNE position.
    expect(got['Ami masque'].location).toBeNull();
    expect(got['Ami masque'].mapVisibility).toBe('hidden');
    expect(got['Ami amis'].mapVisibility).toBe('friends');
    // Tous les profils de l'ami sont annoncés (le direct d'un autre rôle s'y rattache).
    expect(got['Ami tous'].personIds.sort()).toEqual([String(F.all.sitter), String(F.all.walker)].sort());
  });

  test('même position floutée quel que soit mon profil', async () => {
    const pos = [];
    for (const [, user] of ASME) {
      const r = await call('/', user);
      pos.push(byName(r.body.friends)['Ami tous'].location.coordinates);
    }
    expect(pos[1]).toEqual(pos[0]);
    expect(pos[2]).toEqual(pos[0]);
  });

  test('un inconnu n\'a aucun ami, donc aucune position', async () => {
    const r = await call('/', { id: String(STRANGER.owner), role: 'owner' });
    expect(r.body.friends).toEqual([]);
  });
});

describe('GET /friends/diagnose (source de « Mes amis » dans l\'app) — les 3 profils', () => {
  test.each(ASME)('connecté en %s : les mêmes amis acceptés', async (_l, user) => {
    const r = await call('/diagnose', user);
    const accepted = r.body.friendships.filter((f) => f.status === 'accepted');
    expect(accepted.map((f) => f.otherName).sort()).toEqual(['Ami amis', 'Ami masque', 'Ami test', 'Ami tous']);
    // l'amitié a été nouée depuis MON profil propriétaire : je reste le demandeur
    expect(accepted.every((f) => f.iAmRequester === true && f.iAmAddressee === false)).toBe(true);
  });
});

describe('GET /friends/members/world — isFriend, réinjection, test, masqué', () => {
  const pointOf = (body, id) => (body.members || []).find((m) => String(m.id) === String(id)
    || (m.personIds || []).map(String).includes(String(id)));

  test('inconnu (remplit le cache partagé) : seul « Visible par tous » (hors test), jamais isFriend', async () => {
    const w = await call('/members/world', { id: String(STRANGER.owner), role: 'owner' });
    expect(w.status).toBe(200);
    expect(pointOf(w.body, F.all.sitter)).toBeTruthy();
    expect(pointOf(w.body, F.all.sitter).isFriend).toBeUndefined();
    expect(pointOf(w.body, F.friends.owner)).toBeFalsy();
    expect(pointOf(w.body, F.hidden.walker)).toBeFalsy();
    expect(pointOf(w.body, F.test.sitter)).toBeFalsy(); // test exclu de la vitrine
  });

  test.each(ASME)('ami, connecté en %s : isFriend partout, test visible, masqué absent', async (_l, user) => {
    const w = await call('/members/world', user);
    const all = pointOf(w.body, F.all.walker);
    expect(all).toBeTruthy();
    expect(all.isFriend).toBe(true);
    expect((all.personIds || []).map(String).sort()).toEqual([String(F.all.sitter), String(F.all.walker)].sort());
    expect(pointOf(w.body, F.friends.owner).isFriend).toBe(true);
    expect(pointOf(w.body, F.test.sitter).isFriend).toBe(true);
    expect(pointOf(w.body, F.test.sitter).approxKm).toBe(1);
    expect(pointOf(w.body, F.hidden.walker)).toBeFalsy();
    // une seule entrée par personne
    const n = (w.body.members || []).filter((m) => (m.personIds || [m.id]).map(String).includes(String(F.all.sitter))).length;
    expect(n).toBe(1);
  });

  test('ami « Visible par tous » ABSENT du cache (au-delà du plafond) : réinjecté pour ses amis seulement', async () => {
    // Le cache partagé (5 min) a été construit AVANT ce membre : il n'y est pas,
    // exactement comme un membre au-delà du plafond de 3 000.
    await Owner.collection.insertOne(doc(LATE.owner, LATE.email, 'Ami tardif', 'all', LATE.at));
    await befriend(LATE.owner, 'Owner');
    const asFriend = await call('/members/world', { id: String(ME.sitter), role: 'sitter' });
    const p = pointOf(asFriend.body, LATE.owner);
    expect(p).toBeTruthy();
    expect(p.isFriend).toBe(true);
    expect(p.hiddenFromMap).toBe(false);
    expect(p.approxKm).toBe(1);
    const asStranger = await call('/members/world', { id: String(STRANGER.owner), role: 'owner' });
    expect(pointOf(asStranger.body, LATE.owner)).toBeFalsy();
  });
});

describe('Direct depuis le profil PROPRIÉTAIRE (point 4) — envoyé aux 3 profils de chaque ami', () => {
  test('le propriétaire qui partage atteint tous les profils de ses amis, sauf « Masqué »', async () => {
    const { emitToUser } = require('../src/sockets/emitter');
    const { relayLivePosition } = require('../src/sockets/mapSocket');
    emitToUser.mockClear();
    const n = await relayLivePosition({ userId: String(ME.owner), role: 'owner', lat: LAT + 0.001, lng: LNG + 0.001 });
    expect(n).toBeGreaterThan(0);
    const rooms = emitToUser.mock.calls
      .filter((c) => c[2] === 'map:friend-position')
      .map((c) => `${c[0]}:${String(c[1])}`);
    // l'ami « Visible par tous » : ses DEUX profils (gardien ET promeneur)
    expect(rooms).toContain(`sitter:${String(F.all.sitter)}`);
    expect(rooms).toContain(`walker:${String(F.all.walker)}`);
    expect(rooms).toContain(`owner:${String(F.friends.owner)}`);
    // un ami masqué reçoit quand même MON direct (c'est MOI qui partage) ;
    // l'inconnu, jamais.
    expect(rooms.some((r) => r.endsWith(String(STRANGER.owner)))).toBe(false);
    await relayLivePosition({ userId: String(ME.owner), role: 'owner', offline: true });
  });
});
