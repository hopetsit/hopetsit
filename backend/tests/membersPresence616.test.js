// 616 (PAM, 15/10/2026) — GET /friends/members/presence?ids=…
// Daniel (10/10) : le point « en ligne / hors ligne » de la PawMap doit
// refléter le VRAI état et se mettre à jour sans relancer l'app. La route
// renvoie, pour les ids demandés, l'état de présence de la PERSONNE (un de
// ses profils en ligne = en ligne), avec le même index que /members/nearby.
// Sans base ni réseau (modèles simulés).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const DOCS = {
  Owner: [
    { _id: 'alice_owner', email: 'alice@example.test', oldId: 11 },
    { _id: 'bob_owner', email: 'bob@example.test' },
  ],
  Sitter: [
    { _id: 'alice_sitter', email: 'alice@example.test' },
    { _id: 'carl_sitter', email: 'carl@example.test' },
  ],
  Walker: [
    { _id: 'bob_walker', email: 'bob@example.test' },
  ],
};

const chain = (result) => {
  const c = {
    select: () => c, limit: () => c, sort: () => c,
    lean: () => Promise.resolve(result),
    then: (ok, ko) => Promise.resolve(result).then(ok, ko),
  };
  return c;
};
const mockModel = (name) => ({
  find: jest.fn((q) => {
    const ids = (q && q._id && q._id.$in ? q._id.$in : []).map(String);
    return chain(DOCS[name].filter((d) => ids.includes(String(d._id))).map((d) => ({ ...d })));
  }),
  findById: jest.fn(() => chain(null)),
});
jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));
jest.mock('../src/models/Friendship', () => ({ find: jest.fn(() => chain([])) }));
jest.mock('../src/models/UserSubscription', () => ({ find: jest.fn(() => chain([])) }));
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve([String(id)])),
  personIndex: jest.fn(() => Promise.resolve(new Map())),
}));

// Index de présence simulé : seule la personne « alice » est en ligne, via
// son profil GARDIEN (le profil propriétaire doit donc ressortir en ligne).
const mockPresence = { ids: new Set(['alice_sitter']), emails: new Set(['alice@example.test']), oldIds: new Set() };
const mockEmitter = {
  buildPresenceIndex: jest.fn(() => Promise.resolve(mockPresence)),
  isIdentityOnline: jest.fn((doc, index) => {
    if (!doc || !index) return false;
    const id = doc._id ? String(doc._id) : null;
    if (id && index.ids.has(id)) return true;
    if (doc.email && index.emails.has(String(doc.email).toLowerCase())) return true;
    return false;
  }),
};
jest.mock('../src/sockets/emitter', () => mockEmitter);

const router = require('../src/routes/friendRoutes');

function handler(path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path);
  if (!layer) throw new Error(`route ${path} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
function call(fn, query = {}) {
  return new Promise((resolve, reject) => {
    const req = { user: { id: 'bob_owner', role: 'owner' }, query, headers: {} };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(body) { resolve({ status: this.statusCode, body }); },
    };
    fn(req, res).catch(reject);
  });
}

describe('GET /friends/members/presence (616)', () => {
  const presenceRoute = () => handler('/members/presence');

  test('la route existe, placée avant /members/world (jamais éclipsée par /:id)', () => {
    const paths = router.stack.filter((l) => l.route).map((l) => l.route.path);
    const iPresence = paths.indexOf('/members/presence');
    const iParam = paths.findIndex((p) => p.startsWith('/:'));
    expect(iPresence).toBeGreaterThanOrEqual(0);
    if (iParam >= 0) expect(iPresence).toBeLessThan(iParam);
  });

  test('un profil en ligne = toute la personne en ligne ; les autres hors ligne', async () => {
    const r = await call(presenceRoute(), { ids: 'alice_owner,alice_sitter,bob_walker,carl_sitter' });
    expect(r.status).toBe(200);
    expect(r.body.online).toEqual({
      alice_owner: true, // en ligne par son e-mail (profil gardien connecté)
      alice_sitter: true,
      bob_walker: false,
      carl_sitter: false,
    });
    expect(typeof r.body.at).toBe('string');
    expect(Number.isNaN(Date.parse(r.body.at))).toBe(false);
  });

  test('id inconnu → hors ligne (jamais « en ligne » par défaut)', async () => {
    const r = await call(presenceRoute(), { ids: 'inconnu_1' });
    expect(r.body.online).toEqual({ inconnu_1: false });
  });

  test('ids vides, doublons et espaces : réponse vide ou dédoublonnée, jamais 500', async () => {
    const vide = await call(presenceRoute(), {});
    expect(vide.status).toBe(200);
    expect(vide.body.online).toEqual({});
    const dup = await call(presenceRoute(), { ids: ' bob_walker , bob_walker,, ' });
    expect(dup.body.online).toEqual({ bob_walker: false });
  });

  test('plafond : au plus 300 ids traités', async () => {
    const ids = Array.from({ length: 350 }, (_, i) => `id_${i}`).join(',');
    const r = await call(presenceRoute(), { ids });
    expect(Object.keys(r.body.online)).toHaveLength(300);
  });

  test('index de présence indisponible → tout hors ligne, 200', async () => {
    mockEmitter.buildPresenceIndex.mockImplementationOnce(() => Promise.resolve(null));
    const r = await call(presenceRoute(), { ids: 'alice_owner' });
    expect(r.status).toBe(200);
    expect(r.body.online).toEqual({ alice_owner: false });
  });
});
