// v586 (25/09/2026) — UNE SEULE VÉRITÉ « qui me voit sur la carte » :
// preferences.mapVisibility = 'all' | 'friends' | 'hidden' (+ migration douce
// depuis hideFromMap). Daniel : « masquer / visible par tous n'est pas synchro
// avec le menu de la PawMap ». Preuve : 3 états × (ami, inconnu) sur les VRAIS
// gestionnaires de /friends/members/nearby, /friends/members/world et
// /friends/live-positions, + la route publique /sitters/nearby (règle pure
// applyPublicPrivacy) et l'API /users/me/map-prefs (lecture / écriture).
// Zone fictive (lat -35 / lng -30), modèles simulés : aucune base, aucun réseau.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const LAT = -35.2;
const LNG = -30.4;
const FUTURE = new Date(Date.now() + 30 * 24 * 3600 * 1000);
const NOW_LOC = () => ({ type: 'Point', coordinates: [LNG, LAT], liveShareActive: true, updatedAt: new Date() });

// Quatre gardiens « moi » (un par état + un ancien profil hideFromMap sans le
// nouveau champ), tous abonnés PawSpot (donc listés dans « proches »).
const DOCS = {
  Owner: [
    { _id: 'friend1', email: 'friend@example.test', name: 'Ami', location: { type: 'Point', coordinates: [LNG + 0.005, LAT] }, preferences: {} },
  ],
  Sitter: [
    { _id: 'vAll', email: 'all@example.test', name: 'Tous', location: NOW_LOC(), preferences: { mapVisibility: 'all' }, mapBoostExpiry: FUTURE },
    { _id: 'vFriends', email: 'friends@example.test', name: 'Amis', location: NOW_LOC(), preferences: { mapVisibility: 'friends', hideFromMap: true }, mapBoostExpiry: FUTURE },
    { _id: 'vHidden', email: 'hidden@example.test', name: 'Masque', location: NOW_LOC(), preferences: { mapVisibility: 'hidden', hideFromMap: true }, mapBoostExpiry: FUTURE },
    { _id: 'vLegacy', email: 'legacy@example.test', name: 'Ancien', location: NOW_LOC(), preferences: { hideFromMap: true }, mapBoostExpiry: FUTURE },
  ],
  Walker: [
    { _id: 'stranger1', email: 'stranger@example.test', name: 'Inconnu', location: { type: 'Point', coordinates: [LNG - 0.01, LAT] }, preferences: {} },
  ],
};
const MINE = ['vAll', 'vFriends', 'vHidden', 'vLegacy'];

function get(doc, path) {
  return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), doc);
}
function matches(doc, q) {
  if (!q) return true;
  for (const [k, v] of Object.entries(q)) {
    if (k === '$or') { if (!v.some((c) => matches(doc, c))) return false; continue; }
    if (k === 'location') continue; // $near ignoré
    if (k === 'location.coordinates.1') { if (!Array.isArray(get(doc, 'location.coordinates'))) return false; continue; }
    const val = k === '_id' ? String(doc._id) : get(doc, k);
    if (v && typeof v === 'object' && '$ne' in v) { if (val === v.$ne) return false; continue; }
    if (v && typeof v === 'object' && '$in' in v) { if (!v.$in.map(String).includes(String(val))) return false; continue; }
    if (v && typeof v === 'object' && '$exists' in v) continue;
    if (String(val) !== String(v)) return false;
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
  updateOne: jest.fn((q, u) => {
    const d = DOCS[name].find((x) => String(x._id) === String(q._id));
    if (d && u.$set) {
      for (const [k, val] of Object.entries(u.$set)) {
        const parts = k.split('.');
        let o = d;
        for (const p of parts.slice(0, -1)) { o[p] = o[p] || {}; o = o[p]; }
        o[parts[parts.length - 1]] = val;
      }
    }
    return Promise.resolve({ acknowledged: true });
  }),
});

jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));
jest.mock('../src/models/UserSubscription', () => ({
  find: jest.fn(() => chain([])),
  findOne: jest.fn(() => chain(null)),
  hasActivePawFollow: jest.fn(() => Promise.resolve(false)),
  isInSameFamily: jest.fn(() => Promise.resolve(false)),
  familyActiveMatch: jest.fn(() => ({})),
}));
jest.mock('../src/models/Friendship', () => ({
  find: jest.fn((q) => {
    // Une amitié acceptée friend1 ↔ chacun des 4 « moi », partage allumé
    // des deux côtés (sinon live-positions ne renverrait rien de toute façon).
    const rows = ['vAll', 'vFriends', 'vHidden', 'vLegacy'].map((m) => ({
      requesterId: 'friend1', requesterModel: 'Owner', addresseeId: m, addresseeModel: 'Sitter',
      status: 'accepted', requesterSharesPosition: true, addresseeSharesPosition: true,
    }));
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
  emitToUser: jest.fn(),
}));
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve([String(id)])),
  personIndex: jest.fn((ids) => Promise.resolve(new Map(ids.map((i) => [String(i), {
    ids: [String(i)], set: new Set([String(i)]),
    docs: [{ id: String(i), model: String(i) === 'friend1' ? 'Owner' : (String(i) === 'stranger1' ? 'Walker' : 'Sitter') }],
  }])))),
}));
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: jest.fn((id) => {
    const s = String(id);
    const model = s === 'friend1' ? 'Owner' : (s === 'stranger1' ? 'Walker' : 'Sitter');
    return Promise.resolve({ ids: [s], set: new Set([s]), docs: [{ id: s, model }] });
  }),
}));

const router = require('../src/routes/friendRoutes');
const mv = require('../src/utils/mapVisibility');

function handler(path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path);
  if (!layer) throw new Error(`route ${path} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
function call(fn, user, query = {}, body = undefined) {
  return new Promise((resolve, reject) => {
    const req = { user, query, body, headers: {} };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ status: this.statusCode, body: b }); },
    };
    Promise.resolve(fn(req, res)).catch(reject);
  });
}
const ids = (body) => (body.members || []).map((m) => m.id);
const FRIEND = { id: 'friend1', role: 'owner' };
const STRANGER = { id: 'stranger1', role: 'walker' };
const Q = { lat: String(LAT), lng: String(LNG), radiusInMeters: '25000' };

// Attendu : [état, vu par l'ami, vu par l'inconnu]
const EXPECT = [
  ['vAll', true, true],
  ['vFriends', true, false],
  ['vHidden', false, false],
  ['vLegacy', true, false], // ancien hideFromMap = « amis seulement »
];

describe('règle pure — 3 états + migration', () => {
  test('mapVisibilityOf : champ neuf prioritaire, sinon ancien hideFromMap', () => {
    expect(mv.mapVisibilityOf({ preferences: { mapVisibility: 'hidden', hideFromMap: false } })).toBe('hidden');
    expect(mv.mapVisibilityOf({ preferences: { hideFromMap: true } })).toBe('friends');
    expect(mv.mapVisibilityOf({ preferences: {} })).toBe('all');
    expect(mv.mapVisibilityOf({})).toBe('all');
    expect(mv.mapVisibilityOf({ preferences: { mapVisibility: 'n/importe' } })).toBe('all');
  });
  test('mapVisibilitySet écrit toujours les deux champs', () => {
    expect(mv.mapVisibilitySet('hidden')).toEqual({ 'preferences.mapVisibility': 'hidden', 'preferences.hideFromMap': true });
    expect(mv.mapVisibilitySet('friends')).toEqual({ 'preferences.mapVisibility': 'friends', 'preferences.hideFromMap': true });
    expect(mv.mapVisibilitySet('all')).toEqual({ 'preferences.mapVisibility': 'all', 'preferences.hideFromMap': false });
  });
  test.each(EXPECT)('visibleToViewer %s : ami=%s, inconnu=%s ; soi-même toujours', (id, friend, stranger) => {
    const d = DOCS.Sitter.find((x) => x._id === id);
    expect(mv.visibleToViewer(d, { friendIds: new Set([id]) })).toBe(friend);
    expect(mv.visibleToViewer(d, { friendIds: new Set() })).toBe(stranger);
    expect(mv.visibleToViewer(d, { viewerIds: new Set([id]) })).toBe(true);
  });
  test('route publique (/sitters|walkers/nearby) : applyPublicPrivacy suit les 3 états', () => {
    const docs = DOCS.Sitter.map((d) => ({ ...d }));
    const asFriend = mv.applyPublicPrivacy(docs, { friendIds: new Set(MINE) }).map((d) => d._id);
    const asStranger = mv.applyPublicPrivacy(docs, { friendIds: new Set() }).map((d) => d._id);
    expect(asFriend.sort()).toEqual(['vAll', 'vFriends', 'vLegacy']);
    expect(asStranger).toEqual(['vAll']);
  });
  test('strictestVisibility : un seul profil masqué masque la personne', () => {
    expect(mv.strictestVisibility([{ preferences: { mapVisibility: 'all' } }, { preferences: { mapVisibility: 'hidden' } }])).toBe('hidden');
    expect(mv.strictestVisibility([{ preferences: {} }, { preferences: { hideFromMap: true } }])).toBe('friends');
  });
});

describe('/friends/members/nearby et /world — 3 états × ami / inconnu', () => {
  test('inconnu d\'abord (remplit le cache partagé de world)', async () => {
    const w = await call(handler('/members/world'), STRANGER);
    const n = await call(handler('/members/nearby'), STRANGER, Q);
    expect(w.status).toBe(200);
    expect(n.status).toBe(200);
    for (const [id, , stranger] of EXPECT) {
      expect([id, ids(w.body).includes(id)]).toEqual([id, stranger]);
      expect([id, ids(n.body).includes(id)]).toEqual([id, stranger]);
    }
  });
  test('ami ensuite (cache chaud) : amis seulement réinjectés, masqué absent', async () => {
    const w = await call(handler('/members/world'), FRIEND);
    const n = await call(handler('/members/nearby'), FRIEND, Q);
    for (const [id, friend] of EXPECT) {
      expect([id, ids(w.body).includes(id)]).toEqual([id, friend]);
      expect([id, ids(n.body).includes(id)]).toEqual([id, friend]);
    }
  });
});

describe('/friends/live-positions — un ami « masqué » ne sort jamais', () => {
  test('ami : Tous / Amis / ancien réglage visibles, Masqué absent', async () => {
    const r = await call(handler('/live-positions'), FRIEND);
    expect(r.status).toBe(200);
    const got = (r.body.positions || []).map((p) => p.userId).sort();
    expect(got).toEqual(['vAll', 'vFriends', 'vLegacy']);
  });
  test('inconnu : personne (pas d\'amitié)', async () => {
    const r = await call(handler('/live-positions'), STRANGER);
    expect(r.body.positions).toEqual([]);
  });
});

describe('/users/me/map-prefs — lecture et écriture de l\'état', () => {
  const ctl = require('../src/controllers/mapPrefsController');
  test('GET : état relu (migration douce comprise)', async () => {
    const r = await call(ctl.getMapPrefs, { id: 'vLegacy', role: 'sitter' });
    expect(r.body.mapVisibility).toBe('friends');
    expect(r.body.hideFromMap).toBe(true);
  });
  test('PATCH mapVisibility=hidden puis all : écrit les deux champs', async () => {
    let r = await call(ctl.updateMapPrefs, { id: 'vAll', role: 'sitter' }, {}, { mapVisibility: 'hidden' });
    expect(r.status).toBe(200);
    const d = DOCS.Sitter.find((x) => x._id === 'vAll');
    expect(d.preferences.mapVisibility).toBe('hidden');
    expect(d.preferences.hideFromMap).toBe(true);
    r = await call(ctl.updateMapPrefs, { id: 'vAll', role: 'sitter' }, {}, { mapVisibility: 'all' });
    expect(d.preferences.mapVisibility).toBe('all');
    expect(d.preferences.hideFromMap).toBe(false);
  });
  test('PATCH ancien client hideFromMap=true → « amis seulement »', async () => {
    await call(ctl.updateMapPrefs, { id: 'vAll', role: 'sitter' }, {}, { hideFromMap: true });
    const d = DOCS.Sitter.find((x) => x._id === 'vAll');
    expect(d.preferences.mapVisibility).toBe('friends');
    await call(ctl.updateMapPrefs, { id: 'vAll', role: 'sitter' }, {}, { mapVisibility: 'all' });
  });
  test('PATCH valeur inconnue → 400', async () => {
    const r = await call(ctl.updateMapPrefs, { id: 'vAll', role: 'sitter' }, {}, { mapVisibility: 'invisible' });
    expect(r.status).toBe(400);
  });
});
