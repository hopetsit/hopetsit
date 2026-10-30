// 2910 (BOB) — Daniel : « les abonnements et achats doivent suivre les 3 profils ».
// Un boost acheté sur un profil est recopié sur les autres profils de la même personne.
process.env.NODE_ENV = 'test';
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Walker; let sync;
const DAY = 86400000;
let n = 0;
async function person(extraW = {}, extraS = {}, extraO = {}) {
  n += 1; const email = `bs2910_${n}@example.org`; const pw = 'MotDePasse2910!';
  const o = await Owner.create({ name: 'P', email, password: pw, ...extraO });
  const s = await Sitter.create({ name: 'P', email, password: pw, ...extraS });
  const w = await Walker.create({ name: 'P', email, password: pw, ...extraW });
  return { o, s, w, email };
}

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init()]);
  sync = require('../src/services/boostSync2910');
});
afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });

test('boost acheté en promeneuse → gardienne et propriétaire boostées, sans ligne d’achat', async () => {
  const until = new Date(Date.now() + 30 * DAY);
  const p = await person({ boostExpiry: until, boostTier: 'platinum', boostPurchases: [{ tier: 'platinum', amount: 19.99 }] });
  const r = await sync.syncAllActiveBoosts();
  expect(r.changed).toBe(2);
  for (const M of [Sitter, Owner]) {
    const d = await M.findOne({ email: p.email }).lean();
    expect(new Date(d.boostExpiry).getTime()).toBe(until.getTime());
    expect(d.boostTier).toBe('platinum');
    expect(d.boostPurchases || []).toHaveLength(0);
  }
  expect((await Walker.findById(p.w._id).lean()).boostPurchases).toHaveLength(1);
});

test('jamais raccourci, boost expiré ignoré, 2e passe sans effet', async () => {
  const longer = new Date(Date.now() + 60 * DAY);
  const p = await person({ boostExpiry: new Date(Date.now() + 10 * DAY), boostTier: 'bronze' }, { boostExpiry: longer, boostTier: 'gold' }, { boostExpiry: new Date(Date.now() - DAY), boostTier: 'silver' });
  await sync.syncBoostsForEmail(p.email);
  expect(new Date((await Sitter.findById(p.s._id).lean()).boostExpiry).getTime()).toBe(longer.getTime());
  const w = await Walker.findById(p.w._id).lean();
  expect(new Date(w.boostExpiry).getTime()).toBe(longer.getTime());
  expect(w.boostTier).toBe('gold');
  expect(await sync.syncBoostsForEmail(p.email)).toBe(0);
});

test('boost carte recopié avec sa position quand l’autre profil n’en a pas', async () => {
  const until = new Date(Date.now() + 7 * DAY);
  const p = await person({}, { mapBoostExpiry: until, mapBoostTier: 'gold', mapBoostLocation: { type: 'Point', coordinates: [2.35, 48.85], label: 'Paris' } });
  await sync.syncBoostsForUser(p.s._id, 'Sitter');
  const w = await Walker.findById(p.w._id).lean();
  expect(new Date(w.mapBoostExpiry).getTime()).toBe(until.getTime());
  expect(w.mapBoostLocation.coordinates).toEqual([2.35, 48.85]);
});

test('une autre personne n’est jamais touchée', async () => {
  const a = await person({ boostExpiry: new Date(Date.now() + 5 * DAY), boostTier: 'gold' });
  const b = await person();
  await sync.syncAllActiveBoosts();
  expect((await Sitter.findById(b.s._id).lean()).boostExpiry || null).toBeNull();
  expect((await Sitter.findById(a.s._id).lean()).boostExpiry).toBeTruthy();
});

test('identité vérifiée sur la gardienne → promeneuse ET propriétaire ont le badge, jamais l’inverse', async () => {
  const p = await person({ kycStatus: 'pending_payment' }, { kycStatus: 'verified', kycVerifiedAt: new Date('2026-10-28T16:22:50Z'), kycApplicantId: 'didit-1', identityVerification: { status: 'verified' } });
  expect(await sync.syncKycForEmail(p.email)).toBe(2);
  const w = await Walker.findById(p.w._id).lean();
  expect(w.kycStatus).toBe('verified');
  expect(w.kycApplicantId).toBe('didit-1');
  expect(w.identityVerification.status).toBe('verified');
  // 3010 — le profil propriétaire reçoit aussi le badge.
  expect((await Owner.findById(p.o._id).lean()).kycStatus).toBe('verified');
  expect(await sync.syncKycForEmail(p.email)).toBe(0);
  const q = await person({ kycStatus: 'rejected' }, { kycStatus: 'pending_payment' });
  expect(await sync.syncKycForEmail(q.email)).toBe(0);
  expect((await Walker.findById(q.w._id).lean()).kycStatus).toBe('rejected');
});

test('la passe complète recopie aussi l’identité', async () => {
  const p = await person({}, { kycStatus: 'verified' });
  await sync.syncAllActiveBoosts();
  expect((await Walker.findById(p.w._id).lean()).kycStatus).toBe('verified');
});

test('3010 : un propriétaire seul « vérifié » ne contamine jamais gardien/promeneur (la source est toujours un prestataire)', async () => {
  const p = await person({}, {}, { kycStatus: 'verified' });
  expect(await sync.syncKycForEmail(p.email)).toBe(0);
  expect((await Sitter.findById(p.s._id).lean()).kycStatus).toBe('none');
});
