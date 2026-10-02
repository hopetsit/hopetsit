// 607 (ZOE, 02/10/2026) — fuite mesurée en ligne par NEO : GET /friends/search
// renvoyait l'adresse e-mail complète de chaque personne trouvée, à n'importe quel
// compte connecté. Règle : la recherche ne renvoie jamais d'e-mail, de téléphone,
// d'adresse ni de position — seulement ce que montre une fiche publique
// (Prénom I., photo, rôle, ville). Chercher PAR e-mail exact reste possible.
// Mêmes contrôles pour la liste des demandes (nom de secours = jamais l'e-mail)
// et pour la liste des conversations (otherParty sans e-mail).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/services/notificationSender', () => new Proxy({}, { get: () => jest.fn(async () => ({})) }));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)),
  isIdentityOnline: jest.fn(() => false),
  emitToUser: jest.fn(),
  emitToConversation: jest.fn(),
  userRoom: (role, id) => `user:${role}:${id}`,
}));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Friendship; let router;
const oid = () => new mongoose.Types.ObjectId();
const ME = oid();
const T = { owner: oid(), sitter: oid(), nameless: oid() };

function handler(path, method = 'get') {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods[method]);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
function call(path, user, query = {}) {
  const fn = handler(path);
  return new Promise((resolve, reject) => {
    const req = { user, query, headers: {}, params: {} };
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); } };
    Promise.resolve(fn(req, res)).catch(reject);
  });
}
const base = (o) => ({ createdAt: new Date(), updatedAt: new Date(), ...o });

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Friendship = require('../src/models/Friendship');
  router = require('../src/routes/friendRoutes');
  await Owner.collection.insertOne(base({ _id: ME, name: 'Moi Test', firstName: 'Moi', lastName: 'Test', email: 'moi607@example.test' }));
  await Owner.collection.insertOne(base({
    _id: T.owner, name: 'Lucie Martin', firstName: 'Lucie', lastName: 'Martin', email: 'lucie.martin607@example.test',
    mobile: '+33600000001', address: '12 rue Secrète', city: 'Lyon', location: { type: 'Point', coordinates: [4.83, 45.76], city: 'Lyon' },
  }));
  await Sitter.collection.insertOne(base({
    _id: T.sitter, name: 'Paul Durand', firstName: 'Paul', lastName: 'Durand', email: 'pauldurand607@example.test',
    mobile: '+33600000002', address: '3 avenue Privée', city: 'Paris',
  }));
  // Ancien compte sans prénom / nom : le nom de secours ne doit JAMAIS être l'e-mail.
  await Sitter.collection.insertOne(base({ _id: T.nameless, name: 'Zoé Ancienne', email: 'zoe.secret607@example.test' }));
  await Friendship.collection.insertOne({
    requesterId: T.nameless, requesterModel: 'Sitter', addresseeId: ME, addresseeModel: 'Owner',
    status: 'pending', createdAt: new Date(), updatedAt: new Date(),
  });
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

const ASME = { id: String(ME), role: 'owner' };
const FORBIDDEN = /@|example\.test|\+336|rue Secrète|avenue Privée|Martin|Durand/;

test('recherche par nom : ni e-mail, ni téléphone, ni adresse, nom = Prénom I.', async () => {
  const r = await call('/search', ASME, { q: 'lucie' });
  expect(r.status).toBe(200);
  expect(r.body.users).toHaveLength(1);
  const u = r.body.users[0];
  expect(u).toMatchObject({ id: String(T.owner), role: 'owner', name: 'Lucie M.', city: 'Lyon' });
  expect(Object.keys(u).sort()).toEqual(['avatar', 'city', 'id', 'name', 'role']);
  expect(JSON.stringify(r.body)).not.toMatch(FORBIDDEN);
});

test('un morceau d\'e-mail (domaine) ne liste plus personne', async () => {
  const r = await call('/search', ASME, { q: 'example.test' });
  expect(r.body.users).toHaveLength(0);
  const r2 = await call('/search', ASME, { q: 'pauldurand607' });
  expect(r2.body.users).toHaveLength(0);
});

test('e-mail EXACT en entrée : trouvé, mais l\'e-mail n\'est pas renvoyé', async () => {
  const r = await call('/search', ASME, { q: 'PaulDurand607@example.test' });
  expect(r.body.users).toHaveLength(1);
  expect(r.body.users[0]).toMatchObject({ id: String(T.sitter), name: 'Paul D.', role: 'sitter' });
  expect(JSON.stringify(r.body)).not.toMatch(FORBIDDEN);
});

test('demandes reçues : nom de secours = nom du compte, jamais un morceau d\'e-mail', async () => {
  const r = await call('/requests', ASME);
  const s = JSON.stringify(r.body);
  expect(s).not.toMatch(/zoe\.secret607|secret607|@example/);
});
