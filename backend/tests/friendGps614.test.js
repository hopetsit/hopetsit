// 614 (PAM, 07/10/2026) — Daniel : « pourquoi john n'est pas à côté de Cam
// alors qu'on est à côté ». MESURÉ (API admin) : john était posé sur sa
// position de PROFIL (centre d'Alhama de Murcia), à 13 km de chez lui ; le
// GPS envoyé par l'app à l'ouverture de la carte était jeté (< 50 km).
//
// VRAIE base Mongo en mémoire, vrais gestionnaires (POST /users/me/home-position
// via updateHomePosition, GET /friends, GET /friends/members/world). Zone
// fictive (lat -35 / lng -30), aucun réseau, aucune production.
//
// Vérifié :
//   · l'ouverture de la carte (même ville) n'écrit PAS la position de profil
//     mais garde le GPS à part (`lastGps`, 3 profils, updatedAt intact) ;
//   · un AMI voit ce GPS exact (positionSource 'gps') sur la carte et dans
//     « Mes amis » ;
//   · un NON-ami ne le voit jamais (position de profil floutée ~1 km) ;
//   · « Masqué » : aucune position, même pour un ami ;
//   · GPS de plus de 12 h : retour à la position de profil ;
//   · `lastGps` ne sort jamais d'une lecture ordinaire (select: false).
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
let router; let updateHomePosition; let friendPositionOf;

const oid = () => new mongoose.Types.ObjectId();
const LAT = -35.2;
const LNG = -30.4;
const KM = (a, b, c, d) => {
  const R = 6371; const r = (x) => (x * Math.PI) / 180;
  const h = Math.sin(r(c - a) / 2) ** 2 + Math.cos(r(a)) * Math.cos(r(c)) * Math.sin(r(d - b) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
};

// john : 3 profils, inscrit au « centre-ville » ; il vit à 13 km au sud.
const JOHN = { owner: oid(), sitter: oid(), walker: oid(), email: 'john614@example.test' };
const HOME = [LNG, LAT];
const REAL = [LNG + 0.04, LAT - 0.115]; // ≈ 13 km
const ME = { owner: oid(), email: 'daniel614@example.test' };
const STRANGER = { owner: oid(), email: 'stranger614@example.test' };
const HIDDEN = { walker: oid(), email: 'hidden614@example.test' };
const OLD_UPDATED = new Date('2026-09-01T00:00:00Z');

function doc(_id, email, name, vis, at) {
  return {
    _id,
    email,
    name,
    firstName: name,
    preferences: vis ? { mapVisibility: vis, hideFromMap: vis !== 'all' } : {},
    location: { type: 'Point', coordinates: at, city: 'Ville fictive' },
    homeLocation: { coordinates: at, city: 'Ville fictive', at: new Date('2026-09-01T00:00:00Z') },
    createdAt: OLD_UPDATED,
    updatedAt: OLD_UPDATED,
  };
}

function handler(path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods.get);
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
const befriend = (fromId, fromModel, otherId, otherModel) => Friendship.collection.insertOne({
  requesterId: fromId, requesterModel: fromModel,
  addresseeId: otherId, addresseeModel: otherModel,
  status: 'accepted', acceptedAt: new Date(), createdAt: new Date(), updatedAt: new Date(),
  requesterSharesPosition: true, addresseeSharesPosition: true,
});
const pointOf = (body, id) => (body.members || []).find((m) => String(m.id) === String(id)
  || (m.personIds || []).map(String).includes(String(id)));

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Friendship = require('../src/models/Friendship');
  router = require('../src/routes/friendRoutes');
  ({ updateHomePosition } = require('../src/utils/homePosition590'));
  ({ friendPositionOf } = require('../src/utils/friendPosition587'));

  await Owner.collection.insertOne(doc(JOHN.owner, JOHN.email, 'john C', 'all', HOME));
  await Sitter.collection.insertOne(doc(JOHN.sitter, JOHN.email, 'john C', 'all', HOME));
  await Walker.collection.insertOne(doc(JOHN.walker, JOHN.email, 'john C', 'all', HOME));
  await Owner.collection.insertOne(doc(ME.owner, ME.email, 'Daniel', 'all', [LNG + 0.3, LAT]));
  await Owner.collection.insertOne(doc(STRANGER.owner, STRANGER.email, 'Inconnu', 'all', [LNG - 0.3, LAT]));
  await Walker.collection.insertOne(doc(HIDDEN.walker, HIDDEN.email, 'Ami masque', 'hidden', HOME));
  // Daniel est ami avec le profil PROMENEUR de john (comme en production).
  await befriend(ME.owner, 'Owner', JOHN.walker, 'Walker');
  await befriend(ME.owner, 'Owner', HIDDEN.walker, 'Walker');
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

describe('614 — john ouvre la carte chez lui (13 km de son inscription)', () => {
  test('AVANT : un ami le voit à sa position de PROFIL (le bug de Daniel)', async () => {
    const w = await call('/members/world', { id: String(ME.owner), role: 'owner' });
    const p = pointOf(w.body, JOHN.walker);
    expect(p.isFriend).toBe(true);
    expect(p.positionSource).toBe('home');
    expect(p.location.coordinates).toEqual(HOME);
  });

  test('ouverture de la carte : profil inchangé, GPS gardé à part sur les 3 profils', async () => {
    const r = await updateHomePosition(String(JOHN.owner), { lat: REAL[1], lng: REAL[0] });
    expect(r.reason).toBe('same_city'); // < 50 km : la position de profil ne bouge pas
    for (const M of [Owner, Sitter, Walker]) {
      const d = await M.findById(JOHN[M.modelName.toLowerCase()]).select('+lastGps +homeLocation').lean();
      expect(d.lastGps.coordinates).toEqual(REAL);
      expect(d.homeLocation.coordinates).toEqual(HOME);
      expect(d.location.coordinates).toEqual(HOME);
      expect(new Date(d.updatedAt).getTime()).toBe(OLD_UPDATED.getTime());
    }
    // jamais dans une lecture ordinaire
    const plain = await Walker.findById(JOHN.walker).lean();
    expect(plain.lastGps).toBeUndefined();
  });

  test('APRÈS : l\'AMI le voit à sa vraie position (carte + « Mes amis »)', async () => {
    const w = await call('/members/world', { id: String(ME.owner), role: 'owner' });
    const p = pointOf(w.body, JOHN.walker);
    expect(p.positionSource).toBe('gps');
    expect(p.approx).toBe(false);
    expect(p.location.coordinates).toEqual(REAL);
    const f = await call('/', { id: String(ME.owner), role: 'owner' });
    const o = f.body.friends.find((x) => x.other.name === 'john C').other;
    expect(o.positionSource).toBe('gps');
    expect(o.location.coordinates).toEqual(REAL);
  });

  test('un NON-ami ne voit jamais ce GPS (profil flouté ~1 km)', async () => {
    const w = await call('/members/world', { id: String(STRANGER.owner), role: 'owner' });
    const p = pointOf(w.body, JOHN.walker);
    expect(p).toBeTruthy();
    expect(p.isFriend).toBeUndefined();
    expect(p.approx).toBe(true);
    expect(p.positionSource).not.toBe('gps');
    const [lng, lat] = p.location.coordinates;
    expect(KM(lat, lng, HOME[1], HOME[0])).toBeLessThan(1.5);
    expect(KM(lat, lng, REAL[1], REAL[0])).toBeGreaterThan(10);
    expect(JSON.stringify(w.body)).not.toContain(String(REAL[1]));
  });

  test('« Masqué » : aucune position, même avec un GPS frais', async () => {
    await updateHomePosition(String(HIDDEN.walker), { lat: REAL[1], lng: REAL[0] });
    const f = await call('/', { id: String(ME.owner), role: 'owner' });
    const o = f.body.friends.find((x) => x.other.name === 'Ami masque').other;
    expect(o.location).toBeNull();
  });

  test('cas réel du 06/10 : john arrête son DIRECT près de Cam → ses amis le gardent LÀ (pas au profil)', async () => {
    const map = require('../src/sockets/mapSocket');
    const NEAR_CAM = [LNG + 0.05, LAT - 0.12];
    // on repart d'un john sans GPS d'ouverture de carte
    for (const M of [Owner, Sitter, Walker]) {
      await M.collection.updateOne({ _id: JOHN[M.modelName.toLowerCase()] }, { $unset: { lastGps: '' } });
    }
    map.touchLiveSession({ userId: String(JOHN.walker), role: 'walker', lat: NEAR_CAM[1], lng: NEAR_CAM[0] });
    await require('../src/utils/liveDevices589').stopEverywhere(String(JOHN.walker), { notifyFriends: false });
    expect(map.getLiveSessionForIds([String(JOHN.walker)])).toBeNull(); // direct bien coupé
    const w = await call('/members/world', { id: String(ME.owner), role: 'owner' });
    const p = pointOf(w.body, JOHN.walker);
    expect(p.positionSource).toBe('gps');
    expect(p.location.coordinates).toEqual(NEAR_CAM);
    // et toujours rien pour un non-ami
    const s = await call('/members/world', { id: String(STRANGER.owner), role: 'owner' });
    expect(JSON.stringify(s.body)).not.toContain(String(NEAR_CAM[1]));
  });

  test('GPS de plus de 12 h : retour à la position de profil', () => {
    const now = new Date('2026-10-07T12:00:00Z');
    const base = { location: { coordinates: HOME }, homeLocation: { coordinates: HOME, at: OLD_UPDATED } };
    const fresh = friendPositionOf([{ role: 'walker', d: { ...base, lastGps: { coordinates: REAL, at: new Date('2026-10-07T01:00:00Z') } } }], { now });
    expect(fresh.positionSource).toBe('gps');
    const stale = friendPositionOf([{ role: 'walker', d: { ...base, lastGps: { coordinates: REAL, at: new Date('2026-10-06T23:00:00Z') } } }], { now });
    expect(stale.positionSource).toBe('home');
    expect(stale.location.coordinates).toEqual(HOME);
  });
});
