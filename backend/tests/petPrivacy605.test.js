// v605 ZOE (30/09/2026) — fiches animaux : plus d'e-mail du propriétaire
// donné à n'importe qui. Avant : GET /pets/all (sans connexion) listait TOUS
// les animaux de la plateforme avec l'e-mail de leur propriétaire, et
// GET /pets/:id (sans connexion) donnait l'e-mail + n° de passeport / puce.
// Vraie base Mongo en mémoire, aucune donnée réelle.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(), deleteMedia: jest.fn() }));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo;
let petController;
let ownerId;
let otherOwnerId;
let petId;

const mockRes = () => {
  const res = {};
  res.status = jest.fn(() => res);
  res.json = jest.fn((b) => { res.body = b; return res; });
  return res;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  const Owner = require('../src/models/Owner');
  const Pet = require('../src/models/Pet');
  petController = require('../src/controllers/petController');
  const o = await Owner.collection.insertOne({ name: 'Marie', email: 'marie605@example.test' });
  ownerId = o.insertedId.toString();
  const o2 = await Owner.collection.insertOne({ name: 'Paul', email: 'paul605@example.test' });
  otherOwnerId = o2.insertedId.toString();
  const p = await Pet.collection.insertOne({
    ownerId: o.insertedId, petName: 'Filou', category: 'dog',
    passportNumber: 'PASS-605', chipNumber: 'CHIP-605',
  });
  petId = p.insertedId.toString();
});

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

const routeLayer = (path, method) => {
  const router = require('../src/routes/petRoutes');
  return router.stack.find((l) => l.route && l.route.path === path && l.route.methods[method]);
};

test('GET /pets/all exige une connexion et ne liste plus toute la plateforme', () => {
  const { requireAuth } = require('../src/middleware/auth');
  const layer = routeLayer('/all', 'get');
  expect(layer).toBeTruthy();
  const handles = layer.route.stack.map((s) => s.handle);
  expect(handles).toContain(requireAuth);
  expect(handles).toContain(petController.listPets);
  expect(handles).not.toContain(petController.getAllPets);
});

test('GET /pets/:id exige une connexion', () => {
  const { requireAuth } = require('../src/middleware/auth');
  const layer = routeLayer('/:id', 'get');
  expect(layer.route.stack.map((s) => s.handle)).toContain(requireAuth);
});

test('/pets/all : un gardien sans propriétaire désigné ne reçoit rien', async () => {
  const res = mockRes();
  await petController.listPets({ user: { id: 'x', role: 'sitter' }, query: {} }, res);
  expect(res.status).toHaveBeenCalledWith(403);
});

test('fiche animal vue par un gardien : pas d’e-mail du propriétaire', async () => {
  const res = mockRes();
  await petController.getPetById({ params: { id: petId }, user: { id: 'sitter605', role: 'sitter' } }, res);
  const body = res.body;
  expect(body).toBeTruthy();
  expect(JSON.stringify(body)).not.toContain('marie605@example.test');
  expect(body.pet.owner.name).toBe('Marie');
});

test('fiche animal vue par un autre propriétaire : pas d’e-mail', async () => {
  const res = mockRes();
  await petController.getPetById({ params: { id: petId }, user: { id: otherOwnerId, role: 'owner' } }, res);
  expect(JSON.stringify(res.body)).not.toContain('marie605@example.test');
});

test('fiche animal vue par SON propriétaire : e-mail gardé', async () => {
  const res = mockRes();
  await petController.getPetById({ params: { id: petId }, user: { id: ownerId, role: 'owner' } }, res);
  expect(res.body.pet.owner.email).toBe('marie605@example.test');
});
