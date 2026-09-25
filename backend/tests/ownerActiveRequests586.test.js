// v586 (point 9) — GET /posts/requests/by-owner/:ownerId : demandes ACTIVES
// d'un propriétaire (et de ses autres profils) lues par un gardien /
// promeneur connecté. Ville seule, jamais d'adresse ni de coordonnées,
// comptes de test jamais exposés, ma candidature signalée.
// Aucun accès réseau, aucune base (modèles simulés).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockOID = (n) => String(n).padStart(24, '0');
const O1 = mockOID(1); // propriétaire Daniel
const O2 = mockOID(2); // 2e profil propriétaire de la même personne (même e-mail)
const OT = mockOID(3); // compte de test
const S1 = mockOID(11); // gardien spectateur
const S_SELF = mockOID(12); // profil gardien de Daniel (même e-mail que O1)
const W1 = mockOID(21); // promeneur spectateur

const mockPEOPLE = {
  [O1]: { _id: O1, email: 'daniel@example.org', currency: 'EUR', m: 'owner' },
  [O2]: { _id: O2, email: 'daniel@example.org', currency: 'EUR', m: 'owner' },
  [OT]: { _id: OT, email: 'qa+test@example.org', m: 'owner' },
  [S1]: { _id: S1, email: 'gardien@example.org', m: 'sitter' },
  [S_SELF]: { _id: S_SELF, email: 'daniel@example.org', m: 'sitter' },
  [W1]: { _id: W1, email: 'promeneur@example.org', m: 'walker' },
};

const future = new Date(Date.now() + 5 * 24 * 3600 * 1000);
const past = new Date(Date.now() - 5 * 24 * 3600 * 1000);
const mockPOSTS = [
  { _id: mockOID(101), ownerId: O1, postType: 'request', serviceTypes: ['pet_sitting'], startDate: future, endDate: future,
    location: { city: 'Paris', lat: 48.8601, lng: 2.3401, address: '12 rue Secrète' }, petIds: [mockOID(201)], createdAt: new Date() },
  { _id: mockOID(102), ownerId: O2, postType: 'request', serviceTypes: ['dog_walking'], startDate: future,
    location: { city: 'Paris', lat: 48.85, lng: 2.35 }, petIds: [mockOID(201)], createdAt: new Date() },
  { _id: mockOID(103), ownerId: O1, postType: 'request', serviceTypes: ['pet_sitting'], startDate: past, endDate: past,
    location: { city: 'Paris' }, petIds: [mockOID(201)], createdAt: new Date() },
  { _id: mockOID(104), ownerId: O1, postType: 'request', serviceTypes: ['pet_sitting'], startDate: future,
    reservedBy: { bookingId: mockOID(900) }, location: { city: 'Paris' }, petIds: [mockOID(201)], createdAt: new Date() },
  { _id: mockOID(105), ownerId: OT, postType: 'request', serviceTypes: ['pet_sitting'], startDate: future,
    location: { city: 'Lyon' }, petIds: [], createdAt: new Date() },
];

const mockChain = (result) => {
  const c = { select: () => c, sort: () => c, limit: () => c, lean: () => Promise.resolve(result), catch: () => c };
  return c;
};
const mockIdsIn = (q, key) => (q[key] && q[key].$in ? q[key].$in.map(String) : null);
const mockPeopleModel = (m) => ({
  findById: jest.fn((id) => mockChain(mockPEOPLE[id] && mockPEOPLE[id].m === m ? mockPEOPLE[id] : null)),
  find: jest.fn((q) => {
    const ids = mockIdsIn(q, '_id');
    if (ids) return mockChain(ids.map((i) => mockPEOPLE[i]).filter((d) => d && d.m === m));
    const emails = (q.$or || []).map((c) => c.email).filter(Boolean);
    return mockChain(Object.values(mockPEOPLE).filter((d) => d.m === m && emails.includes(d.email)));
  }),
});
jest.mock('../src/models/Owner', () => mockPeopleModel('owner'));
jest.mock('../src/models/Sitter', () => mockPeopleModel('sitter'));
jest.mock('../src/models/Walker', () => mockPeopleModel('walker'));
jest.mock('../src/models/Post', () => ({
  find: jest.fn((q) => {
    const owners = q.ownerId.$in.map(String);
    return mockChain(mockPOSTS.filter((p) => owners.includes(String(p.ownerId)) && p.postType === 'request'));
  }),
}));
jest.mock('../src/models/Pet', () => ({
  find: jest.fn(() => mockChain([{ _id: mockOID(201), petName: 'Rex', category: 'dog' }])),
}));
const mockAPPS = [];
jest.mock('../src/models/Application', () => ({
  find: jest.fn((q) => {
    const posts = q.postId.$in.map(String);
    return mockChain(mockAPPS.filter((a) => posts.includes(String(a.postId))
      && (String(a.sitterId) === String(q.sitterId) || String(a.walkerId) === String(q.walkerId))));
  }),
}));

const { getOwnerActiveRequests } = require('../src/controllers/ownerActiveRequestsController');

const call = async (user, ownerId, query = {}) => {
  let status = 200;
  let body = null;
  const res = { status(c) { status = c; return this; }, json(b) { body = b; return this; } };
  await getOwnerActiveRequests({ user, params: { ownerId }, query }, res);
  return { status, body };
};

describe('GET /posts/requests/by-owner/:ownerId', () => {
  beforeEach(() => { mockAPPS.length = 0; });

  test('gardien : demandes actives seulement, ville sans adresse ni coordonnées', async () => {
    const { status, body } = await call({ id: S1, role: 'sitter' }, O1, { lat: '48.8566', lng: '2.3522' });
    expect(status).toBe(200);
    expect(body.posts.map((p) => p.id)).toEqual([mockOID(101)]); // passée, réservée, promenade exclues
    const p = body.posts[0];
    expect(p.city).toBe('Paris');
    expect(p.pets).toEqual([{ id: mockOID(201), name: 'Rex', category: 'dog' }]);
    expect(Number.isInteger(p.distanceKm)).toBe(true);
    const json = JSON.stringify(body);
    expect(json).not.toMatch(/Secrète|48\.86|2\.34|lat|lng|email|phone/);
    expect(p.myApplication).toBeNull();
  });

  test('promeneur : voit la promenade publiée par l\'autre profil propriétaire de la personne', async () => {
    const { body } = await call({ id: W1, role: 'walker' }, O1);
    expect(body.posts.map((p) => p.id)).toEqual([mockOID(102)]);
    expect(body.posts[0].distanceKm).toBeNull();
  });

  test('candidature déjà envoyée / refusée → myApplication', async () => {
    mockAPPS.push({ postId: mockOID(101), sitterId: S1, status: 'rejected' });
    const { body } = await call({ id: S1, role: 'sitter' }, O1);
    expect(body.posts[0].myApplication).toBe('rejected');
  });

  test('compte de test → jamais exposé', async () => {
    const { body } = await call({ id: S1, role: 'sitter' }, OT);
    expect(body.posts).toEqual([]);
  });

  test('mes propres demandes (autre profil de moi) → liste vide', async () => {
    const { body } = await call({ id: S_SELF, role: 'sitter' }, O1);
    expect(body.posts).toEqual([]);
  });

  test('propriétaire → 403, id invalide → 400', async () => {
    expect((await call({ id: O2, role: 'owner' }, O1)).status).toBe(403);
    expect((await call({ id: S1, role: 'sitter' }, 'abc')).status).toBe(400);
  });
});
