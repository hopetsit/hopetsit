// v594 — page propriétaire vide depuis la PawMap : profil public complet.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { ownerPublicProfile } = require('../src/utils/ownerPublic594');

let mongo; let Owner; let Sitter; let Pet;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Pet = require('../src/models/Pet');
  await Promise.all([Owner.init(), Sitter.init(), Pet.init()]);
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('bio, ville, animaux ; jamais e-mail ni passeport', async () => {
  const o = await Owner.create({ name: 'Proprio Test', email: 'proprio594@example.test', password: 'MotDePasse594!', bio: 'J aime les chiens', city: 'Murcia' });
  await Pet.create({ ownerId: o._id, petName: 'Rex', breed: 'Labrador', passportNumber: 'SECRET123' });
  const p = await ownerPublicProfile(String(o._id));
  expect(p.bio).toBe('J aime les chiens');
  expect(p.city).toBe('Murcia');
  expect(p.pets).toHaveLength(1);
  expect(p.pets[0].petName).toBe('Rex');
  expect(JSON.stringify(p)).not.toMatch(/proprio594|SECRET123/);
});

test('id du gardien de la même personne → son profil propriétaire', async () => {
  const email = 'multi594@example.test';
  const o = await Owner.create({ name: 'Multi Test', email, password: 'MotDePasse594!', bio: 'bio multi' });
  const s = await Sitter.create({ name: 'Multi Test', email, password: 'MotDePasse594!' });
  const p = await ownerPublicProfile(String(s._id));
  expect(p && p.id).toBe(String(o._id));
});

test('compte bloqué ou id invalide → null', async () => {
  const o = await Owner.create({ name: 'Bloque Test', email: 'bloque594@example.test', password: 'MotDePasse594!', status: 'banned' });
  expect(await ownerPublicProfile(String(o._id))).toBeNull();
  expect(await ownerPublicProfile('pas-un-id')).toBeNull();
});
