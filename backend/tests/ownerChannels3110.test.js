// 3110 (ADA, demande de Daniel via BOB) — « Le propriétaire est revenu » : sessions RÉELLES depuis la publication,
// par canal (site / app), dernière connexion depuis la publication ; nos scripts exclus ; compte +test / équipe = 0.
// Données FICTIVES, base Mongo en mémoire, vrai boardSignals.
process.env.NODE_ENV = 'test';
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let ActivityEvent; let boardSignals;
const H = 3600000;
const ins = async (M, doc) => String((await M.collection.insertOne(doc)).insertedId);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); ActivityEvent = require('../src/models/ActivityEvent');
  ({ boardSignals } = require('../src/utils/ownerReturn2610'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

test('par canal depuis la publication, scripts et sessions d’avant exclus ; jamais revenu = 0 ; +test / équipe = 0', async () => {
  const now = Date.now(); const pub = new Date(now - 48 * H);
  const real = await ins(Owner, { name: 'Réel', email: 'reel3110@example.org', status: 'active' });
  const never = await ins(Owner, { name: 'Absent', email: 'absent3110@example.org', status: 'active' });
  const test = await ins(Owner, { name: 'Test', email: 'dadaciao84+testowner3110@gmail.com', status: 'active' });
  const staff = await ins(Owner, { name: 'Equipe', email: 'equipe3110@example.org', status: 'active', isStaff: true });
  const ev = (userId, agoH, extra) => ActivityEvent.create({ userId, role: 'owner', at: new Date(now - agoH * H), ...extra });
  await ev(real, 72, { origin: 'web', appVersion: 'web' });                 // avant la publication : non compté
  await ev(real, 30, { origin: 'web', appVersion: 'web' });
  await ev(real, 20, { origin: 'app', appVersion: '23.1.597+631' });
  await ev(real, 5, { origin: 'web', appVersion: 'web' });                  // la dernière
  await ev(real, 2, { origin: 'script', appVersion: 'web' });               // nos scripts : jamais comptés
  await ev(never, 60, { origin: 'app', appVersion: '23.1.597+631' });       // revenu AVANT seulement
  await ev(test, 3, { origin: 'app', appVersion: '23.1.597+631' });
  await ev(staff, 3, { origin: 'web', appVersion: 'web' });
  const item = (id, n) => ({ postId: `p${n}`, owner: { id }, stages: { published: { at: pub } } });
  const m = await boardSignals([item(real, 1), item(never, 2), item(test, 3), item(staff, 4)]);
  const r = m.get('p1');
  expect(r.sessionsByChannel).toEqual({ web: 2, app: 1 });
  expect(r.realSessionsSincePublish).toBe(3);
  expect(new Date(r.lastReturnSincePublishAt).getTime()).toBe(now - 5 * H);
  expect(r.lastReturnSincePublishChannel).toBe('web');
  expect(r.internalOwner).toBe(false);
  const nv = m.get('p2');
  expect(nv.sessionsByChannel).toEqual({ web: 0, app: 0 });
  expect(nv.lastReturnSincePublishAt).toBeNull();
  expect(nv.lastRealReturnAt).toBeTruthy(); // revenu avant la demande : visible, mais pas « depuis la publication »
  for (const k of ['p3', 'p4']) {
    expect(m.get(k).internalOwner).toBe(true);
    expect(m.get(k).sessionsByChannel).toEqual({ web: 0, app: 0 });
    expect(m.get(k).lastReturnSincePublishAt).toBeNull();
  }
});
