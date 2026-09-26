// v594 — « Vu il y a 5 j » alors que la personne était active le jour même :
// l'activité réelle pose maintenant lastSeenAt sur ses 3 profils.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { touchLastSeen } = require('../src/utils/activity590');

let mongo; let Owner; let Walker;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Walker = require('../src/models/Walker');
  await Promise.all([Owner.init(), Walker.init()]);
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('activité en promeneur → lastSeenAt à jour aussi sur le profil propriétaire', async () => {
  const old = new Date(Date.now() - 5 * 86400000);
  const email = 'frere594@example.test';
  const o = await Owner.create({ name: 'Frere Test', email, password: 'MotDePasse594!', lastSeenAt: old });
  const w = await Walker.create({ name: 'Frere Test', email, password: 'MotDePasse594!', lastSeenAt: old });
  const now = Date.now();
  await touchLastSeen(String(w._id), now);
  const [ro, rw] = await Promise.all([Owner.findById(o._id).lean(), Walker.findById(w._id).lean()]);
  expect(new Date(rw.lastSeenAt).getTime()).toBe(now);
  expect(new Date(ro.lastSeenAt).getTime()).toBe(now);
  // 2e passage dans les 5 min : pas de nouvelle écriture.
  await touchLastSeen(String(w._id), now + 60000);
  expect(new Date((await Walker.findById(w._id).lean()).lastSeenAt).getTime()).toBe(now);
});
