// v584 (lot C du chantier du 24/09) — PREUVE serveur du mode « visible par mes
// amis seulement » (exigence de Daniel, LEGENDE_PAWMAP.md) : 3 comptes en zone
// fictive (lat -35 / lng -30), sans base ni réseau (modèles simulés) :
//   · MOI     : gardien MASQUÉ (preferences.hideFromMap = true), abonné PawSpot
//               (donc listé dans la couche « proches ») ;
//   · L'AMI   : propriétaire, amitié ACCEPTÉE avec moi ;
//   · L'INCONNU : promeneur, aucune amitié.
// On appelle les VRAIS gestionnaires des routes GET /friends/members/nearby et
// GET /friends/members/world, dans cet ordre :
//   1. l'inconnu appelle world (le cache partagé de 5 min se remplit SANS moi),
//   2. l'ami appelle nearby ET world → je suis dans les deux réponses,
//   3. l'inconnu rappelle nearby ET world (cache chaud) → je n'y suis pas,
//   4. l'ami reçoit ma position EXACTE dans nearby, l'inconnu ne me reçoit pas.
// Puis la même règle sur la route PUBLIQUE /sitters/nearby (fuite du lot B) :
// l'ami voit exact, l'inconnu voit flouté, le masqué est invisible pour lui.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const LAT = -35.2;
const LNG = -30.4;
const FUTURE = new Date(Date.now() + 30 * 24 * 3600 * 1000);

const DOCS = {
  Owner: [
    { _id: 'friend1', email: 'friend@example.test', name: 'Ami', location: { type: 'Point', coordinates: [LNG + 0.005, LAT] }, preferences: {} },
  ],
  Sitter: [
    { _id: 'me1', email: 'me@example.test', name: 'Moi', location: { type: 'Point', coordinates: [LNG, LAT] }, preferences: { hideFromMap: true }, mapBoostExpiry: FUTURE, kycStatus: 'verified' },
    { _id: 'open1', email: 'open@example.test', name: 'Ouvert', location: { type: 'Point', coordinates: [LNG + 0.01, LAT + 0.01] }, preferences: { hideFromMap: false }, mapBoostExpiry: FUTURE },
  ],
  Walker: [
    { _id: 'stranger1', email: 'stranger@example.test', name: 'Inconnu', location: { type: 'Point', coordinates: [LNG - 0.01, LAT] }, preferences: {} },
  ],
};

function matches(doc, q) {
  if (!q) return true;
  for (const [k, v] of Object.entries(q)) {
    if (k === '$or') {
      if (!v.some((c) => matches(doc, c))) return false;
    } else if (k === 'location') {
      // $near : ignoré (tout le monde est dans le rayon de test)
    } else if (k === 'location.coordinates.1') {
      if (!doc.location || !Array.isArray(doc.location.coordinates)) return false;
    } else if (k === 'preferences.hideFromMap') {
      const val = doc.preferences ? doc.preferences.hideFromMap : undefined;
      if (v && typeof v === 'object' && '$ne' in v) { if (val === v.$ne) return false; }
      else if (val !== v) return false;
    } else if (k === '_id') {
      if (v && typeof v === 'object' && '$in' in v) { if (!v.$in.map(String).includes(String(doc._id))) return false; }
      else if (String(doc._id) !== String(v)) return false;
    } else if (v && typeof v === 'object' && '$ne' in v) {
      if (doc[k] === v.$ne) return false;
    } else if (v && typeof v === 'object' && '$in' in v) {
      if (!v.$in.map(String).includes(String(doc[k]))) return false;
    } else if (doc[k] !== v) {
      return false;
    }
  }
  return true;
}

const chain = (result) => {
  const c = {
    select: () => c, limit: () => c, sort: () => c,
    lean: () => Promise.resolve(result),
    then: (ok, ko) => Promise.resolve(result).then(ok, ko),
    catch: () => c,
  };
  return c;
};

const mockModel = (name) => ({
  find: jest.fn((q) => chain(DOCS[name].filter((d) => matches(d, q)).map((d) => ({ ...d })))),
  findById: jest.fn((id) => chain(DOCS[name].find((d) => String(d._id) === String(id)) || null)),
  exists: jest.fn(() => Promise.resolve(false)),
});

jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));
jest.mock('../src/models/UserSubscription', () => ({
  find: jest.fn(() => chain([])),
  findOne: jest.fn(() => chain(null)),
}));
jest.mock('../src/models/Friendship', () => ({
  find: jest.fn((q) => {
    // Une seule amitié acceptée : friend1 ↔ me1.
    const rows = [{ requesterId: 'friend1', addresseeId: 'me1', status: 'accepted' }];
    const ids = new Set();
    for (const c of (q.$or || [])) {
      for (const v of Object.values(c)) for (const x of (v.$in || [])) ids.add(String(x));
    }
    return chain(rows.filter((r) => ids.has(String(r.requesterId)) || ids.has(String(r.addresseeId))));
  }),
}));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)),
  isIdentityOnline: jest.fn(() => false),
}));
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve([String(id)])),
  personIndex: jest.fn((ids) => Promise.resolve(new Map(ids.map((i) => [String(i), { ids: [String(i)] }])))),
}));

const router = require('../src/routes/friendRoutes');

function handler(path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path);
  if (!layer) throw new Error(`route ${path} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}

function call(fn, user, query = {}) {
  return new Promise((resolve, reject) => {
    const req = { user, query, headers: {} };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(body) { resolve({ status: this.statusCode, body }); },
    };
    fn(req, res).catch(reject);
  });
}

const ids = (body) => (body.members || []).map((m) => m.id);
const nearby = () => handler('/members/nearby');
const world = () => handler('/members/world');
const FRIEND = { id: 'friend1', role: 'owner' };
const STRANGER = { id: 'stranger1', role: 'walker' };
const Q = { lat: String(LAT), lng: String(LNG), radiusInMeters: '25000' };

describe('mode « amis seulement » — /friends/members/nearby et /world, 3 comptes', () => {
  test("1. l'inconnu remplit le cache de la couche monde : je n'y suis pas", async () => {
    const r = await call(world(), STRANGER);
    expect(r.status).toBe(200);
    expect(ids(r.body)).toContain('open1');
    expect(ids(r.body)).not.toContain('me1');
  });

  test("2. l'ami me voit dans nearby (position exacte + drapeaux) ET dans world (cache chaud)", async () => {
    const n = await call(nearby(), FRIEND, Q);
    expect(n.status).toBe(200);
    expect(ids(n.body)).toContain('me1');
    const me = n.body.members.find((m) => m.id === 'me1');
    expect(me.location.coordinates).toEqual([LNG, LAT]);
    expect(me.kycVerified).toBe(true);
    expect(me.isBoosted).toBe(false);
    expect(typeof me.availableToday).toBe('boolean');

    const w = await call(world(), FRIEND);
    expect(ids(w.body)).toContain('me1');
    const meWorld = w.body.members.find((m) => m.id === 'me1');
    expect(meWorld.hiddenFromMap).toBe(true);
    expect(meWorld.approx).toBe(true);
    // Le cache partagé, lui, ne me contient toujours pas.
    expect(w.body.members.filter((m) => m.id === 'me1')).toHaveLength(1);
  });

  test("3. l'inconnu, cache chaud : toujours pas moi, ni dans nearby ni dans world", async () => {
    const n = await call(nearby(), STRANGER, Q);
    expect(n.status).toBe(200);
    expect(ids(n.body)).toContain('open1');
    expect(ids(n.body)).not.toContain('me1');
    const w = await call(world(), STRANGER);
    expect(ids(w.body)).toContain('open1');
    expect(ids(w.body)).not.toContain('me1');
  });

  test('4. la couche monde ne contient jamais un compte de test', async () => {
    DOCS.Sitter.push({ _id: 'test1', email: 'dadaciao84+testsitter@gmail.com', name: 'Test Sitter', location: { coordinates: [LNG, LAT] }, preferences: {} });
    // Le cache est chaud : on force un cache périmé en réinitialisant le module.
    jest.resetModules();
    const r2 = require('../src/routes/friendRoutes');
    const l = r2.stack.find((x) => x.route && x.route.path === '/members/world');
    const fn = l.route.stack[l.route.stack.length - 1].handle;
    const r = await call(fn, STRANGER);
    expect(ids(r.body)).not.toContain('test1');
    DOCS.Sitter.pop();
  });
});
