// 2910 (BOB) — Daniel : « sa candidature est devant tout le monde ? » : dans la liste des
// candidats du PROPRIÉTAIRE (/applications/my), les candidats au PawBoost actif passent en tête,
// puis du plus récent au plus ancien. Le gardien voit ses candidatures dans l'ordre habituel.
process.env.NODE_ENV = 'test';
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => ({ ok: true })), sendEmailOnly: jest.fn(async () => ({ sent: true })) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Walker; let Application; let ctl;
const DAY = 86400000;
const PASS = 'MotDePasse2910!';
const call = (user) => new Promise((resolve) => {
  const res = { status() { return this; }, json: (b) => resolve(b) };
  ctl.listApplications({ user, query: {} }, res);
});

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Application = require('../src/models/Application');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Application.init()]);
  ctl = require('../src/controllers/applicationController');
});
afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });

test('boosté en tête chez le propriétaire, ordre par date sinon', async () => {
  const o = await Owner.create({ name: 'O', email: 'o2910@example.org', password: PASS });
  const old = await Sitter.create({ name: 'Ancien', email: 's1_2910@example.org', password: PASS });
  const boost = await Sitter.create({ name: 'Agnes', email: 's2_2910@example.org', password: PASS, boostExpiry: new Date(Date.now() + 10 * DAY), boostTier: 'platinum' });
  const recent = await Walker.create({ name: 'Recent', email: 'w1_2910@example.org', password: PASS });
  const expired = await Sitter.create({ name: 'Expire', email: 's3_2910@example.org', password: PASS, boostExpiry: new Date(Date.now() - DAY) });
  const t = Date.now();
  const mk = (extra, ms) => Application.create({ ownerId: o._id, status: 'pending', createdAt: new Date(t - ms), ...extra });
  await mk({ sitterId: boost._id }, 5 * DAY);
  await mk({ sitterId: old._id }, 3 * DAY);
  await mk({ walkerId: recent._id }, 1 * DAY);
  await mk({ sitterId: expired._id }, 2 * DAY);
  const r = await call({ id: String(o._id), role: 'owner' });
  const ids = r.applications.map((a) => String((a.sitter && (a.sitter.id || a.sitter._id)) || (a.walker && (a.walker.id || a.walker._id)) || a.sitterId || a.walkerId));
  expect(ids[0]).toBe(String(boost._id));
  expect(ids.slice(1)).toEqual([String(recent._id), String(expired._id), String(old._id)]);
});
