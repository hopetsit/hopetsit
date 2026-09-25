// v586 — PUT /users/me/profile { preferences } : fusion clé par clé (ne
// touche plus `preferences.pawMap`), visibilité à 3 états et « Mon fond »
// recopiés sur les 3 profils de la personne. Avant : l'objet `preferences`
// était remplacé EN ENTIER, sur le seul profil du rôle courant.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const STORE = {
  Owner: { p1: { _id: 'p1', email: 'x@example.test', preferences: { hideFromMap: false, wallpaper: 'auto', pawMap: { nightMode: true } } } },
  Sitter: { p1s: { _id: 'p1s', email: 'x@example.test', preferences: { wallpaper: 'auto' } } },
  Walker: { p1w: { _id: 'p1w', email: 'x@example.test', preferences: {} } },
};
function applySet(doc, set) {
  for (const [k, v] of Object.entries(set || {})) {
    const parts = k.split('.');
    let o = doc;
    for (const p of parts.slice(0, -1)) { o[p] = o[p] || {}; o = o[p]; }
    o[parts[parts.length - 1]] = v;
  }
}
const model = (name) => ({
  findByIdAndUpdate: jest.fn((id, ops) => {
    const d = STORE[name][id];
    if (!d) return Promise.resolve(null);
    applySet(d, ops.$set);
    return Promise.resolve({ ...d, toObject() { return { ...d }; } });
  }),
  updateOne: jest.fn((q, ops) => { const d = STORE[name][q._id]; if (d) applySet(d, ops.$set); return { catch: () => null }; }),
  findById: jest.fn(() => ({ select: () => ({ lean: () => Promise.resolve(null) }), lean: () => Promise.resolve(null) })),
});
jest.mock('../src/models/Owner', () => model('Owner'));
jest.mock('../src/models/Sitter', () => model('Sitter'));
jest.mock('../src/models/Walker', () => model('Walker'));
jest.mock('../src/config/firebaseAdmin', () => ({}));
jest.mock('../src/services/loyaltyService', () => ({ getOwnerStats: jest.fn(async () => ({})) }));
jest.mock('../src/services/referralService', () => ({ getMyReferrals: jest.fn(async () => ({})) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn() }));
jest.mock('../src/utils/sharedIdentity', () => ({ propagateSharedIdentity: jest.fn(() => Promise.resolve()) }));
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: jest.fn(() => Promise.resolve({
    ids: ['p1', 'p1s', 'p1w'],
    set: new Set(['p1', 'p1s', 'p1w']),
    docs: [{ id: 'p1', model: 'Owner' }, { id: 'p1s', model: 'Sitter' }, { id: 'p1w', model: 'Walker' }],
  })),
}));

const { updateProfile } = require('../src/controllers/userController');

function put(body) {
  return new Promise((resolve, reject) => {
    const req = { params: { id: 'p1' }, user: { id: 'p1', role: 'owner' }, body, headers: {} };
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); } };
    Promise.resolve(updateProfile(req, res)).catch(reject);
  });
}

test('visibilité « masqué » + fond « aucun » : écrits sur les 3 profils, pawMap intact', async () => {
  const r = await put({ preferences: { mapVisibility: 'hidden', wallpaper: 'none', notifications: false } });
  expect(r.status).toBe(200);
  for (const [name, id] of [['Owner', 'p1'], ['Sitter', 'p1s'], ['Walker', 'p1w']]) {
    const p = STORE[name][id].preferences;
    expect([name, p.mapVisibility, p.hideFromMap, p.wallpaper]).toEqual([name, 'hidden', true, 'none']);
  }
  expect(STORE.Owner.p1.preferences.pawMap).toEqual({ nightMode: true });
  expect(STORE.Owner.p1.preferences.notifications).toBe(false);
  // Les réglages propres au rôle (notifications…) ne sont PAS recopiés.
  expect(STORE.Sitter.p1s.preferences.notifications).toBeUndefined();
});

test('ancienne app : hideFromMap=false → « visible par tous » partout', async () => {
  await put({ preferences: { hideFromMap: false } });
  for (const [name, id] of [['Owner', 'p1'], ['Sitter', 'p1s'], ['Walker', 'p1w']]) {
    expect(STORE[name][id].preferences.mapVisibility).toBe('all');
  }
});
