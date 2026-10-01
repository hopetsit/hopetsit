// 607 (ZOE, 02/10/2026) — e-mail « review_after_booking » : la phrase « ton code de
// parrainage est dans ton profil » n'est plus envoyée à une personne dont la dernière
// app connue est iOS ≥ 607 (codes de parrainage masqués sur iPhone/iPad).
// Vraie base Mongo en mémoire, vrai planificateur ; l'envoi d'e-mail et la liste des
// réservations terminées sont simulés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockMails = [];
jest.mock('../src/services/emailService', () => ({
  sendEmail: jest.fn(async (to, subject, text, html) => { mockMails.push({ to, subject, text, html }); return true; }),
}));
const mockBookings = [];
jest.mock('../src/models/Booking', () => ({
  find: jest.fn(() => ({ select: () => ({ limit: () => ({ lean: async () => mockBookings }) }) })),
  countDocuments: jest.fn(async () => 1),
}));

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let sched;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  await Promise.all([Owner.init(), Sitter.init(), require('../src/models/LifecycleEmail').init()]);
  sched = require('../src/services/lifecycleEmailScheduler');
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

test('le paragraphe retiré est bien celui du parrainage, dans les 9 langues', () => {
  for (const l of LANGS) {
    const tpl = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'src', 'locales', l, 'lifecycle.json'), 'utf8')).review_after_booking;
    expect(tpl.paragraphs).toHaveLength(2);
    expect(tpl.paragraphs[sched.REVIEW_REFERRAL_PARAGRAPH]).toMatch(/PawPoints/);
    const kept = sched.paragraphsFor(tpl, { omitReferral: true });
    expect(kept).toEqual([tpl.paragraphs[0]]);
    expect(kept.join(' ')).not.toMatch(/PawPoints/);
    expect(sched.paragraphsFor(tpl)).toEqual(tpl.paragraphs);
  }
});

async function scenario(platform, build, i) {
  const email = `revmail607_${i}@example.test`;
  const o = await Owner.create({ name: `Marie Test${i}`, email, password: 'MotDePasse607!', appLocale: 'fr' });
  await Owner.collection.updateOne({ _id: o._id }, { $set: {
    createdAt: new Date('2026-08-01T00:00:00Z'),
    fcmDevices: [{ token: `t${i}`, platform, appBuild: build, at: new Date() }],
  } });
  mockBookings.length = 0;
  mockBookings.push({ _id: new mongoose.Types.ObjectId(), ownerId: o._id });
  mockMails.length = 0;
  await sched.runLifecycleOnce({ max: 5 });
  return mockMails.filter((m) => m.to === email);
}

test('iPhone app 607 : e-mail envoyé SANS la phrase du code de parrainage', async () => {
  const m = await scenario('ios', 607, 1);
  expect(m).toHaveLength(1);
  expect(m[0].html).toMatch(/avis sur le profil/);
  expect(m[0].html).not.toMatch(/code de parrainage/);
  expect(m[0].text).not.toMatch(/code de parrainage/);
});

test('iPhone app 606 et Android : inchangé (la phrase reste)', async () => {
  for (const [p, b, i] of [['ios', 606, 2], ['android', 610, 3]]) {
    const m = await scenario(p, b, i);
    expect(m).toHaveLength(1);
    expect(m[0].html).toMatch(/code de parrainage/);
  }
});
